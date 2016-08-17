# ReactiveAutomaton

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) + State Machine, inspired by [Redux](https://github.com/reactjs/redux) and [Elm](http://elm-lang.org/). A successor of [SwiftState](https://github.com/ReactKit/SwiftState).

## Example

(Demo app is available at [ReactiveCocoaCatalog](https://github.com/inamiy/ReactiveCocoaCatalog))

![](Assets/login-diagram.png)

To make a state transition diagram like above _with additional effects_, follow these steps:

```swift
// 1. Define `State`s and `Input`s.
enum State {
    case LoggedOut, LoggingIn, LoggedIn, LoggingOut
}

enum Input {
    case Login, LoginOK, Logout, LogoutOK
    case ForceLogout
}

// Additional effects (`SignalProducer`s) while state-transitioning.
// (NOTE: Use `SignalProducer.empty` for no effect)
let loginOKProducer = /* show UI, setup DB, request APIs, ..., and send `Input.LoginOK` */
let logoutOKProducer = /* show UI, clear cache, cancel APIs, ..., and send `Input.LogoutOK` */
let forceLogoutOKProducer = /* do something more special, ..., and send `Input.LogoutOK` */

let canForceLogout: State -> Bool = [.LoggingIn, .LoggedIn].contains

// 2. Setup state-transition mappings.
let mappings: [Automaton<State, Input>.NextMapping] = [

  /*  Input   |   fromState => toState     |      Effect       */
  /* ----------------------------------------------------------*/
    .Login    | .LoggedOut  => .LoggingIn  | loginOKProducer,
    .LoginOK  | .LoggingIn  => .LoggedIn   | .empty,
    .Logout   | .LoggedIn   => .LoggingOut | logoutOKProducer,
    .LogoutOK | .LoggingOut => .LoggedOut  | .empty,

    .ForceLogout | canForceLogout => .LoggingOut | forceLogoutOKProducer
]

// 3. Prepare input pipe for sending `Input` to `Automaton`.
let (inputSignal, inputObserver) = Signal<Input, NoError>.pipe()

// 4. Setup `Automaton`.
let automaton = Automaton(
    state: .LoggedOut,
    input: inputSignal,
    mapping: reduce(mappings),  // combine mappings using `reduce` helper
    strategy: .Latest   // NOTE: `.Latest` cancels previous running effect
)

// Observe state-transition replies (`.Success` or `.Failure`).
automaton.replies.observeNext { reply in
    print("received reply = \(reply)")
}

// Observe current state changes.
automaton.state.producer.startWithNext { state in
    print("current state = \(state)")
}
```

And let's test!

```swift
let send = inputObserver.sendNext

expect(automaton.state.value) == .LoggedIn    // already logged in
send(Input.Logout)
expect(automaton.state.value) == .LoggingOut  // logging out...
// `logoutOKProducer` will automatically send `Input.LogoutOK` later 
// and transit to `State.LoggedOut`.

expect(automaton.state.value) == .LoggedOut   // already logged out
send(Input.Login)
expect(automaton.state.value) == .LoggingIn   // logging in... 
// `loginOKProducer` will automatically send `Input.LoginOK` later 
// and transit to `State.LoggedIn`.

// 👨🏽 < But wait, there's more!
// Let's send `Input.ForceLogout` immediately after `State.LoggingIn`.

send(Input.ForceLogout)                       // 💥💣💥
expect(automaton.state.value) == .LoggingOut  // logging out...
// `forceLogoutOKProducer` will automatically send `Input.LogoutOK` later
// and transit to `State.LoggedOut`.
```

Note that **any sizes of `State` and `Input` will work using `ReactiveAutomaton`**, from single state (like above example) to covering whole app's states (like React.js + Redux architecture).

## References

1. [iOSDC 2016 (Tokyo)](https://iosdc.jp/2016/) (TBD 2016/08/20) 
2. [iOSConf SG (Singapore)](http://iosconf.sg/) (TBD 2016/10/20-21) 

## License

[MIT](LICENSE)
