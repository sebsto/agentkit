// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "AIAgentExample",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "MCPClient", targets: ["MCPClient"]),
        .executable(name: "MCPServer", targets: ["MCPServer"]),
        .executable(name: "AgentClient", targets: ["AgentClient"]),
    ],
    dependencies: [
        .package(name: "AgentKit", path: "..")
    ],
    targets: [
        .executableTarget(
            name: "MCPServer",
            dependencies: [
                .product(name: "AgentKit", package: "AgentKit")
            ],
            // path: "Sources/MCPServer"
        ),
        .executableTarget(
            name: "MCPClient",
            dependencies: [
                .product(name: "AgentKit", package: "AgentKit")
            ],
            // path: "Sources/MCPClient"
        ),
        .executableTarget(
            name: "AgentClient",
            dependencies: [
                .product(name: "AgentKit", package: "AgentKit")
            ],
            // path: "Sources/AgentClient"
        ),
    ]
)
