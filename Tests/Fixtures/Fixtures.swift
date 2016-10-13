//
//  Fixtures.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-06-02.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveSwift
import ReactiveAutomaton

enum AuthState: String, CustomStringConvertible
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
enum AuthInput: String, CustomStringConvertible
{
    case Login = "Login"
    case LoginOK = "LoginOK"
    case Logout = "Logout"
    case ForceLogout = "ForceLogout"
    case LogoutOK = "LogoutOK"

    var description: String { return self.rawValue }
}

enum MyState
{
    case state0, state1, state2
}

enum MyInput
{
    case input0, input1, input2
}

// MARK: Extensions

extension Event
{
    public var isCompleting: Bool
    {
        switch self {
            case .value, .failed, .interrupted:
                return false

            case .completed:
                return true
        }
    }

    public var isInterrupting: Bool
    {
        switch self {
            case .value, .failed, .completed:
                return false

            case .interrupted:
                return true
        }
    }
}
