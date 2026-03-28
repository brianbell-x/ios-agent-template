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
        .target(
            name: "ChatSessionSupport",
            path: ".",
            sources: [
                "ChatAgent/Chat/ChatModels.swift",
                "ChatAgent/Chat/TranscriptStore.swift",
                "ChatAgent/Chat/ChatSessionStore.swift",
                "PackageSupport/ChatAPIClientProtocol.swift",
            ]
        ),
        .testTarget(
            name: "ChatStreamSupportTests",
            dependencies: ["ChatStreamSupport"],
            path: "Tests/ChatStreamSupportTests"
        ),
        .testTarget(
            name: "ChatSessionSupportTests",
            dependencies: ["ChatSessionSupport"],
            path: "Tests/ChatSessionSupportTests"
        ),
    ]
)
