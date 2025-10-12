import AgentKit
import Logging 

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// var logger = Logger(label: "AgentKit-Example")
// logger.logLevel = .debug

/// Option 1. Just call the agent, it sends its ouput to stdout
try await Agent("Tell me about Swift 6", auth: .sso("pro"), region: .eucentral1) //, logger: logger)
// or in two lines
// let agent = try await Agent()
// try await agent("Tell me about Swift 6")

/// Option 2.  Provide the agent with a callback function
// let agent = try await Agent()
// try await agent("Tell me about swift 6") { event in
//     print(event, terminator: "")
// }

/// Option 3.  Invoke `streamAsync(String)` to receive a stream of events
// let agent = Agent()
// for try await event in agent.streamAsync("Tell me about swift 6") {
//     switch event {
//     case .text(let text):
//         print(text, terminator: "")
//     default:
//         break
//     }
// }

/// Option 4. Use local tools
// let agent = try await Agent(tools: [WeatherTool(), FXRateTool()])
// try await agent(
//     "What is the weather in Lille today? Give a one paragraph summary with key metrics. Do not use bullet points."
// )

// try await agent("How much is 100 GBP in EUR?")

/// Option 5, use MCP servers defined in a config file
// let configFile = "./json/mcp-http.json"
// let url = URL(fileURLWithPath: configFile)

// let agent = try await Agent(mcpConfigFile: url)
// print("This agent has \(agent.tools.count) tools")
// agent.tools.forEach { tool in
//     print("- \(tool.toolName)")
// }	
// try await agent(
//     "What is the weather in Lille today? Give a one paragraph summary with key metrics. Do not use bullet points."
// ) { event in 
//     print(event, terminator: "")
// }

// print("\n")
// try await agent("How much is 100 GBP in EUR?")
