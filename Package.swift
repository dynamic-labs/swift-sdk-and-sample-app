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
            url: "PASTE_URL_HERE",
            checksum: "PASTE_CHECKSUM_HERE"
        )
    ]
)