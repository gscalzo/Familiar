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
        NSLog("[Familiar] applicationDidFinishLaunching started")
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
        guard let url = xmlURL else {
            NSLog("[Familiar] ERROR: animations.xml not found in bundle")
            return
        }
        NSLog("[Familiar] Loading XML from: \(url.path)")
        do {
            let data = try Data(contentsOf: url)
            try petManager.loadXML(from: data)
            NSLog(
                "[Familiar] XML loaded: \(petManager.loadedPetData?.header.petName ?? "?"), \(petManager.loadedPetData?.animations.count ?? 0) animations"
            )

            // Set up state file and animation config
            let watcher = petManager.stateFileWatcher
            watcher.writeDefaultConfigIfNeeded()
            petManager.loadAnimationConfig()

            // Ensure default state file exists so reconciliation spawns a pet
            if !watcher.stateFileExists() || watcher.readStates().isEmpty {
                watcher.writeStates(["default": PetState.default])
                NSLog("[Familiar] Wrote default state file")
            }

            // Start the timer; reconciliation on first tick will spawn pets from state file
            petManager.ensureTimerStarted()

            NSLog("[Familiar] Pet manager initialized. Reconciliation will spawn pets.")
        } catch {
            NSLog("[Familiar] ERROR loading XML: \(error)")
        }
    }
}
