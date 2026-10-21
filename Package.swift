// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MacAuthenticator", platforms: [.macOS(.v14)], products: [
    .executable(name: "MacAuthenticator", targets: ["MacAuthenticator"])
], targets: [
    .target(name: "AuthenticatorCore"),
    .executableTarget(name: "MacAuthenticator", dependencies: ["AuthenticatorCore"]),
    .testTarget(name: "AuthenticatorCoreTests", dependencies: ["AuthenticatorCore"])
])
