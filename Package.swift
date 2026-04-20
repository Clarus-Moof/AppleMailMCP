// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleMailMCP",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AppleMailMCP", targets: ["AppleMailMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0")
    ],
    targets: [
        .executableTarget(
            name: "AppleMailMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/AppleMailMCP"
        )
    ]
)
