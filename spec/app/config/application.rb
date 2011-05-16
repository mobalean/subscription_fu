require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"
require "active_record/railtie"
require "rails/test_unit/railtie"
require 'subscription_fu/railtie'
require 'subscription_fu/engine'

module RailsApp
  class Application < Rails::Application
  end
end
