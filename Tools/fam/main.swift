import Foundation

// MARK: - State Model (local, no dependency on FamiliarDomain)

struct PetState: Codable {
    var mood: String
    var event: String?
    var eventTimestamp: String? // ISO 8601 string
}

// MARK: - Constants

let moods: Set<String> = ["chill", "think", "work", "wait", "sleep"]
let events: Set<String> = ["yay", "oops", "hmm", "go", "done"]

let familiarDir = NSHomeDirectory() + "/.familiar"
let stateFile = familiarDir + "/state.json"

// MARK: - State File I/O

func readStates() -> [String: PetState] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: stateFile)) else { return [:] }
    return (try? JSONDecoder().decode([String: PetState].self, from: data)) ?? [:]
}

func writeStates(_ states: [String: PetState]) {
    try? FileManager.default.createDirectory(
        atPath: familiarDir, withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(states) else { return }
    try? data.write(to: URL(fileURLWithPath: stateFile))
}

// MARK: - ISO 8601 Timestamp

func now() -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: Date())
}

// MARK: - Usage

func printUsage() {
    print("""
    fam — control your desktop pet

    USAGE: fam <command> [name]

    MOODS (persistent):
      fam chill [name]       idle / normal wandering
      fam think [name]       contemplating
      fam work [name]        busy, running
      fam wait [name]        patient, munching
      fam sleep [name]       deep sleep

    EVENTS (one-shot):
      fam yay [name]         celebration
      fam oops [name]        stumble
      fam hmm [name]         warning bump
      fam go [name]          energetic start
      fam done [name]        happy finish

    LIFECYCLE:
      fam kill [name]        remove a pet
      fam kill --all         remove all pets

    STATUS:
      fam                    list all pets
      fam help               show this help
    """)
}

// MARK: - Main

let args = CommandLine.arguments.dropFirst() // drop executable path
let command = args.first
let name = args.dropFirst().first ?? "default"

switch command {
case nil:
    // Status: list all pets
    let states = readStates()
    if states.isEmpty {
        print("No pets. Use 'fam chill' to create one.")
    } else {
        for (petName, state) in states.sorted(by: { $0.key < $1.key }) {
            let eventInfo = state.event.map { " (event: \($0))" } ?? ""
            print("  \(petName): \(state.mood)\(eventInfo)")
        }
    }

case "help", "--help", "-h":
    printUsage()

case "kill":
    if name == "--all" {
        writeStates([:])
        print("All pets removed.")
    } else {
        var states = readStates()
        if states.removeValue(forKey: name) != nil {
            writeStates(states)
            print("Removed \(name).")
        } else {
            print("No pet named '\(name)'.")
        }
    }

case let cmd? where moods.contains(cmd):
    var states = readStates()
    var state = states[name] ?? PetState(mood: "chill")
    state.mood = cmd
    state.event = nil
    state.eventTimestamp = nil
    states[name] = state
    writeStates(states)
    print("\(name): \(cmd)")

case let cmd? where events.contains(cmd):
    var states = readStates()
    var state = states[name] ?? PetState(mood: "chill")
    state.event = cmd
    state.eventTimestamp = now()
    states[name] = state
    writeStates(states)
    print("\(name): \(state.mood) + \(cmd)")

default:
    fputs("Unknown command: \(command ?? "")\n", stderr)
    fputs("Run 'fam help' for usage.\n", stderr)
    exit(1)
}
