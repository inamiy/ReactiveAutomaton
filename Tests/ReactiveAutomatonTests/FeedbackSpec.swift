import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

class FeedbackSpec: QuickSpec
{
    override func spec()
    {
        typealias Automaton = ReactiveAutomaton.Automaton<AuthState, AuthInput>
        typealias Mapping = Automaton.Mapping
        typealias Feedback = ReactiveAutomaton.Feedback<Reply<AuthState, AuthInput>.Success, AuthInput>

        let (signal, observer) = Signal<AuthInput, Never>.pipe()
        var automaton: Automaton?
        var lastReply: Reply<AuthState, AuthInput>?
        var testScheduler: TestScheduler!

        describe("Feedback") {

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

                let mappings: [Mapping] = [
                    .login    | .loggedOut  => .loggingIn,
                    .loginOK  | .loggingIn  => .loggedIn,
                    .logout   | .loggedIn   => .loggingOut,
                    .logoutOK | .loggingOut => .loggedOut
                ]

                automaton = Automaton(
                    state: .loggedOut,
                    inputs: signal,
                    mapping: reduce(mappings),
                    feedback: reduce([
                        Feedback(
                            filter: { $0.input == AuthInput.login },
                            produce: { _ in loginOKProducer }
                        ),
                        Feedback(
                            filter: { $0.input == AuthInput.logout },
                            produce: { _ in logoutOKProducer }
                        )
                    ])
                )

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut (auto) => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
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

    }
}
