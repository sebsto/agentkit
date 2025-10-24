# Build stage
FROM swift:6.2 AS builder

RUN apt-get -y update && apt-get install -y libssl-dev

WORKDIR /AgentKit

# Copy full AgentKit project one level up
COPY .. .

# To cache the packages in a layer
RUN --mount=type=cache,target=/.swiftpm (cd Example && swift package resolve)

# Build MCPServer
RUN --mount=type=cache,target=/.swiftpm (cd Example && swift build -c release --product MCPServer -Xswiftc -g -Xlinker -s)

# Runtime stage
FROM swift:6.2-slim

WORKDIR /app

# Copy the built binary
COPY --from=builder /AgentKit/Example/.build/release/MCPServer /app/MCPServer

# Run the server
CMD ["./MCPServer"]