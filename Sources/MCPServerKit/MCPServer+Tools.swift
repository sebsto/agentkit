import MCP

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension MCPServer {
    package func registerTools(tools: [any ToolProtocol]) async {
        // register the tools, part 1 : tools/list
        await server.withMethodHandler(ListTools.self) { params in
            let _tools = try tools.map { tool in
                Tool(
                    name: tool.toolName,
                    description: tool.toolDescription,
                    inputSchema: try JSONDecoder().decode(
                        Value.self,
                        from: tool.inputSchema.data(using: .utf8)!
                    )
                )
            }

            return ListTools.Result(tools: _tools, nextCursor: nil)
        }

        // register the tools, part 2 : tools/call
        await server.withMethodHandler(CallTool.self) { params in
            // Check if the tool name is in our list of tools
            guard let tool = tools.first(where: { $0.toolName == params.name }) else {
                throw MCPServerError.unknownTool(params.name)
            }

            // call the tool with JSON input
            let output = try await tool.handle(jsonInput: params)

            // return the result
            return CallTool.Result(content: [.text(text: String(describing: output), annotations: nil, _meta: nil)])
        }
    }
}
