require "ostruct"
require "fileutils"

module GitCassette
  def self.record(name, &block)
    FileUtils.mkdir_p('cassettes')
    FileUtils.mkdir_p('repos')
    FileUtils.touch("cassettes/#{name}.bundle")
    FileUtils.mkdir_p("repos/#{name}")
    block.call
  end

  def self.configure
    yield(OpenStruct.new)
  end
end
