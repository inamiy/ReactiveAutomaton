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
        typealias EffectMapping = Automaton.EffectMapping<Never>

        var automaton: Automaton?
        var lastReply: Reply<MyState, MyInput>?
        var lastRepliesEvent: Signal<Reply<MyState, MyInput>, Never>.Event?

        /// Flag for internal effect `sendInput1And2AfterDelay` disposed.
        var effectDisposed: Bool?

        var signal: Signal<MyInput, Never>!
        var observer: Signal<MyInput, Never>.Observer!
        var testScheduler: TestScheduler!

        describe("Deinit") {

            beforeEach {
                testScheduler = TestScheduler()
                let (signal_, observer_) = Signal<MyInput, Never>.pipe()
                signal = signal_
                observer = observer_

                let sendInput1And2AfterDelay =
                    SignalProducer<MyInput, Never>(value: .input2)
                        .delay(1, on: testScheduler)
                        .prefix(value: .input1)
                        .delay(1, on: testScheduler)
                        .on(disposed: { effectDisposed = true })

                let mappings: [EffectMapping] = [
                    .input0 | .state0 => .state1 | sendInput1And2AfterDelay,
                    .input1 | .state1 => .state2 | .empty,
                    .input2 | .state2 => .state0 | .empty
                ]

                automaton = Automaton(state: .state0, inputs: signal, mapping: reduce(mappings))

                _ = automaton?.replies.observe { event in
                    lastRepliesEvent = event

                    if let reply = event.value {
                        lastReply = reply
                    }
                }

                lastReply = nil
                lastRepliesEvent = nil
                effectDisposed = false
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
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == false
                    }

                    observer.send(value: .input0)

                    expect(automaton?.state.value) == .state1
                    expect(lastReply?.input) == .input0
                    expect(lastRepliesEvent?.isTerminating) == false
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == false
                    }

                    // `sendInput1And2AfterDelay` will automatically send `.input1` at this point
                    testScheduler.advance(by: .seconds(1))

                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isTerminating) == false
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == false
                    }

                    weak var weakAutomaton = automaton
                    automaton = nil

                    expect(weakAutomaton).to(beNil())
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isCompleting) == true  // isCompleting
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == true
                    }

                    // If `sendInput1And2AfterDelay` is still alive, it will send `.input2` at this point,
                    // but it's already interrupted because `automaton` is deinited.
                    testScheduler.advance(by: .seconds(1))

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
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == false
                    }

                    observer.send(value: .input0)

                    expect(automaton?.state.value) == .state1
                    expect(lastReply?.input) == .input0
                    expect(lastRepliesEvent?.isTerminating) == false
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == false
                    }

                    // `sendInput1And2AfterDelay` will automatically send `.input1` at this point
                    testScheduler.advance(by: .seconds(1))

                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isTerminating) == false
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == false
                    }

                    observer.sendInterrupted()

                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isInterrupting) == true    // interrupting, not isCompleting
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == true
                    }

                    // If `sendInput1And2AfterDelay` is still alive, it will send `.input2` at this point,
                    // but it's already interrupted because of `sendInterrupted`.
                    testScheduler.advance(by: .seconds(1))

                    // Last state & input should NOT change.
                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                }

            }

            // Unlike `automaton.deinit` or `inputSignal` sending `.Interrupted`,
            // inputSignal` sending `.Completed` does NOT cancel internal effect,
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
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == false
                    }

                    observer.send(value: .input0)

                    expect(automaton?.state.value) == .state1
                    expect(lastReply?.input) == .input0
                    expect(lastRepliesEvent?.isTerminating) == false
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == false
                    }

                    // `sendInput1And2AfterDelay` will automatically send `.input1` at this point.
                    testScheduler.advance(by: .seconds(1))

                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isTerminating) == false
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == false
                    }

                    observer.sendCompleted()

                    // Not completed yet because `sendInput1And2AfterDelay` is still in progress.
                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isTerminating) == true
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == true
                    }

                    // `sendInput1And2AfterDelay` will automatically send `.input2` at this point.
                    testScheduler.advance(by: .seconds(1))

                    // Last state & input should NOT change.
                    expect(automaton?.state.value) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesEvent?.isCompleting) == true
                    testScheduler.tickAndCheck {
                        expect(effectDisposed) == true
                    }
                }

            }

        }

    }
}

// MARK: - Private

extension TestScheduler
{
    /// Advance virtual 1 nanosecond.
    ///
    /// This is used to safely observe `on(disposed:)` via signal deallocation i.e. `Event.interrupted`.
    /// See behavior change in: https://github.com/ReactiveCocoa/ReactiveSwift/pull/355
    ///
    /// For example, when `delay`'s upstream is deallocated, `delay`'s observer will send `.interrupted` AFTER scheduler runs.
    fileprivate func tickAndCheck(_ next: () -> ())
    {
        self.advance(by: .nanoseconds(1))
        next()
    }
}
