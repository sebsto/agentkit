#if MCPMacros

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import ToolShared

enum ToolError: Error, CustomStringConvertible {
    case unsupportedDeclaration
    case missingInputType
    case missingHandlerFunction
    case missingDocComment
    case parameterMismatch(String)

    var description: String {
        switch self {
        case .unsupportedDeclaration:
            return "Tool macro can only be applied to structs that implement ToolProtocol"
        case .missingInputType:
            return "Could not determine Input type from ToolProtocol conformance"
        case .missingHandlerFunction:
            return "Could not find handler function in the struct"
        case .missingDocComment:
            return "Handler function must have a DocC comment with parameter descriptions"
        case .parameterMismatch(let message):
            return "Parameter mismatch between DocC comment and function signature: \(message)"
        }
    }
}

struct SchemaInfo {
    let parameters: [ParameterInfo]
}

public struct ParameterInfo {
    public let name: String
    public let type: String
    public let description: String?
    public let isOptional: Bool

    public init(name: String, type: String, description: String?, isOptional: Bool) {
        self.name = name
        self.type = type
        self.description = description
        self.isOptional = isOptional
    }
}

struct DocCommentParser {
    func parse(_ docComment: String, functionDecl: FunctionDeclSyntax) throws -> SchemaInfo {
        let lines = docComment.components(separatedBy: .newlines)
        var parameters: [ParameterInfo] = []

        let functionParams = functionDecl.signature.parameterClause.parameters

        for (_, param) in functionParams.enumerated() {
            let paramName = param.firstName.text
            let paramType = param.type.trimmed.description
            let isOptional = paramType.hasSuffix("?")

            var description: String?
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- Parameter") {
                    if (paramName == "_" && trimmed.contains("- Parameter _:"))
                        || (paramName != "_" && trimmed.contains("- Parameter \(paramName):"))
                    {
                        let parts = trimmed.components(separatedBy: ": ")
                        if parts.count > 1 {
                            description = parts.dropFirst().joined(separator: ": ").trimmingCharacters(in: .whitespaces)
                        }
                        break
                    }
                }
            }

            guard description != nil else {
                throw ToolError.parameterMismatch(paramName)
            }

            let paramInfo = ParameterInfo(
                name: paramName == "_" ? "input" : paramName,
                type: paramType,
                description: description,
                isOptional: isOptional
            )
            parameters.append(paramInfo)
        }

        return SchemaInfo(parameters: parameters)
    }
}

public struct ToolMacro: MemberMacro, ExtensionMacro {

    // Helper function to get access modifier string
    private static func getAccessModifier(from structDecl: StructDeclSyntax) -> String {
        let accessLevel = SchemaGenerationUtils.extractAccessLevel(from: structDecl)
        return accessLevel.map { "\($0) " } ?? ""
    }

    // Helper function to check if a property already exists
    private static func propertyExists(named propertyName: String, in structDecl: StructDeclSyntax) -> Bool {
        for member in structDecl.memberBlock.members {
            if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in variableDecl.bindings {
                    if let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                        identifier.identifier.text == propertyName
                    {
                        return true
                    }
                }
            }
        }
        return false
    }

    // Helper function to check if an initializer already exists
    private static func initializerExists(in structDecl: StructDeclSyntax) -> Bool {
        for member in structDecl.memberBlock.members {
            if member.decl.is(InitializerDeclSyntax.self) {
                return true
            }
        }
        return false
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw ToolError.unsupportedDeclaration
        }

        let (name, description, schema) = try extractMacroArguments(from: node)

        var properties: [DeclSyntax] = []

        if let name {
            if let nameProperty = try generateNameProperty(name: name, in: structDecl) {
                properties.append(nameProperty)
            }
        }

        if let description {
            if let descriptionProperty = try generateDescriptionProperty(description: description, in: structDecl) {
                properties.append(descriptionProperty)
            }
        }

        // If schema is provided, use it directly. Otherwise generate it from DocC comments
        if let schema {
            let schemaProperty = generateSchemaInstanceInputSchemaProperty(
                from: schema,
                in: structDecl,
                context: context
            )
            properties.append(schemaProperty)
        } else {
            // Only when no schema is provided, require and process DocC comments
            let (handlerFunc, docComment) = try findHandlerFunctionWithDocComment(in: structDecl)
            let schemaInfo = try parseDocComment(docComment, for: handlerFunc)
            try validateParameterConsistency(schemaInfo: schemaInfo, handlerFunc: handlerFunc)
            properties.append(generateInputSchemaProperty(from: schemaInfo, in: structDecl, context: context))
        }

        // Generate initializer if none exists
        if !initializerExists(in: structDecl) {
            let accessModifier = getAccessModifier(from: structDecl)
            let initDecl: DeclSyntax = "\(raw: accessModifier)init() {}"
            properties.append(initDecl)
        }

        return properties
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw ToolError.unsupportedDeclaration
        }

        let structName = structDecl.name.text

        // Always generate internal extension to avoid public protocol conformance issues
        let extensionDecl: DeclSyntax = """
            extension \(raw: structName): ToolProtocol {}
            """

        guard let extensionSyntax = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionSyntax]
    }

    private static func extractMacroArguments(
        from node: AttributeSyntax
    ) throws -> (name: String?, description: String?, schema: String?) {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return (nil, nil, nil)
        }

        var name: String?
        var description: String?
        var schema: String?

        for argument in arguments {
            if let label = argument.label?.text {
                switch label {
                case "name":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                        let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                    {
                        name = segment.content.text
                    }
                case "description":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                        let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                    {
                        description = segment.content.text
                    }
                case "schema":
                    // Extract the schema instance or type passed as argument
                    let expressionString = argument.expression.trimmed.description

                    // Check if it's a metatype reference (ends with .self)
                    if expressionString.hasSuffix(".self") {
                        // Remove .self and use the type name for static access
                        let typeName = String(expressionString.dropLast(5))  // Remove ".self"
                        schema = "\(typeName)"  // Will be handled as static access
                    } else {
                        // Regular instance expression
                        schema = expressionString
                    }

                default:
                    break
                }
            }
        }

        return (name, description, schema)
    }

    public static func generateNameProperty(name: String, in structDecl: StructDeclSyntax) throws -> DeclSyntax? {
        guard !propertyExists(named: "toolName", in: structDecl) else {
            return nil  // Property already exists, don't generate it
        }

        let accessModifier = getAccessModifier(from: structDecl)

        let nameProperty: DeclSyntax = """
            \(raw: accessModifier)let toolName = "\(raw: name)"
            """

        return nameProperty
    }

    public static func generateDescriptionProperty(
        description: String,
        in structDecl: StructDeclSyntax
    ) throws -> DeclSyntax? {
        guard !propertyExists(named: "toolDescription", in: structDecl) else {
            return nil  // Property already exists, don't generate it
        }

        let accessModifier = getAccessModifier(from: structDecl)

        let descriptionProperty: DeclSyntax = """
            \(raw: accessModifier)let toolDescription = "\(raw: description)"
            """

        return descriptionProperty
    }

    private static func generateInputSchemaProperty(
        from schemaInfo: SchemaInfo,
        in structDecl: StructDeclSyntax,
        context: some MacroExpansionContext
    ) -> DeclSyntax {
        let accessModifier = getAccessModifier(from: structDecl)

        let schemaJson = generateSchemaJson(from: schemaInfo, in: structDecl, context: context)
        let escapedSchemaJson = SchemaGenerationUtils.cleanAndEscapeJson(schemaJson)

        let propertyCode = "\(accessModifier)var inputSchema: String { return \"\(escapedSchemaJson)\" }"
        let schemaProperty: DeclSyntax = "\(raw: propertyCode)"

        return schemaProperty
    }

    private static func generateSchemaInstanceInputSchemaProperty(
        from schemaExpression: String,
        in structDecl: StructDeclSyntax,
        context: some MacroExpansionContext
    ) -> DeclSyntax {
        let accessModifier = getAccessModifier(from: structDecl)

        // Generate code to access the schema property (works for both static and instance access)
        let propertyCode = "\(accessModifier)var inputSchema: String { return (\(schemaExpression)).schema }"

        let schemaProperty: DeclSyntax = "\(raw: propertyCode)"
        return schemaProperty
    }

    private static func generateSchemaJson(
        from schemaInfo: SchemaInfo,
        in structDecl: StructDeclSyntax,
        context: some MacroExpansionContext
    ) -> String {
        if schemaInfo.parameters.count == 1 {
            let param = schemaInfo.parameters[0]
            return generateSingleParameterSchema(param, in: structDecl, context: context)
        } else {
            return generateObjectSchema(from: schemaInfo)
        }
    }

    public static func generateSingleParameterSchema(
        _ param: ParameterInfo,
        in structDecl: StructDeclSyntax,
        context: some MacroExpansionContext
    ) -> String {
        let cleanType = param.type.replacingOccurrences(of: "?", with: "")

        // First, check if it's a nested type within the struct
        if let nestedStruct = SchemaGenerationUtils.findNestedType(in: structDecl, typeName: cleanType) {
            return SchemaGenerationUtils.generateSchemaJson(from: nestedStruct, description: param.description)
        }

        // If it's not a nested type, check if it's an external type with @SchemaDefinition
        if !isBuiltInType(cleanType) {
            // Check if the type has @SchemaDefinition
            // if hasSchemaDefinition(cleanType, in: context) {
            // Return the schema from the external type's static schema property
            // }
        }

        // For built-in types, wrap them in an object schema for Bedrock compatibility
        if isBuiltInType(cleanType) {
            let typeSchema = SchemaGenerationUtils.generateTypeSchema(param.type)
            let propertyName = param.name

            var propertySchema: String
            if let description = param.description {
                propertySchema =
                    "\"\(propertyName)\": { \"type\": \"\(typeSchema)\", \"description\": \"\(description)\" }"
            } else {
                propertySchema = "\"\(propertyName)\": { \"type\": \"\(typeSchema)\" }"
            }

            let required = param.isOptional ? "" : ", \"required\": [\"\(propertyName)\"]"
            return "{ \"type\": \"object\", \"properties\": { \(propertySchema) }\(required) }"
        }

        // Fallback for non-built-in types (shouldn't reach here normally)
        let typeSchema = SchemaGenerationUtils.generateTypeSchema(param.type)
        if let description = param.description {
            return "{ \"type\": \"\(typeSchema)\", \"description\": \"\(description)\" }"
        } else {
            return "{ \"type\": \"\(typeSchema)\" }"
        }
    }

    private static func isBuiltInType(_ type: String) -> Bool {
        let builtInTypes = ["String", "Int", "Double", "Float", "Bool", "Int32", "Int64", "UInt", "UInt32", "UInt64"]
        return builtInTypes.contains(type)
    }

    private static func generateObjectSchema(from schemaInfo: SchemaInfo) -> String {
        var properties: [String] = []
        var required: [String] = []

        for param in schemaInfo.parameters {
            let typeSchema = SchemaGenerationUtils.generateTypeSchema(param.type)

            var propertySchema: String
            if let description = param.description {
                propertySchema =
                    "\"\(param.name)\": { \"type\": \"\(typeSchema)\", \"description\": \"\(description)\" }"
            } else {
                propertySchema = "\"\(param.name)\": { \"type\": \"\(typeSchema)\" }"
            }

            properties.append(propertySchema)

            if !param.isOptional {
                required.append("\"\(param.name)\"")
            }
        }

        let propertiesJson = properties.joined(separator: ", ")
        let requiredJson = required.joined(separator: ", ")

        var schema: String
        if !required.isEmpty {
            schema = "{ \"type\": \"object\", \"properties\": { \(propertiesJson) }, \"required\": [\(requiredJson)] }"
        } else {
            schema = "{ \"type\": \"object\", \"properties\": { \(propertiesJson) } }"
        }

        return schema
    }

    private static func findHandlerFunctionWithDocComment(
        in structDecl: StructDeclSyntax
    ) throws -> (FunctionDeclSyntax, String) {
        for member in structDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self),
                functionDecl.name.text == "handle"
            {

                let docComment = extractDocComment(from: functionDecl)
                if docComment.isEmpty {
                    throw ToolError.missingDocComment
                }

                return (functionDecl, docComment)
            }
        }

        throw ToolError.missingHandlerFunction
    }

    private static func extractDocComment(from functionDecl: FunctionDeclSyntax) -> String {
        var docLines: [String] = []

        for piece in functionDecl.leadingTrivia {
            switch piece {
            case .docLineComment(let text):
                let cleanText = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                docLines.append(cleanText)
            case .docBlockComment(let text):
                let cleanText =
                    text
                    .dropFirst(3)
                    .dropLast(2)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                docLines.append(cleanText)
            default:
                continue
            }
        }

        return docLines.joined(separator: "\n")
    }

    private static func parseDocComment(_ docComment: String, for handlerFunc: FunctionDeclSyntax) throws -> SchemaInfo
    {
        let parser = DocCommentParser()
        return try parser.parse(docComment, functionDecl: handlerFunc)
    }

    private static func validateParameterConsistency(schemaInfo: SchemaInfo, handlerFunc: FunctionDeclSyntax) throws {
        let functionParams = handlerFunc.signature.parameterClause.parameters

        if schemaInfo.parameters.count != functionParams.count {
            throw ToolError.parameterMismatch(
                "DocC comment has \(schemaInfo.parameters.count) parameters, but function has \(functionParams.count)"
            )
        }

        for (index, param) in functionParams.enumerated() {
            let funcParamName = param.firstName.text
            let funcParamType = param.type.trimmed.description

            if index < schemaInfo.parameters.count {
                let docParam = schemaInfo.parameters[index]
                // Handle unnamed parameters: both should be treated as "_" for validation
                let expectedParamName = funcParamName
                let docParamName = docParam.name
                // the below should never happen because we check that in doc parsing
                if docParamName != expectedParamName {
                    throw ToolError.parameterMismatch(
                        "Parameter \(index): DocC has '\(docParamName)' but function has '\(expectedParamName)'"
                    )
                }

                if !isTypeCompatible(docType: docParam.type, funcType: funcParamType) {
                    throw ToolError.parameterMismatch(
                        "Parameter '\(funcParamName)': DocC type '\(docParam.type)' doesn't match function type '\(funcParamType)'"
                    )
                }
            }
        }
    }

    private static func isTypeCompatible(docType: String, funcType: String) -> Bool {
        let normalizedDocType = docType.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFuncType = funcType.trimmingCharacters(in: .whitespacesAndNewlines)

        return normalizedDocType == normalizedFuncType
            || (normalizedDocType == "string" && normalizedFuncType == "String")
            || (normalizedDocType == "number" && (normalizedFuncType == "Double" || normalizedFuncType == "Int"))
            || (normalizedDocType == "boolean" && normalizedFuncType == "Bool")
    }

}

#endif
