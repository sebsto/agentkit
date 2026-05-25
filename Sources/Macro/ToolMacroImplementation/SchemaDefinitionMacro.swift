#if MCPMacros

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import ToolShared

/// A macro that generates an OpenAPI schema for a type
public struct SchemaDefinitionMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return []
        }

        let schemaJson = SchemaGenerationUtils.generateSchemaJson(from: structDecl)
        let accessLevel = SchemaGenerationUtils.extractAccessLevel(from: structDecl)
        let accessModifier = accessLevel.map { "\($0) " } ?? ""

        // Clean the JSON but don't escape quotes - SwiftSyntax will handle that
        let cleanedJson =
            schemaJson
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Use SwiftSyntax to properly create the string literal
        let schemaProperty: DeclSyntax = """
            \(raw: accessModifier)static var schema: String {
                return \(literal: cleanedJson)
            }
            """

        return [schemaProperty]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let schemaExtension = try ExtensionDeclSyntax("extension \(type): Schema {}")
        return [schemaExtension]
    }
}

#endif
