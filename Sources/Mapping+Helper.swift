import ReactiveSwift

/// "From-" and "to-" states represented as `.state1 => .state2` or `anyState => .state3`.
public struct Transition<State>
{
    public let fromState: (State) -> Bool
    public let toState: State
}

// MARK: - Custom Operators

// MARK: `=>` (Transition constructor)

precedencegroup TransitionPrecedence {
    associativity: left
    higherThan: AdditionPrecedence
}
infix operator => : TransitionPrecedence    // higher than `|`

public func => <State>(left: @escaping (State) -> Bool, right: State) -> Transition<State>
{
    return Transition(fromState: left, toState: right)
}

public func => <State: Equatable>(left: State, right: State) -> Transition<State>
{
    return { $0 == left } => right
}

// MARK: `|` (Automaton.Mapping constructor)

//infix operator | : AdditionPrecedence   // Comment-Out: already built-in

public func | <Input, State>(
    inputFunc: @escaping (Input) -> Bool,
    transition: Transition<State>
    ) -> Automaton<Input, State>.Mapping
{
    return { input, fromState in
        if inputFunc(input) && transition.fromState(fromState) {
            return transition.toState
        }
        else {
            return nil
        }
    }
}

public func | <Input: Equatable, State>(
    input: Input,
    transition: Transition<State>
    ) -> Automaton<Input, State>.Mapping
{
    return { $0 == input } | transition
}

public func | <Input, State>(
    inputFunc: @escaping (Input) -> Bool,
    transition: @escaping (State) -> State
    ) -> Automaton<Input, State>.Mapping
{
    return { input, fromState in
        if inputFunc(input) {
            return transition(fromState)
        }
        else {
            return nil
        }
    }
}

public func | <Input: Equatable, State>(
    input: Input,
    transition: @escaping (State) -> State
    ) -> Automaton<Input, State>.Mapping
{
    return { $0 == input } | transition
}

// MARK: `|` (Automaton.EffectMapping constructor)

public func | <Input, State, Queue>(
    mapping: @escaping Automaton<Input, State>.Mapping,
    effect: Effect<Input, State, Queue>
    ) -> Automaton<Input, State>.EffectMapping<Queue>
{
    return { input, fromState in
        if let toState = mapping(input, fromState) {
            return (toState, effect)
        }
        else {
            return nil
        }
    }
}

// MARK: - Functions

/// Helper for "any state" or "any input" mappings, e.g.
/// - `let mapping = .input0 | any => .state1`
/// - `let mapping = any | .state1 => .state2`
public func any<T>(_: T) -> Bool
{
    return true
}

/// Folds multiple `Automaton.Mapping`s into one (preceding mapping has higher priority).
public func reduce<Input, State, Mappings: Sequence>(_ mappings: Mappings)
    -> Automaton<Input, State>.Mapping
    where Mappings.Iterator.Element == Automaton<Input, State>.Mapping
{
    return { input, fromState in
        for mapping in mappings {
            if let toState = mapping(input, fromState) {
                return toState
            }
        }
        return nil
    }
}

/// Folds multiple `Automaton.EffectMapping`s into one (preceding mapping has higher priority).
public func reduce<Input, State, Mappings: Sequence, Queue>(_ mappings: Mappings)
    -> Automaton<Input, State>.EffectMapping<Queue>
    where Mappings.Iterator.Element == Automaton<Input, State>.EffectMapping<Queue>
{
    return { input, fromState in
        for mapping in mappings {
            if let tuple = mapping(input, fromState) {
                return tuple
            }
        }
        return nil
    }
}

// MARK: - Mapping conversion

/// Converts `Automaton.Mapping` to `Automaton.EffectMapping`.
public func toEffectMapping<Input, State, Queue>(_ mapping: @escaping Automaton<Input, State>.Mapping)
    -> Automaton<Input, State>.EffectMapping<Queue>
{
    return { input, state in
        return mapping(input, state).map { ($0, nil) }
    }
}

/// Converts `Automaton.EffectMapping` to `Automaton.Mapping`, discarding effects.
public func toMapping<Input, State, Queue>(
    _ effectMapping: @escaping Automaton<Input, State>.EffectMapping<Queue>
    ) -> Automaton<Input, State>.Mapping
{
    return { input, state in
        return effectMapping(input, state)?.0
    }
}
