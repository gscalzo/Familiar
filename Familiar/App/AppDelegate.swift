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

        if needsOnboarding() { return }
        loadDefaultPetAndSpawn()
    }

    private func needsOnboarding() -> Bool {
        guard !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return false }
        guard !CGPreflightScreenCaptureAccess() else {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            return false
        }
        showOnboardingWindow()
        return true
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
        guard let url = findAnimationsXML() else { return }
        NSLog("[Familiar] Loading XML from: \(url.path)")
        do {
            let data = try Data(contentsOf: url)
            try petManager.loadXML(from: data)
            NSLog(
                "[Familiar] XML loaded: \(petManager.loadedPetData?.header.petName ?? "?"), \(petManager.loadedPetData?.animations.count ?? 0) animations"
            )
            setupStateFileAndStart()
        } catch {
            NSLog("[Familiar] ERROR loading XML: \(error)")
        }
    }

    private func findAnimationsXML() -> URL? {
        // Load last-used pet or default to esheep64
        let lastPet = UserDefaults.standard.string(forKey: "lastPetName") ?? "esheep64"
        return Self.findPetXML(named: lastPet) ?? Self.findPetXML(named: "esheep64")
    }

    static func findPetXML(named name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "xml", subdirectory: "Pets")
            ?? Bundle.main.url(forResource: name, withExtension: "xml", subdirectory: "Pets")
    }

    static func availablePets() -> [String] {
        guard let petsURL = Bundle.module.url(forResource: "Pets", withExtension: nil)
            ?? Bundle.main.url(forResource: "Pets", withExtension: nil)
        else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: petsURL, includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.pathExtension == "xml" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    private func setupStateFileAndStart() {
        let watcher = petManager.stateFileWatcher
        watcher.writeDefaultConfigIfNeeded()
        petManager.loadAnimationConfig()

        if !watcher.stateFileExists() || watcher.readStates().isEmpty {
            watcher.writeStates(["default": PetState.default])
            NSLog("[Familiar] Wrote default state file")
        }

        petManager.ensureTimerStarted()
        NSLog("[Familiar] Pet manager initialized. Reconciliation will spawn pets.")
    }
}
