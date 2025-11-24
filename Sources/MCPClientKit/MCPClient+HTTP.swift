import Logging
import MCP

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension MCPClient {

    /// Creates a transport for HTTP servers
    /// static because this is called from `init()`
    public static func startHTTPTool(
        client: Client,
        url: String,
        logger: Logger
    ) async throws {
        logger.trace(
            "Creating transport",
            metadata: [
                "url": "\(url)"
            ]
        )

        guard let url = URL(string: url) else {
            throw MCPClientError.urlMalformed(url: url)
        }
        let transport = HTTPClientTransport(endpoint: url)

        try await client.connect(transport: transport)
        logger.trace("Connected to MCP HTTP server")

    }
}
