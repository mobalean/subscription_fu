require "paypal"

module SubscriptionFu
  class Config
    attr_accessor :plan_class_name, :paypal_api_user_id, :paypal_api_pwd, :paypal_api_sig
    attr_reader :available_plans

    def initialize
      @available_plans = {}
      @plan_class_name = "SubscriptionFu::Plan"
      paypal_use_production!
      ::Paypal.logger = Rails.logger
    end

    def paypal_use_sandbox!
      ::Paypal.sandbox = true
    end

    def paypal_use_production!
      ::Paypal.sandbox = false
    end

    def add_plan(key, price, data = {})
      available_plans[key] = plan_class.new(key, price, data)
    end

    def add_free_plan(key, data = {})
      add_plan(key, 0, data)
    end

    private

    def plan_class
      plan_class_name.constantize
    end
  end
end
