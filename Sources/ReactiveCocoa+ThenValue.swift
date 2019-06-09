//
//  ReactiveCocoa+ThenValue.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-08-15.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import ReactiveSwift

extension SignalProducerProtocol {
    /// Ignores all values & attaches single `replacement` value on `.Completed`.
    public func then<U>(value replacement: U) -> SignalProducer<U, Error> {
        return self.producer.then(SignalProducer(value: replacement))
    }
}
