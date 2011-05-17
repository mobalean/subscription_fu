class MyCustomPlan < SubscriptionFu::Plan
  attr_accessor :tickets

  def private_events?
    price > 1000
  end

  def custom_email_from?
    price > 1000
  end

  def extra_promotion?
    ! free_plan?
  end
end

RailsApp::Application.configure do
  config.subscription_fu.paypal_api_user_id = "michae_1272617165_biz_api1.mobalean.com"
  config.subscription_fu.paypal_api_pwd = "1272617171"
  config.subscription_fu.paypal_api_sig = "ATpPRKe6SEGaLcgDfFD-kBQgVsGuA9iFQwK6d4x6Qs4iti0XYRkZQl9Q"

  config.subscription_fu.plan_class_name = "MyCustomPlan"

  config.subscription_fu.add_free_plan 'free', :tickets => 100
  config.subscription_fu.add_plan 'basic', 1000, :tickets => 100
  config.subscription_fu.add_plan 'premium', 5000, :tickets => 200
  config.subscription_fu.add_plan 'profess', 20000, :tickets => 1000
end
