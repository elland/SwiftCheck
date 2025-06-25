// swift-tools-version:6.0

import PackageDescription

let package = Package(
	name: "SwiftCheck",
    platforms: [.iOS(.v16), .macOS(.v14)],
	products: [
		.library(
			name: "SwiftCheck",
			targets: ["SwiftCheck"]),
	],
	dependencies: [
		.package(url: "https://github.com/llvm-swift/FileCheck.git", from: "0.2.6")
	],
	targets: [
		.target(
			name: "SwiftCheck"),
		.testTarget(
			name: "SwiftCheckTests",
			dependencies: ["SwiftCheck", "FileCheck"]),
	]
)

