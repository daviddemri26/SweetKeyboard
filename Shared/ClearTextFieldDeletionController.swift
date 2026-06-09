import UIKit

@MainActor
protocol ClearTextDocumentProxy: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    var selectedText: String? { get }
    var hasText: Bool { get }

    func adjustTextPosition(byCharacterOffset offset: Int)
    func deleteBackward()
}

@MainActor
final class UITextDocumentProxyClearTextAdapter: ClearTextDocumentProxy {
    private let proxy: any UITextDocumentProxy

    init(_ proxy: any UITextDocumentProxy) {
        self.proxy = proxy
    }

    var documentContextBeforeInput: String? {
        proxy.documentContextBeforeInput
    }

    var documentContextAfterInput: String? {
        proxy.documentContextAfterInput
    }

    var selectedText: String? {
        proxy.selectedText
    }

    var hasText: Bool {
        proxy.hasText
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        proxy.adjustTextPosition(byCharacterOffset: offset)
    }

    func deleteBackward() {
        proxy.deleteBackward()
    }
}

struct ClearTextFieldDeletionBatchResult: Equatable {
    enum Status: Equatable {
        case complete
        case needsAnotherBatch
        case stalled
        case reachedBatchLimit
    }

    let status: Status
    let operationCount: Int
}

@MainActor
struct ClearTextFieldDeletionController {
    private let maximumOperationsPerBatch: Int
    private let maximumBatchCount: Int
    private let maximumCursorNudgeAttempts: Int
    private let maximumCompletionNudgeAttempts: Int
    private var completedBatchCount = 0
    private var consecutiveCursorNudgeCount = 0
    private var consecutiveCompletionNudgeCount = 0
    private var hasMadeTextProgress = false

    init(
        maximumOperationsPerBatch: Int = 120,
        maximumBatchCount: Int = 1_000,
        maximumCursorNudgeAttempts: Int = 64,
        maximumCompletionNudgeAttempts: Int = 3
    ) {
        self.maximumOperationsPerBatch = max(1, maximumOperationsPerBatch)
        self.maximumBatchCount = max(1, maximumBatchCount)
        self.maximumCursorNudgeAttempts = max(0, maximumCursorNudgeAttempts)
        self.maximumCompletionNudgeAttempts = max(0, maximumCompletionNudgeAttempts)
    }

    mutating func performNextBatch(on proxy: ClearTextDocumentProxy) -> ClearTextFieldDeletionBatchResult {
        guard completedBatchCount < maximumBatchCount else {
            return ClearTextFieldDeletionBatchResult(status: .reachedBatchLimit, operationCount: 0)
        }

        completedBatchCount += 1
        var operationCount = 0

        while operationCount < maximumOperationsPerBatch {
            if let selectedText = proxy.selectedText, !selectedText.isEmpty {
                proxy.deleteBackward()
                recordTextProgress()
                operationCount += 1
                continue
            }

            if let followingText = proxy.documentContextAfterInput, !followingText.isEmpty {
                proxy.adjustTextPosition(byCharacterOffset: followingText.count)
                proxy.deleteBackward()
                recordTextProgress()
                operationCount += 2
                continue
            }

            if let precedingText = proxy.documentContextBeforeInput, !precedingText.isEmpty {
                proxy.deleteBackward()
                recordTextProgress()
                operationCount += 1
                continue
            }

            if proxy.hasText, nudgeCursorToExposeMoreContext(on: proxy) {
                return ClearTextFieldDeletionBatchResult(
                    status: .needsAnotherBatch,
                    operationCount: operationCount + 1
                )
            }

            if !proxy.hasText, nudgeCursorBeforeCompleting(on: proxy) {
                return ClearTextFieldDeletionBatchResult(
                    status: .needsAnotherBatch,
                    operationCount: operationCount + 1
                )
            }

            return ClearTextFieldDeletionBatchResult(
                status: proxy.hasText ? .stalled : .complete,
                operationCount: operationCount
            )
        }

        if !proxy.hasText {
            return ClearTextFieldDeletionBatchResult(status: .complete, operationCount: operationCount)
        }

        return ClearTextFieldDeletionBatchResult(status: .needsAnotherBatch, operationCount: operationCount)
    }

    private mutating func recordTextProgress() {
        hasMadeTextProgress = true
        consecutiveCursorNudgeCount = 0
        consecutiveCompletionNudgeCount = 0
    }

    private mutating func nudgeCursorToExposeMoreContext(on proxy: ClearTextDocumentProxy) -> Bool {
        guard consecutiveCursorNudgeCount < maximumCursorNudgeAttempts else {
            return false
        }

        let leftAttemptCount = max(1, maximumCursorNudgeAttempts * 3 / 4)
        let offset = consecutiveCursorNudgeCount < leftAttemptCount ? -1 : 1
        consecutiveCursorNudgeCount += 1
        proxy.adjustTextPosition(byCharacterOffset: offset)
        return true
    }

    private mutating func nudgeCursorBeforeCompleting(on proxy: ClearTextDocumentProxy) -> Bool {
        guard hasMadeTextProgress,
              consecutiveCompletionNudgeCount < maximumCompletionNudgeAttempts else {
            return false
        }

        let leftAttemptCount = max(1, maximumCompletionNudgeAttempts - 1)
        let offset = consecutiveCompletionNudgeCount < leftAttemptCount ? -1 : 1
        consecutiveCompletionNudgeCount += 1
        proxy.adjustTextPosition(byCharacterOffset: offset)
        return true
    }
}
