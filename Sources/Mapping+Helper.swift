//
//  Mapping+Helper.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-05-19.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

/// "From-" and "to-" states represented as `.State1 => .State2` or `anyState => .State3`.
public struct Transition<State>
{
    public let fromState: State -> Bool
    public let toState: State
}

// MARK: - Custom Operators

infix operator => { associativity left precedence 150 } // higher than `|` (precedence 140)

public func => <State>(left: State -> Bool, right: State) -> Transition<State>
{
    return Transition(fromState: left, toState: right)
}

public func => <State: Equatable>(left: State, right: State) -> Transition<State>
{
    return { $0 == left } => right
}

//infix operator | { associativity left precedence 140 }   // Comment-Out: already built-in

public func | <State: StateType, Input: InputType>(inputFunc: Input -> Bool, transition: Transition<State>) -> Automaton<State, Input>.Mapping
{
    return { state, input in
        if inputFunc(input) && transition.fromState(state) {
            return transition.toState
        }
        else {
            return nil
        }
    }
}

public func | <State: StateType, Input: protocol<InputType, Equatable>>(input: Input, transition: Transition<State>) -> Automaton<State, Input>.Mapping
{
    return { $0 == input } | transition
}

// MARK: Functions

/// Helper for "any state" mapping, e.g. `let mapping = .Input0 | anyState => .State1`.
public func anyState<State: StateType>(_: State) -> Bool
{
    return true
}

/// Helper for "any input" mapping, e.g. `let mapping = anyInput | .State1 => .State2`.
public func anyInput<Input: InputType>(_: Input) -> Bool
{
    return true
}

/// Concatenates multiple `Automaton.Mapping`s to one (preceding mapping has higher priority).
public func concat<State: StateType, Input: InputType, Mappings: SequenceType where Mappings.Generator.Element == Automaton<State, Input>.Mapping>(mappings: Mappings) -> Automaton<State, Input>.Mapping
{
    return { state, input in
        for mapping in mappings {
            if let toState = mapping(state, input) {
                return toState
            }
        }
        return nil
    }
}
