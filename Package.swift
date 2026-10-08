// swift-tools-version: 5.8
import PackageDescription
let package = Package(name: "DentalLab", platforms: [.macOS(.v13)], products: [.executable(name: "DentalLab", targets: ["DentalLab"])], targets: [.target(name: "CryptoSupport"), .executableTarget(name: "DentalLab", dependencies: ["CryptoSupport"], exclude: ["CryptoBridge.h"], swiftSettings: [.unsafeFlags(["-F", "Vendor"])], linkerSettings: [.unsafeFlags(["-F", "Vendor", "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]) ])])
