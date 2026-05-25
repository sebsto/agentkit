import MCP

/// A type-safe builder for creating prompts with parameters
public struct PromptBuilder {
    public var name: String
    public var description: String
    public var template: String
    public var parameters: [String: String] = [:]

    public init(name: String, description: String) {
        self.name = name
        self.description = description
        self.template = ""
    }

    /// Sets the template text with parameter placeholders
    public mutating func text(_ text: String) {
        self.template = text
    }

    /// Adds a parameter to the template
    public mutating func parameter(_ name: String, description: String) {
        parameters[name] = description
    }

    /// Validates that all placeholders in the template have corresponding parameters
    private func validateParameters() throws {
        let pattern = /\{([^}]+)\}/
        let matches = template.matches(of: pattern)

        let placeholderNames = matches.map { match in
            String(match.1)
        }

        // Check for missing parameters
        let missingParameters = placeholderNames.filter { !parameters.keys.contains($0) }
        if !missingParameters.isEmpty {
            throw PromptError.missingParameters(missingParameters)
        }

        // Check for extra parameters
        let extraParameters = parameters.keys.filter { !placeholderNames.contains($0) }
        if !extraParameters.isEmpty {
            throw PromptError.extraParameters(extraParameters)
        }
    }

    /// Builds the final prompt
    public func build() throws -> MCPPrompt {
        try validateParameters()
        return MCPPrompt(
            name: name,
            description: description,
            template: template,
            parameters: parameters
        )
    }
}

/// Errors that can occur during prompt building and rendering
public enum PromptError: Swift.Error {
    case missingParameters([String])
    case extraParameters([String])
    case missingParameterValue(String)

    public var description: String {
        switch self {
        case .missingParameters(let params):
            return "Missing parameters: \(params.joined(separator: ", "))"
        case .extraParameters(let params):
            return "Extra parameters defined but not used in template: \(params.joined(separator: ", "))"
        case .missingParameterValue(let param):
            return "Missing value for parameter: \(param)"
        }
    }
}

/// A type-safe prompt with parameters
public struct MCPPrompt: Sendable, MCPPromptProtocol {
    public let name: String
    public let description: String
    public let template: String
    public let parameters: [String: String]

    /// Creates a new prompt with the given parameters
    public init(
        name: String,
        description: String,
        template: String,
        parameters: [String: String]
    ) {
        self.name = name
        self.description = description
        self.template = template
        self.parameters = parameters
    }

    /// Creates a prompt using a builder pattern
    public static func build(_ configure: (inout PromptBuilder) -> Void) throws -> MCPPrompt {
        var builder = PromptBuilder(name: "", description: "")
        configure(&builder)
        return try builder.build()
    }

    /// Renders the prompt with the given parameter values
    public func render(with values: [String: String]) throws -> String {
        var result = template
        for (name, _) in parameters {
            guard let value = values[name] else {
                throw PromptError.missingParameterValue(name)
            }
            result = result.replacingOccurrences(
                of: "{\(name)}",
                with: value
            )
        }
        return result
    }
}
