import SwiftUI
import UIKit

@main
struct MarginApp: App {
    @StateObject private var store = SettingsStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onOpenURL { url in
                    // margin://open?url=<target> — used by widgets in "via app" launch mode.
                    if let target = Shortcut.target(fromRoutedURL: url) {
                        UIApplication.shared.open(target)
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.flush() }
        }
    }
}
