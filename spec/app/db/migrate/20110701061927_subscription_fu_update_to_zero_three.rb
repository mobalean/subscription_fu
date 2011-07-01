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
