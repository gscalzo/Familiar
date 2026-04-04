// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Familiar",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FamiliarDomain", targets: ["FamiliarDomain"]),
    ],
    targets: [
        .target(
            name: "FamiliarDomain",
            path: "Familiar/Domain"
        ),
        .testTarget(
            name: "FamiliarTests",
            dependencies: ["FamiliarDomain"],
            path: "FamiliarTests/Domain"
        ),
    ]
)
