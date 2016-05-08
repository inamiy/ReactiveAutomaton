//
//  ReactiveCocoa+SampleFrom.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-05-07.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveCocoa

// MARK: sampleFrom http://rxmarbles.com/#withLatestFrom

// NOTE:
// `sampleFrom` (Rx.withLatestFrom) works similar to `combineLatest` + `sampleOn` as discussed in
// https://github.com/ReactiveCocoa/ReactiveCocoa/pull/2082#issuecomment-112301993 ,
// but it should rather NOT be affected by `samplee`'s termination events.
// That also means, `samplee` should be restricted to have `NoError` as error type.

extension SignalType {

    /// Flipped version of `sampleOn`, combining `self`'s (sampler) and `samplee`'s values.
    /// - Returns: A signal that terminates only when `self` terminates (`samplee` doesn't affect).
    @warn_unused_result(message="Did you forget to call `observe` on the signal?")
    internal func sampleFrom<Value2>(samplee: Signal<Value2, NoError>) -> Signal<(Value, Value2), Error> {
        return Signal { observer in
            let state = Atomic<Value2?>(nil)
            let disposable = CompositeDisposable()

            disposable += samplee.observeNext { value in
                state.value = value
            }

            disposable += self.observe { event in
                switch event {
                case let .Next(value):
                    if let value2 = state.value {
                        observer.sendNext((value, value2))
                    }
                case .Completed:
                    observer.sendCompleted()
                case let .Failed(error):
                    observer.sendFailed(error)
                case .Interrupted:
                    observer.sendInterrupted()
                }
            }

            return disposable
        }
    }

    /// Flipped version of `sampleOn`, combining `self`'s (sampler) and `samplee`'s values.
    /// - Returns: A signal that terminates only when `self` terminates (`samplee` doesn't affect).
    @warn_unused_result(message="Did you forget to call `observe` on the signal?")
    internal func sampleFrom<Value2>(samplee: SignalProducer<Value2, NoError>) -> Signal<(Value, Value2), Error> {
        return Signal { observer in
            let d = CompositeDisposable()
            samplee.startWithSignal { signal, disposable in
                d += disposable
                d += self.sampleFrom(signal).observe(observer)
            }
            return d
        }
    }
}

extension SignalProducerType {

    /// Flipped version of `sampleOn`, combining `self`'s (sampler) and `samplee`'s values.
    /// - Returns: A signalProducer that terminates only when `self` terminates (`samplee` doesn't affect).
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    internal func sampleFrom<Value2>(samplee: Signal<Value2, NoError>) -> SignalProducer<(Value, Value2), Error> {
        return lift(Signal.sampleFrom)(samplee)
    }

    /// Flipped version of `sampleOn`, combining `self`'s (sampler) and `samplee`'s values.
    /// - Returns: A signalProducer that terminates only when `self` terminates (`samplee` doesn't affect).
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    internal func sampleFrom<Value2>(samplee: SignalProducer<Value2, NoError>) -> SignalProducer<(Value, Value2), Error> {
        return lift(Signal.sampleFrom)(samplee)
    }
}
