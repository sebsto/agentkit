import BedrockService

/// Protocol defining the core interface for AI agents
public protocol AgentProtocol {
    /// Execute a prompt and handle the response through a callback
    /// - Parameters:
    ///   - prompt: The input prompt to process
    ///   - callback: Optional callback to handle streaming events
    func callAsFunction(_ prompt: String, callback: Agent.AgentCallbackFunction?) async throws
}

/// Make the existing Agent conform to AgentProtocol
extension Agent: AgentProtocol {
    // Agent already has the required callAsFunction method with matching signature
}