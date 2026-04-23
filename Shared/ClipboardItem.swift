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
    let isPinned: Bool
    let pinnedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case createdAt
        case source
        case isPinned
        case pinnedAt
    }

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        source: Source,
        isPinned: Bool = false,
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.source = source
        self.isPinned = isPinned
        self.pinnedAt = isPinned ? pinnedAt : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedIsPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false

        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        source = try container.decode(Source.self, forKey: .source)
        isPinned = decodedIsPinned
        pinnedAt = decodedIsPinned ? try container.decodeIfPresent(Date.self, forKey: .pinnedAt) : nil
    }

    func withPinState(isPinned: Bool, pinnedAt: Date?) -> ClipboardItem {
        ClipboardItem(
            id: id,
            text: text,
            createdAt: createdAt,
            source: source,
            isPinned: isPinned,
            pinnedAt: pinnedAt
        )
    }
}
