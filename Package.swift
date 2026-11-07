// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftPETSCII",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "SwiftPETSCII",
            targets: ["SwiftPETSCII"]
        ),
    ],
    targets: [
        .target(name: "SwiftPETSCII"),
        .testTarget(
            name: "SwiftPETSCIITests",
            dependencies: ["SwiftPETSCII"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
