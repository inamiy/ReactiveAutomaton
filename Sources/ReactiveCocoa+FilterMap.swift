//
//  ReactiveCocoa+FilterMap.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-07-21.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Foundation
import ReactiveSwift

// Code from https://github.com/RACCommunity/Rex

extension SignalProtocol {
    /// Applies `transform` to values from `signal` with non-`nil` results unwrapped and
    /// forwared on the returned signal.
    internal func filterMap<U>(_ transform: @escaping (Value) -> U?) -> Signal<U, Error> {
        return Signal<U, Error> { observer in
            return self.observe { event in
                switch event {
                case let .value(value):
                    if let mapped = transform(value) {
                        observer.send(value: mapped)
                    }
                case let .failed(error):
                    observer.send(error: error)
                case .completed:
                    observer.sendCompleted()
                case .interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }
}

extension SignalProducerProtocol {
    /// Applies `transform` to values from self with non-`nil` results unwrapped and
    /// forwared on the returned producer.
    internal func filterMap<U>(_ transform: @escaping (Value) -> U?) -> SignalProducer<U, Error> {
        return lift { $0.filterMap(transform) }
    }
}
