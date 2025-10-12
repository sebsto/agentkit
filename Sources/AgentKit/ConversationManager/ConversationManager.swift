/// The context refers to the information provided to the agent for understanding and reasoning. This includes:
/// - User messages
/// - Agent responses
/// - Tool usage and results
/// - System prompts
///
/// As conversations grow, managing this context becomes increasingly important for several reasons:
/// - Token Limits: Language models have fixed context windows (maximum tokens they can process)
/// - Performance: Larger contexts require more processing time and resources
/// - Relevance: Older messages may become less relevant to the current conversation
/// - Coherence: Maintaining logical flow and preserving important information
///
/// The AgentKit provides a flexible system for context management through the ConversationManager interface.
/// This allows you to implement different strategies for managing conversation history.
public protocol ConversationManager {
    /// This method is called after each event loop cycle completes to manage the conversation history.
    /// It's responsible for applying your management strategy to the messages array,
    /// which may have been modified with tool results and assistant responses.
    /// The agent runs this method automatically after processing each user input and generating a response.
    ///
    /// Parameters:
    /// - history: the current conversation history
    /// Returns:
    /// - the compacted conversation history
    func applyManagement(history: History) async throws -> History

    /// This method is called when the model's context window is exceeded (typically due to token limits).
    /// It implements the specific strategy for reducing the window size when necessary.
    /// The agent calls this method when it encounters a context window overflow exception,
    /// giving your implementation a chance to trim the conversation history before retrying.
    ///
    /// Parameters:
    /// - history: the current conversation history
    /// Returns:
    /// - the compacted conversation history
    func reduceContext(history: History) async throws -> History

    /// This attribute is tracked by conversation managers, and utilized by Session Management t
    /// o efficiently load messages from the session storage. The count represent messages provided
    /// by the user or LLM that have been removed from the agent's messages,
    /// but not messages included by the conversation manager through something like summarization.
    func removedMessageCount() -> Int
}

/// The NullConversationManager is a simple implementation that does not modify the conversation history. It's useful for:
///
/// - Short conversations that won't exceed context limits
/// - Debugging purposes
public class NullConversationManager: ConversationManager {
    private var removedMessages = 0
    public init() {}
    public func applyManagement(history: History) async throws -> History { history }
    public func reduceContext(history: History) async throws -> History { History() }
    public func removedMessageCount() -> Int { 0 }
}
