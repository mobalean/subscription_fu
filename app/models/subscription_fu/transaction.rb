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
        data = (err.respond_to?(:data) ? err.data : {}).merge(:subscription => subscription.inspect, :transaction => self.inspect)
        ::ExceptionNotifier::Notifier.background_exception_notification(err, :data => data).deliver
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
    token = SubscriptionFu::Paypal.paypal.start_checkout(return_url, cancel_url, initiator_email, sub_plan.price_with_tax, sub_plan.currency, sub_human_description)
    update_attributes!(:identifier => token)
    "#{SubscriptionFu.config.paypal_landing_url}?cmd=_express-checkout&token=#{CGI.escape(token)}"
  end

  def start_checkout_nogw(return_url, cancel_url)
    update_attributes!(:identifier => SubscriptionFu.friendly_token)
    return_url
  end

  def complete_activation_paypal(opts)
    raise "did you call start_checkout first?" if identifier.blank?
    raise "already activated" if sub_activated?

    paypal_profile_id, paypal_status =
      SubscriptionFu::Paypal.paypal.create_recurring(identifier, sub_billing_starts_at, sub_plan.price, sub_plan.price_tax, sub_plan.currency, sub_human_description)
    subscription.update_attributes!(:paypal_profile_id => paypal_profile_id, :activated_at => Time.now)
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
    # update the record beforehand, because paypal raises an error if
    # the profile is already cancelled
    complete_cancellation(opts)
    SubscriptionFu::Paypal.paypal.cancel_recurring(sub_paypal_profile_id, sub_cancel_reason)
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
