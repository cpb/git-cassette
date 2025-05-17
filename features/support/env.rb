$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
require 'aruba/cucumber'
require 'rspec/expectations'

Aruba.configure do |config|
  config.command_launcher = :in_process
end 