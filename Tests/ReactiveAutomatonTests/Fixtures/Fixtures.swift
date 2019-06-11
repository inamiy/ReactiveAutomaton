//
//  Fixtures.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-06-02.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import ReactiveSwift
import ReactiveAutomaton

// MARK: AuthState/Input

enum AuthState: String, CustomStringConvertible
{
    case loggedOut
    case loggingIn
    case loggedIn
    case loggingOut

    var description: String { return self.rawValue }
}

/// - Note:
/// `LoginOK` and `LogoutOK` should only be used internally
/// (but Swift can't make them as `private case`)
enum AuthInput: String, CustomStringConvertible
{
    case login
    case loginOK
    case logout
    case forceLogout
    case logoutOK

    var description: String { return self.rawValue }
}

// MARK: CountState/Input

typealias CountState = Int

enum CountInput: String, CustomStringConvertible
{
    case increment
    case decrement

    var description: String { return self.rawValue }
}

// MARK: MyState/Input

enum MyState
{
    case state0, state1, state2
}

enum MyInput
{
    case input0, input1, input2
}

// MARK: Helpers

protocol With {}

extension With
{
    func with(_ f: (inout Self) -> Void) -> Self
    {
        var copy = self
        f(&copy)
        return copy
    }
}

// MARK: Extensions

extension Signal.Event
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

extension Lifetime.Token: Equatable
{
    public static func == (lhs: Lifetime.Token, rhs: Lifetime.Token) -> Bool
    {
        return lhs === rhs
    }
}
