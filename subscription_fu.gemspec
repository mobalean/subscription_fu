$:.push File.expand_path("../lib", __FILE__)
require "subscription_fu/version"

Gem::Specification.new do |s|
  s.name         = "subscription_fu"
  s.version      = SubscriptionFu::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Paul McMahon", "Michael Reinsch"]
  s.email        = "info@mobalean.com"
  s.homepage     = "http://www.mobalean.com"
  s.summary      = "Subscription Fu"
  s.description  = "Subscription Fu"

  s.files         = `git ls-files`.split("\n")
  s.require_path = 'lib'
  s.rubyforge_project = nil

  s.add_dependency 'actionpack', '>= 3.0.3'
  s.add_dependency 'rack', '>= 1.2.1'
  s.add_dependency 'rest-client', '>= 1.6.1'
 
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
end

