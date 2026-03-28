import Foundation

actor TranscriptStore {
    private let fileURL: URL?
    private var newestRevision = 0

    init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    static func live() -> TranscriptStore {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let fileURL = supportDirectory?.appending(path: "chat_snapshot.json")
        return TranscriptStore(fileURL: fileURL)
    }

    static func preview() -> TranscriptStore {
        TranscriptStore(fileURL: nil)
    }

    func load() throws -> ConversationSnapshot? {
        guard let fileURL else { return nil }
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ConversationSnapshot.self, from: data)
    }

    func save(_ snapshot: ConversationSnapshot) throws {
        guard let fileURL else { return }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        guard let fileURL else { return }
        if FileManager.default.fileExists(atPath: fileURL.path()) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    func replace(snapshot: ConversationSnapshot?, revision: Int) throws {
        guard revision >= newestRevision else { return }
        newestRevision = revision

        if let snapshot {
            try save(snapshot)
        } else {
            try clear()
        }
    }
}
