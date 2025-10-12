import BedrockService
import Logging
import MCPServerKit
import Synchronization

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A high-level AI agent that provides conversational capabilities using Amazon Bedrock.
///
/// The Agent struct simplifies interaction with Bedrock models by providing a callable interface
/// and handling authentication, model configuration, and conversation flow.
public final class Agent {

    /// The Bedrock model used for generating responses.
    public let model: BedrockModel
    /// The system prompt that defines the agent's behavior and context.
    public let systemPrompt: String
    /// the list of tools this agent can use to answer questions
    public let tools: [any ToolProtocol]
    /// the history of messages
    // public let messages: Mutex<History>
    public var messages: History

    private let bedrock: BedrockService
    internal let logger: Logger

    /// Creates a new Agent instance with the specified configuration.
    ///
    /// There are three ways to pass MCP server configurations, which are cumulative (all servers will be passed to the agent):
    /// 1. Pass MCPClient instances directly via mcpTools parameter
    /// 2. Pass URL to mcp.json config file via mcpConfigFile parameter
    /// 3. Pass MCPServerConfiguration object via mcpConfig parameter
    ///
    /// - Parameters:
    ///   - initialPrompt: The initial prompt to send to the agent. Defaults to empty string.
    ///   - systemPrompt: The system prompt to guide the agent's behavior. Defaults to empty string.
    ///   - model: The Bedrock model to use. Defaults to Claude Sonnet v4.
    ///   - messages: The conversation history. Defaults to empty array.
    ///   - tools: The local tools this agent can use to answer questions. Defaults to empty array.
    ///   - mcpTools: The remote MCP tools this agent can use. Defaults to empty array.
    ///   - mcpConfig: An MCPServerConfiguration object. Defaults to nil
    ///   - mcpConfigFile: An URL of an mcp.json file with the list of MCP servers. Defaults to nil.
    ///   - auth: The authentication method. Defaults to default credential chain.
    ///   - region: The AWS region to use. Defaults to us-east-1.
    ///   - logger: Optional custom logger. If nil, creates a default logger.
    ///   - callback: Optional callback function to handle events during processing.
    /// - Throws: An error if authentication fails or the Bedrock service cannot be initialized.
    @discardableResult
    public init(
        _ initialPrompt: String = "",
        systemPrompt: String = "",
        model: BedrockModel = .claude_sonnet_v4,
        messages: History = [],
        tools localTools: [any ToolProtocol] = [],
        mcpTools: [MCPClient] = [],
        mcpConfig: MCPServerConfiguration? = nil,
        mcpConfigFile: URL? = nil,
        auth: AuthenticationMethod = .default,
        region: Region = .useast1,
        logger: Logger? = nil,
        callback: AgentCallbackFunction? = nil
    ) async throws {

        self.systemPrompt = systemPrompt
        // self.messages = Mutex(messages)
        self.messages = messages
        self.model = model

        // create a logger when none is given
        if let logger {
            self.logger = logger
        } else {
            var logger = Logger(label: "AgentKit")
            logger.logLevel =
                ProcessInfo.processInfo.environment["LOG_LEVEL"].flatMap {
                    Logger.Level(rawValue: $0)
                } ?? .info
            self.logger = logger
        }

        // create our bag of tools by combining the local and remote tools
        let remoteTools = try await Agent.collectTools(
            mcpTools: mcpTools,
            mcpConfig: mcpConfig,
            mcpConfigFile: mcpConfigFile,
            logger: self.logger
        )
        self.tools = localTools + remoteTools

        let bedrockAuth = try Agent.makeBedrockAuth(auth: auth, logger: self.logger)

        self.bedrock = try await BedrockService(
            region: region,
            logger: self.logger,
            authentication: bedrockAuth
        )

        if initialPrompt != "" {
            try await self.runLoop(
                prompt: initialPrompt,
                systemPrompt: systemPrompt,
                bedrock: bedrock,
                model: model,
                tools: tools,
                logger: self.logger,
                callback: callback
            )
        }

    }

    /// Sends a message to the agent and processes the response.
    ///
    /// This method enables callable syntax, allowing you to use the agent like a function:
    /// ```swift
    /// let agent = try await Agent()
    /// try await agent("Hello, how are you?")
    /// ```
    ///
    /// - Parameters:
    ///   - message: The message to send to the agent.
    ///   - callback: Optional callback function to handle events during processing.
    /// - Throws: An error if the conversation fails or the model is not supported.
    public func callAsFunction(_ message: String, callback: AgentCallbackFunction? = nil) async throws {
        try await self.runLoop(
            prompt: message,
            systemPrompt: self.systemPrompt,
            bedrock: self.bedrock,
            model: self.model,
            tools: self.tools,
            logger: self.logger,
            callback: callback
        )
    }

    public func getHistory() -> History {
        // self.messages.withLock { $0 }
        self.messages
    }
    public func appendToHistory(_ message: Message) {
        // self.messages.withLock { $0.append(message) }
        self.messages.append(message)
    }
    public func lastMessageFromHistory() -> Message? {
        // self.messages.withLock { $0.last }
        self.messages.last
    }
}
