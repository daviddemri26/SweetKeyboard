import Foundation

enum KeyboardShiftState: Equatable {
    case off
    case autoSingle
    case autoPersistent
    case manualSingle
    case manualLocked

    var isActive: Bool {
        self != .off
    }

    var isAutomatic: Bool {
        switch self {
        case .autoSingle, .autoPersistent:
            return true
        case .off, .manualSingle, .manualLocked:
            return false
        }
    }

    var isManual: Bool {
        switch self {
        case .manualSingle, .manualLocked:
            return true
        case .off, .autoSingle, .autoPersistent:
            return false
        }
    }
}

struct KeyboardShiftToggleResult: Equatable {
    let state: KeyboardShiftState
    let lastShiftTapAt: Date?
    let suppressedAutoCapitalizationContext: AutoCapitalizationContext?
}

struct KeyboardShiftStateMachine {
    func toggledState(
        from currentState: KeyboardShiftState,
        lastShiftTapAt: Date?,
        now: Date,
        doubleTapInterval: TimeInterval,
        autoCapitalizationContext: AutoCapitalizationContext?
    ) -> KeyboardShiftToggleResult {
        if let lastShiftTapAt, now.timeIntervalSince(lastShiftTapAt) <= doubleTapInterval {
            if currentState == .manualLocked {
                return KeyboardShiftToggleResult(
                    state: .off,
                    lastShiftTapAt: nil,
                    suppressedAutoCapitalizationContext: autoCapitalizationContext
                )
            }

            return KeyboardShiftToggleResult(
                state: .manualLocked,
                lastShiftTapAt: nil,
                suppressedAutoCapitalizationContext: nil
            )
        }

        switch currentState {
        case .off:
            return KeyboardShiftToggleResult(
                state: .manualSingle,
                lastShiftTapAt: now,
                suppressedAutoCapitalizationContext: nil
            )
        case .autoSingle, .autoPersistent, .manualSingle, .manualLocked:
            return KeyboardShiftToggleResult(
                state: .off,
                lastShiftTapAt: now,
                suppressedAutoCapitalizationContext: autoCapitalizationContext
            )
        }
    }

    func applyingAutoCapitalizationDecision(
        _ decision: AutoCapitalizationDecision,
        to currentState: KeyboardShiftState,
        isSuppressed: Bool
    ) -> KeyboardShiftState {
        guard !currentState.isManual else {
            return currentState
        }

        guard !isSuppressed else {
            return .off
        }

        switch decision {
        case .off:
            return .off
        case .singleLetter:
            return .autoSingle
        case .persistent:
            return .autoPersistent
        }
    }

    func stateAfterCharacterInsertion(
        from currentState: KeyboardShiftState,
        autoCapitalizationDecision: AutoCapitalizationDecision,
        isSuppressed: Bool
    ) -> KeyboardShiftState {
        switch currentState {
        case .manualSingle:
            return .off
        case .manualLocked:
            return .manualLocked
        case .off, .autoSingle, .autoPersistent:
            return applyingAutoCapitalizationDecision(
                autoCapitalizationDecision,
                to: currentState,
                isSuppressed: isSuppressed
            )
        }
    }

    func shouldUseForwardDelete(
        shiftState: KeyboardShiftState,
        isForwardDeleteWithShiftEnabled: Bool
    ) -> Bool {
        isForwardDeleteWithShiftEnabled && shiftState == .manualSingle
    }
}
