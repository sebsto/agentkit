import AgentKit

/// Examples of how to use the MCPPrompt API
enum MCPPromptExample {
    /// Example of a code review prompt
    static func codeReviewPrompt() throws -> MCPPrompt {
        try MCPPrompt.build { builder in
            builder.name = "code-review"
            builder.description = "A prompt for reviewing code"
            builder.text("Please review this code: {code} in {language}")
            builder.parameter("code", description: "the code to review")
            builder.parameter("language", description: "the language of the code")
        }
    }

    /// Example of rendering a code review prompt
    static func renderCodeReviewPrompt() throws -> String {
        let prompt = try codeReviewPrompt()
        return try prompt.render(with: [
            "code": "print('Hello, World!')",
            "language": "Python",
        ])
    }

    /// Example of a greeting prompt
    static func greetingPrompt() throws -> MCPPrompt {
        try MCPPrompt.build { builder in
            builder.name = "greeting"
            builder.description = "A greeting prompt"
            builder.text("Hello {name}, welcome to {place}")
            builder.parameter("name", description: "The name to greet")
            builder.parameter("place", description: "The place to welcome to")
        }
    }

    /// Example of rendering a greeting prompt
    static func renderGreetingPrompt() throws -> String {
        let prompt = try greetingPrompt()
        return try prompt.render(with: [
            "name": "Alice",
            "place": "Wonderland",
        ])
    }

    /// Example of a prompt with nested braces
    static func nestedBracesPrompt() throws -> MCPPrompt {
        try MCPPrompt.build { builder in
            builder.name = "nested"
            builder.description = "A prompt with nested braces"
            builder.text("This is {not_a_parameter} but this is {parameter}")
            builder.parameter("not_a_parameter", description: "A non-parameter")
            builder.parameter("parameter", description: "A parameter")
        }
    }

    /// Example of rendering a prompt with nested braces
    static func renderNestedBracesPrompt() throws -> String {
        let prompt = try nestedBracesPrompt()
        return try prompt.render(with: [
            "not_a_parameter": "{still_not_a_parameter}",
            "parameter": "value",
        ])
    }
}
