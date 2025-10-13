import BedrockService

extension Agent {
    public enum AgentError: Error, Equatable {
        case modelNotSupported(BedrockModel)
        case toolNotFound(String)
        case toolInputNotFound(JSON)
        case maxRetriesExceeded(Error?)

        public static func == (lhs: AgentError, rhs: AgentError) -> Bool {
            switch (lhs, rhs) {
            case (.modelNotSupported(let lhsModel), .modelNotSupported(let rhsModel)):
                return lhsModel == rhsModel
            case (.toolNotFound(let lhsTool), .toolNotFound(let rhsTool)):
                return lhsTool == rhsTool
            case (.toolInputNotFound(_), .toolInputNotFound(_)):
                return true
            case (.maxRetriesExceeded, .maxRetriesExceeded):
                return true
            default:
                return false
            }
        }

    }
}
