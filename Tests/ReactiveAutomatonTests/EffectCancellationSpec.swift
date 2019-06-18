import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

class EffectCancellationSpec: QuickSpec
{
    override func spec()
    {
        describe("Cancellation using Lifetime") {

            typealias State = _State<Lifetime.Token>
            typealias Automaton = ReactiveAutomaton.Automaton<Input, State>
            typealias EffectMapping = Automaton.EffectMapping<Never>

            let (signal, observer) = Signal<Input, Never>.pipe()
            var automaton: Automaton?
            var lastReply: Reply<Input, State>?
            var testScheduler: TestScheduler!
            var isEffectDetected: Bool = false

            beforeEach {
                testScheduler = TestScheduler()
                isEffectDetected = false

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let requestOKProducer =
                    SignalProducer<Input, Never>(value: .requestOK)
                        .delay(1, on: testScheduler)

                let mapping: EffectMapping = { input, fromState in
                    switch (fromState.status, input) {
                    case (.idle, .userAction(.request)):
                        let (lifetime, token) = Lifetime.make()
                        let toState = fromState.with {
                            $0.status = .requesting(token)
                        }
                        let effect = requestOKProducer
                            .take(during: lifetime)
                            .on(value: { _ in
                                isEffectDetected = true
                            })
                        return (toState, Effect(effect))

                    case (.requesting, .userAction(.cancel)):
                        let toState = fromState.with {
                            $0.status = .idle
                        }
                        return (toState, nil)

                    case (.requesting, .requestOK):
                        let toState = fromState.with {
                            $0.status = .idle
                        }
                        return (toState, nil)

                    default:
                        return nil
                    }
                }

                automaton = Automaton(state: State(), inputs: signal, mapping: mapping)

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("request success") {
                expect(automaton?.state.value.status) == .idle
                expect(lastReply).to(beNil())

                observer.send(value: .userAction(.request))

                expect(lastReply?.input) == .userAction(.request)
                expect(lastReply?.fromState.status) == .idle
                expect(lastReply?.toState?.status.requesting).toNot(beNil())
                expect(automaton?.state.value.status.requesting).toNot(beNil())

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advance(by: .seconds(2))

                expect(lastReply?.input) == .requestOK
                expect(lastReply?.fromState.status.requesting).toNot(beNil())
                expect(lastReply?.toState?.status) == .idle
                expect(automaton?.state.value.status) == .idle
                expect(isEffectDetected) == true
            }

            it("request cancelled") {
                expect(automaton?.state.value.status) == .idle
                expect(lastReply).to(beNil())

                observer.send(value: .userAction(.request))

                expect(lastReply?.input) == .userAction(.request)
                expect(lastReply?.fromState.status) == .idle
                expect(lastReply?.toState?.status.requesting).toNot(beNil())
                expect(automaton?.state.value.status.requesting).toNot(beNil())

                // `loginOKProducer` will automatically send `.loginOK`
                observer.send(value: .userAction(.cancel))

                expect(lastReply?.input) == .userAction(.cancel)
                expect(lastReply?.fromState.status.requesting).toNot(beNil())
                expect(lastReply?.toState?.status) == .idle
                expect(automaton?.state.value.status) == .idle

                lastReply = nil // clear `lastReply` to not retain `Lifetime.Token`
                testScheduler.advance(by: .seconds(2))

                expect(isEffectDetected) == false
            }

        }

        describe("Cancellation using Effect.until") {

            typealias State = _State<_Void>
            typealias Automaton = ReactiveAutomaton.Automaton<Input, State>
            typealias EffectMapping = Automaton.EffectMapping<Never>

            let (signal, observer) = Signal<Input, Never>.pipe()
            var automaton: Automaton?
            var lastReply: Reply<Input, State>?
            var testScheduler: TestScheduler!
            var isEffectDetected: Bool = false

            beforeEach {
                testScheduler = TestScheduler()
                isEffectDetected = false

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let requestOKProducer =
                    SignalProducer<Input, Never>(value: .requestOK)
                        .delay(1, on: testScheduler)

                let mapping: EffectMapping = { input, fromState in
                    switch (fromState.status, input) {
                    case (.idle, .userAction(.request)):
                        let toState = fromState.with {
                            $0.status = .requesting(_Void())
                        }
                        let effect = requestOKProducer
                            .on(value: { _ in
                                isEffectDetected = true
                            })
                        return (toState, Effect(effect, until: .userAction(.cancel)))

                    case (.requesting, .userAction(.cancel)):
                        let toState = fromState.with {
                            $0.status = .idle
                        }
                        return (toState, nil)

                    case (.requesting, .requestOK):
                        let toState = fromState.with {
                            $0.status = .idle
                        }
                        return (toState, nil)

                    default:
                        return nil
                    }
                }

                automaton = Automaton(state: State(), inputs: signal, mapping: mapping)

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("request success") {
                expect(automaton?.state.value.status) == .idle
                expect(lastReply).to(beNil())

                observer.send(value: .userAction(.request))

                expect(lastReply?.input) == .userAction(.request)
                expect(lastReply?.fromState.status) == .idle
                expect(lastReply?.toState?.status.requesting).toNot(beNil())
                expect(automaton?.state.value.status.requesting).toNot(beNil())

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advance(by: .seconds(2))

                expect(lastReply?.input) == .requestOK
                expect(lastReply?.fromState.status.requesting).toNot(beNil())
                expect(lastReply?.toState?.status) == .idle
                expect(automaton?.state.value.status) == .idle
                expect(isEffectDetected) == true
            }

            it("request cancelled") {
                expect(automaton?.state.value.status) == .idle
                expect(lastReply).to(beNil())

                observer.send(value: .userAction(.request))

                expect(lastReply?.input) == .userAction(.request)
                expect(lastReply?.fromState.status) == .idle
                expect(lastReply?.toState?.status.requesting).toNot(beNil())
                expect(automaton?.state.value.status.requesting).toNot(beNil())

                // `loginOKProducer` will automatically send `.loginOK`
                observer.send(value: .userAction(.cancel))

                expect(lastReply?.input) == .userAction(.cancel)
                expect(lastReply?.fromState.status.requesting).toNot(beNil())
                expect(lastReply?.toState?.status) == .idle
                expect(automaton?.state.value.status) == .idle

                lastReply = nil // clear `lastReply` to not retain `Lifetime.Token`
                testScheduler.advance(by: .seconds(2))

                expect(isEffectDetected) == false
            }

        }

    }
}

// MARK: - Private

private enum Input: Equatable
{
    case userAction(UserAction)
    case requestOK

    enum UserAction
    {
        case request
        case cancel
    }
}

private struct _State<Requesting>: With, Equatable
    where Requesting: Equatable
{
    var status: Status = .idle

    enum Status: Equatable {
        case idle
        case requesting(Requesting)

        var requesting: Requesting?
        {
            guard case let .requesting(value) = self else { return nil }
            return value
        }
    }
}

private struct _Void: Equatable {}
