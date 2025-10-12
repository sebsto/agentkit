import BedrockService
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public extension Agent {

    /// Authentication methods supported by the agent.
    enum AuthenticationMethod {
        /// Use temporary credentials from a file path.
        case tempCredentials(String)
        /// Use a named AWS profile.
        case profile(String)
        /// Use AWS SSO with optional profile name.
        case sso(String?)
        /// Use default AWS credential chain.
        case `default`
    }
    
    // static because it is used by the initializer
    static package func makeBedrockAuth(auth: AuthenticationMethod, logger: Logger) throws -> BedrockAuthentication {
        let bedrockAuth: BedrockAuthentication
        switch auth {
        case .tempCredentials(let path):
            logger.warning(
                "Using temporary credentials file",
                metadata: ["path": .string(path)]
            )
            let tempCredentials = try Self.loadAWSCredentials(fromFile: path, logger: logger)
            bedrockAuth = .static(
                accessKey: tempCredentials.accessKeyId,
                secretKey: tempCredentials.secretAccessKey,
                sessionToken: tempCredentials.sessionToken
            )
        case .sso(let profileName):
            bedrockAuth = .sso(profileName: profileName ?? "default")
        case .profile(let profileName):
            bedrockAuth = .profile(profileName: profileName)
        default:
            bedrockAuth = .default
        }
        return bedrockAuth
    }

    private enum CredentialsError: Error {
        case fileNotFound(String)
        case invalidData(String)
        case decodingError(Error)
        case credentialsExpired(Date, Date)  // Includes expiration date and current date for context
    }
    private static func loadAWSCredentials(fromFile path: String, logger: Logger) throws -> AWSTemporaryCredentials {
        let fileManager = FileManager.default

        // Check if file exists
        guard fileManager.fileExists(atPath: path) else {
            throw CredentialsError.fileNotFound("Credentials file not found at path: \(path)")
        }

        // Read file data
        guard let data = fileManager.contents(atPath: path) else {
            throw CredentialsError.invalidData("Could not read data from file: \(path)")
        }

        logger.info(
            "Using temporary credentials file",
            metadata: ["path": .string(path)]
        )

        // Decode JSON into AWSTemporaryCredentials
        let credentials: AWSTemporaryCredentials
        do {
            let decoder = JSONDecoder()
            credentials = try decoder.decode(AWSTemporaryCredentials.self, from: data)
        } catch {
            throw CredentialsError.decodingError(error)
        }
        // Verify credentials haven't expired
        let currentDate = Date()
        if currentDate >= credentials.expiration {
            throw CredentialsError.credentialsExpired(credentials.expiration, currentDate)
        }
        return credentials
    }
}
