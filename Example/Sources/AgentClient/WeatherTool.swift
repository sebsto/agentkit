import AgentKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Tool(
    name: "weather",
    description: "Get detailled weather information for a city."
)
struct WeatherTool {
    /// Get weather information for a specific city
    /// - Parameter input: The city name to get the weather for
    func handle(input city: String) async throws -> String {
        let weatherURL = "http://wttr.in/\(city)?format=j1"
        let url = URL(string: weatherURL)!
        let (data, _) = try await URLSession.shared.data(from: url)

        // return the data as a string
        return String(decoding: data, as: UTF8.self)
    }
}
