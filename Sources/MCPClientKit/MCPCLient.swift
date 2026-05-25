import Logging
import MCP
import MCPShared
import Synchronization

// We can't use FoundationEssentials on Linux because Process is not defined there.
// to be removed when we will migrate to swift-process 

// #if canImport(FoundationEssentials)
// import FoundationEssentials
// #else
import Foundation
// #endif


/// A MCPClient is teh struct that allows to communicate with a MCP Server
/// and invoke its tools, get its resources or prompts.
public actor MCPClient: Sendable {

    public let name: String

    package let client: Client
    package let logger: Logger
    private var process: Process? = nil

    // to make MCPCLient Sendable and the compiler happy
    private let _tools: Mutex<[Tool]>
    public var tools: [Tool] {
        get {
            _tools.withLock { $0 }
        }
    }

    public init(
        with serverConfig: MCPServerConfiguration.ServerConfiguration,
        name: String,
        version: String = "1.0.0",
        logger: Logger
    ) async throws {
        self.name = name
        self.client = Client(name: name, version: version)
        self.logger = logger

        // start the process and enumerate all the tools available
        switch serverConfig {
        case .stdio(let config):
            self.process = try await MCPClient.startStdioTool(
                client: client,
                command: config.command,
                args: config.args,
                logger: self.logger
            )
        case .http(let config):
            try await MCPClient.startHTTPTool(client: client, url: config.url, logger: logger)
        }

        let (tools, _) = try await client.listTools()
        _tools = Mutex(tools)
    }

    deinit {
        if let process {
            MCPClient.disconnectAndTerminateServerProcess(client: client, process: process)
        }
    }

    /// Invoke a tool
    public func invokeTool(
        name toolName: String,
        arguments: [String: MCPValue],
        logger: Logger = Logger(label: "MCPClient")
    ) async throws -> String {

        logger.trace(
            "Going to call a tool",
            metadata: ["toolName": "\(toolName)", "arguments": "\(arguments)"]
        )

        // call the tool with the provided arguments
        let (content, isError) = try await self.client.callTool(name: toolName, arguments: arguments)

        logger.trace(
            "Tool result",
            metadata: ["content": "\(content)", "isError": "\(String(describing: isError))"]
        )

        guard let c = content.first,
            case let .text(text, _, _) = c
        else {
            logger.error("Tool returned an unsupported response (something else than text)")
            throw MCPClientError.unsupportedToolResponse
        }
        // Check if the tool returned an error
        guard isError == nil
        else {
            logger.error("Tool returned an error")
            throw MCPClientError.toolError(message: text)
        }

        return text
    }

    /// Returns the tool with the given name, or nil if not found.
    /// - Parameter toolName: The name of the tool to look up
    /// - Returns: The tool if found, nil otherwise
    /// - Note: This method checks the list of tools available in the MCP server.
    public func getTool(named toolName: String) -> Tool? {
        self.tools.first { $0.name == toolName }
    }
    /// Checks if the tool with the given name exists in the list of tools.
    /// - Parameter toolName: The name of the tool to check
    /// - Returns: A boolean indicating whether the tool exists
    /// - Note: This method checks the list of tools available in the MCP server.
    public func hasTool(named toolName: String) -> Bool {
        self.tools.map { $0.name }.contains(toolName)
    }

}
