module PaypalTestHelper

  class RequestParamMatcher
    def initialize(opts = {})
      @opts = opts
    end
    def =~(request)
      parsed_req = CGI.parse(request.body)
      @opts.all? {|key,value| parsed_req[key].first == value }
    end
  end

  class PaypalRequestMatcher < RequestParamMatcher
    def initialize(method, opts = {})
      super(opts.merge("METHOD" => method))
    end
  end

  def mock_paypal_ipn_validation_ok
    stub_request(:post, "https://www.paypal.com/cgi-bin/webscr").
      to_return(:status => 200, :body => "VERIFIED", :headers => {}).
      with{|request| RequestParamMatcher.new("cmd" => "_notify-validate") =~ request }
  end

  def mock_paypal_ipn_validation_invalid
    stub_request(:post, "https://www.paypal.com/cgi-bin/webscr").
      to_return(:status => 200, :body => "INVALID", :headers => {}).
      with{|request| RequestParamMatcher.new("cmd" => "_notify-validate") =~ request }
  end

  def mock_paypal_express_checkout(token = "token123")
    stub_request(:post, "https://api-3t.paypal.com/nvp").
      to_return(:status => 200, :body => "ACK=Success&TOKEN=#{token}", :headers => {}).
      with{|request| PaypalRequestMatcher.new("SetExpressCheckout") =~ request }
  end

  def mock_paypal_profile_details(profile, status, last_billing, next_billing)
    res_details = paypal_profile_res(profile, status, "NEXTBILLINGDATE"=>next_billing, 'LASTPAYMENTDATE'=>last_billing)
    stub_request(:post, "https://api-3t.paypal.com/nvp").
      to_return(:status => 200, :body => res_details, :headers => {}).
      with{|request| PaypalRequestMatcher.new("GetRecurringPaymentsProfileDetails", "PROFILEID" => profile) =~ request }
  end

  def mock_paypal_create_profile(token, new_profile_id = "49vnq320dsj", status = "ActiveProfile")
    stub_request(:post, "https://api-3t.paypal.com/nvp").
      to_return(:status => 200, :body => paypal_profile_res(new_profile_id, status), :headers => {}).
      with{|request| PaypalRequestMatcher.new("CreateRecurringPaymentsProfile", "TOKEN" => token) =~ request }
  end

  def mock_paypal_create_profile_with_error(token)
    stub_request(:post, "https://api-3t.paypal.com/nvp").
      to_return(:status => 200, :body => paypal_error_res, :headers => {}).
      with{|request| PaypalRequestMatcher.new("CreateRecurringPaymentsProfile", "TOKEN" => token) =~ request }
  end

  def mock_paypal_delete_profile(profile_id)
    stub_request(:post, "https://api-3t.paypal.com/nvp").
      to_return(:status => 200, :body => paypal_res("PROFILEID"=>"Cancel"), :headers => {}).
      with{|request| PaypalRequestMatcher.new("ManageRecurringPaymentsProfileStatus", "ACTION"=>"Cancel", "PROFILEID"=>profile_id) =~ request }
  end

  def mock_paypal_delete_profile_with_error(profile_id)
    stub_request(:post, "https://api-3t.paypal.com/nvp").
      to_return(:status => 200, :body => paypal_error_res, :headers => {}).
      with{|request| PaypalRequestMatcher.new("ManageRecurringPaymentsProfileStatus", "ACTION"=>"Cancel", "PROFILEID"=>profile_id) =~ request }
  end

  def paypal_res(opts = {})
    opts.reverse_merge("ACK"=>"Success").reject{|k,v| v.nil? }.map{|k,v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join('&')
  end

  def paypal_error_res(opts = {})
    paypal_res(opts.merge("ACK"=>"Failure", "L_SEVERITYCODE0"=>"Error", "L_ERRORCODE0"=>"11556"))
  end

  def paypal_profile_res(profile, status, opts = {})
    paypal_res(opts.merge("PROFILEID"=>profile,"STATUS"=>status))
  end

end

RSpec.configuration.include PaypalTestHelper
