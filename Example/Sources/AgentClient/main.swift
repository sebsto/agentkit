import AgentKit
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

var logger = Logger(label: "AgentKit-Example")
logger.logLevel = .info

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
// try await Agent(
//     "Who are you?",
//     auth: .sso("pro"),
//     region: .eucentral1,
//     logger: logger
// )


// Option - Use a RAG System
try await Agent(
    "When writing a blog post for the AWS News blog, should I write open source or open-source?",
    model: .nova_micro,
    // ragSystem: .bedrockKnowledgeBase("EQ13XRVPLE"),
    auth: .sso("pro"),
    region: .uswest2,
    logger: logger
)

/// Option 2 Create and use the agent in two different steps 
// Create an agent with default settings
// let agent = try await Agent() 

// Ask the agent a question
// try await agent("Tell me about Swift 6")

/// Option 3  Invoke `streamAsync(String)` to receive a stream of events
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
