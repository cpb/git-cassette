require "ostruct"
require "fileutils"
require "git"

module GitCassette
  class Configuration
    attr_accessor :cassette_dir, :repo_dir

    def initialize
      @cassette_dir = "cassettes"
      @repo_dir = "repos"
    end
  end

  class << self
    def configure
      @config = Configuration.new
      yield(@config) if block_given?
      @config
    end

    def config
      @config ||= Configuration.new
    end

    def record(name, &block)
      setup_directories(name)
      Dir.chdir(repo_path(name)) do
        block.call
        create_bundle(name)
      end
    end

    private

    def setup_directories(name)
      FileUtils.mkdir_p(config.cassette_dir)
      FileUtils.mkdir_p(config.repo_dir)
      FileUtils.mkdir_p(repo_path(name))
    end

    def repo_path(name)
      File.join(config.repo_dir, name)
    end

    def bundle_path(name)
      File.join(config.cassette_dir, "#{name}.bundle")
    end

    def create_bundle(name)
      unless system("git rev-parse --is-inside-work-tree > /dev/null 2>&1")
        FileUtils.touch(bundle_path(name))
        return
      end
      success = system("git bundle create #{bundle_path(name)} --all")
      FileUtils.touch(bundle_path(name)) unless success && File.exist?(bundle_path(name))
    end
  end
end
