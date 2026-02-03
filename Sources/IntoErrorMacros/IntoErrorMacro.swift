import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - IntoErrorMacro (for enums)

public struct IntoErrorMacro {}

extension IntoErrorMacro: MemberMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw IntoErrorMacroError.notAnEnum
        }

        let cases = extractCases(from: enumDecl)

        // Check if any case already has Error or any Error type
        let hasFallback = cases.contains { $0.errorType == "Error" || $0.errorType == "any Error" }

        if hasFallback {
            return []
        }

        // Generate fallback case
        let fallbackCase: DeclSyntax = "case unknown(any Error)"
        return [fallbackCase]
    }
}

extension IntoErrorMacro: ExtensionMacro {
    public static func expansion(
        of _: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw IntoErrorMacroError.notAnEnum
        }

        var cases = extractCases(from: enumDecl)

        // Check if we need to add fallback case for init generation
        let hasFallback = cases.contains { $0.errorType == "Error" || $0.errorType == "any Error" }
        if !hasFallback {
            cases.append(ErrorCase(caseName: "unknown", errorType: "any Error"))
        }

        let typedInits = generateTypedInits(cases: cases)
        let convertingInit = generateConvertingInit(cases: cases)

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

extension IntoErrorMacro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw IntoErrorMacroError.notAnEnum
        }

        let enumName = enumDecl.name.trimmedDescription

        // Only generate sync operator - use @Err for async functions
        let syncOperator: DeclSyntax = """
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

        return [syncOperator]
    }
}

enum IntoErrorMacroError: Error, CustomStringConvertible {
    case notAnEnum

    var description: String {
        switch self {
        case .notAnEnum:
            return "@IntoError can only be applied to enums"
        }
    }
}

// MARK: - ErrMacro (for functions)

public struct ErrMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in _: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw ErrMacroError.notAFunction
        }

        guard let body = funcDecl.body else {
            throw ErrMacroError.missingBody
        }

        // Check if macro has an argument: @Err(Type.self)
        let hasArgument: Bool
        let argumentType: String?
        if case let .argumentList(args) = node.arguments,
           let firstArg = args.first?.expression
        {
            hasArgument = true
            let argText = firstArg.description.trimmingCharacters(in: .whitespaces)
            if argText.hasSuffix(".self") {
                argumentType = String(argText.dropLast(5))
            } else {
                argumentType = argText
            }
        } else {
            hasArgument = false
            argumentType = nil
        }

        // Check if function has typed throws
        let hasTypedThrows = funcDecl.signature.effectSpecifiers?.throwsClause?.type != nil
        let typedThrowsType = funcDecl.signature.effectSpecifiers?.throwsClause?.type?
            .description.trimmingCharacters(in: .whitespaces)

        // Determine error type and validate usage
        let errorType: String
        if hasArgument {
            // @Err(Type.self) - should NOT have typed throws
            if hasTypedThrows {
                throw ErrMacroError.argumentWithTypedThrows
            }
            guard let argType = argumentType else {
                throw ErrMacroError.invalidArgument
            }
            errorType = argType
        } else {
            // @Err - MUST have typed throws
            guard let thrownType = typedThrowsType else {
                throw ErrMacroError.missingTypedThrows
            }
            errorType = thrownType
        }

        // Check if function returns a value (non-Void)
        let hasReturnValue = funcDecl.signature.returnClause != nil

        // Process statements to handle implicit return
        var statements = Array(body.statements)
        if hasReturnValue, !statements.isEmpty {
            let lastIndex = statements.count - 1
            let lastItem = statements[lastIndex]

            // If last statement is an expression (not already a return), add return
            if lastItem.item.as(ReturnStmtSyntax.self) == nil,
               let expr = lastItem.item.as(ExprSyntax.self)
            {
                let returnStmt = ReturnStmtSyntax(
                    returnKeyword: .keyword(.return, trailingTrivia: .space),
                    expression: expr
                )
                statements[lastIndex] = CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
            }
        }

        let modifiedStatements = CodeBlockItemListSyntax(statements)

        // Wrap body in do-catch
        let wrappedBody: CodeBlockItemSyntax = """
        do {
        \(modifiedStatements)
        } catch let error as \(raw: errorType) {
            throw error
        } catch {
            throw \(raw: errorType)(converting: error)
        }
        """

        return [wrappedBody]
    }
}

enum ErrMacroError: Error, CustomStringConvertible {
    case notAFunction
    case missingBody
    case missingTypedThrows
    case argumentWithTypedThrows
    case invalidArgument

    var description: String {
        switch self {
        case .notAFunction:
            return "@Err can only be applied to functions"
        case .missingBody:
            return "@Err requires a function with a body"
        case .missingTypedThrows:
            return "@Err without argument requires typed throws, e.g. throws(AppError). Use @Err(AppError.self) for untyped throws."
        case .argumentWithTypedThrows:
            return "@Err(Type) should only be used with untyped throws. Remove the argument and use @Err instead."
        case .invalidArgument:
            return "@Err requires a valid error type argument"
        }
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
                  let firstParam = parameterClause.parameters.first
            else {
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

func generateConvertingInit(cases: [ErrorCase]) -> String {
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
