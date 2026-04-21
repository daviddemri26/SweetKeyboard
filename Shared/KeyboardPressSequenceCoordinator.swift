import Foundation

enum SequencedKeyboardLayoutTarget: Equatable {
    case letters
    case symbols
}

enum SequencedKeyKind: Equatable {
    case text(String)
    case shift
    case layoutSwitch(SequencedKeyboardLayoutTarget)
    case primaryAction
}

enum SequencedKeyEffect: Equatable {
    case insertText(String)
    case toggleShift
    case setKeyboardLayout(SequencedKeyboardLayoutTarget)
    case insertPrimaryAction
}

enum SymbolKeyboardPostAction: Equatable {
    case characterInsertion
    case settings
    case space
    case backspace
    case cursorMovement
    case primaryAction
}

func shouldReturnToLetterKeyboardAfterSymbolsAction(
    _ action: SymbolKeyboardPostAction,
    isSymbolLockEnabled: Bool
) -> Bool {
    switch action {
    case .characterInsertion:
        return !isSymbolLockEnabled
    case .settings:
        return true
    case .space, .backspace, .cursorMovement, .primaryAction:
        return false
    }
}

struct KeyboardPressSequenceCoordinator {
    private struct PendingInteraction: Equatable {
        let id: ObjectIdentifier
        let kind: SequencedKeyKind
    }

    private var pendingInteraction: PendingInteraction?

    var hasPendingInteraction: Bool {
        pendingInteraction != nil
    }

    mutating func handleTouchDown(id: ObjectIdentifier, kind: SequencedKeyKind) -> [SequencedKeyEffect] {
        let effects = commitPendingInteractionBeforeTouchDown(id: id)
        beginPendingInteraction(id: id, kind: kind)
        return effects
    }

    mutating func commitPendingInteractionBeforeTouchDown(id: ObjectIdentifier) -> [SequencedKeyEffect] {
        guard let pendingInteraction, pendingInteraction.id != id else {
            return []
        }

        self.pendingInteraction = nil
        return effects(for: pendingInteraction.kind)
    }

    mutating func beginPendingInteraction(id: ObjectIdentifier, kind: SequencedKeyKind) {
        pendingInteraction = PendingInteraction(id: id, kind: kind)
    }

    mutating func handleTouchUpInside(id: ObjectIdentifier) -> [SequencedKeyEffect] {
        guard let pendingInteraction, pendingInteraction.id == id else {
            return []
        }

        self.pendingInteraction = nil
        return effects(for: pendingInteraction.kind)
    }

    mutating func handleTouchCancelled(id: ObjectIdentifier) {
        guard let pendingInteraction, pendingInteraction.id == id else {
            return
        }

        self.pendingInteraction = nil
    }

    mutating func cancelAll() {
        pendingInteraction = nil
    }

    private func effects(for kind: SequencedKeyKind) -> [SequencedKeyEffect] {
        switch kind {
        case .text(let text):
            return [.insertText(text)]
        case .shift:
            return [.toggleShift]
        case .layoutSwitch(let target):
            return [.setKeyboardLayout(target)]
        case .primaryAction:
            return [.insertPrimaryAction]
        }
    }
}
