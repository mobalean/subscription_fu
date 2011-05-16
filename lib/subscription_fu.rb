
module SubscriptionFu
  autoload :Config, "subscription_fu/config"
  autoload :Paypal, "subscription_fu/paypal"

  def self.config
    @config ||= SubscriptionFu::Config.new
  end
end
