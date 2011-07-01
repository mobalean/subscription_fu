require "paypal"

module SubscriptionFu::Paypal
  UTC_TZ = ActiveSupport::TimeZone.new("UTC")

  CANCELED_STATE = "Cancelled"
  ACTIVE_STATE = "Active"

  def self.express_request
    config = SubscriptionFu.config
    ::Paypal::Express::Request.new(
      :username   => config.paypal_api_user_id,
      :password   => config.paypal_api_pwd,
      :signature  => config.paypal_api_sig)
  end

  def self.recurring_details(profile_id)
    res = SubscriptionFu::Paypal.express_request.subscription(profile_id)
    { :status => res.recurring.status,
      :next_billing_date => UTC_TZ.parse(res.recurring.summary.next_billing_date.to_s),
      :last_payment_date => UTC_TZ.parse(res.recurring.summary.last_payment_date.to_s) }
  end
end
