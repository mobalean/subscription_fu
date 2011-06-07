require 'spec_helper'

describe SubscriptionFu::Plan do
  it "should calculate tax" do
    plan = described_class.new("basic", 1000)
    plan.price_with_tax.should == 1050
    plan.price_tax.should == 50
  end
end
