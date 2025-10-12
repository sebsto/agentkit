# AgentKit

A Swift framework for building AI agents with Amazon Bedrock and Model Context Protocol (MCP) support. AgentKit simplifies creating conversational AI agents that can use tools and integrate with MCP servers.

## Overview

AgentKit provides a high-level API for building AI agents that can:
- Have conversations using Amazon Bedrock models
- Use local tools to perform actions
- Connect to remote MCP servers for extended capabilities
- Handle authentication and configuration seamlessly

## Requirements

- macOS 15 or later
- Swift 6.2 or later
- AWS credentials configured

## Installation

Add AgentKit to your Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/sebsto/AgentKit", from: "1.0.0")
]
```

## 1. Simple Agent

Create a basic conversational agent with minimal setup:

```swift
import AgentKit

// Simple one-liner - agent responds to stdout
try await Agent("Tell me about Swift 6")

// Two-step approach
let agent = try await Agent()
try await agent("Tell me about Swift 6")

// With custom authentication and region
try await Agent(
    "Tell me about Swift 6", 
    auth: .sso("my-profile"), 
    region: .eucentral1
)

// With callback for custom output handling
let agent = try await Agent()
try await agent("Tell me about Swift 6") { event in
    print(event, terminator: "")
}

// Streaming approach
let agent = try await Agent()
for try await event in agent.streamAsync("Tell me about Swift 6") {
    switch event {
    case .text(let text):
        print(text, terminator: "")
    default:
        break
    }
}
```

## 2. Tools

Create tools that agents can use to perform specific actions. Tools are defined using the `@Tool` macro.

**Important**: Swift DocC comments on the `handle` function parameters and `@SchemaDefinition` struct properties are crucial - they become the tool descriptions that AI models use to understand how to invoke your tools correctly.

### Simple String Tool

```swift
import AgentKit

@Tool(
    name: "weather",
    description: "Get detailed weather information for a city."
)
struct WeatherTool {
    /// Get weather information for a specific city
    /// - Parameter input: The city name to get the weather for
    func handle(input city: String) async throws -> String {
        let weatherURL = "http://wttr.in/\(city)?format=j1"
        let url = URL(string: weatherURL)!
        let (data, _) = try await URLSession.shared.data(from: url)
        return String(decoding: data, as: UTF8.self)
    }
}
```

### Complex Structured Tool

```swift
import AgentKit

@SchemaDefinition
struct CalculatorInput: Codable {
    /// The first operand of the operation
    let a: Double
    /// The second operand of the operation
    let b: Double
    /// The arithmetic operation: "add", "subtract", "multiply", "divide"
    let operation: String
}

@Tool(
    name: "calculator",
    description: "Performs basic arithmetic operations",
    schema: CalculatorInput.self
)
struct CalculatorTool {
    func handle(input: CalculatorInput) async throws -> Double {
        switch input.operation {
        case "add":
            return input.a + input.b
        case "subtract":
            return input.a - input.b
        case "multiply":
            return input.a * input.b
        case "divide":
            guard input.b != 0 else {
                throw MCPServerError.invalidParam("b", "Cannot divide by zero")
            }
            return input.a / input.b
        default:
            throw MCPServerError.invalidParam("operation", "Unknown operation: \(input.operation)")
        }
    }
}
```

### Currency Exchange Tool

```swift
import AgentKit

@SchemaDefinition
struct FXRatesInput: Codable {
    /// The source currency code (e.g., USD, EUR, GBP)
    let sourceCurrency: String
    /// The target currency code (e.g., USD, EUR, GBP)
    let targetCurrency: String
}

@Tool(
    name: "foreign_exchange_rates",
    description: "Get current foreign exchange rates between two currencies",
    schema: FXRatesInput.self
)
struct FXRateTool {
    func handle(input: FXRatesInput) async throws -> String {
        let fxURL = "https://hexarate.paikama.co/api/rates/latest/\(input.sourceCurrency)?target=\(input.targetCurrency)"
        let url = URL(string: fxURL)!
        let (data, _) = try await URLSession.shared.data(from: url)
        return String(decoding: data, as: UTF8.self)
    }
}
```

## 3. Agent + Tools

Combine agents with local tools for enhanced capabilities:

```swift
import AgentKit

// Create agent with multiple tools
let agent = try await Agent(tools: [
    WeatherTool(), 
    FXRateTool(), 
    CalculatorTool()
])

// Use the tools through natural conversation
try await agent("What is the weather in Paris today?")
try await agent("How much is 100 USD in EUR?")
try await agent("What is 15 * 23?")
```

## 4. Exposing Tools as MCP Server

Share your tools with other applications by creating MCP servers:

### STDIO Server

```swift
import AgentKit

@main
struct MyMCPServer {
    static func main() async throws {
        try await MCPServer.withMCPServer(
            name: "MyToolServer",
            version: "1.0.0",
            transport: .stdio,
            tools: [
                WeatherTool(),
                CalculatorTool(),
                FXRateTool()
            ]
        ) { server in
            try await server.run()
        }
    }
}
```

### HTTP Server

```swift
import AgentKit

@main
struct MyHTTPServer {
    static func main() async throws {
        try await MCPServer.withMCPServer(
            name: "MyToolServer",
            version: "1.0.0",
            transport: .http(port: 8080),
            tools: [
                WeatherTool(),
                CalculatorTool(),
                FXRateTool()
            ]
        ) { server in
            try await server.run()
        }
    }
}
```

### Server with Prompts

```swift
import AgentKit

let weatherPrompt = try! MCPPrompt.build { builder in
    builder.name = "current-weather"
    builder.description = "Get current weather for a city"
    builder.text("What is the weather today in {city}?")
    builder.parameter("city", description: "The name of the city")
}

@main
struct MyServerWithPrompts {
    static func main() async throws {
        try await MCPServer.withMCPServer(
            name: "MyToolServer",
            version: "1.0.0",
            transport: .stdio,
            tools: [WeatherTool()],
            prompts: [weatherPrompt]
        ) { server in
            try await server.run()
        }
    }
}
```

## 5. Agent + MCP Servers

Connect agents to remote MCP servers for extended capabilities:

### Using Configuration File

Create a JSON configuration file (`mcp-config.json`):

```json
{
    "mcpServers": {
        "weather-server": {
            "command": "./weather-server",
            "args": [],
            "disabled": false,
            "timeout": 60000
        },
        "calculator-server": {
            "url": "http://127.0.0.1:8080/mcp",
            "disabled": false,
            "timeout": 60000
        }
    }
}
```

Use the configuration file:

```swift
import AgentKit

let configFile = URL(fileURLWithPath: "./mcp-config.json")
let agent = try await Agent(mcpConfigFile: configFile)

print("Agent has \(agent.tools.count) tools available")
agent.tools.forEach { tool in
    print("- \(tool.toolName)")
}

try await agent("What is the weather in London and what is 25 * 4?")
```

### Using MCPServerConfiguration

```swift
import AgentKit

let config = MCPServerConfiguration()
config.addServer(
    name: "weather-server",
    command: "./weather-server",
    args: []
)
config.addServer(
    name: "calculator-server", 
    url: "http://127.0.0.1:8080/mcp"
)

let agent = try await Agent(mcpConfig: config)
try await agent("Get weather for Berlin and calculate 100 * 1.2")
```

### Using MCPClient Directly

```swift
import AgentKit

// Create individual MCP clients
let weatherClient = try await MCPClient(
    command: "./weather-server",
    args: [],
    name: "weather-server"
)

let calculatorClient = try await MCPClient(
    url: "http://127.0.0.1:8080/mcp",
    name: "calculator-server"
)

// Use clients with agent
let agent = try await Agent(mcpTools: [weatherClient, calculatorClient])
try await agent("What's the weather in Tokyo and what is 50 divided by 2?")
```

### Mixed Local and Remote Tools

```swift
import AgentKit

let agent = try await Agent(
    tools: [WeatherTool()],  // Local tools
    mcpConfigFile: URL(fileURLWithPath: "./remote-servers.json")  // Remote tools
)

try await agent("Compare weather in Paris with currency rates USD to EUR")
```

## 6. Authentication

AgentKit supports multiple AWS authentication methods:

### Default Credential Chain

```swift
let agent = try await Agent(auth: .default)
```

### AWS SSO

```swift
let agent = try await Agent(auth: .sso("my-sso-profile"))
// or with default profile
let agent = try await Agent(auth: .sso(nil))
```

### Named Profile

```swift
let agent = try await Agent(auth: .profile("my-aws-profile"))
```

### Temporary Credentials

```swift
let agent = try await Agent(auth: .tempCredentials("/path/to/credentials.json"))
```

The temporary credentials file should contain:

```json
{
    "accessKeyId": "AKIA...",
    "secretAccessKey": "...",
    "sessionToken": "...",
    "expiration": "2024-01-01T00:00:00Z"
}
```

### Custom Region

```swift
let agent = try await Agent(
    auth: .sso("my-profile"),
    region: .eucentral1
)
```

## Advanced Configuration

### Custom Models

```swift
let agent = try await Agent(
    model: .claude_haiku_v3,
    auth: .sso("my-profile")
)
```

### System Prompts

```swift
let agent = try await Agent(
    systemPrompt: "You are a helpful assistant specialized in weather and finance.",
    tools: [WeatherTool(), FXRateTool()]
)
```

### Custom Logging

```swift
import Logging

var logger = Logger(label: "MyAgent")
logger.logLevel = .debug

let agent = try await Agent(
    tools: [WeatherTool()],
    logger: logger
)
```

## Examples

The `Example` directory contains complete working examples:

- **AgentClient**: Demonstrates various agent usage patterns
- **MCPServer**: Shows how to create MCP servers with tools
- **MCPClient**: Illustrates connecting to remote MCP servers

Build and run examples:

```bash
cd Example
swift build
.build/debug/AgentClient
.build/debug/MCPServer
.build/debug/MCPClient
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.