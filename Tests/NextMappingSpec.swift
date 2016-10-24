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

                /// Sends `.LoginOK` after delay, simulating async work during `.LoggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LoginOK)
                        .delay(1, on: testScheduler)

                /// Sends `.LogoutOK` after delay, simulating async work during `.LoggingOut`.
                let logoutOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LogoutOK)
                        .delay(1, on: testScheduler)

                let mappings: [Automaton.NextMapping] = [
                    .Login    | .LoggedOut  => .LoggingIn  | loginOKProducer,
                    .LoginOK  | .LoggingIn  => .LoggedIn   | .empty,
                    .Logout   | .LoggedIn   => .LoggingOut | logoutOKProducer,
                    .LogoutOK | .LoggingOut => .LoggedOut  | .empty,
                ]

                // strategy = `.Merge`
                automaton = Automaton(state: .LoggedOut, input: signal, mapping: reduce(mappings), strategy: .merge)

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.state.value) == .LoggedOut
                expect(lastReply).to(beNil())

                observer.send(value: .Login)

                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState) == .LoggingIn
                expect(automaton?.state.value) == .LoggingIn

                // `loginOKProducer` will automatically send `.LoginOK`
                testScheduler.advance(by: 1)

                expect(lastReply?.input) == .LoginOK
                expect(lastReply?.fromState) == .LoggingIn
                expect(lastReply?.toState) == .LoggedIn
                expect(automaton?.state.value) == .LoggedIn

                observer.send(value: .Logout)

                expect(lastReply?.input) == .Logout
                expect(lastReply?.fromState) == .LoggedIn
                expect(lastReply?.toState) == .LoggingOut
                expect(automaton?.state.value) == .LoggingOut

                // `logoutOKProducer` will automatically send `.LogoutOK`
                testScheduler.advance(by:1)

                expect(lastReply?.input) == .LogoutOK
                expect(lastReply?.fromState) == .LoggingOut
                expect(lastReply?.toState) == .LoggedOut
                expect(automaton?.state.value) == .LoggedOut
            }

        }

        describe("Func-based NextMapping") {

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.LoginOK` after delay, simulating async work during `.LoggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LoginOK)
                        .delay(1, on: testScheduler)

                /// Sends `.LogoutOK` after delay, simulating async work during `.LoggingOut`.
                let logoutOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LogoutOK)
                        .delay(1, on: testScheduler)

                let mapping: NextMapping = { fromState, input in
                    switch (fromState, input) {
                        case (.LoggedOut, .Login):
                            return (.LoggingIn, loginOKProducer)
                        case (.LoggingIn, .LoginOK):
                            return (.LoggedIn, .empty)
                        case (.LoggedIn, .Logout):
                            return (.LoggingOut, logoutOKProducer)
                        case (.LoggingOut, .LogoutOK):
                            return (.LoggedOut, .empty)
                        default:
                            return nil
                    }
                }

                // strategy = `.Merge`
                automaton = Automaton(state: .LoggedOut, input: signal, mapping: mapping, strategy: .merge)

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.state.value) == .LoggedOut
                expect(lastReply).to(beNil())

                observer.send(value: .Login)

                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState) == .LoggingIn
                expect(automaton?.state.value) == .LoggingIn

                // `loginOKProducer` will automatically send `.LoginOK`
                testScheduler.advance(by:1)

                expect(lastReply?.input) == .LoginOK
                expect(lastReply?.fromState) == .LoggingIn
                expect(lastReply?.toState) == .LoggedIn
                expect(automaton?.state.value) == .LoggedIn

                observer.send(value: .Logout)

                expect(lastReply?.input) == .Logout
                expect(lastReply?.fromState) == .LoggedIn
                expect(lastReply?.toState) == .LoggingOut
                expect(automaton?.state.value) == .LoggingOut

                // `logoutOKProducer` will automatically send `.LogoutOK`
                testScheduler.advance(by:1)

                expect(lastReply?.input) == .LogoutOK
                expect(lastReply?.fromState) == .LoggingOut
                expect(lastReply?.toState) == .LoggedOut
                expect(automaton?.state.value) == .LoggedOut
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
                        disposable += testScheduler.schedule(after: 0.1) {
                            observer.send(value: .LoginOK)
                            observer.sendCompleted()
                        }
                    }

                let mappings: [Automaton.NextMapping] = [
                    .Login    | .LoggedOut  => .LoggingIn  | loginOKProducer,
                    .LoginOK  | .LoggingIn  => .LoggedIn   | .empty,
                ]

                // strategy = `.Merge`
                automaton = Automaton(state: .LoggedOut, input: signal, mapping: reduce(mappings), strategy: .merge)

                _ = automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.state.value) == .LoggedOut
                expect(lastReply).to(beNil())
                expect(effectCallCount) == 0

                observer.send(value: .Login)

                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState) == .LoggingIn
                expect(automaton?.state.value) == .LoggingIn
                expect(effectCallCount) == 1

                // `loginOKProducer` will automatically send `.LoginOK`
                testScheduler.advance(by: 1)

                expect(lastReply?.input) == .LoginOK
                expect(lastReply?.fromState) == .LoggingIn
                expect(lastReply?.toState) == .LoggedIn
                expect(automaton?.state.value) == .LoggedIn
                expect(effectCallCount) == 1
            }

        }

    }
}
