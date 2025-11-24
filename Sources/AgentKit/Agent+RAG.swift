import BedrockService
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Agent {

    public enum RAG {
        case bedrockKnowledgeBase(String)
    }

    func retrieve(ragSystem: RAG, query: String, maxResult: Int) async throws -> String {

        guard case let .bedrockKnowledgeBase(knowledgeBaseId) = ragSystem else {
            fatalError("This library only support Bedrock Knowledgebase at the moment")
        }

        logger.trace("Invoking RAG system", metadata: ["KnowledgeBaseId": "\(knowledgeBaseId)"])
        let result = try await self.bedrock.retrieve(knowledgeBaseId: knowledgeBaseId, retrievalQuery: query, numberOfResults: maxResult)
        return try result.toJSON()
    }
}