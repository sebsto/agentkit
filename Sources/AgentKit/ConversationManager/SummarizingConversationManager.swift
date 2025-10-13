import BedrockService
import Foundation

/// The SummarizingConversationManager implements intelligent conversation context management by summarizing
/// older messages instead of simply discarding them. This approach preserves important information while staying within context limits.
public struct SummarizingConversationManager: ConversationManager {

    /// Percentage of messages to summarize when reducing context (clamped between 0.1 and 0.8)
    public let summaryRatio: Double

    /// Minimum number of recent messages to always keep
    public let preserveRecentMessages: Int

    /// Custom agent for generating summaries
    public let summarizationAgent: AgentProtocol?

    /// Custom system prompt for summarization
    public let summarizationSystemPrompt: String?

    /// Count of messages that have been removed from the conversation
    private var _removedMessageCount: Int = 0

    /// Default system prompt for summarization
    private static let defaultSummarizationPrompt = """
        You are summarizing a conversation. Create a concise bullet-point summary that:
        - Focuses on key topics, decisions, and important information discussed
        - Preserves technical details, tool usage, and specific data mentioned
        - Omits conversational elements and focuses on actionable information
        - Uses third-person format (e.g., "The user asked about...", "The assistant provided...")

        Format as bullet points without conversational language.
        """

    /// Creates a new SummarizingConversationManager
    /// - Parameters:
    ///   - summaryRatio: Percentage of messages to summarize when reducing context (default: 0.3, clamped between 0.1 and 0.8)
    ///   - preserveRecentMessages: Minimum number of recent messages to always keep (default: 10)
    ///   - summarizationAgent: Custom agent for generating summaries (optional)
    ///   - summarizationSystemPrompt: Custom system prompt for summarization (optional)
    public init(
        summaryRatio: Double = 0.3,
        preserveRecentMessages: Int = 10,
        summarizationAgent: AgentProtocol? = nil,
        summarizationSystemPrompt: String? = nil
    ) {
        self.summaryRatio = max(0.1, min(0.8, summaryRatio))
        self.preserveRecentMessages = preserveRecentMessages
        self.summarizationAgent = summarizationAgent
        self.summarizationSystemPrompt = summarizationSystemPrompt

        // Ensure only one summarization method is provided
        assert(
            summarizationAgent == nil || summarizationSystemPrompt == nil,
            "Cannot use both summarizationAgent and summarizationSystemPrompt"
        )
    }

    public mutating func applyManagement(history: History) async throws -> History {
        // For regular management, we don't need to summarize unless context is exceeded
        history
    }

    public mutating func reduceContext(history: History) async throws -> History {
        guard history.count > preserveRecentMessages else {
            return history
        }

        let messagesToSummarize = Int(Double(history.count) * summaryRatio)
        let actualMessagesToSummarize = min(messagesToSummarize, history.count - preserveRecentMessages)

        guard actualMessagesToSummarize > 0 else {
            return history
        }

        // Split history into messages to summarize and messages to preserve
        let messagesToSummarizeArray = History(Array(history.prefix(actualMessagesToSummarize)))
        let preservedMessages = History(Array(history.dropFirst(actualMessagesToSummarize)))

        // Ensure we don't break tool use/result pairs
        let (cleanMessagesToSummarize, cleanPreservedMessages) = preserveToolPairs(
            toSummarize: messagesToSummarizeArray,
            toPreserve: preservedMessages
        )

        // Generate summary
        let summary = try await generateSummary(for: cleanMessagesToSummarize)

        // Create summary message
        let summaryMessage = Message(
            from: .user,
            content: [.text("Previous conversation summary:\n\(summary)")]
        )

        _removedMessageCount += cleanMessagesToSummarize.count

        return History([summaryMessage]) + Array(cleanPreservedMessages)
    }

    public func removedMessageCount() -> Int {
        _removedMessageCount
    }

    /// Ensures tool use and result message pairs aren't broken during summarization
    private func preserveToolPairs(toSummarize: History, toPreserve: History) -> (History, History) {
        var adjustedToSummarize = toSummarize
        var adjustedToPreserve = toPreserve

        // Check if the last message to summarize is a tool use without its result
        if let lastMessage = adjustedToSummarize.last,
            lastMessage.role == .assistant
        {

            // Check if this message contains tool use
            let hasToolUse = lastMessage.content.contains { content in
                if case .toolUse = content { return true }
                return false
            }

            if hasToolUse {
                // Move this message to preserved to keep it with its result
                var toSummarizeArray = Array(adjustedToSummarize)
                var toPreserveArray = Array(adjustedToPreserve)
                if let movedMessage = toSummarizeArray.popLast() {
                    toPreserveArray.insert(movedMessage, at: 0)
                }
                adjustedToSummarize = History(toSummarizeArray)
                adjustedToPreserve = History(toPreserveArray)
            }
        }

        return (adjustedToSummarize, adjustedToPreserve)
    }

    /// Generates a summary for the given messages
    private func generateSummary(for messages: History) async throws -> String {
        guard !messages.isEmpty else {
            return "No previous conversation to summarize."
        }

        // Convert messages to text for summarization
        let conversationText = messages.map { message in
            let roleText = message.role.description.capitalized
            let contentText = extractTextContent(from: message.content)
            return "\(roleText): \(contentText)"
        }.joined(separator: "\n\n")

        let prompt = "Please summarize the following conversation:\n\n\(conversationText)"

        // Use custom agent if provided, otherwise create a simple summarization request
        if let customAgent = summarizationAgent {
            // Use the custom agent for summarization
            var summaryResult = ""
            try await customAgent(prompt) { event in
                if case .text(let text) = event {
                    summaryResult += text
                }
            }
            return summaryResult.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Use a simple text-based summary (in a real implementation, this would use the main agent)
            return generateSimpleSummary(from: messages)
        }
    }

    /// Extracts text content from message content
    private func extractTextContent(from content: [Content]) -> String {
        content.compactMap { content in
            switch content {
            case .text(let text):
                return text
            case .toolUse(let toolUse):
                return "Used tool: \(toolUse.name)"
            case .toolResult(let result):
                return "Tool result: \(result.id)"
            default:
                return nil
            }
        }.joined(separator: " ")
    }

    /// Generates a simple summary without using an agent (fallback)
    private func generateSimpleSummary(from messages: History) -> String {
        var topics: Set<String> = []
        var toolsUsed: Set<String> = []
        var keyPoints: [String] = []

        for message in messages {
            let content = extractTextContent(from: message.content)

            // Extract potential topics (simple keyword extraction)
            let words = content.lowercased().components(
                separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
            )
            let significantWords = words.filter { $0.count > 4 }
            topics.formUnion(Set(significantWords.prefix(3)))

            // Extract tool usage
            for content in message.content {
                if case .toolUse(let toolUse) = content {
                    toolsUsed.insert(toolUse.name)
                }
            }

            // Add key points for user messages
            if message.role == .user && content.count > 20 {
                keyPoints.append("User discussed: \(String(content.prefix(100)))")
            }
        }

        var summary = "• Conversation covered topics: \(Array(topics.prefix(5)).joined(separator: ", "))\n"

        if !toolsUsed.isEmpty {
            summary += "• Tools used: \(toolsUsed.joined(separator: ", "))\n"
        }

        for point in keyPoints.prefix(3) {
            summary += "• \(point)\n"
        }

        return summary
    }
}
