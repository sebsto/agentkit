#if MCPHTTPSupport
import HTTPTypes
import Hummingbird
import MCP
import ServiceLifecycle
import Logging
import Foundation

extension MCPServer {
    public func startHttpServer(port: Int = 8080) async throws {
        // Register MCP handlers
        if let tools, tools.count > 0 {
            await registerTools(tools: tools)
        }
        if let prompts, prompts.count > 0 {
            await registerPrompts(prompts: prompts)
        }
        if !resources.resources.isEmpty {
            await registerResources(resources: resources)
        }

        // Create router and add MCP endpoint
        let router = Router()

        // order matters. Middleware is applied to routes added after this
        router.addMiddleware {
            LogRequestsMiddleware(.trace)
        }

        let mcpController = StreamableMCPController(
            path: "mcp",
            jsonResponses: true,
            server: self.server
        )
        try await mcpController.start()

        router.addRoutes(mcpController.endpoints)

        // Create Hummingbird application
        let app = Application(
            router: router,
            configuration: .init(address: .hostname("127.0.0.1", port: port)),
            logger: self.logger
        )

        // Create service group with the MCPServer and the HTTP server
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [app],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: self.logger
            )
        )
        try await serviceGroup.run()
    }
}
#endif
