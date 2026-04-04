// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Familiar",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FamiliarDomain", targets: ["FamiliarDomain"]),
        .library(name: "FamiliarInfrastructure", targets: ["FamiliarInfrastructure"]),
    ],
    targets: [
        .target(
            name: "FamiliarDomain",
            path: "Familiar/Domain"
        ),
        .target(
            name: "FamiliarInfrastructure",
            dependencies: ["FamiliarDomain"],
            path: "Familiar/Infrastructure"
        ),
        .executableTarget(
            name: "FamiliarApp",
            dependencies: ["FamiliarDomain", "FamiliarInfrastructure"],
            path: "Familiar/App",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "fam",
            path: "Tools/fam"
        ),
        .testTarget(
            name: "FamiliarTests",
            dependencies: ["FamiliarDomain"],
            path: "FamiliarTests/Domain"
        ),
        .testTarget(
            name: "FamiliarInfrastructureTests",
            dependencies: ["FamiliarInfrastructure", "FamiliarDomain"],
            path: "FamiliarTests/Infrastructure"
        ),
    ]
)
