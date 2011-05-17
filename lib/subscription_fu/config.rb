module SubscriptionFu
  class Config
    attr_accessor :plan_class_name, :paypal_nvp_api_url, :paypal_api_user_id, :paypal_api_pwd, :paypal_api_sig, :paypal_landing_url
    attr_reader :available_plans

    def initialize
      @available_plans = {}
      @plan_class_name = "SubscriptionFu::Plan"
      paypal_use_production!
    end

    def paypal_use_sandbox!
      self.paypal_nvp_api_url = "https://api-3t.sandbox.paypal.com/nvp"
      self.paypal_landing_url = "https://www.sandbox.paypal.com/cgi-bin/webscr"
    end

    def paypal_use_production!
      self.paypal_nvp_api_url = "https://api-3t.paypal.com/nvp"
      self.paypal_landing_url = "https://www.paypal.com/cgi-bin/webscr"
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
