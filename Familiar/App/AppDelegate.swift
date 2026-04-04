import AppKit
import FamiliarDomain
import FamiliarInfrastructure
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let petManager = PetManager()
    private var activityToken: NSObjectProtocol?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "Desktop pet animation"
        )

        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            if !CGPreflightScreenCaptureAccess() {
                showOnboardingWindow()
                return
            }
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }

        loadDefaultPetAndSpawn()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    private func showOnboardingWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Familiar Setup"
        window.contentView = NSHostingView(rootView: OnboardingView(onComplete: { [weak self] in
            window.close()
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self?.loadDefaultPetAndSpawn()
        }))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func loadDefaultPetAndSpawn() {
        let xmlURL = Bundle.module.url(forResource: "animations", withExtension: "xml")
            ?? Bundle.main.url(forResource: "animations", withExtension: "xml")
        if let url = xmlURL, let data = try? Data(contentsOf: url) {
            try? petManager.loadXML(from: data)
            petManager.addPet()
        }
    }
}
