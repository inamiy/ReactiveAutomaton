import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

class InitialEffectSpec: QuickSpec
{
    override func spec()
    {
        typealias Automaton = ReactiveAutomaton.Automaton<AuthInput, AuthState>
        typealias EffectMapping = Automaton.EffectMapping<Never>

        let (signal, observer) = Signal<AuthInput, Never>.pipe()
        var automaton: Automaton?
        var lastReply: Reply<AuthInput, AuthState>?
        var testScheduler: TestScheduler!

        describe("InitialEffect") {

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
                    .login    | .loggedOut  => .loggingIn  | .init(loginOKProducer),
                    .loginOK  | .loggingIn  => .loggedIn   | .empty,
                    .logout   | .loggedIn   => .loggingOut | .init(logoutOKProducer),
                    .logoutOK | .loggingOut => .loggedOut  | .empty
                ]

                automaton = Automaton(
                    state: .loggedOut,
                    effect: Effect(SignalProducer(value: .login).delay(1, on: testScheduler)),
                    inputs: signal,
                    mapping: reduce(mappings)
                )

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut (auto) => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                // NOTE: Instead of manually sending `.login`, initial effect already handles it.
                testScheduler.advance(by: .seconds(1))
                // observer.send(value: .login)

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

    }
}
