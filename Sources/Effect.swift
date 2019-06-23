import ReactiveSwift

/// Managed side-effect that enqueues `producer` on `EffectQueue`
/// to perform arbitrary `Queue.flattenStrategy`.
public struct Effect<Input, State, Queue> where Queue: EffectQueueProtocol
{
    /// "Cold" stream that runs side-effect and sends next `Input`.
    public let producer: SignalProducer<Input, Never>

    /// Effect queue that associates with `producer` to perform various `flattenStrategy`s.
    internal let queue: EffectQueue<Queue>

    /// `(input, fromState)` predicate for running `producer` cancellation.
    /// - Note: Cancellation will be triggered regardless of state-transition success or failure.
    internal let until: (Input, State) -> Bool

    /// - Parameters:
    ///   - queue: Uses custom queue, or set `nil` as default queue to use `merge` strategy.
    ///   - until: `(input, fromState)` predicate for running `producer` cancellation.
    public init(
        _ producer: SignalProducer<Input, Never>,
        queue: Queue? = nil,
        until: @escaping (Input, State) -> Bool = { _, _ in false }
        )
    {
        self.producer = producer
        self.queue = queue.map(EffectQueue.custom) ?? .default
        self.until = until
    }

    /// Empty side-effect.
    public static var none: Effect<Input, State, Queue>
    {
        return Effect(.empty)
    }
}

extension Effect: ExpressibleByNilLiteral
{
    public init(nilLiteral: ())
    {
        self = .none
    }
}

extension Effect where Input: Equatable
{
    public init(
        _ producer: SignalProducer<Input, Never>,
        queue: Queue? = nil,
        until input: Input
        )
    {
        self.init(
            producer,
            queue: queue,
            until: { i, _ in i == input }
        )
    }
}
