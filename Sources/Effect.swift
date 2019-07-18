import ReactiveSwift

/// Managed side-effect that enqueues `producer` on `EffectQueue`
/// to perform arbitrary `Queue.flattenStrategy`.
///
/// This type also handles effect cancellation via `cancel`.
public struct Effect<Input, Queue, ID>
    where Queue: EffectQueueProtocol, ID: Equatable
{
    internal let kind: Kind

    internal init(kind: Kind)
    {
        self.kind = kind
    }

    /// Managed side-effect that enqueues `producer` on `EffectQueue`
    /// to perform arbitrary `Queue.flattenStrategy`.
    ///
    /// - Parameters:
    ///   - producer: "Cold" stream that runs side-effect and sends next `Input`.
    ///   - queue: Uses custom queue, or set `nil` as default queue to use `merge` strategy.
    ///   - id: Effect identifier for cancelling running `producer`.
    public init(
        _ producer: SignalProducer<Input, Never>,
        queue: Queue? = nil,
        id: ID? = nil
        )
    {
        self.init(kind: .producer(
            Producer(
                producer: producer,
                queue: queue.map(EffectQueue.custom) ?? .default,
                id: id
            )
        ))
    }

    /// Cancels running `producer` by specifying `identifiers`.
    public static func cancel(
        _ identifiers: @escaping (ID) -> Bool
        ) -> Effect<Input, Queue, ID>
    {
        return Effect(kind: .cancel(identifiers))
    }

    /// Cancels running `producer` by specifying `identifier`.
    public static func cancel(
        _ identifier: ID
        ) -> Effect<Input, Queue, ID>
    {
        return Effect(kind: .cancel { $0 == identifier })
    }

    /// Empty side-effect.
    public static var none: Effect<Input, Queue, ID>
    {
        return Effect(.empty)
    }

    // MARK: - Functor

    public func mapInput<Input2>(_ f: @escaping (Input) -> Input2) -> Effect<Input2, Queue, ID>
    {
        switch self.kind {
        case let .producer(producer):
            return .init(kind: .producer(Effect<Input2, Queue, ID>.Producer(
                producer: producer.producer.map(f),
                queue: producer.queue,
                id: producer.id
            )))
        case let .cancel(predicate):
            return .cancel(predicate)
        }
    }
}

extension Effect: ExpressibleByNilLiteral
{
    public init(nilLiteral: ())
    {
        self = .none
    }
}

extension Effect
{
    internal var producer: Producer?
    {
        guard case let .producer(value) = self.kind else { return nil }
        return value
    }

    internal var cancel: ((ID) -> Bool)?
    {
        guard case let .cancel(value) = self.kind else { return nil }
        return value
    }
}

// MARK: - Inner Types

extension Effect
{
    internal enum Kind
    {
        case producer(Producer)
        case cancel((ID) -> Bool)
    }

    internal struct Producer
    {
        /// "Cold" stream that runs side-effect and sends next `Input`.
        internal let producer: SignalProducer<Input, Never>

        /// Effect queue that associates with `producer` to perform various `flattenStrategy`s.
        internal let queue: EffectQueue<Queue>

        /// Effect identifier for cancelling running `producer`.
        internal let id: ID?
    }
}
