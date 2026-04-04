import SwiftUI

@main
struct FamiliarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Familiar", systemImage: "pawprint.fill") {
            MenuBarView()
                .environment(appDelegate.petManager)
        }
        .menuBarExtraStyle(.window)
    }
}
