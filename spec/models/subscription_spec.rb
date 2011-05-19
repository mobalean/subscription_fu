require 'spec_helper'

describe SubscriptionFu::Subscription do

  class << self
    def should_build_valid_successor(expected_plan_key, start_time_instance, billing_start_time_instance)
      it "should be valid subscription successor" do
        @succ.subject.should == @sub.subject
        @succ.prev_subscription.should == @sub
        @succ.plan_key.should == expected_plan_key
        @succ.starts_at.should == instance_variable_get("@#{start_time_instance}")
        @succ.billing_starts_at.should == instance_variable_get("@#{billing_start_time_instance}")
      end
    end
    def should_build_valid_activation_transaction(sub_instance, trans_instance, first_sub)
      it "should build valid activation transaction" do
        sub = instance_variable_get("@#{sub_instance}")
        trans = instance_variable_get("@#{trans_instance}")
        trans.subscription.should == sub
        trans.initiator.should == @initiator
        trans.action.should == "activation"
        trans.status.should == "initiated"
        trans.identifier.should be_nil

        if first_sub
          trans.related_transactions.should be_empty
        else
          trans.related_transactions.size.should == 1
          rel_trans = trans.related_transactions.first
          rel_trans.subscription.should == sub.prev_subscription
          rel_trans.initiator.should == @initiator
          rel_trans.action.should == "cancellation"
          rel_trans.status.should == "initiated"
          rel_trans.identifier.should be_nil
        end
      end
    end
    def should_build_free_activation_transaction
      it "should be activation transaction for free sub" do
        @trans.gateway.should == "nogw"
      end
    end
    def should_build_paypal_activation_transaction
      it "should be activation transaction for paypal sub" do
        @trans.gateway.should == "paypal"
      end
    end
    def should_activate_subscription(sub_instance)
      it "should activate subscription" do
        sub = instance_variable_get("@#{sub_instance}").reload
        sub.should be_activated
        sub.transactions.first.status.should == "complete"
      end
    end
    def should_cancel_previous_subscription(sub_instance)
      it "should cancel previous sub" do
        sub = instance_variable_get("@#{sub_instance}").prev_subscription.reload
        sub.canceled_at.should be_present
        sub.transactions.last.status.should == "complete"
      end
    end
    def should_cancel_subscription(sub_instance)
      it "should cancel sub" do
        sub = instance_variable_get("@#{sub_instance}").reload
        sub.canceled_at.should be_present
        sub.transactions.last.status.should == "complete"
      end
    end
    def should_have_free_activation_flow(sub_instance, first_sub)
      context "activation" do
        before { @trans = instance_variable_get("@#{sub_instance}").initiate_activation(@initiator) }
        should_build_valid_activation_transaction(sub_instance, :trans, first_sub)
        should_build_free_activation_transaction
        context "authorize" do
          before { @redirect_target = @trans.start_checkout("http://return.to", "http://cancel.to") }
          it("should redirect to return URL") { @redirect_target.should == "http://return.to" }
          context "complete" do
            before { mock_paypal_delete_profile("fgsga564aa") } unless first_sub
            before { @trans.complete! }
            should_activate_subscription(sub_instance)
            should_cancel_previous_subscription(sub_instance) unless first_sub
          end
        end
      end
    end
    def should_have_paid_activation_flow(sub_instance, first_sub, prev_sub_is_free = false)
      context "activation" do
        before { @trans = instance_variable_get("@#{sub_instance}").initiate_activation(@initiator) }
        should_build_valid_activation_transaction(sub_instance, :trans, first_sub)
        should_build_paypal_activation_transaction
        context "authorization" do
          before do
            mock_paypal_express_checkout
            @redirect_target = @trans.start_checkout("http://return.to", "http://cancel.to")
          end
          it("should redirect to return URL") do
            @redirect_target.should == "https://www.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=token123"
          end
          context "complete" do
            before { mock_paypal_create_profile("token123", "6bvsaksd9j") }
            before { mock_paypal_delete_profile("fgsga564aa") } unless first_sub
            before { @trans.complete! }
            should_activate_subscription(sub_instance)
            should_cancel_previous_subscription(sub_instance) unless first_sub
          end
          context "complete with error in cancel" do
            before { mock_paypal_create_profile("token123", "6bvsaksd9j") }
            before { mock_paypal_delete_profile_with_error("fgsga564aa") }
            before { @trans.complete! }
            should_activate_subscription(sub_instance)
            it "should cancel previous sub with failure" do
              sub = instance_variable_get("@#{sub_instance}").prev_subscription.reload
              sub.canceled_at.should be_present
              sub.transactions.last.status.should == "failed"
            end
          end unless first_sub || prev_sub_is_free
          context "complete with error in create" do
            before { mock_paypal_create_profile_with_error("token123") }
            before { mock_paypal_delete_profile("fgsga564aa") } unless first_sub
            before { @trans.complete! }
            it "should not activate subscription" do
              sub = instance_variable_get("@#{sub_instance}").reload
              sub.should_not be_activated
              sub.transactions.first.status.should == "failed"
            end
            it "should not cancel previous subscription" do
              sub = instance_variable_get("@#{sub_instance}").prev_subscription.reload
              sub.canceled_at.should be_blank
              sub.transactions.last.status.should == "aborted"
            end unless first_sub
          end
        end
      end
    end
  end

  it { should belong_to :subject }
  it { should have_many :transactions }
  it { should validate_presence_of :subject }
  it { should validate_presence_of :plan_key }
  %w( free profess premium basic ).each {|p| it { should allow_value(p).for(:plan_key) } }
  it { should_not allow_value("blah").for(:plan_key) }
  it { should validate_presence_of :starts_at }

  context "base" do
    before { @initiator = Factory(:initiator)  }

    context "free subscription" do
      before { @sub = Factory(:subscription, :plan_key => "free") }
      it("should indicate it isn't a paid subscription") { @sub.should_not be_paid_subscription }
      it("should return human name") do
        pending do
          @sub.human_description.should == "MyApp Free subscription for Subject, 0 JPY per month"
        end
      end
      it("should return no next_billing_date") { @sub.next_billing_date.should be_nil }
      should_have_free_activation_flow(:sub, true)
      context "basic successor" do
        before do
          @sub.activate_without_billing!
          @now = Time.now
          at_time(@now) { @succ = @sub.subject.build_next_subscription('basic') ; @succ.save! }
        end
        should_build_valid_successor("basic", :now, :now)
        should_have_paid_activation_flow(:succ, false, true)
      end
    end

    context "basic subscription" do
      before { @sub = Factory(:subscription, :plan_key => "basic", :paypal_profile_id => "bg5431ddf") }
      it("should indicate it is a paid subscription") { @sub.should be_paid_subscription }
      it("should return human name") do
        pending do
          @sub.human_description.should == "MyApp Basic subscription for Subject, 1050 JPY per month"
        end
      end
    end

    context "premium subscription" do
      before do
        @now = Time.parse("2010-01-12 11:45")
        @sub_start = Time.parse("2010-01-10 00:00 UTC")
        @next_billing = Time.parse("2010-02-10 00:00 UTC")
        @sub = Factory(:subscription, :plan_key => "premium", :paypal_profile_id => "fgsga564aa",
                       :starts_at => @sub_start, :billing_starts_at => @sub_start, :activated_at => @sub_start)
      end

      context "active on paypal" do
        before { mock_paypal_profile_details("fgsga564aa", "ActiveProfile", "2010-01-10", "2010-02-10") }
        it("should return next_billing_date") { @sub.next_billing_date.should == @next_billing }
        it("should return last_billing_date") { @sub.last_billing_date.should == Time.parse("2010-01-10 00:00 UTC") }
        it("should return estimated_next_billing_date") { @sub.estimated_next_billing_date.should == @next_billing }
        it("should return successor_billing_start_date") { @sub.successor_billing_start_date.should == @next_billing }
        context "profess successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('profess'); @succ.save! } }
          should_build_valid_successor("profess", :now, :next_billing)
          should_have_paid_activation_flow(:succ, false)
        end
        context "basic successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('basic'); @succ.save! } }
          should_build_valid_successor("basic", :next_billing, :next_billing)
          should_have_paid_activation_flow(:succ, false)
        end
        context "free successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('free'); @succ.save! } }
          should_build_valid_successor("free", :next_billing, :next_billing)
          should_have_free_activation_flow(:succ, false)
        end
      end

      context "canceled on paypal" do
        before { mock_paypal_profile_details("fgsga564aa", "CanceledProfile", "2010-01-10", nil) }
        it("should return next_billing_date") { @sub.next_billing_date.should be_nil }
        it("should return last_billing_date") { @sub.last_billing_date.should == Time.parse("2010-01-10 00:00 UTC") }
        it("should return estimated_next_billing_date") { @sub.estimated_next_billing_date.should == @next_billing }
        it("should return successor_billing_start_date") { @sub.successor_billing_start_date.should == @next_billing }
        context "profess successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('profess'); @succ.save! } }
          should_build_valid_successor("profess", :now, :next_billing)
        end
        context "basic successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('basic'); @succ.save! } }
          should_build_valid_successor("basic", :next_billing, :next_billing)
        end
        context "free successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('free'); @succ.save! } }
          should_build_valid_successor("free", :next_billing, :next_billing)
        end
      end

      context "canceled on paypal, no payments made" do
        before { mock_paypal_profile_details("fgsga564aa", "CanceledProfile", nil, nil) }
        it("should return next_billing_date") { @sub.next_billing_date.should be_nil }
        it("should return last_billing_date") { @sub.last_billing_date.should be_nil }
        it("should return estimated_next_billing_date") { @sub.estimated_next_billing_date.should be_nil }
        it("should return successor_billing_start_date") { at_time(@now) { @sub.successor_billing_start_date.should == @now } }
        context "profess successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('profess'); @succ.save! } }
          should_build_valid_successor("profess", :now, :now)
        end
        context "basic successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('basic'); @succ.save! } }
          should_build_valid_successor("basic", :now, :now)
        end
        context "free successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('free'); @succ.save! } }
          should_build_valid_successor("free", :now, :now)
        end
      end

      context "canceled on our side" do
        before { @sub.update_attributes(:canceled_at => @next_billing, :cancel_reason => 'admin') }
        it("should return successor_billing_start_date") { @sub.successor_billing_start_date.should == @next_billing }
        context "profess successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('profess'); @succ.save! } }
          should_build_valid_successor("profess", :now, :next_billing)
        end
        context "basic successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('basic'); @succ.save! } }
          should_build_valid_successor("basic", :next_billing, :next_billing)
        end
        context "free successor" do
          before { at_time(@now) { @succ = @sub.subject.build_next_subscription('free'); @succ.save! } }
          should_build_valid_successor("free", :next_billing, :next_billing)
        end
      end
    end
  end
end
