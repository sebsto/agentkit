import MCP

extension MCPServer {
    public func startStdioServer() async throws {
        if let tools, tools.count > 0 {
            await registerTools(tools: tools)
        }

        if let prompts, prompts.count > 0 {
            await registerPrompts(prompts: prompts)
        }

        if !resources.resources.isEmpty {
            await registerResources(resources: resources)
        }

        // start the server with the stdio transport
        try await server.start(transport: StdioTransport())
        await server.waitUntilCompleted()
    }
}
