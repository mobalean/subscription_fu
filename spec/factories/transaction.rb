Factory.define :transaction, :class => "SubscriptionFu::Transaction" do |t|
  t.association :subscription
  t.association :initiator
  t.gateway "nogw"
  t.status "initiated"
  t.action "activation"
end
