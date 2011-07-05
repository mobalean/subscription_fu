class SubscriptionFu::SystemInitiator < ActiveRecord::Base
  set_table_name :subscription_system_initiators

  def self.paypal_sync_initiator
    find_or_create_by_name("paypal sync", :description => "Updates subscription status based on status returned by Paypal")
  end

  def to_s
    name
  end
end
