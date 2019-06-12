import ReactiveSwift

/// Deterministic finite state machine that receives "input"
/// and with "current state" transform to "next state" & "output (additional effect)".
public final class Automaton<State, Input>
{
    /// Basic state-transition function type.
    public typealias Mapping = (State, Input) -> State?

    /// Transducer (input & output) mapping with `Effect<Input>` (additional effect) as output,
    /// which may emit next input values for continuous state-transitions.
    public typealias EffectMapping<Queue> = (State, Input) -> (State, Effect<Input, Queue>?)?
        where Queue: EffectQueueProtocol

    /// `Reply` signal that notifies either `.success` or `.failure` of state-transition on every input.
    public let replies: Signal<Reply<State, Input>, Never>

    /// Current state.
    public let state: Property<State>

    fileprivate let _repliesObserver: Signal<Reply<State, Input>, Never>.Observer

    fileprivate let _disposable: Disposable

    /// Initializer using `Mapping`.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - input: `Signal<Input, Never>` that automaton receives.
    ///   - mapping: Simple `Mapping` that designates next state only (no additional effect).
    public convenience init(
        state initialState: State,
        inputs inputSignal: Signal<Input, Never>,
        mapping: @escaping Mapping
        )
    {
        self.init(
            state: initialState,
            inputs: inputSignal,
            mapping: { _toEffectMapping(mapping($0, $1)) }
        )
    }

    /// Initializer using `EffectMapping`.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - effect: Initial effect.
    ///   - input: `Signal<Input, Never>` that automaton receives.
    ///   - mapping: `EffectMapping` that designates next state and also generates additional effect.
    public convenience init<Queue>(
        state initialState: State,
        effect initialEffect: Effect<Input, Queue>? = nil,
        inputs inputSignal: Signal<Input, Never>,
        mapping: @escaping EffectMapping<Queue>
        ) where Queue: EffectQueueProtocol
    {
        self.init(
            state: initialState,
            inputs: inputSignal,
            makeSignals: { from -> MakeSignals in
                let mapped = from
                    .map { input, fromState in
                        return (input, fromState, mapping(fromState, input))
                    }

                let replies = mapped
                    .map { input, fromState, mapped -> Reply<State, Input> in
                        if let (toState, _) = mapped {
                            return .success((input, fromState, toState))
                        }
                        else {
                            return .failure((input, fromState))
                        }
                    }

                var effects = mapped
                    .filterMap { _, _, mapped -> Effect<Input, Queue>? in
                        guard case let .some(_, effect) = mapped else { return nil }
                        return effect
                    }
                    .producer

                if let initialEffect = initialEffect {
                    effects = effects.prefix(value: initialEffect)
                }

                let effectInputs = SignalProducer.merge(
                    EffectQueue<Queue>.allCases.map { queue in
                        effects
                            .filter { $0.queue == queue }
                            .flatMap(queue.flattenStrategy) { $0.producer }
                    }
                )

                return (replies, effectInputs)
            }
        )
    }

    internal init(
        state initialState: State,
        inputs inputSignal: Signal<Input, Never>,
        makeSignals: (Signal<(Input, State), Never>) -> MakeSignals
        )
    {
        let stateProperty = MutableProperty(initialState)
        self.state = Property(capturing: stateProperty)

        (self.replies, self._repliesObserver) = Signal<Reply<State, Input>, Never>.pipe()

        let effectInputs = Signal<Input, Never>.pipe()

        let mergedInputs = Signal.merge(inputSignal, effectInputs.output)

        let mapped = mergedInputs
            .withLatest(from: stateProperty.producer)

        let (replies, effects) = makeSignals(mapped)

        let d = CompositeDisposable()

        d += stateProperty <~ replies.filterMap { $0.toState }

        d += replies.observeValues(self._repliesObserver.send(value:))

        let effectDisposable = effects.start(effectInputs.input)

        d += effectDisposable

        d += inputSignal
            .observeCompleted { [_repliesObserver] in
                effectDisposable.dispose()
                _repliesObserver.sendCompleted()
                effectInputs.input.sendCompleted()
            }

        d += inputSignal
            .observeInterrupted { [_repliesObserver] in
                effectDisposable.dispose()
                _repliesObserver.sendInterrupted()
                effectInputs.input.sendInterrupted()
            }

        self._disposable = d
    }

    deinit
    {
        self._repliesObserver.sendCompleted()
        self._disposable.dispose()
    }
}

extension Automaton
{
    internal typealias MakeSignals = (
        replies: Signal<Reply<State, Input>, Never>,
        effects: SignalProducer<Input, Never>
    )
}

// MARK: - Private

private func _toEffectMapping<State, Input>(_ toState: State?) -> (State, Effect<Input, Never>?)?
{
    if let toState = toState {
        return (toState, nil)
    }
    else {
        return nil
    }
}
