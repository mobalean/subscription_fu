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


  shared_examples "successful checkout" do
    before { @res = @trans.complete }
    it("should return true") { @res.should == true }
    it "should transition" do
      @trans.status.should == "complete"
      @trans.subscription.should be_activated
    end
  end

  shared_examples "failed checkout" do
    before { @res = @trans.complete }
    it("should return false") { @res.should == false }
    it("should fail") { @trans.status.should == "failed" }
  end

  context "initiated activation nogw transaction" do
    before do
      @sub = Factory(:subscription, :plan_key => 'free')
      @trans = Factory(:transaction, :gateway => "nogw", :status => "initiated", :action => "activation", :subscription => @sub)
    end
    should_have_nogw_initiated_status

    context "checkout" do
      before { @redirect_target = @trans.start_checkout("url1", "url2") }
      it("should redirect to confirmation URL") { @redirect_target.should == "url1" }
      it_should_behave_like "successful checkout"
    end
  end

  context "initiated cancellation nogw transaction" do
    before do
      @sub = Factory(:subscription, :plan_key => 'free')
      @trans = Factory(:transaction, :gateway => "nogw", :status => "initiated", :action => "cancellation", :subscription => @sub)
    end
    should_have_nogw_initiated_status
    should_not_support_start_checkout
    context "complete" do
      before { @res = @trans.complete }
      it("should return true") { @res.should == true }
      it "should transition" do
        @trans.status.should == "complete"
        @trans.subscription.should be_canceled
      end
    end
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
        @redirect_target = @trans.start_checkout("url1", "url2")
      end
      it "should redirect to paypal" do
        @redirect_target.should == "https://www.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=bgds65sd"
        @trans.identifier.should == "bgds65sd"
      end
      context "ok" do
        before { mock_paypal_create_profile("bgds65sd") }
        it_should_behave_like "successful checkout"
      end
      context "error (paypal)" do
        before { mock_paypal_create_profile_with_error("bgds65sd") }
        it_should_behave_like "failed checkout"
      end
      context "error (http)" do
        before { stub_request(:post, "https://api-3t.paypal.com/nvp").to_return(:status => 500, :body => "Internal Server Error") }
        it_should_behave_like "failed checkout"
      end
    end
    context "without checkout" do
      it_should_behave_like "failed checkout"
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

  it "should calculate tax correctly" do
    trans = Factory(:transaction, :gateway => "paypal", :status => "initiated", :action => "activation", :identifier => "foo")
    trans.sub_plan.price_tax.should == 250
    mock_paypal_create_profile("foo", "AMT" => "5000.00", "TAXAMT" => "250.00")
    trans.complete
    trans.status.should == "complete"
  end

end
