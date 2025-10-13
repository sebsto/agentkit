// DateFormatter is not yet available in FoundationEssentials 
// #if canImport(FoundationEssentials)
// import FoundationEssentials
// #else
import Foundation
// #endif

struct AWSTemporaryCredentials: Codable {
    let version: Int
    let accessKeyId: String
    let secretAccessKey: String
    let sessionToken: String
    let expiration: Date

    enum CodingKeys: String, CodingKey {
        case version = "Version"
        case accessKeyId = "AccessKeyId"
        case secretAccessKey = "SecretAccessKey"
        case sessionToken = "SessionToken"
        case expiration = "Expiration"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        accessKeyId = try container.decode(String.self, forKey: .accessKeyId)
        secretAccessKey = try container.decode(String.self, forKey: .secretAccessKey)
        sessionToken = try container.decode(String.self, forKey: .sessionToken)

        // Parse ISO 8601 date format
        let dateString = try container.decode(String.self, forKey: .expiration)

        guard let date = AWSTemporaryCredentials.dateFormatter().date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .expiration,
                in: container,
                debugDescription: "Date string does not match expected format"
            )
        }
        expiration = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(accessKeyId, forKey: .accessKeyId)
        try container.encode(secretAccessKey, forKey: .secretAccessKey)
        try container.encode(sessionToken, forKey: .sessionToken)

        // Format date as ISO 8601 string
        let formatter = AWSTemporaryCredentials.dateFormatter()
        let dateString = formatter.string(from: expiration)
        try container.encode(dateString, forKey: .expiration)
    }

    private static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
