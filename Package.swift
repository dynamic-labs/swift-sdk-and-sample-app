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
            targets: ["DynamicSDKSwift"])
    ],
    targets: [
        .binaryTarget(
            name: "DynamicSDKSwift",
            url: "https://github.com/dynamic-labs/swift-sdk-and-sample-app/releases/download/1.0.0/DynamicSDKSwift.xcframework.zip",
            checksum: "661a21c969cd9733b6c27fe6a9bcb40d1f94ad9cbef8a22dad5b2637d811a39e"
        )
    ]
)