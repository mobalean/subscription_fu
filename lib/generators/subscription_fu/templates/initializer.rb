<%= Rails.application.class.name %>.configure do

  # change this to your PayPal API User ID
  config.subscription_fu.paypal_api_user_id = "michae_1272617165_biz_api1.mobalean.com"
  # change this to your PayPal API password
  config.subscription_fu.paypal_api_pwd = "1272617171"
  # change this to your PayPal API signature
  config.subscription_fu.paypal_api_sig = "ATpPRKe6SEGaLcgDfFD-kBQgVsGuA9iFQwK6d4x6Qs4iti0XYRkZQl9Q"

  # Your subscription plans. You'll need to add at least one plan.

  # You can use a custom class for billing plans. The default is 
  # SubscriptionFu::Plan, which you can use as the base for custom plans.
  # Using your custom plan class allows you to further configure system
  # parameters based on a selected plan.
  #config.subscription_fu.plan_class_name = "MyPlan"

  # The first parameter is an identifier for this plan. For non-free plans,
  # the second parameter isthe price. If you would like to add custom plan 
  # parameters, you can change the class used for plans (see above).
  config.subscription_fu.add_free_plan 'free'
  config.subscription_fu.add_plan 'basic', 1000
  config.subscription_fu.add_plan 'premium', 5000
end
