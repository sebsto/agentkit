#if MCPHTTPSupport

import Logging
import Hummingbird
import HTTPTypes
import MCP
import ServiceLifecycle

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct StreamableMCPController: Service {

    private let path: String
    private let jsonResponses: Bool
    private let serverFactory: @Sendable () async -> Server
    private let sessions: SessionManager = SessionManager()

    init(path: String, jsonResponses: Bool, serverFactory: @escaping @Sendable () async -> Server) {
        self.path = path
        self.jsonResponses = jsonResponses
        self.serverFactory = serverFactory
    }

    /// Service run method — keeps running until cancelled, then disconnects all sessions
    func run() async throws {
        try await gracefulShutdown()
        await sessions.disconnectAll()
    }

    var endpoints: RouteCollection<BasicRequestContext> {
        let routes = RouteCollection(context: BasicRequestContext.self)

        routes
            .get("\(path)", use: mcpHandler)
            .post("\(path)", use: mcpHandler)
            .delete("\(path)", use: mcpHandler)

        return routes
    }

    @Sendable func mcpHandler(request: Request, context: BasicRequestContext) async throws -> Response {
        let body = try await request.body.collect(upTo: .max)

        // Find existing session or create a new one
        let transport: StatefulHTTPServerTransport

        if let sessionID = request.headers[.mcpSessionId],
           let existing = await sessions.transport(for: sessionID) {
            transport = existing
        } else {
            // New client — create a fresh Server + Transport pair
            let newTransport = StatefulHTTPServerTransport()
            let server = await serverFactory()
            try await server.start(transport: newTransport)
            transport = newTransport
        }

        // Convert Hummingbird request to MCP HTTPRequest
        var headers: [String: String] = [:]
        for field in request.headers {
            headers[field.name.rawName] = field.value
        }

        let mcpRequest = MCP.HTTPRequest(
            method: String(describing: request.method),
            headers: headers,
            body: body.readableBytesView.isEmpty ? nil : Data(body.readableBytesView),
            path: path
        )

        // Delegate to the transport
        let mcpResponse = await transport.handleRequest(mcpRequest)

        // Track the session ID from the response so future requests can find this transport
        if let newSessionID = mcpResponse.headers["MCP-Session-Id"] {
            await sessions.associate(sessionID: newSessionID, transport: transport)
        }

        // Convert MCP HTTPResponse to Hummingbird Response
        var responseHeaders = HTTPFields()
        for (key, value) in mcpResponse.headers {
            if let name = HTTPField.Name(key) {
                responseHeaders.append(HTTPField(name: name, value: value))
            }
        }

        let status = HTTPResponse.Status(code: mcpResponse.statusCode)

        switch mcpResponse {
        case .stream(let sseStream, _):
            return Response(
                status: status,
                headers: responseHeaders,
                body: .init { writer in
                    let allocator = ByteBufferAllocator()
                    do {
                        for try await data in sseStream {
                            try await writer.write(allocator.buffer(bytes: data))
                        }
                    } catch {
                        // Stream was terminated (e.g., transport disconnected during shutdown)
                    }
                    try await writer.finish(nil)
                }
            )

        case .accepted(_), .ok(_):
            return Response(
                status: status,
                headers: responseHeaders
            )

        case .data(let data, _):
            let allocator = ByteBufferAllocator()
            return Response(
                status: status,
                headers: responseHeaders,
                body: .init(byteBuffer: allocator.buffer(bytes: data))
            )

        case .error(_, _, _, _):
            let allocator = ByteBufferAllocator()
            if let bodyData = mcpResponse.bodyData {
                return Response(
                    status: status,
                    headers: responseHeaders,
                    body: .init(byteBuffer: allocator.buffer(bytes: bodyData))
                )
            } else {
                return Response(
                    status: status,
                    headers: responseHeaders
                )
            }
        }
    }
}

/// Manages the mapping between MCP session IDs and their transports
actor SessionManager {
    private var sessionToTransport: [String: StatefulHTTPServerTransport] = [:]

    func transport(for sessionID: String) -> StatefulHTTPServerTransport? {
        sessionToTransport[sessionID]
    }

    func associate(sessionID: String, transport: StatefulHTTPServerTransport) {
        sessionToTransport[sessionID] = transport
    }

    /// Disconnect all active transports (closes SSE streams so shutdown can complete)
    func disconnectAll() async {
        for (_, transport) in sessionToTransport {
            await transport.disconnect()
        }
        sessionToTransport.removeAll()
    }
}

extension HTTPField.Name {
    static var mcpSessionId: Self { HTTPField.Name("Mcp-Session-Id")! }
}
#endif
