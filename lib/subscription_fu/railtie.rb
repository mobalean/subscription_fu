module SubscriptionFu
  class Railtie < ::Rails::Railtie
    config.subscription_fu = SubscriptionFu.config
    initializer "subscription_fu.extend.active_record" do |app|
      ActiveSupport.on_load :active_record do
        include SubscriptionFu::Models
      end
    end
  end
end

require "subscription_fu/models"
