module SubscriptionFu
  module Models
    def self.included(base)
      base.send(:extend, ClassMethods)
    end

    module ClassMethods
      def needs_subscription
        send(:include, InstanceMethods)
        has_many :subscriptions, :class_name => "SubscriptionFu::Subscription", :as => :subject, :dependent => :destroy
        delegate :plan, :sponsored?, :canceled?, :prefix => :subscription, :to => :current_subscription, :allow_nil => true
        delegate :plan, :prefix => :upcoming_subscription, :to => :upcoming_subscription, :allow_nil => true
      end
    end

    module InstanceMethods
      def human_description_for_subscription
        self.class.model_name.human
      end

      def current_subscription
        @current_subscription ||= subscriptions.current(Time.now).last
      end

      def upcoming_subscription
        current_subscription ? current_subscription.next_subscriptions.activated.last : nil
      end

      def build_next_subscription(plan_key)
        if current_subscription
          # TODO refactor
          subscriptions.build_for_initializing(plan_key, current_subscription.successor_start_date(plan_key), current_subscription.successor_billing_start_date, current_subscription)
        else
          subscriptions.build_for_initializing(plan_key)
        end
      end
    end

  end
end
