import ReactiveSwift

extension Automaton
{
    /// Initializer using `feedback` for injecting side-effects.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - input: `Signal<Input, Never>` that automaton receives.
    ///   - mapping: Simple `Mapping` that designates next state only (no additional effect).
    ///   - feedback: `Signal` transformer that performs side-effect and emits next input.
    public convenience init(
        state initialState: State,
        inputs inputSignal: Signal<Input, Never>,
        mapping: @escaping Mapping,
        feedback: Feedback<Reply<State, Input>.Success, Input>
        )
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
                        if let toState = mapped {
                            return .success((input, fromState, toState))
                        }
                        else {
                            return .failure((input, fromState))
                        }
                    }

                let effects = feedback.transform(replies.filterMap { $0.success }).producer

                return (replies, effects)
            }
        )
    }
}
