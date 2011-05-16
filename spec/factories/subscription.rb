Factory.define :subscription, :class => "SubscriptionFu::Subscription" do |s|
  s.subject {|s| Factory(:subject) }
  s.starts_at Time.now
  s.billing_starts_at Time.now
  s.plan_key "premium"
end
