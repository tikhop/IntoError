// MARK: - Core Protocol

/// Protocol for error types that support automatic conversion.
/// The `@IntoError` macro automatically generates conformance.
public protocol ErrorConvertible: Error {
    init(converting error: any Error)
}

// MARK: - Catching Helper

extension ErrorConvertible {
    /// Executes a throwing closure and converts any error to this error type.
    ///
    /// ```swift
    /// func doWork() throws(AppError) -> Data {
    ///     try AppError.catching { fetchData() }
    /// }
    /// ```
    @inlinable
    public static func catching<T>(_ work: () throws -> T) throws(Self) -> T {
        do {
            return try work()
        } catch let error as Self {
            throw error
        } catch {
            throw Self(converting: error)
        }
    }
}

// MARK: - Postfix Operator Declaration

/// Postfix `^` operator for error conversion.
/// Use `#intoError(YourError)` to generate the implementation.
postfix operator ^

// MARK: - Infix Operator

/// Converts any thrown error to the specified error type.
///
/// Uses the existing `^` operator (XOR precedence).
///
/// ```swift
/// func doWork() throws(AppError) -> Data {
///     try fetchData() ^ AppError.self
/// }
/// ```
@inlinable
public func ^<T, E: ErrorConvertible>(
    _ expression: @autoclosure () throws -> T,
    _ errorType: E.Type
) throws(E) -> T {
    do {
        return try expression()
    } catch let error as E {
        throw error
    } catch {
        throw E(converting: error)
    }
}
