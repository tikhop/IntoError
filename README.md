# IntoError

Swift macro library for automatic error type conversion. 

> Inspired by Rust crate [thiserror](https://github.com/dtolnay/thiserror).

```swift
@IntoError
enum AppError {
    case network(URLError)
    case parse(DecodingError)
    // case unknown(any Error) — auto-generated if not declared
}

// Sync: use ^ operator
func fetchUser() throws(AppError) -> User {
    let data = try URLSession.shared.data(from: url)^
    let user = try JSONDecoder().decode(User.self, from: data)^
    return user
}

// Async: use @Err macro
@Err
func fetchUserAsync() async throws(AppError) -> User {
    let data = try await URLSession.shared.data(from: url)
    let user = try JSONDecoder().decode(User.self, from: data)
    return user
}
```

## Requirements

- Swift 6.0+ / Xcode 16+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/tikhop/IntoError.git", from: "1.0.0")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: ["IntoError"]
)
```

## API

### `@IntoError`

Attaches to enums and generates boilerplate code for you:
- `Error` and `ErrorConvertible` conformance
- Postfix `^` operator (sync only)
- Typed `init(from:)` for each case
- `init(converting:)` with type-matching switch
- `case unknown(any Error)` if no fallback case declared

```swift
@IntoError
enum MyError {
    case specific(SomeError)
    case other(AnotherError)
}
```

### `^` Postfix Operator

Convert errors inline (sync only):

```swift
func fetch() throws(AppError) -> Data {
    try networkCall()^
}
```

### `@Err`

Wrap function body for error conversion. Works with sync and async.

**With typed throws:**
```swift
@Err
func fetch() async throws(AppError) -> Data {
    try await networkCall()
}
```

**With untyped throws:**
```swift
@Err(AppError.self)
func fetch() async throws -> Data {
    try await networkCall()
}
```

## How It Works

See [How It Works](Sources/IntoError/Docs.docc/How%20It%20Works.md).

## License

MIT
