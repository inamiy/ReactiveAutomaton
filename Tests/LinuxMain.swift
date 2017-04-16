import XCTest
import Quick

@testable import ReactiveAutomatonTests

Quick.QCKMain([
    MappingSpec.self,
    EffectMappingSpec.self,
    AnyMappingSpec.self,
    StateFuncMappingSpec.self,
    EffectMappingLatestSpec.self,
    TerminatingSpec.self
])
