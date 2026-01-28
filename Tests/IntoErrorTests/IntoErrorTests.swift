import Testing
import Foundation
@testable import IntoError

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

// Generate postfix ^ operator for AppError
#intoError(AppError.self)

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
    @Test
    func networkErrorConverts() async throws {
        func wrapper() throws(AppError) -> String {
            try AppError.catching { try throwsNetworkError() }
        }

        do {
            _ = try wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case .network(let networkError) = error else {
                #expect(Bool(false), "Expected .network case")
                return
            }
            #expect(networkError.code == 404)
        }
    }

    @Test
    func parseErrorConverts() async throws {
        func wrapper() throws(AppError) -> String {
            try AppError.catching { try throwsParseError() }
        }

        do {
            _ = try wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case .parse(let parseError) = error else {
                #expect(Bool(false), "Expected .parse case")
                return
            }
            #expect(parseError.message == "Invalid JSON")
        }
    }

    @Test
    func unknownErrorFallback() async throws {
        func wrapper() throws(AppError) -> String {
            try AppError.catching { try throwsGenericError() }
        }

        do {
            _ = try wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case .unknown = error else {
                #expect(Bool(false), "Expected .unknown case")
                return
            }
        }
    }

    @Test
    func successPassesThrough() async throws {
        func wrapper() throws(AppError) -> String {
            try AppError.catching { try succeeds() }
        }

        let result = try wrapper()
        #expect(result == "success")
    }

    @Test
    func typedInitWorks() async throws {
        let networkError = NetworkError(code: 500)
        let appError = AppError(from: networkError)

        guard case .network(let inner) = appError else {
            #expect(Bool(false), "Expected .network case")
            return
        }
        #expect(inner.code == 500)
    }

    @Test
    func infixOperatorWorks() async throws {
        func wrapper() throws(AppError) -> String {
            try throwsNetworkError() ^ AppError.self
        }

        do {
            _ = try wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case .network(let networkError) = error else {
                #expect(Bool(false), "Expected .network case")
                return
            }
            #expect(networkError.code == 404)
        }
    }

    @Test
    func infixOperatorSuccessPassesThrough() async throws {
        func wrapper() throws(AppError) -> String {
            try succeeds()^ 
        }

        let result = try wrapper()
        #expect(result == "success")
    }

    @Test
    func postfixOperatorWorks() async throws {
        func wrapper() throws(AppError) -> String {
            try throwsNetworkError()^
        }

        do {
            _ = try wrapper()
            #expect(Bool(false), "Should have thrown")
        } catch {
            guard case .network(let networkError) = error else {
                #expect(Bool(false), "Expected .network case")
                return
            }
            #expect(networkError.code == 404)
        }
    }

    @Test
    func postfixOperatorSuccessPassesThrough() async throws {
        func wrapper() throws(AppError) -> String {
            try succeeds()^
        }

        let result = try wrapper()
        #expect(result == "success")
    }
}
