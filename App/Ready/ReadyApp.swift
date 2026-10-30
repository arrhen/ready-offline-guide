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
    @AppStorage("appearance") private var appearanceRaw = AppearanceChoice.system.rawValue
    @AppStorage("legalAckVersion") private var legalAckVersion = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .fullScreenCover(isPresented: Binding(get: { legalAckVersion < Legal.version },
                                                      set: { _ in })) {
                    AcknowledgementView { legalAckVersion = Legal.version }
                }
                .onAppear(perform: applyAppearance)
                .onChange(of: appearanceRaw) { applyAppearance() }
                .onChange(of: scenePhase) { applyAppearance() }
        }
    }

    /// Sets the style on the windows themselves. SwiftUI's preferredColorScheme(nil) doesn't
    /// reset a sheet that is already open, so going back to System would leave it stuck.
    private func applyAppearance() {
        let choice = AppearanceChoice(rawValue: appearanceRaw) ?? .system
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            // The screen's own setting, which a window override doesn't change.
            let systemKnown = scene.screen.traitCollection.userInterfaceStyle != .unspecified
            let style: UIUserInterfaceStyle = switch choice.resolved(systemKnown: systemKnown) {
            case .followSystem: .unspecified
            case .light: .light
            case .dark: .dark
            }
            for window in scene.windows { window.overrideUserInterfaceStyle = style }
        }
    }
}
