class SubscriptionFu::Transaction < ActiveRecord::Base
  set_table_name :subscription_transactions

  belongs_to :subscription
  belongs_to :initiator, :polymorphic => true
  belongs_to :related_transaction, :class_name => "SubscriptionFu::Transaction"
  has_many :related_transactions, :class_name => "SubscriptionFu::Transaction", :foreign_key => "related_transaction_id"

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

  def self.create_cancellation(initiator, related_transaction)
    create!(:initiator => initiator, :gateway => 'nogw', :status => 'initiated', :action => "cancellation", :related_transaction => related_transaction)
  end

  def initiator_email
    initiator.email if initiator.respond_to?(:email)
  end

  # billing API

  def needs_authorization?
    gateway == "paypal" && action == "activation"
  end

  def start_checkout(return_url, cancel_url)
    raise "only call start_checkout when authorization is required " unless needs_authorization?
    raise "start_checkout already called once, have a token" unless identifier.blank?
    raise "start_checkout only available in initiated state, but: #{status}" unless status == "initiated"

    token = subscription.start_checkout(return_url, cancel_url, initiator_email)
    update_attributes!(:identifier => token)
    "#{SubscriptionFu.config.paypal_landing_url}?cmd=_express-checkout&token=#{CGI.escape(token)}"
  end

  def start_free_checkout
    update_attributes!(:identifier => Devise.friendly_token)
  end

  def complete!(opts = {})
    raise "complete only available in initiated state, but: #{status}" unless status == "initiated"

    success = true
    begin
      self.send("complete_#{action}_#{gateway}", opts)
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
      related_transactions.each { |t| t.abort! }
      success = false
    end
    success
  end

  def abort!
    raise "abort only available in initiated state, but: #{status}" unless status == "initiated"
    update_attributes(:status => "aborted")
    related_transactions.each { |t| t.abort! }
    true
  end

  private

  def complete_activation_paypal(opts)
    raise "did you call start_checkout first?" if identifier.blank?
    subscription.activate_with_paypal!(identifier)
    complete_activation
  end

  def complete_activation_nogw(opts)
    subscription.activate_without_billing!
    complete_activation
  end

  def complete_activation
    related_transactions.each do |t|
      t.complete!(:effective => subscription.starts_at, :reason => :update)
    end
  end

  def complete_cancellation_paypal(opts)
    complete_cancellation(opts)
  end

  def complete_cancellation_nogw(opts)
    complete_cancellation(opts)
  end

  def complete_cancellation(opts)
    unless subscription.canceled?
      subscription.cancel!(opts[:effective] || Time.now, opts[:reason] || :cancel)
    end
  end
end
