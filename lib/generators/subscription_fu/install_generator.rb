require "rails/generators/active_record/migration"

module SubscriptionFu
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      extend ActiveRecord::Generators::Migration

      source_root File.expand_path("../templates", __FILE__)
      desc "Generates the migrations require for subscription_fu"

      def create_migration_file
        migration_template 'migration.rb', 'db/migrate/create_subscription_fu_tables.rb'
      end
      def copy_initializer
        template 'initializer.rb', 'config/initializers/subscription_fu.rb'
      end
    end
  end
end
