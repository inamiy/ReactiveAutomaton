import ReactiveSwift

/// Managed side-effect that enqueues `producer` on `EffectQueue`
/// to perform arbitrary `Queue.flattenStrategy`.
public struct Effect<Input, Queue> where Queue: EffectQueueProtocol
{
    public let producer: SignalProducer<Input, Never>
    internal let queue: EffectQueue<Queue>

    public init(
        _ producer: SignalProducer<Input, Never>,
        queue: Queue? = nil
        )
    {
        self.producer = producer
        self.queue = queue.map(EffectQueue.custom) ?? .default
    }
}
