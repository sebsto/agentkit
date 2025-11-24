/// Custom error type for MCP tool command operations
public enum MCPClientError: Swift.Error, CustomStringConvertible {
    case fileNotFound(path: String)
    case invalidFormat(reason: String)
    case serverNotFound(name: String)
    case urlMalformed(url: String)
    case toolNotFound(name: String)
    case toolError(message: String)
    case unsupportedToolResponse

    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "Could not read MCP configuration file at \(path)"
        case .urlMalformed(let url):
            return "Invalid URL: \(url)"
        case .invalidFormat(let reason):
            return "Invalid MCP configuration format: \(reason)"
        case .serverNotFound(let name):
            return "Server '\(name)' not found in MCP configuration"
        case .toolNotFound(let name):
            return "Tool '\(name)' not found in MCP configuration"
        case .toolError(let message):
            return "Tool error: \(message)"
        case .unsupportedToolResponse:
            return "Only text responses are supported at the moment"
        }
    }
}
