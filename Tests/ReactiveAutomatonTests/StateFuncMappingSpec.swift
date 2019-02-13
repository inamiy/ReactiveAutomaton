//
//  StateFuncMappingSpec.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-11-26.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

/// Tests for state-change function mapping.
class StateFuncMappingSpec: QuickSpec
{
    override func spec()
    {
        describe("State-change function mapping") {

            typealias Automaton = ReactiveAutomaton.Automaton<CountState, CountInput>
            typealias EffectMapping = Automaton.EffectMapping

            let (signal, observer) = Signal<CountInput, NoError>.pipe()
            var automaton: Automaton?

            beforeEach {
                var mappings: [EffectMapping] = [
                    CountInput.increment | { $0 + 1 } | .empty
                    // Comment-Out: Type inference is super slow in Swift 4.2... (use `+=` instead)
//                    CountInput.decrement | { $0 - 1 } | .empty
                ]
                mappings += [ CountInput.decrement | { $0 - 1 } | .empty ]

                // strategy = `.merge`
                automaton = Automaton(state: 0, input: signal, mapping: reduce(mappings), strategy: .merge)
            }

            it("`.increment` and `.decrement` succeed") {
                expect(automaton?.state.value) == 0
                observer.send(value: .increment)
                expect(automaton?.state.value) == 1
                observer.send(value: .increment)
                expect(automaton?.state.value) == 2
                observer.send(value: .decrement)
                expect(automaton?.state.value) == 1
                observer.send(value: .decrement)
                expect(automaton?.state.value) == 0
            }

        }
    }
}
