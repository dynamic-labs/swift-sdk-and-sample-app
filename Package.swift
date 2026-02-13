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
    targets: [
        .binaryTarget(
            name: "DynamicSDKSwiftBinary",
            path: "Frameworks/DynamicSDKSwift.xcframework"
        ),
        .binaryTarget(
            name: "SwiftBigInt",
            path: "Frameworks/SwiftBigInt.xcframework"
        ),
        .binaryTarget(
            name: "SolanaWeb3",
            path: "Frameworks/SolanaWeb3.xcframework"
        ),
        .binaryTarget(
            name: "AnyCodableSwift",
            path: "Frameworks/AnyCodableSwift.xcframework"
        ),
        .target(
            name: "DynamicSDKSwiftWrapper",
            dependencies: [
                "DynamicSDKSwiftBinary",
                "SwiftBigInt",
                "SolanaWeb3",
                "AnyCodableSwift",
            ],
            path: "Sources/DynamicSDKSwiftWrapper"
        )
    ]
)
