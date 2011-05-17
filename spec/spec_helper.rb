LIB_DIR = File.expand_path('../../', __FILE__) 
$:.unshift File.join(LIB_DIR, 'lib')

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path(File.dirname(__FILE__) + "/app/config/environment")
require 'rspec/rails'
require 'shoulda-matchers'
require 'factory_girl'
require 'time_travel'
require 'webmock/rspec'

load Rails.root.join('db', 'schema.rb')

Factory.definition_file_paths = [ File.join(LIB_DIR, 'spec', 'factories') ]
Factory.find_definitions

Dir[File.join(LIB_DIR, 'spec', 'support', '**', '*.rb')].each {|f| require f}

