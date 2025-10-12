import AgentKit
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

var logger = Logger(label: "AgentKit-Example")
logger.logLevel = .debug

// func generateLongHistory(messageCount: Int = 1000) -> History {
//     let baseText = String(repeating: "This is a test message to create a long conversation history. ", count: 30)  // ~2KB per message

//     var history: History = []
//     for i in 0..<messageCount {
//         let userMessage = Message(from: .user, content: [.text("User message \(i): \(baseText)")])
//         let assistantMessage = Message(from: .assistant, content: [.text("Assistant response \(i): \(baseText)")])
//         history.append(userMessage)
//         history.append(assistantMessage)
//     }
//     return history
// }

/// Option 1. Just call the agent, it sends its ouput to stdout
try await Agent(
    "Tell me about Swift 6",
    // messages: generateLongHistory(),
    auth: .sso("pro"),
    region: .eucentral1,
    logger: logger
)

/// Test with long history
// let agent = try await Agent(auth: .sso("pro"), region: .eucentral1)
// agent.messages = generateLongHistory(messageCount: 150) // ~600KB of history
// try await agent("Summarize our conversation")

/// Option 2. Test conversation manager with long history
// let conversationManager = SlidingWindowConversationManager(windowSize: 20)
// let agent = try await Agent(auth: .sso("pro"), region: .eucentral1)
// agent.messages = generateLongHistory(messageCount: 50)
// try await agent("What can you tell me about our conversation?")

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
