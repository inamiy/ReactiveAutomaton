import Foundation
import PackageDescription

let isSwiftPackageManagerTest = ProcessInfo.processInfo.environment["SWIFTPM_TEST"] == "YES"

let package = Package(
    name: "ReactiveAutomaton",
    dependencies: {
        var deps: [Package.Dependency] = [
            .Package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", majorVersion: 1, minor: 1)
        ]
        if isSwiftPackageManagerTest {
            deps += [
                .Package(url: "https://github.com/Quick/Quick", majorVersion: 1),
                .Package(url: "https://github.com/Quick/Nimble", majorVersion: 6)
            ]
        }
        return deps
    }()
)
