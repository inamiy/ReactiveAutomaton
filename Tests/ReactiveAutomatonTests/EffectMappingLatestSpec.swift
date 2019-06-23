import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

/// EffectMapping tests with `strategy = .latest`.
class EffectMappingLatestSpec: QuickSpec
{
    override func spec()
    {
        typealias Automaton = ReactiveAutomaton.Automaton<AuthInput, AuthState>
        typealias EffectMapping = Automaton.EffectMapping<Queue, Never>

        let (signal, observer) = Signal<AuthInput, Never>.pipe()
        var automaton: Automaton?
        var lastReply: Reply<AuthInput, AuthState>?

        describe("strategy = `.latest`") {

            var testScheduler: TestScheduler!

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
                    .login    | .loggedOut  => .loggingIn  | Effect(loginOKProducer, queue: .request),
                    .loginOK  | .loggingIn  => .loggedIn   | nil,
                    .logout   | .loggedIn   => .loggingOut | Effect(logoutOKProducer, queue: .request),
                    .logoutOK | .loggingOut => .loggedOut  | nil
                ]

                automaton = Automaton(state: .loggedOut, inputs: signal, mapping: reduce(mappings))

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`strategy = .latest` should not interrupt inner effects when transition fails") {
                expect(automaton?.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                observer.send(value: .login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(automaton?.state.value) == .loggingIn

                testScheduler.advance(by: .milliseconds(100))

                // fails (`loginOKProducer` will not be interrupted)
                observer.send(value: .login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState).to(beNil())
                expect(automaton?.state.value) == .loggingIn

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advance(by: .seconds(1))

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(automaton?.state.value) == .loggedIn
            }

        }

    }
}

// MARK: - Private

private enum Queue: EffectQueueProtocol
{
    case request

    var flattenStrategy: FlattenStrategy
    {
        return .latest
    }
}
