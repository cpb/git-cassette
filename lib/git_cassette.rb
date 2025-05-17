require "ostruct"

module GitCassette
  def self.record(name, &block)
    block.call
  end

  def self.configure
    yield(OpenStruct.new)
  end
end

