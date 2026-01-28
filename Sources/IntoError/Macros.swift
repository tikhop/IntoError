/// Generates error conversion infrastructure for an enum.
///
/// This macro inspects your enum cases and generates:
/// - `Error` conformance
/// - Postfix `^` operator for error conversion
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
///     let data = try URLSession.shared.data(from: url)^
///     let model = try JSONDecoder().decode(Model.self, from: data)^
///     return model
/// }
/// ```
///
/// Errors are automatically matched to the correct case:
/// - `URLError` → `.network(_)`
/// - `DecodingError` → `.parse(_)`
/// - Other errors → `.unknown(_)` (if a fallback `Error` case exists)
@attached(extension, conformances: Error, ErrorConvertible, names: named(init(converting:)), named(init(from:)))
@attached(peer, names: named(^))
public macro IntoError() = #externalMacro(module: "IntoErrorMacros", type: "IntoErrorMacro")
