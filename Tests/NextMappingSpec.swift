//
//  NextMappingSpec.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-06-02.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveCocoa
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

        describe("Syntax-sugar NextMapping") {

            var testScheduler: TestScheduler!

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.LoginOK` after delay, simulating async work during `.LoggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LoginOK)
                        .delay(1, onScheduler: testScheduler)

                /// Sends `.LogoutOK` after delay, simulating async work during `.LoggingOut`.
                let logoutOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LogoutOK)
                        .delay(1, onScheduler: testScheduler)

                let mappings: [Automaton.NextMapping] = [
                    .Login    | .LoggedOut  => .LoggingIn  | loginOKProducer,
                    .LoginOK  | .LoggingIn  => .LoggedIn   | .empty,
                    .Logout   | .LoggedIn   => .LoggingOut | logoutOKProducer,
                    .LogoutOK | .LoggingOut => .LoggedOut  | .empty,
                ]

                // strategy = `.Merge`
                automaton = Automaton(state: .LoggedOut, input: signal, mapping: reduce(mappings), strategy: .Merge)

                automaton?.replies.observeNext { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.state.value) == .LoggedOut
                expect(lastReply).to(beNil())

                observer.sendNext(.Login)

                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState) == .LoggingIn
                expect(automaton?.state.value) == .LoggingIn

                // `loginOKProducer` will automatically send `.LoginOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .LoginOK
                expect(lastReply?.fromState) == .LoggingIn
                expect(lastReply?.toState) == .LoggedIn
                expect(automaton?.state.value) == .LoggedIn

                observer.sendNext(.Logout)

                expect(lastReply?.input) == .Logout
                expect(lastReply?.fromState) == .LoggedIn
                expect(lastReply?.toState) == .LoggingOut
                expect(automaton?.state.value) == .LoggingOut

                // `logoutOKProducer` will automatically send `.LogoutOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .LogoutOK
                expect(lastReply?.fromState) == .LoggingOut
                expect(lastReply?.toState) == .LoggedOut
                expect(automaton?.state.value) == .LoggedOut
            }

        }

        describe("Func-based NextMapping") {

            var testScheduler: TestScheduler!

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.LoginOK` after delay, simulating async work during `.LoggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LoginOK)
                        .delay(1, onScheduler: testScheduler)

                /// Sends `.LogoutOK` after delay, simulating async work during `.LoggingOut`.
                let logoutOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LogoutOK)
                        .delay(1, onScheduler: testScheduler)

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
                automaton = Automaton(state: .LoggedOut, input: signal, mapping: mapping, strategy: .Merge)

                automaton?.replies.observeNext { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.state.value) == .LoggedOut
                expect(lastReply).to(beNil())

                observer.sendNext(.Login)

                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState) == .LoggingIn
                expect(automaton?.state.value) == .LoggingIn

                // `loginOKProducer` will automatically send `.LoginOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .LoginOK
                expect(lastReply?.fromState) == .LoggingIn
                expect(lastReply?.toState) == .LoggedIn
                expect(automaton?.state.value) == .LoggedIn

                observer.sendNext(.Logout)

                expect(lastReply?.input) == .Logout
                expect(lastReply?.fromState) == .LoggedIn
                expect(lastReply?.toState) == .LoggingOut
                expect(automaton?.state.value) == .LoggingOut

                // `logoutOKProducer` will automatically send `.LogoutOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .LogoutOK
                expect(lastReply?.fromState) == .LoggingOut
                expect(lastReply?.toState) == .LoggedOut
                expect(automaton?.state.value) == .LoggedOut
            }

        }

    }
}
