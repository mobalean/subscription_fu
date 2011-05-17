require 'spec_helper'

describe SubscriptionFu::Transaction do

  class << self
    def should_have_nogw_initiated_status
      it "should have nogw initiated status" do
        @trans.should_not be_needs_authorization
        @trans.subscription.should_not be_activated
      end
    end
    def should_have_paypal_initiated_status
      it "should have paypal initiated status" do
        @trans.should be_needs_authorization
        @trans.subscription.should_not be_activated
      end
    end
    def should_not_support_start_checkout
      it "should not support start_checkout" do
        lambda { @trans.start_checkout("url1", "url2") }.should raise_error RuntimeError
      end
    end
    def complete_should_transition_to_activated
      context "complete!" do
        before { @trans.complete! }
        it "should transition" do
          @trans.status.should == "complete"
          @trans.subscription.should be_activated
        end
      end
    end
    def complete_should_transition_to_canceled
      context "complete!" do
        before { @trans.complete! }
        it "should transition" do
          @trans.status.should == "complete"
          @trans.subscription.should be_canceled
        end
      end
    end
  end

  it { should belong_to :subscription }
  it { should belong_to :initiator }
  it { should belong_to :related_transaction }
  it { should have_many :related_transactions }

  it { should validate_presence_of :subscription }
  it { should validate_presence_of :initiator }

  it { should validate_presence_of :gateway }
  %w( paypal nogw ).each {|v| it { should allow_value(v).for(:gateway)} }
  it { should_not allow_value("payPal").for(:gateway) }

  it { should validate_presence_of :action }
  %w( activation cancellation ).each {|v| it { should allow_value(v).for(:action)} }
  it { should_not allow_value("actiove").for(:action) }

  it { should validate_presence_of :status }
  %w( initiated complete failed aborted ).each {|v| it { should allow_value(v).for(:status) } }
  it { should_not allow_value("unknown").for(:status) }

  context "initiated activation nogw transaction" do
    before do
      @sub = Factory(:subscription, :plan_key => 'free')
      @trans = Factory(:transaction, :gateway => "nogw", :status => "initiated", :action => "activation", :subscription => @sub)
    end
    should_have_nogw_initiated_status
    should_not_support_start_checkout
    complete_should_transition_to_activated
  end

  context "initiated cancellation nogw transaction" do
    before do
      @sub = Factory(:subscription, :plan_key => 'free')
      @trans = Factory(:transaction, :gateway => "nogw", :status => "initiated", :action => "cancellation", :subscription => @sub)
    end
    should_have_nogw_initiated_status
    should_not_support_start_checkout
    complete_should_transition_to_canceled
  end

  context "complete nogw transaction" do
    before { @trans = Factory(:transaction, :gateway => "nogw", :status => "complete") }
    should_not_support_start_checkout
  end

  context "invalid nogw transaction" do
    before { @trans = Factory(:transaction, :gateway => "nogw", :status => "failed") }
    should_not_support_start_checkout
  end

  context "initiated activation paypal transaction" do
    before { @trans = Factory(:transaction, :gateway => "paypal", :status => "initiated", :action => "activation") }
    should_have_paypal_initiated_status
    context "checkout" do
      before do
        mock_paypal_express_checkout("bgds65sd")
        mock_paypal_create_profile("bgds65sd")
        @token = @trans.start_checkout("url1", "url2")
      end
      it "should set correct token" do
        @token.should == "https://www.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=bgds65sd"
        @trans.identifier.should == "bgds65sd"
      end
      complete_should_transition_to_activated
    end
    context "complete without checkout" do
      before { @trans.complete! }
      it("should fail") { @trans.status.should == "failed" }
    end
  end

  context "complete paypal transaction" do
    before { @trans = Factory(:transaction, :gateway => "paypal", :status => "complete") }
    should_not_support_start_checkout
  end

  context "failed paypal transaction" do
    before { @trans = Factory(:transaction, :gateway => "paypal", :status => "failed") }
    should_not_support_start_checkout
  end

end
