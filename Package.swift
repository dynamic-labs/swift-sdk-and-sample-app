// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DynamicSDKSwift",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "DynamicSDKSwift",
            targets: ["DynamicSDKSwiftWrapper"])
    ],
    dependencies: [
        // Keep these aligned with `dynamic_sdk_swift/Packages/DynamicSDKSwift/Package.swift`
        .package(url: "https://github.com/jlalvarez18/BigInt.git", from: "6.0.0"),
        .package(url: "https://github.com/kantagara/SolanaWeb3.git", from: "1.0.4"),
        .package(url: "https://github.com/kantagara/AnyCodableSwift.git", from: "0.7.0")
    ],
    targets: [
        .binaryTarget(
            name: "DynamicSDKSwift",
            path: "Frameworks/DynamicSDKSwift.xcframework"
        ),
        .target(
            name: "DynamicSDKSwiftWrapper",
            dependencies: [
                "DynamicSDKSwift",
                .product(name: "SwiftBigInt", package: "BigInt"),
                .product(name: "SolanaWeb3", package: "SolanaWeb3"),
                .product(name: "AnyCodableSwift", package: "AnyCodableSwift"),
            ],
            path: "Sources/DynamicSDKSwiftWrapper"
        )
    ]
)