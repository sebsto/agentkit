import MCP

extension MCPServer {
    /// Register prompts with the server
    package func registerPrompts(prompts: [MCPPrompt]) async {
        // register the prompts, part 1 : prompts/list
        await server.withMethodHandler(ListPrompts.self) { params in
            let _prompts = prompts.map { $0.toPrompt() }
            return ListPrompts.Result(prompts: _prompts, nextCursor: nil)
        }

        // register the prompts, part 2 : prompts/get
        await server.withMethodHandler(GetPrompt.self) { params in
            // Check if the prompt name is in our list of prompts
            guard let prompt = prompts.first(where: { $0.name == params.name }) else {
                throw MCPServerError.unknownPrompt(params.name)
            }

            // If arguments are provided, render the prompt
            var messages: [Prompt.Message] = []
            if let arguments = params.arguments {
                let values = arguments.mapValues { value in
                    String(describing: value)
                }
                messages.append(try prompt.toMessage(with: values))
            }

            // If no arguments, return empty messages
            return GetPrompt.Result(description: prompt.description, messages: messages)
        }
    }
}
