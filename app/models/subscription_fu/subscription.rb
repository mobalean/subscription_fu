class SubscriptionFu::Subscription < ActiveRecord::Base
  set_table_name :subscriptions

  AVAILABLE_CANCEL_REASONS = %w( update cancel timeout admin )

  default_scope order("created_at ASC", "id ASC")

  belongs_to :subject, :polymorphic => true
  belongs_to :prev_subscription, :class_name => "SubscriptionFu::Subscription"
  has_many :transactions, :class_name => "SubscriptionFu::Transaction"
  has_many :next_subscriptions, :class_name => "SubscriptionFu::Subscription", :foreign_key => "prev_subscription_id"

  validates :subject, :presence => true
  validates :plan_key, :presence => true, :inclusion => SubscriptionFu.config.available_plans.keys, :on => :create
  validates :starts_at, :presence => true
  validates :billing_starts_at, :presence => true
  validates :paypal_profile_id, :presence => true, :if => :activated_paid_subscription?
  validates :cancel_reason, :presence => true, :inclusion => AVAILABLE_CANCEL_REASONS, :if => :canceled?

  scope :activated, where("subscriptions.activated_at IS NOT NULL")
  scope :current, lambda {|time| activated.where("subscriptions.starts_at <= ? AND (subscriptions.canceled_at IS NULL OR subscriptions.canceled_at > ?)", time, time) }

  # TODO this should probably only take plan?key, prev_sub
  def self.build_for_initializing(plan_key, start_time = Time.now, billing_start_time = start_time, prev_sub = nil)
    new(:plan_key => plan_key, :starts_at => start_time, :billing_starts_at => billing_start_time, :prev_subscription => prev_sub)
  end

  def paid_subscription?
    ! plan.free_plan? && ! sponsored?
  end

  def activated?
    ! activated_at.blank?
  end

  def activated_paid_subscription?
    activated? && paid_subscription?
  end

  def canceled?
    ! canceled_at.blank?
  end

  def plan
    SubscriptionFu.config.available_plans[self.plan_key]
  end

  def human_description
    I18n.t(:description, :scope => [:subscription_fu, :subscription]) % {
      :plan_name => plan.human_name,
      :subject_desc => subject.human_description_for_subscription,
      :price => plan.human_price }
  end

  # billing time data about the subscription

  def next_billing_date
    paypal_recurring_details[:next_billing_date]
  end

  def estimated_next_billing_date
    p = last_billing_date
    p.next_month unless p.nil?
  end

  def last_billing_date
    paypal_recurring_details[:last_payment_date]
  end

  def successor_start_date(new_plan_name)
    new_plan = SubscriptionFu.config.available_plans[new_plan_name]
    if new_plan > self.plan
      # higher plans always start immediately
      Time.now
    else
      # otherwise they start with the next billing cycle
      successor_billing_start_date
    end
  end

  def successor_billing_start_date
    # in case this plan was already canceled, this date takes
    # precedence (there won't be a next billing time anymore).
    canceled_at || next_billing_date || estimated_next_billing_date || Time.now
  end

  # billing API

  def initiate_activation(admin)
    gateway = (plan.free_plan? || sponsored?) ? 'nogw' : 'paypal'
    transactions.create_activation(gateway, admin).tap do |t|
      if prev_subscription
        to_cancel = [prev_subscription]
        to_cancel.push(*prev_subscription.next_subscriptions.where("subscriptions.id <> ?", self).all)
        to_cancel.each {|s| s.initiate_cancellation(admin, t) }
      end
    end
  end

  def initiate_cancellation(admin, activation_transaction)
    transactions.create_cancellation(admin, activation_transaction, self)
  end

  private

  def paypal_recurring_details
    @paypal_recurring_details ||= (paypal_profile_id.blank? ? {} : SubscriptionFu::Paypal.paypal.recurring_details(paypal_profile_id))
  end

  def convert_paypal_status(paypal_status)
    case paypal_status
    when "ActiveProfile"  then "complete"
    when "PendingProfile" then "pending"
    else "invalid"
    end
  end
end
