import AgentKit
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@main
struct Test {
    static func main() async throws {

        var logger = Logger(label: "MCPClient")
        logger.logLevel = .trace

        let configFile = "./json/mcp-mix.json"
        let url = URL(fileURLWithPath: configFile)

        let config = try MCPServerConfiguration(from: url)

        // experiment with stdio server
        // var serverName = "MCPExample-stdio"
        // guard let stdioServerConfig = config[serverName] else {
        //     throw MCPClientError.serverNotFound(name: serverName)
        // }
        // let stdioClient = try await MCPClient(with: stdioServerConfig, name: serverName, logger: logger)
        // print(try await stdioClient.invokeTool(name: "weather", arguments: ["input": "lille"], logger: logger))

        // experiment with http server
        let serverName = "MCPExample-http"
        guard let httpServerConfig = config[serverName] else {
            throw MCPClientError.serverNotFound(name: serverName)
        }
        let httpClient = try await MCPClient(with: httpServerConfig, name: serverName, logger: logger)
        print(try await httpClient.invokeTool(name: "weather", arguments: ["input": "lille"], logger: logger))

    }
}
