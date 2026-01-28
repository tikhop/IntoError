import SwiftSyntax
import SwiftSyntaxMacros

public struct IntoErrorMacro {}

// MARK: - Extension Macro (generates Error conformance + inits)

extension IntoErrorMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw IntoErrorMacroError.notAnEnum
        }

        let cases = extractCases(from: enumDecl)
        let typedInits = generateTypedInits(cases: cases)
        let convertingInit = generateConvertingInit(cases: cases, enumName: type.trimmedDescription)

        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type): Error, ErrorConvertible {
            \(raw: typedInits)
            \(raw: convertingInit)
            }
            """
        )

        return [extensionDecl]
    }
}

// MARK: - Peer Macro (generates postfix ^ operator)

extension IntoErrorMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw IntoErrorMacroError.notAnEnum
        }

        let enumName = enumDecl.name.trimmedDescription

        let operatorDecl: DeclSyntax = """
        postfix func ^<T>(
            _ expression: @autoclosure () throws -> T
        ) throws(\(raw: enumName)) -> T {
            do {
                return try expression()
            } catch let error as \(raw: enumName) {
                throw error
            } catch {
                throw \(raw: enumName)(converting: error)
            }
        }
        """

        return [operatorDecl]
    }
}

// MARK: - Helpers

struct ErrorCase {
    let caseName: String
    let errorType: String
}

func extractCases(from enumDecl: EnumDeclSyntax) -> [ErrorCase] {
    var cases: [ErrorCase] = []

    for member in enumDecl.memberBlock.members {
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
            continue
        }

        for element in caseDecl.elements {
            guard let parameterClause = element.parameterClause,
                  let firstParam = parameterClause.parameters.first else {
                continue
            }

            let caseName = element.name.trimmedDescription
            let errorType = firstParam.type.trimmedDescription

            cases.append(ErrorCase(caseName: caseName, errorType: errorType))
        }
    }

    return cases
}

func generateTypedInits(cases: [ErrorCase]) -> String {
    var inits: [String] = []

    for errorCase in cases {
        let initCode = """
            public init(from error: \(errorCase.errorType)) {
                self = .\(errorCase.caseName)(error)
            }
        """
        inits.append(initCode)
    }

    return inits.joined(separator: "\n\n")
}

func generateConvertingInit(cases: [ErrorCase], enumName: String) -> String {
    var switchCases: [String] = []
    var fallbackCase: String? = nil

    for errorCase in cases {
        if errorCase.errorType == "Error" || errorCase.errorType == "any Error" {
            // This is the fallback case
            fallbackCase = "self = .\(errorCase.caseName)(error)"
        } else {
            switchCases.append("case let e as \(errorCase.errorType): self = .\(errorCase.caseName)(e)")
        }
    }

    let defaultCase = fallbackCase ?? "fatalError(\"Unhandled error type: \\(error)\")"

    let switchBody = switchCases.isEmpty
        ? defaultCase
        : """
        switch error {
                \(switchCases.joined(separator: "\n            "))
                default: \(defaultCase)
                }
        """

    return """
        public init(converting error: any Error) {
            \(switchBody)
        }
    """
}

// MARK: - Errors

enum IntoErrorMacroError: Error, CustomStringConvertible {
    case notAnEnum

    var description: String {
        switch self {
        case .notAnEnum:
            return "@IntoError can only be applied to enums"
        }
    }
}
