// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Glisse",
    platforms: [.macOS(.v14)],
    targets: [
        // La logique pure, testée : protocole série, passage du bord, curseur virtuel sur l'iPhone.
        .target(name: "GlisseCore"),
        // L'app de la barre des menus : CGEventTap, port série, réglages.
        .executableTarget(name: "GlisseApp", dependencies: ["GlisseCore"]),
        .testTarget(name: "GlisseCoreTests", dependencies: ["GlisseCore"]),
    ]
)
