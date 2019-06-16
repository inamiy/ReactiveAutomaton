import ReactiveSwift

/// Managed side-effect that enqueues `producer` on `EffectQueue`
/// to perform arbitrary `Queue.flattenStrategy`.
public struct Effect<Input, Queue> where Queue: EffectQueueProtocol
{
    /// "Cold" stream that runs side-effect and sends next `Input`.
    public let producer: SignalProducer<Input, Never>

    /// Effect queue that associates with `producer` to perform various `flattenStrategy`s.
    internal let queue: EffectQueue<Queue>

    /// - Parameter queue: Uses custom queue, or set `nil` as default queue to use `merge` strategy.
    public init(
        _ producer: SignalProducer<Input, Never>,
        queue: Queue? = nil
        )
    {
        self.producer = producer
        self.queue = queue.map(EffectQueue.custom) ?? .default
    }
}
