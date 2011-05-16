class CreateInitiators < ActiveRecord::Migration
  def self.up
    create_table :initiators do |t|
      t.string :desc
      t.string :email

      t.timestamps
    end
  end

  def self.down
    drop_table :initiators
  end
end
