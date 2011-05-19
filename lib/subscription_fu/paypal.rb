require "rest-client"

class SubscriptionFu::Paypal

  def self.paypal
    new(SubscriptionFu.config.paypal_api_user_id,
        SubscriptionFu.config.paypal_api_pwd,
        SubscriptionFu.config.paypal_api_sig,
        SubscriptionFu.config.paypal_nvp_api_url,
        Rails.logger)
  end

  class Failure < RuntimeError
    attr_reader :request_opts, :response

    def initialize(request_opts, response)
      @request_opts = request_opts
      @response = response
      super "PayPal did not return success: #{@response.inspect}"
    end
    alias :data :request_opts
  end

  def initialize(user, pwd, sig, api_url, logger)
    @user = user
    @pwd = pwd
    @sig = sig
    @api_url = api_url
    @logger = logger
  end

  def start_checkout(return_url, cancel_url, email, maxamt, currency_code, desc)
    res = call_paypal('SetExpressCheckout',
                      'RETURNURL' => return_url,
                      'CANCELURL' => cancel_url,
                      'EMAIL' => email,
                      'NOSHIPPING' => 1,
                      'MAXAMT' => maxamt,
                      'PAYMENTREQUEST_0_AMT' => 0,
                      'PAYMENTREQUEST_0_CURRENCYCODE' => currency_code,
                      'L_BILLINGTYPE0' => 'RecurringPayments',
                      'L_BILLINGAGREEMENTDESCRIPTION0' => desc)
    res['TOKEN'].first
  end

  def create_recurring(token, start_date, amt, taxamt, currency_code, desc)
    res = call_paypal('CreateRecurringPaymentsProfile',
                      'PROFILESTARTDATE' => start_date.utc.iso8601,
                      'BILLINGPERIOD' => 'Month',
                      'BILLINGFREQUENCY' => 1,
                      'MAXFAILEDPAYMENTS' => 0,
                      'AUTOBILLOUTAMT' => 'AddToNextBilling',
                      'AMT' => amt,
                      'TAXAMT' => taxamt,
                      'CURRENCYCODE' => currency_code,
                      'DESC' => desc,
                      'TOKEN' => token)
    [res['PROFILEID'].first, res['PROFILESTATUS'].first || res['STATUS'].first]
  end

  def recurring_details(profile_id)
    utc = ActiveSupport::TimeZone.new("UTC")
    res = call_paypal('GetRecurringPaymentsProfileDetails', 'PROFILEID' => profile_id)
    { :id => res['PROFILEID'].first,
      :status => res['PROFILESTATUS'].first || res['STATUS'].first,
      :next_billing_date => utc.parse(res['NEXTBILLINGDATE'].first.to_s),
      :start_date => utc.parse(res['PROFILESTARTDATE'].first.to_s),
      :cycles_completed => res['NUMCYCLESCOMPLETED'].first.to_i,
      :outstanding_balance => res['OUTSTANDINGBALANCE'].first.to_f,
      :last_payment_date => utc.parse(res['LASTPAYMENTDATE'].first.to_s) }
  end

  def cancel_recurring(profile_id, reason)
    call_paypal('ManageRecurringPaymentsProfileStatus',
                'PROFILEID' => profile_id,
                'ACTION' => 'Cancel',
                'NOTE' => I18n.t(reason, :scope => [:subscription_fu, :subscription, :cancel_notes]))
  end

  private

  def call_paypal(method, opts)
    full_opts = paypal_api_opts(method, opts)
    CGI.parse(RestClient.post(@api_url, full_opts)).tap do |result|
      if result['ACK'].first != 'Success'
        @logger.warn("PayPal did not return success for call to #{method}")
        @logger.info("  called with: #{full_opts.inspect}")
        @logger.info("  result: #{result.inspect}")
        raise Failure.new(full_opts, result)
      else
        @logger.info("PayPal returned success for call to #{method}")
        @logger.info("  result: #{result.inspect}")
      end
    end
  end

  def paypal_api_opts(method, opts)
    opts.merge('USER' => @user, 'PWD' => @pwd, 'SIGNATURE' => @sig, 'VERSION' => '65.0', 'METHOD' => method)
  end

end
