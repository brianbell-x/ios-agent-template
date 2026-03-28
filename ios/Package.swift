// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ChatStreamSupport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ChatStreamSupport", targets: ["ChatStreamSupport"]),
    ],
    targets: [
        .target(
            name: "ChatStreamSupport",
            path: "ChatAgent/Chat",
            sources: [
                "ChatModels.swift",
                "ChatStreamParser.swift",
            ]
        ),
        .testTarget(
            name: "ChatStreamSupportTests",
            dependencies: ["ChatStreamSupport"],
            path: "Tests/ChatStreamSupportTests"
        ),
    ]
)
