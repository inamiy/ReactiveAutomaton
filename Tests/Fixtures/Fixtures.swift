//
//  Fixtures.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-06-02.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveCocoa
import ReactiveAutomaton

enum AuthState: String, StateType, CustomStringConvertible
{
    case LoggedOut = "LoggedOut"
    case LoggingIn = "LoggingIn"
    case LoggedIn = "LoggedIn"
    case LoggingOut = "LoggingOut"

    var description: String { return self.rawValue }
}

/// - Note:
/// `LoginOK` and `LogoutOK` should only be used internally
/// (but Swift can't make them as `private case`)
enum AuthInput: String, InputType, CustomStringConvertible
{
    case Login = "Login"
    case LoginOK = "LoginOK"
    case Logout = "Logout"
    case ForceLogout = "ForceLogout"
    case LogoutOK = "LogoutOK"

    var description: String { return self.rawValue }
}

enum MyState: StateType
{
    case State0, State1, State2
}

enum MyInput: InputType
{
    case Input0, Input1, Input2
}
