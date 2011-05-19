module SubscriptionFu
  autoload :Config, "subscription_fu/config"
  autoload :Paypal, "subscription_fu/paypal"

  def self.config
    @config ||= SubscriptionFu::Config.new
  end

  def self.friendly_token
    ActiveSupport::SecureRandom.base64(44).tr('+/=', 'xyz')
  end
end

require 'subscription_fu/railtie'
require 'subscription_fu/engine'
