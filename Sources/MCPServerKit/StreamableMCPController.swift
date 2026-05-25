#if MCPHTTPSupport

import Logging
import Hummingbird
import HTTPTypes
import MCP

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct StreamableMCPController {

    private let path: String
    private let jsonResponses: Bool
    private let server: Server
    private let transport: StatefulHTTPServerTransport

    init(path: String, jsonResponses: Bool, server: Server) {
        self.path = path
        self.jsonResponses = jsonResponses
        self.server = server
        self.transport = StatefulHTTPServerTransport()
    }

    /// Start the transport (must be called before handling requests)
    func start() async throws {
        try await server.start(transport: transport)
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

        // Delegate to the transport's public handleRequest method
        let mcpResponse = await transport.handleRequest(mcpRequest)

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
                        try await writer.write(allocator.buffer(bytes: data))
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
#endif
