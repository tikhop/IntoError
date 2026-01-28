/// Generates error conversion infrastructure for an enum.
///
/// This macro inspects your enum cases and generates:
/// - `Error` conformance
/// - `ErrorConvertible` conformance (enables `.catching {}`)
/// - Typed `init(from:)` for each wrapped error type
/// - Fallback `init(converting:)` with type-matching switch
///
/// ## Example
///
/// ```swift
/// @IntoError
/// enum DataError {
///     case network(URLError)
///     case parse(DecodingError)
///     case unknown(Error)  // fallback case
/// }
///
/// func fetchData() throws(DataError) -> Data {
///     let data = try DataError.catching {
///         try URLSession.shared.data(from: url)
///     }
///     let model = try DataError.catching {
///         try JSONDecoder().decode(Model.self, from: data)
///     }
///     return model
/// }
/// ```
///
/// Errors are automatically matched to the correct case:
/// - `URLError` → `.network(_)`
/// - `DecodingError` → `.parse(_)`
/// - Other errors → `.unknown(_)` (if a fallback `Error` case exists)
@attached(extension, conformances: Error, ErrorConvertible, names: named(init(converting:)), named(init(from:)))
public macro IntoError() = #externalMacro(module: "IntoErrorMacros", type: "IntoErrorMacro")

/// Generates a postfix `^` operator for the specified error type.
///
/// Call this macro at file scope after defining your `@IntoError` enum:
///
/// ```swift
/// @IntoError
/// enum AppError {
///     case network(URLError)
///     case unknown(Error)
/// }
///
/// #intoError(AppError)
///
/// func fetch() throws(AppError) -> Data {
///     try loadData()^  // converts errors to AppError
/// }
/// ```
@freestanding(declaration, names: named(^))
public macro intoError<E: ErrorConvertible>(_ errorType: E.Type) = #externalMacro(module: "IntoErrorMacros", type: "IntoErrorOperatorMacro")
