#if MCPHTTPSupport
//
//  StreamableMCPController.swift
//

import Logging
import Hummingbird
import HTTPTypes
import ServiceLifecycle
import SSEKit
import MCP
import AsyncAlgorithms

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension HTTPField.Name {
    public static var mcpSessionId: Self { HTTPField.Name("Mcp-Session-Id")! }
}

struct StreamableMCPController {

    private let idActor: ServerIDsActor = ServerIDsActor()

    private let path: String
    private let stateful: Bool
    private let jsonResponses: Bool
    private let server: Server

    init(path: String, stateful: Bool, jsonResponses: Bool, server: Server) {
        self.path = path
        self.stateful = stateful
        self.jsonResponses = jsonResponses
        self.server = server
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

        let serverRef: ServerRef
        if let ref = await self.idActor.ref(request.headers[.mcpSessionId]) {
            context.logger.trace("Found an existing MCP server")
            serverRef = ref
        } else {
            context.logger.trace("Creating a new MCP server")
            let transport = StatefulHTTPServerTransport()
            try await server.start(transport: transport)

            serverRef = .init(
                id: UUID(),
                server: server,
                transport: transport
            )

            await self.idActor.addRef(serverRef)
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

        // Call the transport's public handleRequest method
        let mcpResponse = await serverRef.transport.handleRequest(mcpRequest)

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

                    for try await data in sseStream {
                        if jsonResponses {
                            try await writer.write(allocator.buffer(bytes: data))
                        } else {
                            // Data from the transport is already SSE-formatted
                            try await writer.write(allocator.buffer(bytes: data))
                        }
                    }

                    try await writer.finish(nil)
                }
            )

        case .accepted(_):
            return Response(
                status: status,
                headers: responseHeaders
            )

        case .ok(_):
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

struct ServerRef {
    let id: UUID
    let server: Server
    let transport: StatefulHTTPServerTransport
}

actor ServerIDsActor {
    var servers: [UUID: ServerRef] = [:]
    var started: Bool = false

    func addRef(_ ref: ServerRef) {
        servers[ref.id] = ref
        if !started {
            started = true
        }
    }

    func removeRef(_ ref: ServerRef) async throws {
        await ref.server.stop()
        servers[ref.id] = nil
    }

    func ref(_ serverID: UUID) -> ServerRef? {
        servers[serverID]
    }

    func ref(_ sessionID: String?) -> ServerRef? {
        guard let serverID = UUID(uuidString: sessionID ?? "") else { return nil }

        return servers[serverID]
    }
}
#endif
