import BedrockService

/// Agent callback functionality for handling events during agent execution.
extension Agent {

    /// Metadata type alias for response metadata from Bedrock service.
    public typealias MetaData = ResponseMetadata

    /// Tool use type alias for tool use blocks from Bedrock service.
    public typealias ToolUse = ToolUseBlock

    /// Function type for handling agent callback events.
    /// - Parameter event: The callback event to handle.
    public typealias AgentCallbackFunction = (AgentCallbackEvent) -> Void

    /// Events that can occur during agent execution.
    public enum AgentCallbackEvent: Sendable, CustomStringConvertible {
        /// Text content received from the agent.
        case text(String)
        /// Tool use request from the agent.
        case toolUse(ToolUse)
        /// Complete message received from the agent.
        case message(Message)
        /// Metadata about the agent response.
        case metaData(MetaData)
        /// Agent execution has ended.
        case end

        // this allows users to print(event) in a callback function
        public var description: String {
            switch self {
            case .text(let content):
                return content
            case .message(_):
                return "\n"
            default:
                return ""
            }
        }
    }

}
