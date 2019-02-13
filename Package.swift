// swift-tools-version:4.2

import Foundation
import PackageDescription

let package = Package(
    name: "ReactiveAutomaton",
    products: [
        .library(
            name: "ReactiveAutomaton",
            targets: ["ReactiveAutomaton"]),
    ],
    dependencies:  [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "4.0.0"),
        .package(url: "https://github.com/Quick/Quick", from: "1.0.0"),
        .package(url: "https://github.com/Quick/Nimble", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "ReactiveAutomaton",
            dependencies: ["ReactiveSwift"],
            path: "Sources"),
        .testTarget(
            name: "ReactiveAutomatonTests",
            dependencies: ["ReactiveAutomaton", "Quick", "Nimble"]),
    ]
)
