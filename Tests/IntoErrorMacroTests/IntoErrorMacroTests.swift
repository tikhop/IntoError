@testable import IntoErrorMacros
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

nonisolated(unsafe) let testMacros: [String: Macro.Type] = [
    "IntoError": IntoErrorMacro.self,
    "Err": ErrMacro.self,
]

// MARK: - @IntoError Macro Tests

@Suite
struct IntoErrorMacroExpansionTests {
    @Test
    func expandsEnumWithSingleCase() {
        assertMacroExpansion(
            """
            @IntoError
            enum AppError {
                case network(NetworkError)
            }
            """,
            expandedSource: """
            enum AppError {
                case network(NetworkError)

                case unknown(any Error)
            }

            postfix func ^<T>(
                _ expression: @autoclosure () throws -> T
            ) throws(AppError) -> T {
                do {
                    return try expression()
                } catch let error as AppError {
                    throw error
                } catch {
                    throw AppError(converting: error)
                }
            }

            extension AppError: Error, ErrorConvertible {
                public init(from error: NetworkError) {
                    self = .network(error)
                }

                public init(from error: any Error) {
                    self = .unknown(error)
                }

                public init(converting error: any Error) {
                    switch error {
                    case let e as NetworkError: self = .network(e)
                    default: self = .unknown(error)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test
    func expandsEnumWithMultipleCases() {
        assertMacroExpansion(
            """
            @IntoError
            enum DataError {
                case network(URLError)
                case parse(DecodingError)
            }
            """,
            expandedSource: """
            enum DataError {
                case network(URLError)
                case parse(DecodingError)

                case unknown(any Error)
            }

            postfix func ^<T>(
                _ expression: @autoclosure () throws -> T
            ) throws(DataError) -> T {
                do {
                    return try expression()
                } catch let error as DataError {
                    throw error
                } catch {
                    throw DataError(converting: error)
                }
            }

            extension DataError: Error, ErrorConvertible {
                public init(from error: URLError) {
                    self = .network(error)
                }

                public init(from error: DecodingError) {
                    self = .parse(error)
                }

                public init(from error: any Error) {
                    self = .unknown(error)
                }

                public init(converting error: any Error) {
                    switch error {
                    case let e as URLError: self = .network(e)
                    case let e as DecodingError: self = .parse(e)
                    default: self = .unknown(error)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test
    func expandsEnumWithFallbackErrorCase() {
        assertMacroExpansion(
            """
            @IntoError
            enum AppError {
                case network(NetworkError)
                case unknown(Error)
            }
            """,
            expandedSource: """
            enum AppError {
                case network(NetworkError)
                case unknown(Error)
            }

            postfix func ^<T>(
                _ expression: @autoclosure () throws -> T
            ) throws(AppError) -> T {
                do {
                    return try expression()
                } catch let error as AppError {
                    throw error
                } catch {
                    throw AppError(converting: error)
                }
            }

            extension AppError: Error, ErrorConvertible {
                public init(from error: NetworkError) {
                    self = .network(error)
                }

                public init(from error: Error) {
                    self = .unknown(error)
                }

                public init(converting error: any Error) {
                    switch error {
                    case let e as NetworkError: self = .network(e)
                    default: self = .unknown(error)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test
    func failsOnNonEnum() {
        assertMacroExpansion(
            """
            @IntoError
            struct NotAnEnum {}
            """,
            expandedSource: """
            struct NotAnEnum {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@IntoError can only be applied to enums", line: 1, column: 1),
                DiagnosticSpec(message: "@IntoError can only be applied to enums", line: 1, column: 1),
                DiagnosticSpec(message: "@IntoError can only be applied to enums", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }
}

// MARK: - @Err Body Macro Tests

@Suite
struct ErrBodyMacroExpansionTests {
    @Test
    func expandsSyncFunctionWithTypedThrows() {
        assertMacroExpansion(
            """
            @Err
            func fetch() throws(AppError) -> String {
                try getData()
            }
            """,
            expandedSource: """
            func fetch() throws(AppError) -> String {
                do {
                    return try getData()
                } catch let error as AppError {
                    throw error
                } catch {
                    throw AppError(converting: error)
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test
    func expandsAsyncFunctionWithTypedThrows() {
        assertMacroExpansion(
            """
            @Err
            func fetch() async throws(AppError) -> Data {
                try await fetchRemote()
            }
            """,
            expandedSource: """
            func fetch() async throws(AppError) -> Data {
                do {
                    return try await fetchRemote()
                } catch let error as AppError {
                    throw error
                } catch {
                    throw AppError(converting: error)
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test
    func expandsFunctionWithExplicitReturn() {
        assertMacroExpansion(
            """
            @Err
            func fetch() throws(AppError) -> String {
                let result = try getData()
                return result
            }
            """,
            expandedSource: """
            func fetch() throws(AppError) -> String {
                do {
                    let result = try getData()
                    return result
                } catch let error as AppError {
                    throw error
                } catch {
                    throw AppError(converting: error)
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test
    func expandsVoidFunction() {
        assertMacroExpansion(
            """
            @Err
            func save() throws(AppError) {
                try writeData()
            }
            """,
            expandedSource: """
            func save() throws(AppError) {
                do {
                    try writeData()
                } catch let error as AppError {
                    throw error
                } catch {
                    throw AppError(converting: error)
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test
    func expandsWithExplicitErrorType() {
        assertMacroExpansion(
            """
            @Err(AppError.self)
            func fetch() throws -> String {
                try getData()
            }
            """,
            expandedSource: """
            func fetch() throws -> String {
                do {
                    return try getData()
                } catch let error as AppError {
                    throw error
                } catch {
                    throw AppError(converting: error)
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test
    func expandsAsyncWithExplicitErrorType() {
        assertMacroExpansion(
            """
            @Err(DataError.self)
            func fetchAsync() async throws -> Data {
                try await loadData()
            }
            """,
            expandedSource: """
            func fetchAsync() async throws -> Data {
                do {
                    return try await loadData()
                } catch let error as DataError {
                    throw error
                } catch {
                    throw DataError(converting: error)
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test
    func failsWithoutTypedThrowsAndNoArgument() {
        assertMacroExpansion(
            """
            @Err
            func fetch() throws -> String {
                try getData()
            }
            """,
            expandedSource: """
            func fetch() throws -> String {
                try getData()
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Err without argument requires typed throws, e.g. throws(AppError). Use @Err(AppError.self) for untyped throws.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    @Test
    func failsWithArgumentAndTypedThrows() {
        assertMacroExpansion(
            """
            @Err(AppError.self)
            func fetch() throws(AppError) -> String {
                try getData()
            }
            """,
            expandedSource: """
            func fetch() throws(AppError) -> String {
                try getData()
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Err(Type) should only be used with untyped throws. Remove the argument and use @Err instead.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }
}
