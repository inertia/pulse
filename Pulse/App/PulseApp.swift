import SwiftUI

@main
struct PulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        SwiftUI.Settings { SettingsView() }   // ⌘, opens settings window
    }
}
