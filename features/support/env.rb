$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
require 'aruba/cucumber'
require 'rspec/expectations'

Aruba.configure do |config|
  config.command_launcher = :spawn
end

Before do
  src = File.expand_path('../../../lib', __FILE__)
  dest = File.join(expand_path('.'), 'lib')
  FileUtils.rm_rf(dest)
  FileUtils.cp_r(src, dest)
end