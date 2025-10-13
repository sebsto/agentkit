#if MCPHTTPSupport
//
//  SSEController.swift
//  HgAIServices
//
//  Created by Stephen Tallent on 3/19/25.
//

//
//  MainController.swift
//  HgAIServices
//
//  Created by Stephen Tallent on 2/19/25.
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
            .get("\(path)", use: mcpGet)
            .post("\(path)", use: mcpPost)

        return routes
    }

    @Sendable func mcpPost(request: Request, context: BasicRequestContext) async throws -> Response {
        guard let accepts = request.headers[.accept],
            accepts.contains("application/json") || accepts.contains("text/event-stream")
        else {
            context.logger.trace("Missing Accept header with application/json or text/event-stream")
            return .init(status: .notAcceptable)
        }

        let body = try await request.body.collect(upTo: .max)

        let serverRef: ServerRef
        if let ref = await self.idActor.ref(request.headers[.mcpSessionId]) {
            context.logger.trace("Found an existing MCP server")
            serverRef = ref
        } else {
            context.logger.trace("Creating a new MCP server")
            let transport = StreamableServerTransport()
            try await server.start(transport: transport)

            serverRef = .init(
                id: UUID(),
                server: server,
                transport: transport
            )

            await self.idActor.addRef(serverRef)
        }

        if let streamInfo = try await serverRef.transport.handlePost(data: Data(body.readableBytesView)) {

            return .init(
                status: .ok,
                headers: [
                    .contentType: jsonResponses ? "application/json" : "text/event-stream",
                    .mcpSessionId: serverRef.id.uuidString,
                ],
                body: .init { writer in
                    let allocator = ByteBufferAllocator()

                    try await request.body.consumeWithInboundCloseHandler { requestBody in

                        for try await data in streamInfo.stream {

                            if jsonResponses {
                                try await writer.write(allocator.buffer(bytes: data))
                            } else {
                                try await writer.write(
                                    ServerSentEvent(data: SSEValue(string: String(data: data, encoding: .utf8) ?? ""))
                                        .makeBuffer(allocator: allocator)
                                )
                            }

                        }

                    } onInboundClosed: {
                    }

                    try await writer.finish(nil)
                }
            )

        } else {
            return Response(
                status: .accepted,
                headers: HTTPFields(dictionaryLiteral: (.mcpSessionId, serverRef.id.uuidString))
            )
        }

    }

    @Sendable func mcpGet(request: Request, context: BasicRequestContext) async throws -> Response {
        guard stateful else { return .init(status: .methodNotAllowed) }

        guard let sessionId = request.headers[.mcpSessionId] else { return .init(status: .badRequest) }
        guard let serverRef = await self.idActor.ref(sessionId) else { return .init(status: .badRequest) }

        let getStream = try await serverRef.transport.handleGet()

        return .init(
            status: .ok,
            headers: [
                .contentType: "text/event-stream",
                .mcpSessionId: sessionId,
            ],
            body: .init { writer in
                let allocator = ByteBufferAllocator()

                try await request.body.consumeWithInboundCloseHandler { requestBody in

                    for try await data in getStream {
                        guard let s = String(data: data, encoding: .utf8) else { continue }

                        try await writer.write(
                            ServerSentEvent(data: .init(string: s)).makeBuffer(allocator: allocator)
                        )
                    }

                } onInboundClosed: {
                    Task {
                        await serverRef.transport.endGet()
                    }
                }

                try await writer.finish(nil)
            }
        )

    }

}

struct ServerRef {
    let id: UUID
    let server: Server
    let transport: StreamableServerTransport
}

actor ServerIDsActor {
    var servers: [UUID: ServerRef] = [:]
    var started: Bool = false

    func addRef(_ ref: ServerRef) {
        servers[ref.id] = ref
        if !started {
            started = true
            Task {
                await self.startNotifiers()
            }
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

    // Purely for testing periodic notificatons
    func startNotifiers() async {
        //        do {
        //            let timer = AsyncTimerSequence(interval: .seconds(5), clock: ContinuousClock())
        //
        //            for await tick in timer {
        //                for ref in servers.values {
        //                    if await ref.transport.isGetConnected() {
        //                        try await ref.server.notify(GenericNotification.message(.init(level: "info", data: "world \(tick)")))
        //                    }
        //
        //                }
        //            }
        //        } catch {
        //
        //        }
    }

}

struct GenericNotification: MCP.Notification, Sendable {
    static var name: String { "notifications/message" }
    public struct Parameters: Hashable, Codable, Sendable {
        let level: String
        let data: String
    }
}
#endif
