// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftPETSCII",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftPETSCII",
            targets: ["SwiftPETSCII"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftPETSCII",
            path: "Sources/SwiftPETSCII"
        ),
        .testTarget(
            name: "SwiftPETSCIITests",
            dependencies: ["SwiftPETSCII"],
            path: "Tests/SwiftPETSCIITests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
