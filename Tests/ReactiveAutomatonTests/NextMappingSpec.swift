//
//  NextMappingSpec.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-06-02.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

/// Tests for `(State, Input) -> (State, Output)?` mapping
/// where `Output = SignalProducer<Input, NoError>`.
class NextMappingSpec: QuickSpec
{
    override func spec()
    {
        typealias Automaton = ReactiveAutomaton.Automaton<AuthState, AuthInput>
        typealias NextMapping = Automaton.NextMapping

        let (signal, observer) = Signal<AuthInput, NoError>.pipe()
        var automaton: Automaton?
        var lastReply: Reply<AuthState, AuthInput>?
        var testScheduler: TestScheduler!

        describe("Syntax-sugar NextMapping") {

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .loginOK)
                        .delay(1, on: testScheduler)

                /// Sends `.logoutOK` after delay, simulating async work during `.loggingOut`.
                let logoutOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .logoutOK)
                        .delay(1, on: testScheduler)

                let mappings: [Automaton.NextMapping] = [
                    .login    | .loggedOut  => .loggingIn  | loginOKProducer,
                    .loginOK  | .loggingIn  => .loggedIn   | .empty,
                    .logout   | .loggedIn   => .loggingOut | logoutOKProducer,
                    .logoutOK | .loggingOut => .loggedOut  | .empty
                ]

                // strategy = `.Merge`
                automaton = Automaton(state: .loggedOut, input: signal, mapping: reduce(mappings), strategy: .merge)

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

        describe("Func-based NextMapping") {

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .loginOK)
                        .delay(1, on: testScheduler)

                /// Sends `.logoutOK` after delay, simulating async work during `.loggingOut`.
                let logoutOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .logoutOK)
                        .delay(1, on: testScheduler)

                let mapping: NextMapping = { fromState, input in
                    switch (fromState, input) {
                        case (.loggedOut, .login):
                            return (.loggingIn, loginOKProducer)
                        case (.loggingIn, .loginOK):
                            return (.loggedIn, .empty)
                        case (.loggedIn, .logout):
                            return (.loggingOut, logoutOKProducer)
                        case (.loggingOut, .logoutOK):
                            return (.loggedOut, .empty)
                        default:
                            return nil
                    }
                }

                // strategy = `.Merge`
                automaton = Automaton(state: .loggedOut, input: signal, mapping: mapping, strategy: .merge)

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
        describe("Next-producer should be called only once per input") {

            var effectCallCount = 0

            beforeEach {
                testScheduler = TestScheduler()
                effectCallCount = 0

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, NoError> { observer, disposable in
                        effectCallCount += 1
                        disposable += testScheduler.schedule(after: .milliseconds(100)) {
                            observer.send(value: .loginOK)
                            observer.sendCompleted()
                        }
                    }

                let mappings: [Automaton.NextMapping] = [
                    .login    | .loggedOut  => .loggingIn  | loginOKProducer,
                    .loginOK  | .loggingIn  => .loggedIn   | .empty
                ]

                // strategy = `.Merge`
                automaton = Automaton(state: .loggedOut, input: signal, mapping: reduce(mappings), strategy: .merge)

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
