//
//  TerminatingSpec.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-06-09.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

class TerminatingSpec: QuickSpec
{
    override func spec()
    {
        typealias Automaton = ReactiveAutomaton.Automaton<MyState, MyInput>
        typealias Mapping = Automaton.Mapping

        var automaton: Automaton?
        var lastReply: Reply<MyState, MyInput>?
        var lastRepliesEvent: Event<Reply<MyState, MyInput>, NoError>?

        /// Flag for internal nextProducer `sendInput1And2AfterDelay` disposed.
        var nextProducerDisposed: Bool?

        var signal: Signal<MyInput, NoError>!
        var observer: Signal<MyInput, NoError>.Observer!
        var testScheduler: TestScheduler!

        describe("Deinit") {

            beforeEach {
                testScheduler = TestScheduler()
                let (signal_, observer_) = Signal<MyInput, NoError>.pipe()
                signal = signal_
                observer = observer_

                let sendInput1And2AfterDelay =
                    SignalProducer<MyInput, NoError>(value: .input2)
                        .delay(1, on: testScheduler)
                        .prefix(value: .input1)
                        .delay(1, on: testScheduler)
                        .on(disposed: { nextProducerDisposed = true })

                let mappings: [Automaton.NextMapping] = [
                    .input0 | .state0 => .state1 | sendInput1And2AfterDelay,
                    .input1 | .state1 => .state2 | .empty,
                    .input2 | .state2 => .state0 | .empty
                ]

                // strategy = `.Merge`
                automaton = Automaton(state: .state0, input: signal, mapping: reduce(mappings), strategy: .merge)

                automaton?.replies.observe { event in
                    lastRepliesEvent = event

                    if let reply = event.value {
                        lastReply = reply
                    }
                }

                lastReply = nil
                lastRepliesEvent = nil
                nextProducerDisposed = false
            }

            describe("Automaton deinit") {

                it("automaton deinits before sending input") {
                    expect(automaton?.state.value) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesEvent).to(beNil())

                    weak var weakAutomaton = automaton
                    automaton = nil

                    expect(weakAutomaton).to(beNil())
                    expect(lastReply).to(beNil())
                    expect(lastRepliesEvent?.isCompleting) == true
                }

                it("automaton deinits while sending input") {
                    expect(automaton?.state.value) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesEvent).to(beNil())
                    expect(nextProducerDisposed) == false

                    observer.sendNext(.input0)

                    expect(automaton?.state.value) == .state1
                    expect(lastReply?.input) == .input0
                    expect(lastRepliesEvent?.isTerminating) == false
                    expect(nextProducerDisposed) == false

                    // `sendInput1And2AfterDelay` will automatically send `.input1` at this point
                    testScheduler.advance(by: 1)

                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isTerminating) == false
                    expect(nextProducerDisposed) == false

                    weak var weakAutomaton = automaton
                    automaton = nil

                    expect(weakAutomaton).to(beNil())
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isCompleting) == true  // isCompleting
                    expect(nextProducerDisposed) == true

                    // If `sendInput1And2AfterDelay` is still alive, it will send `.input2` at this point,
                    // but it's already interrupted because `automaton` is deinited.
                    testScheduler.advance(by: 1)

                    // Last input should NOT change.
                    expect(lastReply?.input) == .input1
                }

            }

            // This basically behaves similar to `automaton.deinit`,
            // except `replies` will emit `.Interrupted` instead of `.Completed`.
            describe("inputSignal sendInterrupted") {

                it("inputSignal sendInterrupted before sending input") {
                    expect(automaton?.state.value) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesEvent).to(beNil())

                    observer.sendInterrupted()

                    expect(automaton?.state.value) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesEvent?.isInterrupting) == true
                }

                it("inputSignal sendInterrupted while sending input") {
                    expect(automaton?.state.value) == .state0
                    expect(automaton).toNot(beNil())
                    expect(lastReply).to(beNil())
                    expect(lastRepliesEvent).to(beNil())
                    expect(nextProducerDisposed) == false

                    observer.sendNext(.input0)

                    expect(automaton?.state.value) == .state1
                    expect(lastReply?.input) == .input0
                    expect(lastRepliesEvent?.isTerminating) == false
                    expect(nextProducerDisposed) == false

                    // `sendInput1And2AfterDelay` will automatically send `.input1` at this point
                    testScheduler.advance(by: 1)

                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isTerminating) == false
                    expect(nextProducerDisposed) == false

                    observer.sendInterrupted()

                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isInterrupting) == true    // interrupting, not isCompleting
                    expect(nextProducerDisposed) == true

                    // If `sendInput1And2AfterDelay` is still alive, it will send `.input2` at this point,
                    // but it's already interrupted because of `sendInterrupted`.
                    testScheduler.advance(by: 1)

                    // Last state & input should NOT change.
                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                }

            }

            // Unlike `automaton.deinit` or `inputSignal` sending `.Interrupted`,
            // inputSignal` sending `.Completed` does NOT cancel internal nextProducer,
            // i.e. `sendInput1And2AfterDelay`.
            describe("inputSignal sendCompleted") {

                it("inputSignal sendCompleted before sending input") {
                    expect(automaton?.state.value) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesEvent).to(beNil())

                    observer.sendCompleted()

                    expect(automaton?.state.value) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesEvent?.isCompleting) == true
                }

                it("inputSignal sendCompleted while sending input") {
                    expect(automaton?.state.value) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesEvent).to(beNil())
                    expect(nextProducerDisposed) == false

                    observer.sendNext(.input0)

                    expect(automaton?.state.value) == .state1
                    expect(lastReply?.input) == .input0
                    expect(lastRepliesEvent?.isTerminating) == false
                    expect(nextProducerDisposed) == false

                    // `sendInput1And2AfterDelay` will automatically send `.input1` at this point.
                    testScheduler.advance(by: 1)

                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isTerminating) == false
                    expect(nextProducerDisposed) == false

                    observer.sendCompleted()

                    // Not completed yet because `sendInput1And2AfterDelay` is still in progress.
                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isTerminating) == false
                    expect(nextProducerDisposed) == false

                    // `sendInput1And2AfterDelay` will automatically send `.input2` at this point.
                    testScheduler.advance(by: 1)

                    // Last state & input should change.
                    expect(automaton?.state.value) == .state0
                    expect(lastReply?.input) == .input2
                    expect(lastRepliesEvent?.isCompleting) == true
                    expect(nextProducerDisposed) == true
                }

            }

        }

    }
}
