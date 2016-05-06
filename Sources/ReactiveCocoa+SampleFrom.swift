//
//  ReactiveCocoa+SampleFrom.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-05-07.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveCocoa

private struct SampleState<Value> {
    var latestValue: Value? = nil
    var signalCompleted: Bool = false
    var sampleeCompleted: Bool = false
}

extension SignalType {

    /// Flipped version of `sampleOn`, combining receiver's (sampler) and `samplee`'s values.
    @warn_unused_result(message="Did you forget to call `observe` on the signal?")
    internal func sampleFrom<Value2>(samplee: Signal<Value2, NoError>) -> Signal<(Value, Value2), Error> {
        return Signal { observer in
            let state = Atomic(SampleState<Value2>())
            let disposable = CompositeDisposable()

            disposable += samplee.observe { event in
                switch event {
                case let .Next(value):
                    state.modify { st in
                        var mutableSt = st
                        mutableSt.latestValue = value
                        return mutableSt
                    }
                case .Completed:
                    let oldState = state.modify { st in
                        var mutableSt = st
                        mutableSt.sampleeCompleted = true
                        return mutableSt
                    }

                    if oldState.signalCompleted {
                        observer.sendCompleted()
                    }
                case .Interrupted:
                    observer.sendInterrupted()
                default:
                    break
                }
            }

            disposable += self.observe { event in
                switch event {
                case let .Next(value):
                    if let value2 = state.value.latestValue {
                        observer.sendNext((value, value2))
                    }
                case .Completed:
                    let oldState = state.modify { st in
                        var mutableSt = st
                        mutableSt.signalCompleted = true
                        return mutableSt
                    }

                    if oldState.sampleeCompleted {
                        observer.sendCompleted()
                    }
                case let .Failed(error):
                    observer.sendFailed(error)
                case .Interrupted:
                    observer.sendInterrupted()
                }
            }

            return disposable
        }
    }

    /// Flipped version of `sampleOn`, combining receiver's (sampler) and `samplee`'s values.
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

    /// Flipped version of `sampleOn`, combining receiver's (sampler) and `samplee`'s values.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    internal func sampleFrom<Value2>(samplee: SignalProducer<Value2, NoError>) -> SignalProducer<(Value, Value2), Error> {
        return lift(Signal.sampleFrom)(samplee)
    }
}
