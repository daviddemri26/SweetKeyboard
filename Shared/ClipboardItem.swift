import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        case keyboardCopy
        case systemPasteboardImport

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)

            switch rawValue {
            case Self.keyboardCopy.rawValue, "manualImport":
                self = .keyboardCopy
            case Self.systemPasteboardImport.rawValue:
                self = .systemPasteboardImport
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unsupported clipboard item source: \(rawValue)"
                )
            }
        }
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
