// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Baguette",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WandCore", targets: ["WandCore"]),
        .executable(name: "Baguette", targets: ["Baguette"]),
    ],
    targets: [
        .target(name: "WandCore"),
        // L'icône est copiée dans Baguette.app par scripts/bundle.sh, pas embarquée par SwiftPM.
        .executableTarget(name: "Baguette", dependencies: ["WandCore"], exclude: ["Resources"]),
        .testTarget(
            name: "WandCoreTests",
            dependencies: ["WandCore"],
            // Command Line Tools seuls : le plugin de macros Swift Testing n'est pas trouvé par défaut.
            swiftSettings: [.unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])]
        ),
    ]
)
