import PackageDescription

let package = Package(
    name: "ReactiveAutomaton",
    dependencies: [
        .Package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", majorVersion: 1)
    ]
)
