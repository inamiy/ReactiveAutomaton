import ReactiveSwift

/// FRP-driven `Signal` transformer that is used
/// as an alternative side-effect & feedback system in `Automaton`.
///
/// - Note: `Automaton` supports `Effect` and `EffectQueue` as a primary system.
///
/// - SeeAlso: https://github.com/Babylonpartners/ReactiveFeedback
/// - SeeAlso: https://github.com/NoTests/RxFeedback
public struct Feedback<Input, Output>
{
    internal let transform: (Signal<Input, Never>) -> Signal<Output, Never>

    public init(transform: @escaping (Signal<Input, Never>) -> Signal<Output, Never>)
    {
        self.transform = transform
    }

    public init(produce: @escaping (Input) -> SignalProducer<Output, Never>)
    {
        self.init(transform: { $0 }, produce: produce)
    }

    public init<U>(
        transform: @escaping (Signal<Input, Never>) -> Signal<U, Never>,
        produce: @escaping (U) -> SignalProducer<Output, Never>,
        strategy: FlattenStrategy = .latest
        )
    {
        self.transform = {
            return transform($0)
                .flatMap(strategy) { produce($0) }
        }
    }

    /// Either `produce` or sends `.empty` based on `tryGet`.
    public init<U>(
        tryGet: @escaping (Input) -> U?,
        produce: @escaping (U) -> SignalProducer<Output, Never>
        )
    {
        self.init(
            transform: { $0.map(tryGet) },
            produce: { $0.map(produce) ?? .empty }
        )
    }

    public init(
        filter: @escaping (Input) -> Bool,
        produce: @escaping (Input) -> SignalProducer<Output, Never>
        )
    {
        self.init(
            transform: { $0.filter(filter) },
            produce: produce
        )
    }
}

// MARK: - Functions

/// Folds multiple `Feedback`s into one.
public func reduce<Input, Output>(_ feedbacks: [Feedback<Input, Output>]) -> Feedback<Input, Output>
{
    return Feedback<Input, Output> { signal in
        Signal.merge(feedbacks.map { $0.transform(signal) })
    }
}
