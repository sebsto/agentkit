import MCP

/// Extension to MCPServer for working with resources
extension MCPServer {

    /// Register resources with the server
    package func registerResources(resources: MCPResourceRegistry) async {
        self.resources.add(resources.resources)

        // Register resources/list handler
        await server.withMethodHandler(ListResources.self) { params in
            let mcpResources = resources.asMCPSDKResources()
            return ListResources.Result(resources: mcpResources, nextCursor: nil)
        }

        // Register resources/read handler
        await server.withMethodHandler(ReadResource.self) { params in
            // Find the resource with the requested URI
            guard let resource = resources.find(uri: params.uri) else {
                throw MCPServerError.resourceNotFound(params.uri)
            }

            // Return the resource content
            return ReadResource.Result(contents: [resource.content])
        }

        // Register resources/templates/list handler
        await server.withMethodHandler(ListResourceTemplates.self) { _ in
            // For now, we don't support resource templates
            ListResourceTemplates.Result(templates: [])
        }
    }
}
