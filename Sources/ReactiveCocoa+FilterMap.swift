//
//  ReactiveCocoa+FilterMap.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-07-21.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Foundation
import ReactiveCocoa

// Code from https://github.com/RACCommunity/Rex

extension SignalType {
    /// Applies `transform` to values from `signal` with non-`nil` results unwrapped and
    /// forwared on the returned signal.
    @warn_unused_result(message="Did you forget to call `observe` on the signal?")
    internal func filterMap<U>(transform: Value -> U?) -> Signal<U, Error> {
        return Signal<U, Error> { observer in
            return self.observe { event in
                switch event {
                case let .Next(value):
                    if let mapped = transform(value) {
                        observer.sendNext(mapped)
                    }
                case let .Failed(error):
                    observer.sendFailed(error)
                case .Completed:
                    observer.sendCompleted()
                case .Interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }
}

extension SignalProducerType {
    /// Applies `transform` to values from self with non-`nil` results unwrapped and
    /// forwared on the returned producer.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    internal func filterMap<U>(transform: Value -> U?) -> SignalProducer<U, Error> {
        return lift { $0.filterMap(transform) }
    }
}
