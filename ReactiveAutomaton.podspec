Pod::Spec.new do |s|
  s.name         = "ReactiveAutomaton"
  s.version      = "0.4.0"
  s.summary      = "ReactiveCocoa + State Machine, inspired by Redux and Elm."
  s.homepage     = "https://github.com/inamiy/ReactiveAutomaton"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Yasuhiro Inami" => "inamiy@gmail.com" }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/inamiy/ReactiveAutomaton.git", :tag => "#{s.version}" }
  s.source_files  = "Sources/**/*.swift"

  s.dependency "ReactiveSwift", "~> 4.0"
end
