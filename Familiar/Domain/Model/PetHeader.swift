public struct PetHeader: Sendable {
    public let author: String
    public let title: String
    public let petName: String
    public let version: String
    public let info: String

    public init(author: String, title: String, petName: String, version: String, info: String) {
        self.author = author
        self.title = title
        self.petName = petName
        self.version = version
        self.info = info
    }
}
