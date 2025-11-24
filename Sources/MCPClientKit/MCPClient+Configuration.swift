#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Structure representing the MCP configuration file format
public struct MCPServerConfiguration: Codable, Sendable {
    package let mcpServers: [String: ServerConfiguration]

    public init(mcpServers: [String: ServerConfiguration]) {
        self.mcpServers = mcpServers
    }

    public init(from url: URL) throws {
        let fileManager = FileManager.default

        // Check if the mcp.json file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw MCPClientError.fileNotFound(path: url.path)
        }

        // Read the mcp.json file and parse it
        let mcpData = try Data(contentsOf: url)
        self = try JSONDecoder().decode(MCPServerConfiguration.self, from: mcpData)
    }

    public subscript(serverName: String) -> ServerConfiguration? {
        mcpServers[serverName]
    }

    public enum ServerConfiguration: Codable, Sendable {
        case stdio(ServerConfigurationStdio)
        case http(ServerConfigurationStreamable)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if container.contains(.command) {
                let stdio = try ServerConfigurationStdio(from: decoder)
                self = .stdio(stdio)
            } else if container.contains(.url) {
                let http = try ServerConfigurationStreamable(from: decoder)
                self = .http(http)
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unable to determine tool configuration type"
                    )
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .stdio(let config):
                try config.encode(to: encoder)
            case .http(let config):
                try config.encode(to: encoder)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case command, url
        }
    }

    public struct ServerConfigurationStdio: Codable, Sendable {
        let command: String
        let args: [String]?
        let env: [String: String]?
        let disabled: Bool?
        let timeout: Int?
    }
    public struct ServerConfigurationStreamable: Codable, Sendable {
        let url: String
        let disabled: Bool?
        let timeout: Int?
    }
}
