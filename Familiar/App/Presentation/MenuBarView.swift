import FamiliarDomain
import FamiliarInfrastructure
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @Environment(PetManager.self) private var petManager

    var body: some View {
        Button("Add Pet") { petManager.addPet() }
            .keyboardShortcut("n")

        Button("Load Custom Pet...") { loadCustomPet() }
            .keyboardShortcut("o")

        Divider()

        if !petManager.activePets.isEmpty {
            ForEach(Array(petManager.activePets.enumerated()), id: \.element.id) { index, pet in
                Button("Remove \(petManager.loadedPetData?.header.petName ?? "Pet") #\(index + 1)") {
                    petManager.removePet(id: pet.id)
                }
            }
            Divider()
        }

        Button(petManager.isPaused ? "Resume All" : "Pause All") {
            petManager.togglePause()
        }
        .keyboardShortcut("p")

        Button("Reset Positions") { petManager.resetPositions() }
            .keyboardShortcut("r")

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { LaunchAtLogin.isEnabled = $0 }
        ))

        Button("About Familiar...") { showAbout() }

        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let hostingView = NSHostingView(rootView: AboutView())
        hostingView.setFrameSize(hostingView.fittingSize)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Familiar"
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        aboutWindow = window
    }

    @State private var aboutWindow: NSWindow?

    private func loadCustomPet() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.xml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                try? petManager.loadXML(from: data)
                petManager.removeAll()
                petManager.addPet()
            }
        }
    }
}
