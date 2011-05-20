$:.push File.expand_path("../lib", __FILE__)
require "subscription_fu/version"

Gem::Specification.new do |s|
  s.name         = "subscription_fu"
  s.version      = SubscriptionFu::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Paul McMahon", "Michael Reinsch"]
  s.email        = "info@mobalean.com"
  s.homepage     = "http://www.mobalean.com"
  s.summary      = "Rails support for handling free/paid subscriptions"
  s.description  = "SubscriptionFu helps with building services which have paid subscriptions. It includes the models to store subscription status, and provides integration with PayPal for paid subscriptions."

  s.files         = `git ls-files`.split("\n")
  s.require_path = 'lib'
  s.rubyforge_project = "subscriptionfu"

  s.add_dependency 'rails', '>= 3.0.3'
  s.add_dependency 'rest-client', '>= 1.6.1'
 
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
end

