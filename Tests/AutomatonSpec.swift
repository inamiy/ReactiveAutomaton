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

enum State: String, CustomStringConvertible
{
    case LoggedOut = "LoggedOut"
    case LoggingIn = "LoggingIn"
    case LoggedIn = "LoggedIn"
    case LoggingOut = "LoggingOut"

    var description: String { return self.rawValue }
}

enum Input: String, CustomStringConvertible
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

        beforeEach {
            automaton = Automaton<State, Input>(state: .LoggedOut, signal: signal, mapping: mapping)
            automaton?.signal.observeNext { reply in
                lastReply = reply
            }

            lastReply = nil
        }

        describe("Normal transitions") {

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(automaton?.value) == .LoggedOut
                expect(lastReply).to(beNil())

                observer.sendNext(.Login)
                expect(automaton?.value) == .LoggingIn
                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState) == .LoggingIn    // = automaton.value

                observer.sendNext(.LoginOK)
                expect(automaton?.value) == .LoggedIn
                expect(lastReply?.input) == .LoginOK
                expect(lastReply?.fromState) == .LoggingIn
                expect(lastReply?.toState) == .LoggedIn

                observer.sendNext(.Logout)
                expect(automaton?.value) == .LoggingOut
                expect(lastReply?.input) == .Logout
                expect(lastReply?.fromState) == .LoggedIn
                expect(lastReply?.toState) == .LoggingOut

                observer.sendNext(.LogoutOK)
                expect(automaton?.value) == .LoggedOut
                expect(lastReply?.input) == .LogoutOK
                expect(lastReply?.fromState) == .LoggingOut
                expect(lastReply?.toState) == .LoggedOut
            }

        }

        describe("ForceLogout (auth error) handling") {

            it("`LoggedOut => LoggingIn ==(ForceLogout)==> LoggingOut => LoggedOut` succeed") {
                expect(automaton?.value) == .LoggedOut
                expect(lastReply).to(beNil())

                observer.sendNext(.Login)
                expect(automaton?.value) == .LoggingIn
                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState) == .LoggingIn

                observer.sendNext(.ForceLogout)
                expect(automaton?.value) == .LoggingOut
                expect(lastReply?.input) == .ForceLogout
                expect(lastReply?.fromState) == .LoggingIn
                expect(lastReply?.toState) == .LoggingOut

                // fails
                observer.sendNext(.LoginOK)
                expect(automaton?.value) == .LoggingOut
                expect(lastReply?.input) == .LoginOK
                expect(lastReply?.fromState) == .LoggingOut
                expect(lastReply?.toState).to(beNil())

                // fails
                observer.sendNext(.Logout)
                expect(automaton?.value) == .LoggingOut
                expect(lastReply?.input) == .Logout
                expect(lastReply?.fromState) == .LoggingOut
                expect(lastReply?.toState).to(beNil())

                observer.sendNext(.LogoutOK)
                expect(automaton?.value) == .LoggedOut
                expect(lastReply?.input) == .LogoutOK
                expect(lastReply?.fromState) == .LoggingOut
                expect(lastReply?.toState) == .LoggedOut
            }

        }
    }
}
