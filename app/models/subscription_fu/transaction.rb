class SubscriptionFu::Transaction < ActiveRecord::Base
  set_table_name :subscription_transactions

  belongs_to :subscription
  belongs_to :initiator, :polymorphic => true
  belongs_to :related_transaction, :class_name => "SubscriptionFu::Transaction"
  has_many :related_transactions, :class_name => "SubscriptionFu::Transaction", :foreign_key => "related_transaction_id"

  delegate :plan, :human_description, :starts_at, :billing_starts_at, :paypal_profile_id, :activated?, :canceled?, :cancel_reason, :to => :subscription, :prefix => :sub

  validates :subscription, :presence => true
  validates :initiator, :presence => true
  validates :gateway, :presence => true, :inclusion => %w( paypal nogw )
  validates :action, :presence => true, :inclusion => %w( activation cancellation )
  validates :status, :presence => true, :inclusion => %w( initiated complete failed aborted )

  scope :paypal, where(:gateway => "paypal")
  scope :initiated, where(:status => "initiated")

  def self.create_activation(gateway, initiator)
    create!(:initiator => initiator, :gateway => gateway, :status => 'initiated', :action => "activation")
  end

  def self.create_cancellation(initiator, related_transaction, subscription)
    gateway = subscription.paypal_profile_id.blank? ? 'nogw' : 'paypal'
    create!(:initiator => initiator, :gateway => gateway, :status => 'initiated', :action => "cancellation", :related_transaction => related_transaction)
  end

  def initiator_email
    initiator.email if initiator.respond_to?(:email)
  end

  # billing API

  def needs_authorization?
    gateway == "paypal" && action == "activation"
  end

  def start_checkout(return_url, cancel_url)
    raise "start_checkout is only for activation" unless action == "activation"
    raise "start_checkout is only for non-activated subscriptions" if sub_activated?
    raise "start_checkout already called once, have a token" unless identifier.blank?
    raise "start_checkout only available in initiated state, but: #{status}" unless status == "initiated"

    send("start_checkout_#{gateway}", return_url, cancel_url)
  end

  def complete(opts = {})
    raise "complete only available in initiated state, but: #{status}" unless status == "initiated"

    success = true
    begin
      send("complete_#{action}_#{gateway}", opts)
      update_attributes!(:status => "complete")
    rescue Exception => err
      if defined? ::ExceptionNotifier
        data = {:api_response => err.respond_to?(:response) ? err.response : nil, :subscription => subscription.inspect, :transaction => self.inspect}
        ::ExceptionNotifier::Notifier.background_exception_notification(err, :data => data).deliver
      elsif defined? ::HoptoadNotifier
        data = {:subscription => subscription.inspect, :transaction => self.inspect}
        ::HoptoadNotifier.notify(err, :parameters => data)
      else
        logger.warn(err)
        logger.debug(err.backtrace.join("\n"))
      end
      update_attributes!(:status => "failed")
      related_transactions.each { |t| t.abort }
      success = false
    end
    success
  end

  def abort
    raise "abort only available in initiated state, but: #{status}" unless status == "initiated"
    update_attributes(:status => "aborted")
    related_transactions.each { |t| t.abort }
    true
  end

  private

  def start_checkout_paypal(return_url, cancel_url)
    # TODO: set initiator_email
    pay_req = Paypal::Payment::Request.new(
      :currency_code => sub_plan.currency,
      :billing_type  => :RecurringPayments,
      :billing_agreement_description => sub_human_description)

    response = SubscriptionFu::Paypal.express_request.setup(pay_req, return_url, cancel_url, :no_shipping => true)
    update_attributes!(:identifier => response.token)
    response.redirect_uri
  end

  def start_checkout_nogw(return_url, cancel_url)
    update_attributes!(:identifier => SubscriptionFu.friendly_token)
    return_url
  end

  def complete_activation_paypal(opts)
    raise "did you call start_checkout first?" if identifier.blank?
    raise "already activated" if sub_activated?

    profile = Paypal::Payment::Recurring.new(
      :start_date => sub_billing_starts_at,
      :description => sub_human_description,
      :billing => {
        :period        => :Month,
        :frequency     => 1,
        :amount        => sub_plan.price,
        :tax_amount    => sub_plan.price_tax,
        :currency_code => sub_plan.currency } )
    response = SubscriptionFu::Paypal.express_request.subscribe!(identifier, profile)
    subscription.update_attributes!(:paypal_profile_id => response.recurring.identifier, :activated_at => Time.now)
    complete_activation
  end

  def complete_activation_nogw(opts)
    raise "already activated" if sub_activated?

    subscription.update_attributes!(:activated_at => Time.now)
    complete_activation
  end

  def complete_activation
    related_transactions.each do |t|
      t.complete(:effective => sub_starts_at, :reason => :update)
    end
  end

  def complete_cancellation_paypal(opts)
    begin
      SubscriptionFu::Paypal.express_request.renew!(sub_paypal_profile_id, :Cancel, :note => sub_cancel_reason)
    rescue Paypal::Exception::APIError => err
      if err.response.details.all?{|d| d.error_code == "11556"}
        # 11556 - Invalid profile status for cancel action; profile should be active or suspended
        logger.info("Got '#{err.response.details.inspect}' from paypal which indicates profile wasn't active (any more)...")
      else
        raise err
      end
    end
    complete_cancellation(opts)
  end

  def complete_cancellation_nogw(opts)
    complete_cancellation(opts)
  end

  def complete_cancellation(opts)
    unless sub_canceled?
      cancel_timestamp = opts[:effective] || Time.now
      cancel_reason = opts[:reason] || :cancel
      subscription.update_attributes!(:canceled_at => cancel_timestamp, :cancel_reason => cancel_reason.to_s)
    end
  end
end
