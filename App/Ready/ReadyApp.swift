import SwiftUI
import ReadyCore

/// Lets iOS hand back downloads that finished while the app was not running.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        ModelDownloader.shared.backgroundCompletion = completionHandler
    }
}

@main
struct ReadyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            SetupView()
        }
    }
}
