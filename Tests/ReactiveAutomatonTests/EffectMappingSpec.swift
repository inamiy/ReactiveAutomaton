import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

/// Tests for `(State, Input) -> (State, Output)?` mapping
/// where `Output = SignalProducer<Input, Never>`.
class EffectMappingSpec: QuickSpec
{
    override func spec()
    {
        typealias Automaton = ReactiveAutomaton.Automaton<AuthState, AuthInput>
        typealias EffectMapping = Automaton.EffectMapping<Never>

        let (signal, observer) = Signal<AuthInput, Never>.pipe()
        var automaton: Automaton?
        var lastReply: Reply<AuthState, AuthInput>?
        var testScheduler: TestScheduler!

        describe("Syntax-sugar EffectMapping") {

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, Never>(value: .loginOK)
                        .delay(1, on: testScheduler)

                /// Sends `.logoutOK` after delay, simulating async work during `.loggingOut`.
                let logoutOKProducer =
                    SignalProducer<AuthInput, Never>(value: .logoutOK)
                        .delay(1, on: testScheduler)

                let mappings: [EffectMapping] = [
                    .login    | .loggedOut  => .loggingIn  | loginOKProducer,
                    .loginOK  | .loggingIn  => .loggedIn   | .empty,
                    .logout   | .loggedIn   => .loggingOut | logoutOKProducer,
                    .logoutOK | .loggingOut => .loggedOut  | .empty
                ]

                automaton = Automaton(state: .loggedOut, inputs: signal, mapping: reduce(mappings))

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                observer.send(value: .login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(automaton?.state.value) == .loggingIn

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advance(by: .seconds(1))

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(automaton?.state.value) == .loggedIn

                observer.send(value: .logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(automaton?.state.value) == .loggingOut

                // `logoutOKProducer` will automatically send `.logoutOK`
                testScheduler.advance(by: .seconds(1))

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(automaton?.state.value) == .loggedOut
            }

        }

        describe("Func-based EffectMapping") {

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, Never>(value: .loginOK)
                        .delay(1, on: testScheduler)

                /// Sends `.logoutOK` after delay, simulating async work during `.loggingOut`.
                let logoutOKProducer =
                    SignalProducer<AuthInput, Never>(value: .logoutOK)
                        .delay(1, on: testScheduler)

                let mapping: EffectMapping = { fromState, input in
                    switch (fromState, input) {
                        case (.loggedOut, .login):
                            return (.loggingIn, .init(loginOKProducer))
                        case (.loggingIn, .loginOK):
                            return (.loggedIn, nil)
                        case (.loggedIn, .logout):
                            return (.loggingOut, .init(logoutOKProducer))
                        case (.loggingOut, .logoutOK):
                            return (.loggedOut, nil)
                        default:
                            return nil
                    }
                }

                automaton = Automaton(state: .loggedOut, inputs: signal, mapping: mapping)

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                observer.send(value: .login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(automaton?.state.value) == .loggingIn

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advance(by: .seconds(1))

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(automaton?.state.value) == .loggedIn

                observer.send(value: .logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(automaton?.state.value) == .loggingOut

                // `logoutOKProducer` will automatically send `.logoutOK`
                testScheduler.advance(by: .seconds(1))

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(automaton?.state.value) == .loggedOut
            }

        }

        /// https://github.com/inamiy/RxAutomaton/issues/3
        describe("Additional effect should be called only once per input") {

            var effectCallCount = 0

            beforeEach {
                testScheduler = TestScheduler()
                effectCallCount = 0

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, Never> { observer, disposable in
                        effectCallCount += 1
                        disposable += testScheduler.schedule(after: .milliseconds(100)) {
                            observer.send(value: .loginOK)
                            observer.sendCompleted()
                        }
                    }

                let mappings: [EffectMapping] = [
                    .login    | .loggedOut  => .loggingIn  | loginOKProducer,
                    .loginOK  | .loggingIn  => .loggedIn   | .empty
                ]

                automaton = Automaton(state: .loggedOut, inputs: signal, mapping: reduce(mappings))

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.state.value) == .loggedOut
                expect(lastReply).to(beNil())
                expect(effectCallCount) == 0

                observer.send(value: .login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(automaton?.state.value) == .loggingIn
                expect(effectCallCount) == 1

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advance(by: .seconds(1))

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(automaton?.state.value) == .loggedIn
                expect(effectCallCount) == 1
            }

        }

    }
}
