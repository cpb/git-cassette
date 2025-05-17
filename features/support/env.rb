$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
require 'aruba/cucumber'
require 'rspec/expectations'
require 'git_cassette'

Aruba.configure do |config|
  config.command_launcher = :in_process
  config.main_class = GitCassette::CLI
end 