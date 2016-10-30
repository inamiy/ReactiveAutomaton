# ReactiveAutomaton

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) + State Machine, inspired by [Redux](https://github.com/reactjs/redux) and [Elm](http://elm-lang.org/). A successor of [SwiftState](https://github.com/ReactKit/SwiftState).

## Example

(Demo app is available at [ReactiveCocoaCatalog](https://github.com/inamiy/ReactiveCocoaCatalog))

![](Assets/login-diagram.png)

To make a state transition diagram like above _with additional effects_, follow these steps:

```swift
// 1. Define `State`s and `Input`s.
enum State {
    case loggedOut, loggingIn, loggedIn, loggingOut
}

enum Input {
    case login, loginOK, logout, logoutOK
    case forceLogout
}

// Additional effects (`SignalProducer`s) while state-transitioning.
// (NOTE: Use `SignalProducer.empty` for no effect)
let loginOKProducer = /* show UI, setup DB, request APIs, ..., and send `Input.loginOK` */
let logoutOKProducer = /* show UI, clear cache, cancel APIs, ..., and send `Input.logoutOK` */
let forceLogoutOKProducer = /* do something more special, ..., and send `Input.logoutOK` */

let canForceLogout: (State) -> Bool = [.loggingIn, .loggedIn].contains

// 2. Setup state-transition mappings.
let mappings: [Automaton<State, Input>.NextMapping] = [

  /*  Input   |   fromState => toState     |      Effect       */
  /* ----------------------------------------------------------*/
    .login    | .loggedOut  => .loggingIn  | loginOKProducer,
    .loginOK  | .loggingIn  => .loggedIn   | .empty,
    .logout   | .loggedIn   => .loggingOut | logoutOKProducer,
    .logoutOK | .loggingOut => .loggedOut  | .empty,

    .forceLogout | canForceLogout => .loggingOut | forceLogoutOKProducer
]

// 3. Prepare input pipe for sending `Input` to `Automaton`.
let (inputSignal, inputObserver) = Signal<Input, NoError>.pipe()

// 4. Setup `Automaton`.
let automaton = Automaton(
    state: .loggedOut,
    input: inputSignal,
    mapping: reduce(mappings),  // combine mappings using `reduce` helper
    strategy: .latest   // NOTE: `.latest` cancels previous running effect
)

// Observe state-transition replies (`.success` or `.failure`).
automaton.replies.observeNext { reply in
    print("received reply = \(reply)")
}

// Observe current state changes.
automaton.state.producer.startWithValues { state in
    print("current state = \(state)")
}
```

And let's test!

```swift
let send = inputObserver.send(value:)

expect(automaton.state.value) == .loggedIn    // already logged in
send(Input.logout)
expect(automaton.state.value) == .loggingOut  // logging out...
// `logoutOKProducer` will automatically send `Input.logoutOK` later
// and transit to `State.loggedOut`.

expect(automaton.state.value) == .loggedOut   // already logged out
send(Input.login)
expect(automaton.state.value) == .loggingIn   // logging in...
// `loginOKProducer` will automatically send `Input.loginOK` later
// and transit to `State.loggedIn`.

// 👨🏽 < But wait, there's more!
// Let's send `Input.forceLogout` immediately after `State.loggingIn`.

send(Input.forceLogout)                       // 💥💣💥
expect(automaton.state.value) == .loggingOut  // logging out...
// `forceLogoutOKProducer` will automatically send `Input.logoutOK` later
// and transit to `State.loggedOut`.
```

Note that **any sizes of `State` and `Input` will work using `ReactiveAutomaton`**, from single state (like above example) to covering whole app's states (like React.js + Redux architecture).

## References

1. [iOSDC 2016 (Tokyo, in Japanese)](https://iosdc.jp/2016/) (2016/08/20)
    - [iOSDC Japan 2016 08/20 Track A / Reactive State Machine / 稲見 泰宏 - YouTube](https://www.youtube.com/watch?v=Yvz9H9AWGFM) (video)
    - [Reactive State Machine (Japanese) // Speaker Deck](https://speakerdeck.com/inamiy/reactive-state-machine-japanese) (slide)
2. [iOSConf SG (Singapore, in English)](http://iosconf.sg/) (2016/10/20-21)
    - [Reactive State Machine - iOS Conf SG 2016 - YouTube](https://www.youtube.com/watch?v=Oau4JjJP3nA) (video)
    - [Reactive State Machine // Speaker Deck](https://speakerdeck.com/inamiy/reactive-state-machine-1) (slide)

## License

[MIT](LICENSE)
