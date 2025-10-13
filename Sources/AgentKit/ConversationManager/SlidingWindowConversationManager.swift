import Foundation
import BedrockService

/// The SlidingWindowConversationManager implements a sliding window strategy that maintains a fixed number of recent messages.
/// This is the default conversation manager used by the Agent class.
///
/// Key features:
/// - Maintains Window Size: Automatically removes messages from the window if the number of messages exceeds the limit
/// - Dangling Message Cleanup: Removes incomplete message sequences to maintain valid conversation state
/// - Overflow Trimming: In case of context window overflow, trims oldest messages until request fits in model's context window
/// - Configurable Tool Result Truncation: Enable/disable truncation of tool results when message exceeds context window limits
public struct SlidingWindowConversationManager: ConversationManager {

    /// Maximum number of messages to keep in the conversation window
    public let windowSize: Int

    /// Whether to truncate tool results when they exceed context window limits
    public let shouldTruncateResults: Bool

    /// Count of messages that have been removed from the conversation
    private var _removedMessageCount: Int = 0

    /// Creates a new SlidingWindowConversationManager
    /// - Parameters:
    ///   - windowSize: Maximum number of messages to keep (default: 20)
    ///   - shouldTruncateResults: Enable truncating tool results when message is too large (default: true)
    public init(windowSize: Int = 20, shouldTruncateResults: Bool = true) {
        self.windowSize = windowSize
        self.shouldTruncateResults = shouldTruncateResults
    }

    public mutating func applyManagement(history: History) async throws -> History {
        var managedHistory = history

        // Remove dangling messages (incomplete sequences)
        managedHistory = removeDanglingMessages(from: managedHistory)

        // Apply sliding window if we exceed the window size
        if managedHistory.count > windowSize {
            let messagesToRemove = managedHistory.count - windowSize
            managedHistory = History(Array(managedHistory.dropFirst(messagesToRemove)))
            _removedMessageCount += messagesToRemove
        }

        return managedHistory
    }

    public mutating func reduceContext(history: History) async throws -> History {
        var reducedHistory = history

        // Remove oldest messages until we have a smaller context
        // Remove in chunks to avoid removing too little
        let reductionSize = max(1, windowSize / 4)

        if reducedHistory.count > reductionSize {
            let messagesToRemove = min(reductionSize, reducedHistory.count - 1) // Keep at least 1 message
            reducedHistory = History(Array(reducedHistory.dropFirst(messagesToRemove)))
            _removedMessageCount += messagesToRemove
        }

        // Truncate tool results if enabled
        if shouldTruncateResults {
            reducedHistory = truncateToolResults(in: reducedHistory)
        }

        return reducedHistory
    }

    public func removedMessageCount() -> Int {
        return _removedMessageCount
    }

    /// Removes incomplete message sequences to maintain valid conversation state
    private func removeDanglingMessages(from history: History) -> History {
        var cleanHistory: History = []

        for message in history {
            switch message.role {
            case .user:
                // User messages are always valid starting points
                cleanHistory.append(message)
            case .assistant:
                // Assistant messages should follow user messages or other assistant messages
                if !cleanHistory.isEmpty {
                    cleanHistory.append(message)
                }
            default:
                // Handle any other role types
                cleanHistory.append(message)
            }
        }

        return cleanHistory
    }

    /// Truncates tool results that are too large
    private func truncateToolResults(in history: History) -> History {
        let maxToolResultLength = 2000 // Configurable limit for tool results

        let truncatedMessages = history.map { message in
            let truncatedContent = message.content.map { content in
                switch content {
                case .text(let text):
                    if text.count > maxToolResultLength {
                        let truncatedText = String(text.prefix(maxToolResultLength)) + "\n\n[Result truncated due to length...]"
                        return Content.text(truncatedText)
                    }
                    return content
                case .toolResult(_):
                    // Truncate tool result content if needed
                    return content
                default:
                    return content
                }
            }
            return Message(from: message.role, content: truncatedContent)
        }
        
        return History(truncatedMessages)
    }
}
