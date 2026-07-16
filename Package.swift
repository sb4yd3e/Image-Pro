// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ImagePro",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ImageProCore", targets: ["ImageProCore"]),
        .executable(name: "ImageProApp", targets: ["ImageProApp"]),
        .executable(name: "imagepro-probe", targets: ["ImageProProbe"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/ml-stable-diffusion.git", exact: "1.1.1")
    ],
    targets: [
        .target(
            name: "ImageProCore",
            dependencies: [
                "CWebPBridge",
                .product(name: "StableDiffusion", package: "ml-stable-diffusion")
            ],
            path: "Sources/ImageProCore"
        ),
        .target(
            name: "CWebPBridge",
            path: "Sources/CWebPBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .unsafeFlags([
                    "Sources/CWebPBridge/lib/libwebp.a",
                    "Sources/CWebPBridge/lib/libsharpyuv.a"
                ])
            ]
        ),
        .executableTarget(
            name: "ImageProApp",
            dependencies: ["ImageProCore"],
            path: "Sources/ImageProApp",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "ImageProProbe",
            dependencies: ["ImageProCore"],
            path: "Sources/ImageProProbe"
        ),
        .testTarget(
            name: "ImageProCoreTests",
            dependencies: ["ImageProCore"],
            path: "Tests/ImageProCoreTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
