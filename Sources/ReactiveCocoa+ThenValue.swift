//
//  ReactiveCocoa+ThenValue.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-08-15.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveCocoa

extension SignalProducerType {
    /// Ignores all values & attaches single `replacement` value on `.Completed`.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func then<U>(value replacement: U) -> SignalProducer<U, Error> {
        return self.producer.then(SignalProducer(value: replacement))
    }
}
