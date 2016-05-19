//
//  Automaton.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-05-07.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveCocoa

public protocol StateType {}
public protocol InputType {}

public protocol AutomatonType: class
{
    associatedtype State: StateType
    associatedtype Input: InputType

    /// Current state.
    var state: State { get }

    /// Outputs signal sending `Reply`.
    var signal: Signal<Reply<State, Input>, NoError> { get }
}

/// Deterministic finite automaton.
public final class Automaton<State: StateType, Input: InputType>: AutomatonType
{
    public typealias Mapping = (State, Input) -> State?

    /// Outputs signal sending `Reply`.
    public let signal: Signal<Reply<State, Input>, NoError>

    private let _observer: Observer<Reply<State, Input>, NoError>
    private let _stateProperty: MutableProperty<State>

    /// Current state.
    public var state: State
    {
        return self._stateProperty.value
    }

    public init(state initialState: State, signal inputSignal: Signal<Input, NoError>, mapping: Mapping)
    {
        self._stateProperty = MutableProperty(initialState)

        let replySignal = inputSignal
            .sampleFrom(self._stateProperty.producer)
            .map { input, fromState -> Reply<State, Input> in
                if let toState = mapping(fromState, input) {
                    return .Success(input, fromState, toState)
                }
                else {
                    return .Failure(input, fromState)
                }
            }

        self._stateProperty <~ replySignal
            .flatMap(.Merge) { reply -> SignalProducer<State, NoError> in
                if let toState = reply.toState {
                    return .init(value: toState)
                }
                else {
                    return .never
                }
            }

        let (signal, observer) = Signal<Reply<State, Input>, NoError>.pipe()
        self.signal = signal
        self._observer = observer

        replySignal.observe(self._observer)
    }

    deinit
    {
        self._observer.sendCompleted()
    }
}
