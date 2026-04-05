import FamiliarDomain
import FamiliarInfrastructure
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @Environment(PetManager.self) private var petManager

    var body: some View {
        Menu("Choose Pet") {
            ForEach(AppDelegate.availablePets(), id: \.self) { name in
                Button(petDisplayName(name)) {
                    petManager.switchPet(named: name)
                }
            }
            Divider()
            Button("Load Custom XML...") { loadCustomPet() }
                .keyboardShortcut("o")
        }

        Button("Add Pet") { petManager.addPet() }
            .keyboardShortcut("n")

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

    private func petDisplayName(_ filename: String) -> String {
        filename
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

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
