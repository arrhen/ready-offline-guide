import Foundation
import Testing
@testable import ReadyCore

// SHA-256 of the ASCII bytes "hello".
private let helloHash = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

private func model(bytes: Int64 = 5, sha: String = helloHash) -> ModelOption {
    ModelOption(id: "test", name: "Test", tier: .tiny, downloadBytes: bytes, runtimeBytes: 0,
                license: "MIT", source: "x/y", downloadURL: URL(string: "https://example.com/t.gguf")!, sha256: sha)
}

private func tempStore() throws -> ModelStore {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let store = ModelStore(directory: dir)
    try store.prepare()
    return store
}

private func partial(_ store: ModelStore, _ text: String) throws -> URL {
    let url = store.partialURL(forModelID: "test")
    try Data(text.utf8).write(to: url)
    return url
}

@Suite struct ModelStoreTests {
    @Test func installsVerifiedFile() throws {
        let store = try tempStore()
        let m = model()
        try store.install(downloaded: try partial(store, "hello"), model: m)
        #expect(store.isInstalled(m))
        #expect(!FileManager.default.fileExists(atPath: store.partialURL(forModelID: "test").path))
    }

    @Test func rejectsWrongChecksumAndDeletesFile() throws {
        let store = try tempStore()
        let m = model()
        #expect(throws: InstallError.checksumMismatch) {
            try store.install(downloaded: try partial(store, "jello"), model: m)
        }
        #expect(!store.isInstalled(m))
        #expect(!FileManager.default.fileExists(atPath: store.partialURL(forModelID: "test").path))
    }

    @Test func rejectsWrongSize() throws {
        let store = try tempStore()
        #expect(throws: InstallError.sizeMismatch) {
            try store.install(downloaded: try partial(store, "hello!"), model: model())
        }
    }

    @Test func deleteRemovesInstalledAndPartial() throws {
        let store = try tempStore()
        let m = model()
        try store.install(downloaded: try partial(store, "hello"), model: m)
        _ = try partial(store, "half")
        try store.delete(m)
        #expect(!store.isInstalled(m))
        #expect(!FileManager.default.fileExists(atPath: store.partialURL(forModelID: "test").path))
    }

    @Test func prepareExcludesFolderFromBackup() throws {
        let store = try tempStore()
        let values = try store.directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func catalogLoadsWithPinnedHTTPSURLsAndValidHashes() {
        #expect(ModelCatalog.all.count == 3)
        #expect(Set(ModelCatalog.all.map(\.tier)) == Set(Tier.allCases))
        for m in ModelCatalog.all {
            #expect(m.downloadURL.scheme == "https")
            #expect(m.downloadURL.absoluteString.contains("/resolve/"))
            #expect(m.sha256.count == 64 && m.sha256.allSatisfy(\.isHexDigit))
            #expect(m.downloadBytes > 0)
        }
    }
}
