// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileManagerKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "AnvyxFileKit", targets: ["AnvyxFileKit"]),
    ],
    targets: [
        .target(name: "AnvyxFileKit"),
        .testTarget(name: "AnvyxFileKitTests", dependencies: ["AnvyxFileKit"]),
    ]
)
