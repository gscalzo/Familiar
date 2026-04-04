import FamiliarDomain
import FamiliarInfrastructure
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @Environment(PetManager.self) private var petManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(petManager.loadedPetData?.header.petName ?? "Familiar")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            Divider()

            Button("Add Pet") { petManager.addPet() }
                .keyboardShortcut("n")
                .padding(.horizontal)

            Button("Load Custom Pet...") { loadCustomPet() }
                .keyboardShortcut("o")
                .padding(.horizontal)

            if !petManager.activePets.isEmpty {
                Divider()

                Text("Active Pets (\(petManager.activePets.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ForEach(petManager.activePets) { pet in
                    HStack {
                        Text("\(petManager.loadedPetData?.header.petName ?? "Pet") #\(petIndex(pet) + 1)")
                        Spacer()
                        Button(
                            action: { petManager.removePet(id: pet.id) },
                            label: { Image(systemName: "xmark.circle") }
                        )
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
            }

            Divider()

            Button(petManager.isPaused ? "Resume All" : "Pause All") {
                petManager.togglePause()
            }
            .keyboardShortcut("p")
            .padding(.horizontal)

            Button("Reset Positions") { petManager.resetPositions() }
                .keyboardShortcut("r")
                .padding(.horizontal)

            Divider()

            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .frame(width: 220)
    }

    private func petIndex(_ pet: PetInstance) -> Int {
        petManager.activePets.firstIndex(where: { $0.id == pet.id }) ?? 0
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
