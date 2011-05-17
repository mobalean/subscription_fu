module SubscriptionFu
  module Models
    def self.included(base)
      base.send(:extend, ClassMethods)
    end

    module ClassMethods
      def needs_subscription
        send(:include, InstanceMethods)
        has_many :subscriptions, :class_name => "SubscriptionFu::Subscription", :as => :subject, :dependent => :destroy
        delegate :plan, :sponsored?, :canceled?, :prefix => :subscription, :to => :active_subscription, :allow_nil => true
        delegate :plan, :prefix => :upcoming_subscription, :to => :upcoming_subscription, :allow_nil => true
      end
    end

    module InstanceMethods
      def human_description_for_subscription
        self.class.model_name.human
      end

      def active_subscription
        @active_subscription ||= subscriptions.current(Time.now).last
      end

      def active_subscription?
        !@active_subscription.nil?
      end

      def upcoming_subscription
        active_subscription ? active_subscription.next_subscriptions.activated.last : nil
      end

      def build_next_subscription(plan_key)
        if active_subscription
          # TODO refactor
          subscriptions.build_for_initializing(plan_key, active_subscription.successor_start_date(plan_key), active_subscription.successor_billing_start_date, active_subscription)
        else
          subscriptions.build_for_initializing(plan_key)
        end
      end
    end

  end
end
