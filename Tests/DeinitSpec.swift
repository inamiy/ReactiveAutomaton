//
//  DeinitSpec.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-06-09.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveCocoa
import ReactiveAutomaton
import Quick
import Nimble

class DeinitSpec: QuickSpec
{
    override func spec()
    {
        typealias Automaton = ReactiveAutomaton.Automaton<MyState, MyInput>
        typealias Mapping = Automaton.Mapping

        let (signal, observer) = Signal<MyInput, NoError>.pipe()
        var automaton: Automaton?
        var lastReply: Reply<MyState, MyInput>?
        var completed: Bool?

        /// Flag for `sendInput1And2AfterDelay` disposed.
        var outputDisposed: Bool?

        describe("Deinit") {

            var testScheduler: TestScheduler!

            beforeEach {
                testScheduler = TestScheduler()

                let sendInput1And2AfterDelay =
                    SignalProducer<MyInput, NoError>(value: .Input2)
                        .delay(1, onScheduler: testScheduler)
                        .prefix(value: .Input1)
                        .delay(1, onScheduler: testScheduler)
                        .on(disposed: { outputDisposed = true })

                let mappings: [Automaton.OutMapping] = [
                    .Input0 | .State0 => .State1 | sendInput1And2AfterDelay,
                    .Input1 | .State1 => .State2 | .empty,
                    .Input2 | .State2 => .State0 | .empty
                ]

                automaton = Automaton(state: .State0, input: signal, mapping: concat(mappings))

                automaton?.replies.observeNext { reply in
                    lastReply = reply
                }

                automaton?.replies.observeCompleted {
                    completed = true
                }

                lastReply = nil
                completed = false
                outputDisposed = false
            }

            it("automaton deinits before sending input") {
                expect(automaton?.state.value) == .State0
                expect(automaton).toNot(beNil())
                expect(lastReply).to(beNil())
                expect(completed) == false

                weak var weakAutomaton = automaton
                automaton = nil

                expect(weakAutomaton).to(beNil())
                expect(completed) == true
            }

            it("automaton deinits while sending input") {
                expect(automaton?.state.value) == .State0
                expect(automaton).toNot(beNil())
                expect(lastReply).to(beNil())
                expect(completed) == false
                expect(outputDisposed) == false

                observer.sendNext(.Input0)

                expect(lastReply?.input) == .Input0
                expect(automaton?.state.value) == .State1
                expect(automaton).toNot(beNil())
                expect(completed) == false
                expect(outputDisposed) == false

                // `sendInput1And2AfterDelay` will automatically send `.Input1` at this point
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .Input1
                expect(automaton?.state.value) == .State2
                expect(automaton).toNot(beNil())
                expect(completed) == false
                expect(outputDisposed) == false

                weak var weakAutomaton = automaton
                automaton = nil

                expect(weakAutomaton).to(beNil())
                expect(completed) == true
                expect(outputDisposed) == true

                // If `sendInput1And2AfterDelay` is still alive, it will send `.Input2` at this point,
                // but it's already interrupted because `automaton` is deinited.
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .Input1 // last input should not change

            }

        }

    }
}
