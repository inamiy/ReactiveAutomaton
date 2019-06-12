import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

/// Tests for `anyState`/`anyInput` (predicate functions).
class AnyMappingSpec: QuickSpec
{
    override func spec()
    {
        typealias Automaton = ReactiveAutomaton.Automaton<MyState, MyInput>

        let (signal, observer) = Signal<MyInput, Never>.pipe()
        var automaton: Automaton?
        var lastReply: Reply<MyState, MyInput>?

        describe("`anyState`/`anyInput` mapping") {

            beforeEach {
                let mappings: [Automaton.Mapping] = [
                    .input0 | any => .state1,
                    any     | .state1 => .state2
                ]

                automaton = Automaton(state: .state0, inputs: signal, mapping: reduce(mappings))

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`anyState`/`anyInput` succeeds") {
                expect(automaton?.state.value) == .state0
                expect(lastReply).to(beNil())

                // try any input (fails)
                observer.send(value: .input2)

                expect(lastReply?.input) == .input2
                expect(lastReply?.fromState) == .state0
                expect(lastReply?.toState).to(beNil())
                expect(automaton?.state.value) == .state0

                // try `.login` from any state
                observer.send(value: .input0)

                expect(lastReply?.input) == .input0
                expect(lastReply?.fromState) == .state0
                expect(lastReply?.toState) == .state1
                expect(automaton?.state.value) == .state1

                // try any input
                observer.send(value: .input2)

                expect(lastReply?.input) == .input2
                expect(lastReply?.fromState) == .state1
                expect(lastReply?.toState) == .state2
                expect(automaton?.state.value) == .state2
            }

        }
    }
}
