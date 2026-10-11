// swift-tools-version: 6.0
import Foundation
import PackageDescription

// Command Line Tools seuls : le plugin de macros Swift Testing n'est pas trouvé par défaut.
// Avec Xcode (par exemple sur GitHub Actions), ce dossier n'existe pas et rien n'est ajouté.
let cltTestingPlugins = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
let testSettings: [SwiftSetting] = FileManager.default.fileExists(atPath: cltTestingPlugins)
    ? [.unsafeFlags(["-plugin-path", cltTestingPlugins])]
    : []

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
            swiftSettings: testSettings
        ),
    ]
)
