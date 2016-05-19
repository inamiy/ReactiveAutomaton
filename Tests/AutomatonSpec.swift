//
//  AutomatonSpec.swift
//  AutomatonSpec
//
//  Created by Yasuhiro Inami on 2016-05-07.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveCocoa
import ReactiveAutomaton
import Quick
import Nimble

private enum State: String, StateType, CustomStringConvertible
{
    case LoggedOut = "LoggedOut"
    case LoggingIn = "LoggingIn"
    case LoggedIn = "LoggedIn"
    case LoggingOut = "LoggingOut"

    var description: String { return self.rawValue }
}

private enum Input: String, InputType, CustomStringConvertible
{
    case Login = "Login"
    case LoginOK = "LoginOK"
    case Logout = "Logout"
    case ForceLogout = "ForceLogout"
    case LogoutOK = "LogoutOK"

    var description: String { return self.rawValue }
}

class AutomatonSpec: QuickSpec
{
    override func spec()
    {
        let (signal, observer) = Signal<Input, NoError>.pipe()
        var automaton: Automaton<State, Input>?
        var lastReply: Reply<State, Input>?

        describe("Normal mapping") {

            beforeEach {
                func mapping(fromState: State, input: Input) -> State?
                {
                    switch (fromState, input) {
                        case (.LoggedOut, .Login):
                            return .LoggingIn
                        case (.LoggingIn, .LoginOK):
                            return .LoggedIn
                        case (.LoggedIn, .Logout):
                            return .LoggingOut
                        case (.LoggingOut, .LogoutOK):
                            return .LoggedOut

                        // ForceLogout
                        case (.LoggingIn, .ForceLogout), (.LoggedIn, .ForceLogout):
                            return .LoggingOut

                        default:
                            return nil
                    }
                }

                automaton = Automaton<State, Input>(state: .LoggedOut, signal: signal, mapping: mapping)
                automaton?.signal.observeNext { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            describe("Normal transitions") {

                it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                    expect(automaton?.state) == .LoggedOut
                    expect(lastReply).to(beNil())

                    observer.sendNext(.Login)
                    expect(lastReply?.input) == .Login
                    expect(lastReply?.fromState) == .LoggedOut
                    expect(lastReply?.toState) == .LoggingIn
                    expect(automaton?.state) == .LoggingIn

                    observer.sendNext(.LoginOK)
                    expect(lastReply?.input) == .LoginOK
                    expect(lastReply?.fromState) == .LoggingIn
                    expect(lastReply?.toState) == .LoggedIn
                    expect(automaton?.state) == .LoggedIn

                    observer.sendNext(.Logout)
                    expect(lastReply?.input) == .Logout
                    expect(lastReply?.fromState) == .LoggedIn
                    expect(lastReply?.toState) == .LoggingOut
                    expect(automaton?.state) == .LoggingOut

                    observer.sendNext(.LogoutOK)
                    expect(lastReply?.input) == .LogoutOK
                    expect(lastReply?.fromState) == .LoggingOut
                    expect(lastReply?.toState) == .LoggedOut
                    expect(automaton?.state) == .LoggedOut
                }

            }

            describe("ForceLogout (auth error) handling") {

                it("`LoggedOut => LoggingIn ==(ForceLogout)==> LoggingOut => LoggedOut` succeed") {
                    expect(automaton?.state) == .LoggedOut
                    expect(lastReply).to(beNil())

                    observer.sendNext(.Login)
                    expect(lastReply?.input) == .Login
                    expect(lastReply?.fromState) == .LoggedOut
                    expect(lastReply?.toState) == .LoggingIn
                    expect(automaton?.state) == .LoggingIn

                    observer.sendNext(.ForceLogout)
                    expect(lastReply?.input) == .ForceLogout
                    expect(lastReply?.fromState) == .LoggingIn
                    expect(lastReply?.toState) == .LoggingOut
                    expect(automaton?.state) == .LoggingOut

                    // fails
                    observer.sendNext(.LoginOK)
                    expect(lastReply?.input) == .LoginOK
                    expect(lastReply?.fromState) == .LoggingOut
                    expect(lastReply?.toState).to(beNil())
                    expect(automaton?.state) == .LoggingOut

                    // fails
                    observer.sendNext(.Logout)
                    expect(lastReply?.input) == .Logout
                    expect(lastReply?.fromState) == .LoggingOut
                    expect(lastReply?.toState).to(beNil())
                    expect(automaton?.state) == .LoggingOut

                    observer.sendNext(.LogoutOK)
                    expect(lastReply?.input) == .LogoutOK
                    expect(lastReply?.fromState) == .LoggingOut
                    expect(lastReply?.toState) == .LoggedOut
                    expect(automaton?.state) == .LoggedOut
                }

            }
        }

        describe("Syntax-sugar mapping") {

            beforeEach {
                let canForceLogout: State -> Bool = { $0 == .LoggingIn || $0 == .LoggedIn }

                let mappings: [Automaton<State, Input>.Mapping] = [
                    .Login    | .LoggedOut => .LoggingIn,
                    .LoginOK  | .LoggingIn => .LoggedIn,
                    .Logout   | .LoggedIn => .LoggingOut,
                    .LogoutOK | .LoggingOut => .LoggedOut,

                    .ForceLogout | canForceLogout => .LoggingOut
                ]

                // Use `concat` to combine all mappings.
                let concatMapping = concat(mappings)

                automaton = Automaton<State, Input>(state: .LoggedOut, signal: signal, mapping: concatMapping)
                automaton?.signal.observeNext { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            describe("Normal transitions") {

                it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                    expect(automaton?.state) == .LoggedOut
                    expect(lastReply).to(beNil())

                    observer.sendNext(.Login)
                    expect(lastReply?.input) == .Login
                    expect(lastReply?.fromState) == .LoggedOut
                    expect(lastReply?.toState) == .LoggingIn
                    expect(automaton?.state) == .LoggingIn

                    observer.sendNext(.LoginOK)
                    expect(lastReply?.input) == .LoginOK
                    expect(lastReply?.fromState) == .LoggingIn
                    expect(lastReply?.toState) == .LoggedIn
                    expect(automaton?.state) == .LoggedIn

                    observer.sendNext(.Logout)
                    expect(lastReply?.input) == .Logout
                    expect(lastReply?.fromState) == .LoggedIn
                    expect(lastReply?.toState) == .LoggingOut
                    expect(automaton?.state) == .LoggingOut

                    observer.sendNext(.LogoutOK)
                    expect(lastReply?.input) == .LogoutOK
                    expect(lastReply?.fromState) == .LoggingOut
                    expect(lastReply?.toState) == .LoggedOut
                    expect(automaton?.state) == .LoggedOut
                }

            }

            describe("ForceLogout (auth error) handling") {

                it("`LoggedOut => LoggingIn ==(ForceLogout)==> LoggingOut => LoggedOut` succeed") {
                    expect(automaton?.state) == .LoggedOut
                    expect(lastReply).to(beNil())

                    observer.sendNext(.Login)
                    expect(lastReply?.input) == .Login
                    expect(lastReply?.fromState) == .LoggedOut
                    expect(lastReply?.toState) == .LoggingIn
                    expect(automaton?.state) == .LoggingIn

                    observer.sendNext(.ForceLogout)
                    expect(lastReply?.input) == .ForceLogout
                    expect(lastReply?.fromState) == .LoggingIn
                    expect(lastReply?.toState) == .LoggingOut
                    expect(automaton?.state) == .LoggingOut

                    // fails
                    observer.sendNext(.LoginOK)
                    expect(lastReply?.input) == .LoginOK
                    expect(lastReply?.fromState) == .LoggingOut
                    expect(lastReply?.toState).to(beNil())
                    expect(automaton?.state) == .LoggingOut

                    // fails
                    observer.sendNext(.Logout)
                    expect(lastReply?.input) == .Logout
                    expect(lastReply?.fromState) == .LoggingOut
                    expect(lastReply?.toState).to(beNil())
                    expect(automaton?.state) == .LoggingOut

                    observer.sendNext(.LogoutOK)
                    expect(lastReply?.input) == .LogoutOK
                    expect(lastReply?.fromState) == .LoggingOut
                    expect(lastReply?.toState) == .LoggedOut
                    expect(automaton?.state) == .LoggedOut
                }

            }
        }

        describe("Syntax-sugar mapping + `anyState`/`anyInput`") {

            beforeEach {
                let mappings: [Automaton<State, Input>.Mapping] = [
                    .Login   | anyState => .LoggedIn,
                    anyInput | .LoggedIn => .LoggedOut
                ]

                // Use `concat` to combine all mappings.
                let concatMapping = concat(mappings)

                automaton = Automaton<State, Input>(state: .LoggedOut, signal: signal, mapping: concatMapping)
                automaton?.signal.observeNext { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`anyState`/`anyInput` succeeds") {
                expect(automaton?.state) == .LoggedOut
                expect(lastReply).to(beNil())

                // try any input (fails)
                observer.sendNext(.LoginOK)
                expect(lastReply?.input) == .LoginOK
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState).to(beNil())
                expect(automaton?.state) == .LoggedOut

                // try `.Login` from any state
                observer.sendNext(.Login)
                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState) == .LoggedIn
                expect(automaton?.state) == .LoggedIn

                // try any input
                observer.sendNext(.LogoutOK)
                expect(lastReply?.input) == .LogoutOK
                expect(lastReply?.fromState) == .LoggedIn
                expect(lastReply?.toState) == .LoggedOut
                expect(automaton?.state) == .LoggedOut
            }

        }
    }
}
