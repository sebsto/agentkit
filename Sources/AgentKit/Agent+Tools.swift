import BedrockService
import Logging
import MCPShared

import struct BedrockService.Tool

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public typealias BedrockTool = Tool

extension Agent {
    var toolNames: [String] {
        self.tools.map { $0.toolName }
    }

    func resolveToolUse(
        bedrock: BedrockService,
        requestBuilder: ConverseRequestBuilder,
        tools: [any ToolProtocol],
        toolUse: ToolUseBlock,
        messages: History,
        logger: Logger
    ) async throws -> ConverseRequestBuilder {

        guard messages.last != nil else {
            fatalError(
                "No last message found in the history to resolve tool use"
            )
        }

        // find the tool
        guard let tool = tools.tool(named: toolUse.name) else {
            throw AgentError.toolNotFound(toolUse.name)
        }
        logger.trace(
            "Tool found, going to call it",
            metadata: ["name": "\(toolUse.name)", "input": "\(toolUse.input)"]
        )

        // invoke the tool
        let result = try await tool.handle(jsonInput: toolUse.input)
        logger.trace("Tool Result", metadata: ["result": "\(result)"])

        // pass the result back to the model
        // when the result is a simple string, we must pass it as a String object
        // (because the ToolResultBlock's content is an enum that makes the distinction between string and json)
        if let string = isString(result) {
            return try ConverseRequestBuilder(from: requestBuilder)
                .withHistory(messages)
                .withToolResult(string)
        } else {
            return try ConverseRequestBuilder(from: requestBuilder)
                .withHistory(messages)
                .withToolResult(result)
        }
    }

    private func isString(_ value: Encodable) -> String? {
        guard let string = try? String(data: JSONEncoder().encode(value), encoding: .utf8) else {
            return nil
        }
        return string
    }

    package static func collectTools(
        mcpTools: [MCPClient] = [],
        mcpConfig: MCPServerConfiguration? = nil,
        mcpConfigFile: URL? = nil,
        logger: Logger
    ) async throws -> (tools: [any ToolProtocol], clients: [MCPClient]) {

        // our remote tools (MCP)
        var result: [any ToolProtocol] = []
        var clients: [MCPClient] = []

        // start with the ones we received as MCP clients
        for mcpClient in mcpTools {
            await result.append(contentsOf: mcpClient.asTools())
            clients.append(mcpClient)
        }

        // add the ones we received as a config object
        if let mcpConfig {
            for (key, value) in mcpConfig.mcpServers {
                let mcpClient = try await MCPClient(with: value, name: key, logger: logger)
                await result.append(contentsOf: mcpClient.asTools())
                clients.append(mcpClient)
            }
        }

        // add the ones we received as a config file
        if let mcpConfigFile {
            let mcpConfig = try MCPServerConfiguration(from: mcpConfigFile)
            for (key, value) in mcpConfig.mcpServers {
                let mcpClient = try await MCPClient(with: value, name: key, logger: logger)
                await result.append(contentsOf: mcpClient.asTools())
                clients.append(mcpClient)
            }
        }

        return (result, clients)
    }
}

extension ToolProtocol {
    public func bedrockTool() throws -> BedrockTool {
        let json = try JSON(from: self.inputSchema)
        return try BedrockTool(name: self.toolName, inputSchema: json, description: self.toolDescription)
    }
}

extension Array where Element == any ToolProtocol {
    public func bedrockTools() throws -> [BedrockTool] {
        try self.map { try $0.bedrockTool() }
    }
    public func tool(named toolName: String) -> (any ToolProtocol)? {
        self.first(where: { $0.toolName == toolName })
    }
}
