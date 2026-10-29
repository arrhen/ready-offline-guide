import Foundation
import Observation

public enum DownloadState: Equatable, Sendable {
    case downloading(Double)
    case paused(Double)
    case verifying
    case failed(String)
}

/// Receives URLSession callbacks (on a background queue) and forwards them as plain events.
final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let store: ModelStore
    var onProgress: (@Sendable (String, Double) -> Void)?
    var onDownloaded: (@Sendable (String) -> Void)?
    var onFailed: (@Sendable (String, String, Data?) -> Void)?
    var onBackgroundFinished: (@Sendable () -> Void)?

    init(store: ModelStore) {
        self.store = store
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64,
                    totalBytesWritten written: Int64, totalBytesExpectedToWrite expected: Int64) {
        guard let id = downloadTask.taskDescription, expected > 0 else { return }
        onProgress?(id, Double(written) / Double(expected))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            onFailed?(id, "The server returned an error (\(http.statusCode)).", nil)
            return
        }
        // The temporary file is deleted when this method returns, so move it now.
        let partial = store.partialURL(forModelID: id)
        do {
            try store.prepare()
            try? FileManager.default.removeItem(at: partial)
            try FileManager.default.moveItem(at: location, to: partial)
        } catch {
            onFailed?(id, "Couldn't save the download.", nil)
            return
        }
        onDownloaded?(id)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let id = task.taskDescription else { return }
        let ns = error as NSError
        // Pausing and cancelling are handled by the caller.
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return }
        onFailed?(id, "The download stopped: \(error.localizedDescription)",
                  ns.userInfo[NSURLSessionDownloadTaskResumeData] as? Data)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        onBackgroundFinished?()
    }
}

/// Downloads models in a background session (so it continues with the screen off), lets the
/// user pause and resume, and installs only files that pass the size and checksum checks.
@MainActor @Observable
public final class ModelDownloader {
    public static let shared = ModelDownloader()

    /// Free space to keep after a download finishes.
    static let minimumFreeAfter: Int64 = 1_000_000_000
    private static let cellularKey = "allowsCellularDownloads"

    /// Models with a download in progress, paused or failed. Installed models have no entry.
    public private(set) var states: [String: DownloadState] = [:]
    public private(set) var installedIDs: Set<String> = []
    /// Wi-Fi only unless the user opts in. Applies to downloads started afterwards.
    public var allowsCellular: Bool {
        didSet { UserDefaults.standard.set(allowsCellular, forKey: Self.cellularKey) }
    }
    @ObservationIgnored public var backgroundCompletion: (() -> Void)?

    @ObservationIgnored private let store: ModelStore
    @ObservationIgnored private let catalog: [ModelOption]
    @ObservationIgnored private let delegate: DownloadDelegate
    @ObservationIgnored private var session: URLSession!
    @ObservationIgnored private var tasks: [String: URLSessionDownloadTask] = [:]
    @ObservationIgnored private var resumeData: [String: Data] = [:]

    public init(store: ModelStore = ModelStore(), catalog: [ModelOption] = ModelCatalog.all,
                sessionID: String = "com.arrhen.ready.downloads") {
        self.store = store
        self.catalog = catalog
        self.delegate = DownloadDelegate(store: store)
        self.allowsCellular = UserDefaults.standard.bool(forKey: Self.cellularKey)

        // Wire the callbacks first: a relaunch for a finished download can deliver events
        // as soon as the session exists.
        delegate.onProgress = { [weak self] id, p in Task { @MainActor in self?.setProgress(id, p) } }
        delegate.onDownloaded = { [weak self] id in Task { @MainActor in self?.downloaded(id) } }
        delegate.onFailed = { [weak self] id, message, data in Task { @MainActor in self?.failed(id, message, data) } }
        delegate.onBackgroundFinished = { [weak self] in
            Task { @MainActor in
                self?.backgroundCompletion?()
                self?.backgroundCompletion = nil
            }
        }

        let config = URLSessionConfiguration.background(withIdentifier: sessionID)
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        try? store.prepare()
        refreshInstalled()
        reattach()
    }

    public func isInstalled(_ model: ModelOption) -> Bool { installedIDs.contains(model.id) }

    public func refreshInstalled() {
        installedIDs = Set(catalog.filter { store.isInstalled($0) }.map(\.id))
    }

    /// Starts a download, or continues a paused or failed one.
    public func start(_ model: ModelOption) {
        guard !isInstalled(model), tasks[model.id] == nil else { return }
        let free = DeviceProfile.current().freeStorageBytes
        guard free >= model.downloadBytes + Self.minimumFreeAfter else {
            states[model.id] = .failed("Not enough free space. Free up some storage and try again.")
            return
        }
        do { try store.prepare() } catch {
            states[model.id] = .failed("Couldn't create the models folder.")
            return
        }
        let task: URLSessionDownloadTask
        if let data = resumeData.removeValue(forKey: model.id) {
            task = session.downloadTask(withResumeData: data)
        } else {
            var request = URLRequest(url: model.downloadURL)
            request.allowsCellularAccess = allowsCellular
            task = session.downloadTask(with: request)
        }
        task.taskDescription = model.id
        tasks[model.id] = task
        states[model.id] = .downloading(progress(of: model.id))
        task.resume()
    }

    public func pause(_ model: ModelOption) {
        guard let task = tasks[model.id] else { return }
        let id = model.id
        task.cancel { [weak self] data in Task { @MainActor in self?.paused(id, data) } }
    }

    public func cancel(_ model: ModelOption) {
        tasks.removeValue(forKey: model.id)?.cancel()
        resumeData[model.id] = nil
        states[model.id] = nil
        try? FileManager.default.removeItem(at: store.partialURL(forModelID: model.id))
    }

    public func delete(_ model: ModelOption) {
        try? store.delete(model)
        refreshInstalled()
    }

    public func installedSize(of model: ModelOption) -> Int64 {
        store.installedSize(of: model) ?? 0
    }

    // MARK: Events

    private func progress(of id: String) -> Double {
        switch states[id] {
        case .downloading(let p), .paused(let p): p
        default: 0
        }
    }

    private func setProgress(_ id: String, _ p: Double) {
        guard case .downloading = states[id] else { return }
        states[id] = .downloading(p)
    }

    private func paused(_ id: String, _ data: Data?) {
        tasks[id] = nil
        if let data {
            resumeData[id] = data
            states[id] = .paused(progress(of: id))
        } else {
            // The server can't resume, so the next start begins again.
            states[id] = nil
        }
    }

    private func failed(_ id: String, _ message: String, _ data: Data?) {
        tasks[id] = nil
        if let data {
            resumeData[id] = data
            states[id] = .paused(progress(of: id))
        } else {
            states[id] = .failed(message)
        }
    }

    private func downloaded(_ id: String) {
        tasks[id] = nil
        resumeData[id] = nil
        guard let model = catalog.first(where: { $0.id == id }) else { return }
        states[id] = .verifying
        let store = store
        Task.detached {
            let result = Result { try store.install(downloaded: store.partialURL(forModelID: id), model: model) }
            await self.installFinished(id, result)
        }
    }

    private func installFinished(_ id: String, _ result: Result<Void, Error>) {
        switch result {
        case .success:
            states[id] = nil
            installedIDs.insert(id)
        case .failure(let error):
            states[id] = .failed(error.localizedDescription)
        }
    }

    /// Picks up downloads that kept running while the app was closed.
    private func reattach() {
        session.getAllTasks { [weak self] running in
            Task { @MainActor in
                guard let self else { return }
                for case let task as URLSessionDownloadTask in running {
                    guard let id = task.taskDescription, task.state == .running || task.state == .suspended else { continue }
                    self.tasks[id] = task
                    let expected = task.countOfBytesExpectedToReceive
                    self.states[id] = .downloading(expected > 0 ? Double(task.countOfBytesReceived) / Double(expected) : 0)
                }
            }
        }
    }
}
