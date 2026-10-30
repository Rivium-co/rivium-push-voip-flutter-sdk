// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "rivium_push_voip",
    platforms: [.iOS("13.0")],
    products: [
        .library(name: "rivium-push-voip", targets: ["rivium_push_voip"])
    ],
    dependencies: [
        .package(url: "https://github.com/Rivium-co/rivium-push-voip-ios-sdk.git", from: "0.1.2")
    ],
    targets: [
        .target(
            name: "rivium_push_voip",
            dependencies: [.product(name: "RiviumPushVoip", package: "rivium-push-voip-ios-sdk")]
        )
    ]
)
