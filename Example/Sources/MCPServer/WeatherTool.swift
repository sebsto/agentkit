import AgentKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// This tool returns current weather and weather forecast for a given city.

@Tool(
    name: "weather",
    description:
        "This tool returns current weather and weather forecast for a given city. It returns current data and forecasted data, such as temperature in celsius and farenheit, humidity, rain level in milimiters and inches, wind speed in kmh and mph and direction, pressure in milibar and inches, visibility, weather description."
)
struct WeatherTool {
    typealias Input = String
    typealias Output = String

    /// Get weather information for a specific city
    /// - Parameter input: The city name to get the weather for
    func handle(input city: String) async throws -> String {
        let weatherURL = "http://wttr.in/\(city)?format=j1"
        let url = URL(string: weatherURL)
        guard let url else {
            throw MCPServerError.invalidParam("city", "\(city)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)

        // return the data as a string
        return String(decoding: data, as: UTF8.self)
    }
}

let myWeatherPrompt = try! MCPPrompt.build { builder in
    builder.name = "current-weather"
    builder.description = "A prompt asking the current weather for a given city"
    builder.text("What is the weather today in {city}?")
    builder.parameter("city", description: "the name of the city to get the weather for")
}
