import AgentKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// This tool provides foreign exchange rates between currencies using the Hexarate API.

@SchemaDefinition
// Input structure for the FX rates tool.
// The docc headers will be used to generate the description in the JSON schema
struct FXRatesInput: Codable {
    /// The source currency code (e.g., USD, EUR, GBP)
    /// Must be a valid 3-letter ISO 4217 currency code.
    /// Example: "USD" for US Dollar, "EUR" for Euro.
    /// RegEx pattern: ^[A-Z]{3}$
    let sourceCurrency: String

    /// The target currency code (e.g., USD, EUR, GBP)
    /// Must be a valid 3-letter ISO 4217 currency code.
    /// Example: "USD" for US Dollar, "EUR" for Euro.
    /// RegEx pattern: ^[A-Z]{3}$
    let targetCurrency: String
}

@Tool(
    name: "foreign_exchange_rates",
    description:
        "Get current foreign exchange rates between two currencies. This tool uses the Hexarate API to provide real-time exchange rates. Supports major world currencies using standard 3-letter currency codes (ISO 4217). Returns the current exchange rate from the source currency to the target currency.",
    schema: FXRatesInput.self
)
struct FXRateTool {
    typealias Input = FXRatesInput
    typealias Output = String

    // Fetches foreign exchange rates from the Hexarate API.
    func handle(input: FXRatesInput) async throws -> String {
        // Construct the API URL using the Hexarate API
        let fxURL =
            "https://hexarate.paikama.co/api/rates/latest/\(input.sourceCurrency)?target=\(input.targetCurrency)"
        let url = URL(string: fxURL)
        guard let url else {
            throw MCPServerError.invalidParam("currency", "\(input.sourceCurrency) or \(input.targetCurrency)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)

        // return the data as a string
        return String(decoding: data, as: UTF8.self)
    }

}

// Optional: Create a prompt for the FX rates tool
let fxRatesPrompt = try! MCPPrompt.build { builder in
    builder.name = "exchange-rate"
    builder.description = "A prompt asking for the current exchange rate between two currencies"
    builder.text("What is the current exchange rate from {source_currency} to {target_currency}?")
    builder.parameter("source_currency", description: "the 3-letter code of the source currency (e.g., USD)")
    builder.parameter("target_currency", description: "the 3-letter code of the target currency (e.g., EUR)")
}
