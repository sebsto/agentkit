import BedrockService

extension Agent {
    public enum AgentError: Error {
        case modelNotSupported(BedrockModel)
        case toolNotFound(String)
        case toolInputNotFound(JSON)
        case maxRetriesExceeded(Error?)
    }
}
