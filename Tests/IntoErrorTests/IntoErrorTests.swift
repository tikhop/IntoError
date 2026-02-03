import Foundation
@testable import IntoError
import Testing

// MARK: - Test Error Types

struct NetworkError: Error {
    let code: Int
}

struct ParseError: Error {
    let message: String
}

@IntoError
enum AppError {
    case network(NetworkError)
    case parse(ParseError)
    case unknown(Error)
}

// MARK: - Test Helpers

func throwsNetworkError() throws(NetworkError) -> String {
    throw NetworkError(code: 404)
}

func throwsParseError() throws(ParseError) -> String {
    throw ParseError(message: "Invalid JSON")
}

func throwsGenericError() throws -> String {
    throw NSError(domain: "test", code: 1)
}

func succeeds() throws(NetworkError) -> String {
    "success"
}

// MARK: - Tests

struct IntoErrorTests {
    // MARK: - Postfix ^ Operator Tests

    @Test
    func postfixOperatorConvertsError() throws {
        func wrapper() throws(AppError) -> String {
            try throwsNetworkError()^
        }

        do {
            _ = try wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case let .network(networkError) = error else {
                #expect(Bool(false), "Expected .network case")
                return
            }
            #expect(networkError.code == 404)
        }
    }

    @Test
    func postfixOperatorConvertsParseError() throws {
        func wrapper() throws(AppError) -> String {
            try throwsParseError()^
        }

        do {
            _ = try wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case let .parse(parseError) = error else {
                #expect(Bool(false), "Expected .parse case")
                return
            }
            #expect(parseError.message == "Invalid JSON")
        }
    }

    @Test
    func postfixOperatorSuccessPassesThrough() throws {
        func wrapper() throws(AppError) -> String {
            try succeeds()^
        }

        let result = try wrapper()
        #expect(result == "success")
    }

    // MARK: - Typed Init Tests

    @Test
    func typedInitWorks() throws {
        let networkError = NetworkError(code: 500)
        let appError = AppError(from: networkError)

        guard case let .network(inner) = appError else {
            #expect(Bool(false), "Expected .network case")
            return
        }
        #expect(inner.code == 500)
    }

    // MARK: - @Err Macro Tests (async)

    @Test
    func errMacroAsyncError() async throws {
        func asyncFetch() async throws -> String {
            throw NetworkError(code: 502)
        }

        @Err
        func wrapper() async throws(AppError) -> String {
            try await asyncFetch()
        }

        do {
            _ = try await wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case let .network(networkError) = error else {
                #expect(Bool(false), "Expected .network case, got \(error)")
                return
            }
            #expect(networkError.code == 502)
        }
    }

    @Test
    func errMacroAsyncParseError() async throws {
        func asyncFetch() async throws -> String {
            throw ParseError(message: "Bad JSON")
        }

        @Err
        func wrapper() async throws(AppError) -> String {
            try await asyncFetch()
        }

        do {
            _ = try await wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case let .parse(parseError) = error else {
                #expect(Bool(false), "Expected .parse case, got \(error)")
                return
            }
            #expect(parseError.message == "Bad JSON")
        }
    }

    @Test
    func errMacroAsyncSuccess() async throws {
        func asyncFetch() async throws -> String {
            "async success"
        }

        @Err
        func wrapper() async throws(AppError) -> String {
            try await asyncFetch()
        }

        let result = try await wrapper()
        #expect(result == "async success")
    }

    @Test
    func errMacroAsyncUnknownError() async throws {
        func asyncFetch() async throws -> String {
            throw NSError(domain: "test", code: 1)
        }

        @Err
        func wrapper() async throws(AppError) -> String {
            try await asyncFetch()
        }

        do {
            _ = try await wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case .unknown = error else {
                #expect(Bool(false), "Expected .unknown case, got \(error)")
                return
            }
        }
    }

    // MARK: - @Err Macro Tests (sync)

    @Test
    func errMacroSync() throws {
        @Err
        func wrapper() throws(AppError) -> String {
            try throwsNetworkError()
        }

        do {
            _ = try wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case let .network(networkError) = error else {
                #expect(Bool(false), "Expected .network case")
                return
            }
            #expect(networkError.code == 404)
        }
    }

    // MARK: - @Err(Type.self) Macro Tests (untyped throws)

    @Test
    func errMacroWithExplicitTypeAsync() async throws {
        func asyncFetch() async throws -> String {
            throw NetworkError(code: 501)
        }

        @Err(AppError.self)
        func wrapper() async throws -> String {
            try await asyncFetch()
        }

        do {
            _ = try await wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch let error as AppError {
            guard case let .network(networkError) = error else {
                #expect(Bool(false), "Expected .network case, got \(error)")
                return
            }
            #expect(networkError.code == 501)
        }
    }

    @Test
    func errMacroWithExplicitTypeSync() throws {
        @Err(AppError.self)
        func wrapper() throws -> String {
            try throwsNetworkError()
        }

        do {
            _ = try wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch let error as AppError {
            guard case let .network(networkError) = error else {
                #expect(Bool(false), "Expected .network case")
                return
            }
            #expect(networkError.code == 404)
        }
    }
}
