//
//  Automaton.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-05-07.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveCocoa

public protocol AutomatonType: class
{
    associatedtype State
    associatedtype Input

    var value: State { get }

    var signal: Signal<Reply<State, Input>, NoError> { get }
}

/// Deterministic finite automaton.
public final class Automaton<State, Input>: AutomatonType
{
    public let signal: Signal<Reply<State, Input>, NoError>
    private let _observer: Observer<Reply<State, Input>, NoError>
    private let _value: () -> State

    public var value: State
    {
        return _value()
    }

    public init(state: State, signal: Signal<Input, NoError>, mapping: (State, Input) -> State?)
    {
        let stateProperty = MutableProperty(state)

        let replySignal = signal
            .sampleFrom(stateProperty.producer)
            .map { input, fromState -> Reply<State, Input> in
                if let toState = mapping(fromState, input) {
                    return .Success(input, fromState, toState)
                }
                else {
                    return .Failure(input, fromState)
                }
            }

        stateProperty <~ replySignal
            .flatMap(.Merge) { reply -> SignalProducer<State, NoError> in
                if let toState = reply.toState {
                    return SignalProducer(value: toState).concat(.never)
                }
                else {
                    return .never
                }
            }

        self._value = { stateProperty.value }

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
