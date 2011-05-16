class CreateSubscriptionFuTables < ActiveRecord::Migration
  def self.up
    create_table "subscriptions", :force => true do |t|
      t.references "subject",          :polymorphic => true
      t.references "prev_subscription"
      t.string     "plan_key",         :limit => 10, :null => false
      t.boolean    "sponsored",                      :null => false, :default => false
      t.string     "paypal_profile_id"
      t.datetime   "starts_at",                      :null => false
      t.datetime   "billing_starts_at",              :null => false
      t.datetime   "activated_at"
      t.datetime   "canceled_at"
      t.string     "cancel_reason",     :limit => 10
      t.timestamps
    end

    add_index "subscriptions", ["subject_id", "subject_type"]

    create_table "subscription_transactions" do |t|
      t.references "subscription",                 :null => false
      t.references "initiator",                    :null => false, :polymorphic => true
      t.string     "action",         :limit => 15, :null => false
      t.string     "status",         :limit => 15, :null => false
      t.string     "gateway",        :limit => 10, :null => false
      t.string     "identifier"
      t.references "related_transaction"
      t.timestamps
    end

    add_index "subscription_transactions", ["identifier"]
    add_index "subscription_transactions", ["subscription_id"]
  end

  def self.down
    drop_table "subscriptions"
    drop_table "subscription_transactions"
  end
end
