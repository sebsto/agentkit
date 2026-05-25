#if MCPHTTPSupport
import HTTPTypes
import Hummingbird
import MCP
import ServiceLifecycle
import Logging
import Foundation

extension MCPServer {
    public func startHttpServer(port: Int = 8080) async throws {

        // Capture what we need for the factory closure
        let tools = self.tools
        let prompts = self.prompts
        let resources = self.resources
        let name = self.name
        let version = self.version

        // Factory that creates a fully-configured Server for each new client session
        let serverFactory: @Sendable () async -> Server = {
            let server = Server(
                name: name,
                version: version,
                capabilities: MCPServer.capabilities(tools, prompts, resources)
            )

            if let tools, !tools.isEmpty {
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

                await server.withMethodHandler(CallTool.self) { params in
                    guard let tool = tools.first(where: { $0.toolName == params.name }) else {
                        throw MCPServerError.unknownTool(params.name)
                    }
                    let output = try await tool.handle(jsonInput: params)
                    return CallTool.Result(content: [.text(text: String(describing: output), annotations: nil, _meta: nil)])
                }
            }

            if let prompts, !prompts.isEmpty {
                await server.withMethodHandler(ListPrompts.self) { params in
                    let _prompts = prompts.map { $0.toPrompt() }
                    return ListPrompts.Result(prompts: _prompts, nextCursor: nil)
                }

                await server.withMethodHandler(GetPrompt.self) { params in
                    guard let prompt = prompts.first(where: { $0.name == params.name }) else {
                        throw MCPServerError.unknownPrompt(params.name)
                    }
                    var messages: [Prompt.Message] = []
                    if let arguments = params.arguments {
                        let values = arguments.mapValues { value in
                            String(describing: value)
                        }
                        messages.append(try prompt.toMessage(with: values))
                    }
                    return GetPrompt.Result(description: prompt.description, messages: messages)
                }
            }

            if !resources.resources.isEmpty {
                await server.withMethodHandler(ListResources.self) { params in
                    let mcpResources = resources.asMCPSDKResources()
                    return ListResources.Result(resources: mcpResources, nextCursor: nil)
                }

                await server.withMethodHandler(ReadResource.self) { params in
                    guard let resource = resources.find(uri: params.uri) else {
                        throw MCPServerError.resourceNotFound(params.uri)
                    }
                    return ReadResource.Result(contents: [resource.content])
                }

                await server.withMethodHandler(ListResourceTemplates.self) { _ in
                    ListResourceTemplates.Result(templates: [])
                }
            }

            return server
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
            serverFactory: serverFactory
        )

        router.addRoutes(mcpController.endpoints)

        // Create Hummingbird application
        let app = Application(
            router: router,
            configuration: .init(address: .hostname("127.0.0.1", port: port)),
            logger: self.logger
        )

        // Create service group with the HTTP server and MCP controller
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [app, mcpController],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: self.logger
            )
        )
        try await serviceGroup.run()
    }
}
#endif
