# Updating Subscriptions for Rails

## From 0.2.x to 0.3.0

Add the new table subscription_system_initiators using a migration:

    class SubscriptionFuUpdateToZeroThree < ActiveRecord::Migration
      def self.up
        create_table "subscription_system_initiators" do |t|
          t.string "name"
          t.string "description"
        end
      end
      def self.down
        drop_table "subscription_system_initiators"
      end
    end


