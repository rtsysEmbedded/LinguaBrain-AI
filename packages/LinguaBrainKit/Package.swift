// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "LinguaBrainKit",
    // ADR-009: iOS, iPadOS, and macOS 27 only, matching the app targets.
    platforms: [
        .iOS(.v27),
        .macOS(.v27)
    ],
    products: [
        .library(name: "LinguaBrainDomain", targets: ["LinguaBrainDomain"]),
        .library(name: "LinguaBrainApplication", targets: ["LinguaBrainApplication"]),
        .library(name: "LinguaBrainAI", targets: ["LinguaBrainAI"]),
        .library(name: "LinguaBrainMedia", targets: ["LinguaBrainMedia"]),
        .library(name: "LinguaBrainPersistence", targets: ["LinguaBrainPersistence"]),
        .library(name: "LinguaBrainAnkiExport", targets: ["LinguaBrainAnkiExport"]),
        .library(name: "LinguaBrainTestSupport", targets: ["LinguaBrainTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")
    ],
    targets: [
        .target(
            name: "LinguaBrainDomain",
            dependencies: []
        ),
        .target(
            name: "LinguaBrainApplication",
            dependencies: ["LinguaBrainDomain"]
        ),
        .target(
            name: "LinguaBrainAI",
            dependencies: ["LinguaBrainDomain", "LinguaBrainApplication"]
        ),
        .target(
            name: "LinguaBrainMedia",
            dependencies: ["LinguaBrainDomain", "LinguaBrainApplication"]
        ),
        .target(
            name: "LinguaBrainPersistence",
            dependencies: ["LinguaBrainDomain", "LinguaBrainApplication", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .target(
            name: "LinguaBrainAnkiExport",
            dependencies: ["LinguaBrainDomain", "LinguaBrainApplication", "LinguaBrainMedia", "LinguaBrainPersistence"]
        ),
        .target(
            name: "LinguaBrainTestSupport",
            dependencies: ["LinguaBrainDomain", "LinguaBrainApplication", "LinguaBrainAI"]
        ),
        .testTarget(
            name: "LinguaBrainAITests",
            dependencies: [
                "LinguaBrainDomain",
                "LinguaBrainApplication",
                "LinguaBrainAI",
                "LinguaBrainMedia",
                "LinguaBrainPersistence",
                "LinguaBrainTestSupport"
            ],
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "LinguaBrainApplicationTests",
            dependencies: [
                "LinguaBrainDomain",
                "LinguaBrainApplication",
                "LinguaBrainAI",
                "LinguaBrainPersistence",
                "LinguaBrainTestSupport"
            ]
        ),
        .testTarget(
            name: "LinguaBrainDomainTests",
            dependencies: ["LinguaBrainDomain"]
        ),
        .testTarget(
            name: "LinguaBrainAnkiExportTests",
            dependencies: ["LinguaBrainDomain", "LinguaBrainApplication", "LinguaBrainMedia", "LinguaBrainPersistence", "LinguaBrainAnkiExport", "LinguaBrainTestSupport"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
