// swift-tools-version:5.0

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
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "ReactiveAutomaton",
            dependencies: ["ReactiveSwift"],
            path: "Sources"),
    ]
)

// `$ REACTIVEAUTOMATON_SPM_TEST=1 swift test`
if ProcessInfo.processInfo.environment.keys.contains("REACTIVEAUTOMATON_SPM_TEST") {
    package.targets.append(
        .testTarget(
            name: "ReactiveAutomatonTests",
            dependencies: ["ReactiveAutomaton", "Quick", "Nimble"])
    )

    package.dependencies.append(
        contentsOf: [
            .package(url: "https://github.com/Quick/Quick.git", from: "2.1.0"),
            .package(url: "https://github.com/Quick/Nimble.git", from: "8.0.0"),
        ]
    )
}
