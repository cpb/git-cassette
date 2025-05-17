require 'aruba/cucumber'
require 'rspec/expectations'

Aruba.configure do |config|
  config.command_launcher = :in_process
  config.main_class = GitCassette::CLI
end 