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
            typealias EffectMapping = Automaton.EffectMapping<Never>

            let (signal, observer) = Signal<CountInput, Never>.pipe()
            var automaton: Automaton?

            beforeEach {
                var mappings: [EffectMapping] = [
                    CountInput.increment | { $0 + 1 } | .empty
                    // Comment-Out: Type inference is super slow in Swift 4.2... (use `+=` instead)
//                    CountInput.decrement | { $0 - 1 } | .empty
                ]
                mappings += [ CountInput.decrement | { $0 - 1 } | .empty ]

                automaton = Automaton(state: 0, inputs: signal, mapping: reduce(mappings))
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
