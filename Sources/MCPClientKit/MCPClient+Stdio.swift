import Logging
import MCP

// We can't use FoundationEssentials on Linux because Process is not defined there.
// to be removed when we will migrate to swift-process

// #if canImport(FoundationEssentials)
// import FoundationEssentials
// #else
import Foundation
// #endif

#if os(macOS)
import System
#elseif os(Linux)
import SystemPackage
#else
#error("Unsupported platform")
#endif

extension MCPClient {

    /// Start the processes and connect the stdio streams
    /// static because this is called from `init()`
    public static func startStdioTool(
        client: Client,
        command: String,
        args: [String]?,
        logger: Logger
    ) async throws -> Process {
        logger.trace(
            "Launching process",
            metadata: [
                "command": "\(command)",
                "arguments": "\(args?.joined(separator: " ") ?? "")",
            ]
        )

        // Create pipes for the server input and output
        let serverInputPipe = Pipe()
        let serverOutputPipe = Pipe()
        let serverInput: FileDescriptor = FileDescriptor(
            rawValue: serverInputPipe.fileHandleForWriting.fileDescriptor
        )
        let serverOutput: FileDescriptor = FileDescriptor(
            rawValue: serverOutputPipe.fileHandleForReading.fileDescriptor
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        process.standardInput = serverInputPipe
        process.standardOutput = serverOutputPipe

        let transport = StdioTransport(
            input: serverOutput,
            output: serverInput,
            logger: logger
        )

        try process.run()
        logger.trace("Process launched")

        try await client.connect(transport: transport)
        logger.trace("Connected to MCP server")

        return process
    }

    public static func disconnectAndTerminateServerProcess(client: Client, process: Process) {
        if process.isRunning {
            Task {  // unmanaged task for defer {}
                await client.disconnect()
                process.terminate()
            }
        }
    }
}
