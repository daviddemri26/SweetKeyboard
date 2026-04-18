import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        case keyboardCopy
        case manualImport
    }

    let id: UUID
    let text: String
    let createdAt: Date
    let source: Source

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        source: Source
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.source = source
    }
}
