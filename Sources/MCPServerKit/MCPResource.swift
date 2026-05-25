import Foundation
import MCP
import Synchronization

/// A high-level wrapper for MCP Resources that simplifies resource creation and management.
///
/// `MCPResource` provides a developer-friendly API for working with Model Context Protocol resources,
/// making it easier to define, register, and manage resources in your MCP server.
///
/// Example usage:
/// ```swift
/// // Create a text resource
/// let textResource = MCPResource.text(
///     name: "Documentation",
///     uri: "docs://api-reference",
///     content: "# API Reference\n\nThis document describes...",
///     description: "API documentation for developers",
///     mimeType: "text/markdown"
/// )
///
/// // Create a binary resource
/// let imageData = Data(/* ... */)
/// let imageResource = MCPResource.binary(
///     name: "Logo",
///     uri: "images://logo",
///     data: imageData,
///     description: "Company logo",
///     mimeType: "image/png"
/// )
/// ```
public struct MCPResource: Hashable, Sendable {
    /// The underlying MCP Resource
    public let resource: Resource

    /// The content of this resource
    public let content: Resource.Content

    /// Creates a new MCPResource with the specified parameters
    /// - Parameters:
    ///   - name: The resource name
    ///   - uri: The resource URI
    ///   - content: The resource content
    ///   - description: Optional description of the resource
    ///   - mimeType: Optional MIME type of the resource
    ///   - metadata: Optional metadata for the resource
    public init(
        name: String,
        uri: String,
        content: Resource.Content,
        description: String? = nil,
        mimeType: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.resource = Resource(
            name: name,
            uri: uri,
            description: description,
            mimeType: mimeType
        )
        self.content = content
    }

    /// Creates a text-based resource
    /// - Parameters:
    ///   - name: The resource name
    ///   - uri: The resource URI
    ///   - content: The text content
    ///   - description: Optional description of the resource
    ///   - mimeType: Optional MIME type of the resource (defaults to .plainText)
    ///   - metadata: Optional metadata for the resource
    /// - Returns: A new MCPResource instance
    public static func text(
        name: String,
        uri: String,
        content: String,
        description: String? = nil,
        mimeType: MIMEType = .plainText,
        metadata: [String: String]? = nil
    ) -> MCPResource {
        MCPResource(
            name: name,
            uri: uri,
            content: .text(content, uri: uri, mimeType: mimeType.value),
            description: description,
            mimeType: mimeType.value,
            metadata: metadata
        )
    }

    /// Creates a text-based resource with a string MIME type
    /// - Parameters:
    ///   - name: The resource name
    ///   - uri: The resource URI
    ///   - content: The text content
    ///   - description: Optional description of the resource
    ///   - mimeType: Optional MIME type string (defaults to "text/plain")
    ///   - metadata: Optional metadata for the resource
    /// - Returns: A new MCPResource instance
    public static func text(
        name: String,
        uri: String,
        content: String,
        description: String? = nil,
        mimeTypeString: String? = "text/plain",
        metadata: [String: String]? = nil
    ) -> MCPResource {
        MCPResource(
            name: name,
            uri: uri,
            content: .text(content, uri: uri, mimeType: mimeTypeString),
            description: description,
            mimeType: mimeTypeString,
            metadata: metadata
        )
    }

    /// Creates a binary resource
    /// - Parameters:
    ///   - name: The resource name
    ///   - uri: The resource URI
    ///   - data: The binary data
    ///   - description: Optional description of the resource
    ///   - mimeType: Optional MIME type of the resource
    ///   - metadata: Optional metadata for the resource
    /// - Returns: A new MCPResource instance
    public static func binary(
        name: String,
        uri: String,
        data: Data,
        description: String? = nil,
        mimeType: MIMEType? = nil,
        metadata: [String: String]? = nil
    ) -> MCPResource {
        MCPResource(
            name: name,
            uri: uri,
            content: .binary(data, uri: uri, mimeType: mimeType?.value),
            description: description,
            mimeType: mimeType?.value,
            metadata: metadata
        )
    }

    /// Creates a binary resource with a string MIME type
    /// - Parameters:
    ///   - name: The resource name
    ///   - uri: The resource URI
    ///   - data: The binary data
    ///   - description: Optional description of the resource
    ///   - mimeTypeString: Optional MIME type string
    ///   - metadata: Optional metadata for the resource
    /// - Returns: A new MCPResource instance
    public static func binary(
        name: String,
        uri: String,
        data: Data,
        description: String? = nil,
        mimeTypeString: String? = nil,
        metadata: [String: String]? = nil
    ) -> MCPResource {
        MCPResource(
            name: name,
            uri: uri,
            content: .binary(data, uri: uri, mimeType: mimeTypeString),
            description: description,
            mimeType: mimeTypeString,
            metadata: metadata
        )
    }

    /// Creates a file-based resource by reading from the specified file path
    /// - Parameters:
    ///   - name: The resource name
    ///   - uri: The resource URI
    ///   - filePath: Path to the file to read
    ///   - description: Optional description of the resource
    ///   - mimeType: Optional MIME type of the resource (if nil, will attempt to determine from file extension)
    ///   - metadata: Optional metadata for the resource
    /// - Returns: A new MCPResource instance
    /// - Throws: If the file cannot be read
    public static func file(
        name: String,
        uri: String,
        filePath: String,
        description: String? = nil,
        mimeType: MIMEType? = nil,
        metadata: [String: String]? = nil
    ) throws -> MCPResource {
        let url = URL(fileURLWithPath: filePath)
        let detectedMimeType = mimeType?.value ?? mimeTypeForFileExtension(url.pathExtension)

        let data = try Data(contentsOf: url)

        // For text files, create a text resource
        if let detectedMimeType = detectedMimeType,
            detectedMimeType.hasPrefix("text/") || detectedMimeType == MIMEType.json.value
                || detectedMimeType == MIMEType.xml.value
        {
            guard let textContent = String(data: data, encoding: .utf8) else {
                throw MCPResourceError.invalidTextEncoding
            }
            return .text(
                name: name,
                uri: uri,
                content: textContent,
                description: description,
                mimeTypeString: detectedMimeType,
                metadata: metadata
            )
        }

        // For binary files, create a binary resource
        return .binary(
            name: name,
            uri: uri,
            data: data,
            description: description,
            mimeTypeString: detectedMimeType,
            metadata: metadata
        )
    }

    /// Creates a file-based resource by reading from the specified file path with a string MIME type
    /// - Parameters:
    ///   - name: The resource name
    ///   - uri: The resource URI
    ///   - filePath: Path to the file to read
    ///   - description: Optional description of the resource
    ///   - mimeTypeString: Optional MIME type string (if nil, will attempt to determine from file extension)
    ///   - metadata: Optional metadata for the resource
    /// - Returns: A new MCPResource instance
    /// - Throws: If the file cannot be read
    public static func file(
        name: String,
        uri: String,
        filePath: String,
        description: String? = nil,
        mimeTypeString: String? = nil,
        metadata: [String: String]? = nil
    ) throws -> MCPResource {
        let url = URL(fileURLWithPath: filePath)
        let detectedMimeType = mimeTypeString ?? mimeTypeForFileExtension(url.pathExtension)

        let data = try Data(contentsOf: url)

        // For text files, create a text resource
        if let detectedMimeType = detectedMimeType,
            detectedMimeType.hasPrefix("text/") || detectedMimeType == MIMEType.json.value
                || detectedMimeType == MIMEType.xml.value
        {
            guard let textContent = String(data: data, encoding: .utf8) else {
                throw MCPResourceError.invalidTextEncoding
            }
            return .text(
                name: name,
                uri: uri,
                content: textContent,
                description: description,
                mimeTypeString: detectedMimeType,
                metadata: metadata
            )
        }

        // For binary files, create a binary resource
        return .binary(
            name: name,
            uri: uri,
            data: data,
            description: description,
            mimeTypeString: detectedMimeType,
            metadata: metadata
        )
    }

    /// MIME type representation for common file types
    public enum MIMEType: String {
        // Text formats
        case plainText = "text/plain"
        case html = "text/html"
        case css = "text/css"
        case javascript = "text/javascript"
        case json = "application/json"
        case xml = "application/xml"
        case markdown = "text/markdown"
        case csv = "text/csv"

        // Document formats
        case pdf = "application/pdf"

        // Image formats
        case png = "image/png"
        case jpeg = "image/jpeg"
        case gif = "image/gif"
        case svg = "image/svg+xml"

        // Audio formats
        case mp3 = "audio/mpeg"
        case wav = "audio/wav"

        // Video formats
        case mp4 = "video/mp4"
        case webm = "video/webm"

        // Archive formats
        case zip = "application/zip"

        /// Get the raw MIME type string
        public var value: String {
            rawValue
        }

        /// Determine if this is a text-based MIME type
        public var isText: Bool {
            rawValue.hasPrefix("text/") || rawValue == "application/json" || rawValue == "application/xml"
        }
    }

    /// Helper function to determine MIME type from file extension
    private static func mimeTypeForFileExtension(_ extension: String) -> String? {
        let fileExtension = `extension`.lowercased()

        let mimeType: MIMEType? = {
            switch fileExtension {
            case "txt":
                return .plainText
            case "html", "htm":
                return .html
            case "css":
                return .css
            case "js":
                return .javascript
            case "json":
                return .json
            case "xml":
                return .xml
            case "md", "markdown":
                return .markdown
            case "csv":
                return .csv
            case "pdf":
                return .pdf
            case "png":
                return .png
            case "jpg", "jpeg":
                return .jpeg
            case "gif":
                return .gif
            case "svg":
                return .svg
            case "mp3":
                return .mp3
            case "wav":
                return .wav
            case "mp4":
                return .mp4
            case "webm":
                return .webm
            case "zip":
                return .zip
            default:
                return nil
            }
        }()

        return mimeType?.value
    }
}

/// Errors that can occur when working with MCPResources
public enum MCPResourceError: Swift.Error {
    /// The file could not be read as text with UTF-8 encoding
    case invalidTextEncoding
    /// The resource URI is invalid
    case invalidURI(String)
    /// The resource could not be found
    case resourceNotFound(String)
}

/// A collection of resources that can be registered with an MCP server
public final class MCPResourceRegistry: Sendable {
    private let mutex: Mutex<[MCPResource]>

    /// The resources in this registry
    public var resources: [MCPResource] {
        mutex.withLock { $0 }
    }

    /// Creates a new empty resource registry
    public init() {
        self.mutex = Mutex([])
    }

    /// Creates a resource registry with the specified resources
    /// - Parameter resources: The resources to include in this registry
    public init(resources: [MCPResource]) {
        self.mutex = Mutex(resources)
    }

    /// Adds a resource to the registry
    /// - Parameter resource: The resource to add
    /// - Returns: The registry, for chaining
    @discardableResult
    public func add(_ resource: MCPResource) -> Self {
        mutex.withLock { $0.append(resource) }
        return self
    }

    /// Adds multiple resources to the registry
    /// - Parameter resources: The resources to add
    /// - Returns: The registry, for chaining
    @discardableResult
    public func add(_ resources: [MCPResource]) -> Self {
        mutex.withLock { $0.append(contentsOf: resources) }
        return self
    }

    /// Adds multiple resources to the registry
    /// - Parameter resources: The resources to add
    /// - Returns: The registry, for chaining
    @discardableResult
    public func add(_ resources: MCPResource...) -> Self {
        add(resources)
    }

    /// Removes a resource from the registry
    /// - Parameter uri: The URI of the resource to remove
    /// - Returns: The registry, for chaining
    @discardableResult
    public func remove(uri: String) -> Self {
        mutex.withLock { $0.removeAll { $0.resource.uri == uri } }
        return self
    }

    /// Finds a resource by URI
    /// - Parameter uri: The URI to search for
    /// - Returns: The resource, if found
    public func find(uri: String) -> MCPResource? {
        mutex.withLock { $0.first { $0.resource.uri == uri } }
    }

    /// Converts the registry to a list of MCP Resource objects
    /// - Returns: An array of MCP Resource objects
    public func asMCPSDKResources() -> [Resource] {
        mutex.withLock { $0.map { $0.resource } }
    }

    /// Converts the registry to a map of MCP Resource.Content objects by URI
    /// - Returns: A dictionary mapping URIs to Resource.Content objects
    public func asContentMap() -> [String: Resource.Content] {
        mutex.withLock { Dictionary(uniqueKeysWithValues: $0.map { ($0.resource.uri, $0.content) }) }
    }
}
