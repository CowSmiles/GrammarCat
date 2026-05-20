// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "GrammarCat",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GrammarCat",
            path: "Sources/GrammarCat"
        )
    ],
    swiftLanguageModes: [.v5]
)
