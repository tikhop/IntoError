// MARK: - @IntoError

/// Generates error conversion infrastructure for an enum.
///
/// Generates:
/// - `Error` conformance
/// - `ErrorConvertible` conformance
/// - Postfix `^` operator for sync error conversion
/// - Typed `init(from:)` for each wrapped error type
/// - `init(converting:)` with type-matching switch
/// - Fallback `case unknown(any Error)` if not declared
///
/// ```swift
/// @IntoError
/// enum DataError {
///     case network(URLError)
///     case parse(DecodingError)
/// }
///
/// func fetchData() throws(DataError) -> Data {
///     let data = try URLSession.shared.data(from: url)^
///     let model = try JSONDecoder().decode(Model.self, from: data)^
///     return model
/// }
/// ```
@attached(member, names: named(unknown))
@attached(extension, conformances: Error, ErrorConvertible, names: named(init(converting:)), named(init(from:)))
@attached(peer, names: named(^))
public macro IntoError() = #externalMacro(module: "IntoErrorMacros", type: "IntoErrorMacro")

// MARK: - @Err for Functions

/// Wraps a function body in do-catch for automatic error conversion.
/// Works with both sync and async functions.
/// Use when `^` operator doesn't work (async) or you prefer wrapping the whole function.
///
/// With typed throws (type inferred):
/// ```swift
/// @Err
/// func fetchData() async throws(DataError) -> Data {
///     try await networkCall()
/// }
/// ```
@attached(body)
public macro Err() = #externalMacro(module: "IntoErrorMacros", type: "ErrMacro")

/// Wraps a function body to convert errors to the specified type.
/// Use when function has untyped throws.
///
/// ```swift
/// @Err(AppError.self)
/// func fetchData() async throws -> Data {
///     try await asyncFetch()
/// }
/// ```
@attached(body)
public macro Err<E: ErrorConvertible>(_ errorType: E.Type) = #externalMacro(module: "IntoErrorMacros", type: "ErrMacro")
