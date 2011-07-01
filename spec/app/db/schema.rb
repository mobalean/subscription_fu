# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110701061927) do

  create_table "initiators", :force => true do |t|
    t.string   "desc"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "subjects", :force => true do |t|
    t.string   "desc"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "subscription_system_initiators", :force => true do |t|
    t.string "name"
    t.string "description"
  end

  create_table "subscription_transactions", :force => true do |t|
    t.integer  "subscription_id",                      :null => false
    t.integer  "initiator_id",                         :null => false
    t.string   "initiator_type",                       :null => false
    t.string   "action",                 :limit => 15, :null => false
    t.string   "status",                 :limit => 15, :null => false
    t.string   "gateway",                :limit => 10, :null => false
    t.string   "identifier"
    t.integer  "related_transaction_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "subscription_transactions", ["identifier"], :name => "index_subscription_transactions_on_identifier"
  add_index "subscription_transactions", ["subscription_id"], :name => "index_subscription_transactions_on_subscription_id"

  create_table "subscriptions", :force => true do |t|
    t.integer  "subject_id"
    t.string   "subject_type"
    t.integer  "prev_subscription_id"
    t.string   "plan_key",             :limit => 10,                    :null => false
    t.boolean  "sponsored",                          :default => false, :null => false
    t.string   "paypal_profile_id"
    t.datetime "starts_at",                                             :null => false
    t.datetime "billing_starts_at",                                     :null => false
    t.datetime "activated_at"
    t.datetime "canceled_at"
    t.string   "cancel_reason",        :limit => 10
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "subscriptions", ["subject_id", "subject_type"], :name => "index_subscriptions_on_subject_id_and_subject_type"

end
