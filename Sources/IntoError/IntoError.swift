// MARK: - Core Protocol

/// Protocol for error types that support automatic conversion.
/// The `@IntoError` macro generates conformance automatically.
public protocol ErrorConvertible: Error {
    init(converting error: any Error)
}

// MARK: - Postfix Operator Declaration

postfix operator ^
