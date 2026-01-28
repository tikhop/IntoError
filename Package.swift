// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "IntoError",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "IntoError",
            targets: ["IntoError"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .macro(
            name: "IntoErrorMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "IntoError",
            dependencies: ["IntoErrorMacros"]
        ),
        .testTarget(
            name: "IntoErrorTests",
            dependencies: ["IntoError"]
        ),
    ]
)
