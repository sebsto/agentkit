import Logging
import MCP
import MCPShared

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension MCPClient {

    /// Convert all our MCP Tools to ToolProtocol know by this library (and the Agent)
    public func asTools() -> [any ToolProtocol] {
        self.tools.map { MCPToolWrapper(client: self, tool: $0) }
    }

}

struct MCPToolWrapper: ToolProtocol, CustomStringConvertible {
    typealias Input = [String: MCPValue]
    typealias Output = String

    var toolName: String { tool.name }
    var toolDescription: String { tool.description ?? "" }
    var inputSchema: String {
        guard let schemaData = try? JSONEncoder().encode(tool.inputSchema),
            let schemaString = String(data: schemaData, encoding: .utf8)
        else {
            return "{}"
        }
        return schemaString
    }

    let client: MCPClient
    let tool: Tool

    init(client: MCPClient, tool: Tool) {
        self.client = client
        self.tool = tool
    }
    func handle(input: Input) async throws -> Output {
        try await client.invokeTool(name: self.toolName, arguments: input)
    }

    var description: String {
        "MCPToolWrapper(\(toolName))"
    }
    public init() { fatalError("Can not create a MCPToolWrapper withoit passing a Tool and an MCPCLient") }
}
