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

/// Deterministic finite automaton.
public final class Automaton<State: StateType, Input: InputType>
{
    /// Basic state-transition function type.
    public typealias Mapping = (State, Input) -> (State)?

    /// Transducer (input & output) mapping with `SignalProducer<Input, NoError>` as output,
    /// which can wrap heavy tasks and then emit new "input" values
    /// for automatic & continuous state-transitions.
    public typealias OutMapping = (State, Input) -> (State, SignalProducer<Input, NoError>)?

    /// `Reply` signal.
    public let replies: Signal<Reply<State, Input>, NoError>

    /// Current state.
    public let state: AnyProperty<State>

    private let _observer: Observer<Reply<State, Input>, NoError>

    public convenience init(state initialState: State, input inputSignal: Signal<Input, NoError>, mapping: Mapping)
    {
        self.init(state: initialState, input: inputSignal, mapping: _compose(_emptyOutput, mapping))
    }

    public init(state initialState: State, input inputSignal: Signal<Input, NoError>, mapping: OutMapping)
    {
        let stateProperty = MutableProperty(initialState)
        self.state = AnyProperty(stateProperty)

        let (signal, observer) = Signal<Reply<State, Input>, NoError>.pipe()
        self.replies = signal
        self._observer = observer

        func recurInputProducer(inputProducer: SignalProducer<Input, NoError>) -> SignalProducer<Input, NoError>
        {
            return inputProducer
                .sampleFrom(stateProperty.producer)
                .flatMap(.Latest) { input, fromState -> SignalProducer<Input, NoError> in
                    if let (_, nextInputProducer) = mapping(fromState, input) {
                        return recurInputProducer(nextInputProducer)
                            .prefix(value: input)
                    }
                    else {
                        return .init(value: input)
                    }
                }
        }

        recurInputProducer(SignalProducer(signal: inputSignal))
            .sampleFrom(stateProperty.producer)
            .flatMap(.Latest) { input, fromState -> SignalProducer<Reply<State, Input>, NoError> in
                if let (toState, _) = mapping(fromState, input) {
                    return .init(value: .Success(input, fromState, toState))
                }
                else {
                    return .init(value: .Failure(input, fromState))
                }
            }
            .startWithSignal { [unowned stateProperty] signal, disposable in
                stateProperty <~ signal
                    .flatMap(.Merge) { reply -> SignalProducer<State, NoError> in
                        if let toState = reply.toState {
                            return .init(value: toState)
                        }
                        else {
                            return .never
                        }
                    }

                signal.observe(self._observer)
            }
    }

    deinit
    {
        self._observer.sendCompleted()
    }
}

// MARK: Private

private func _compose<A, B, C>(g: B -> C, _ f: A -> B) -> A -> C
{
    return { x in g(f(x)) }
}

private func _emptyOutput<State: StateType, Input: InputType>(toState: State?) -> (State, SignalProducer<Input, NoError>)?
{
    if let toState = toState {
        return (toState, .empty)
    }
    else {
        return nil
    }
}
