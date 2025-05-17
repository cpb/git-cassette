require "git"
require "fileutils"
require "aruba/rspec"
require_relative "../lib/git_cassette"

RSpec.describe GitCassette do
  include Aruba::Api

  before(:each) do
    setup_aruba
    @cassette_dir = File.join(expand_path("."), "cassettes")
    @repo_dir = File.join(expand_path("."), "repos")
    @test_repo_path = File.join(@repo_dir, "test-cassette")
    @cassette_path = File.join(@cassette_dir, "test-cassette.bundle")
    GitCassette.configure do |config|
      config.cassette_dir = @cassette_dir
      config.repo_dir = @repo_dir
    end
    FileUtils.rm_rf([@cassette_dir, @repo_dir])
  end

  after(:each) do
    FileUtils.rm_rf([@cassette_dir, @repo_dir])
  end

  describe ".record" do
    it "creates necessary directories" do
      in_current_directory do
        GitCassette.record("test-cassette") {}
        expect(directory?("cassettes")).to be true
        expect(directory?("repos")).to be true
        expect(directory?("repos/test-cassette")).to be true
      end
    end

    it "records initial repository state" do
      in_current_directory do
        GitCassette.record("test-cassette") do
          File.write("test.txt", "initial content")
          g = Git.init(Dir.pwd)
          g.add("test.txt")
          g.commit("Initial commit")
        end
        expect(exist?("cassettes/test-cassette.bundle")).to be true
        expect(directory?("repos/test-cassette")).to be true
      end
    end

    it "records modified tracked files" do
      in_current_directory do
        GitCassette.record("test-cassette") do
          File.write("test.txt", "initial content")
          g = Git.init(Dir.pwd)
          g.add("test.txt")
          g.commit("Initial commit")
          File.write("test.txt", "modified content")
        end
        g = Git.open(expand_path("repos/test-cassette"))
        expect(g.status.changed.keys).to include("test.txt")
      end
    end

    it "records untracked files" do
      in_current_directory do
        GitCassette.record("test-cassette") do
          File.write("test.txt", "initial content")
          g = Git.init(Dir.pwd)
          g.add("test.txt")
          g.commit("Initial commit")
          File.write("untracked.txt", "untracked content")
        end
        g = Git.open(expand_path("repos/test-cassette"))
        expect(g.status.untracked.keys).to include("untracked.txt")
      end
    end

    it "records git history" do
      in_current_directory do
        GitCassette.record("test-cassette") do
          File.write("test.txt", "initial content")
          g = Git.init(Dir.pwd)
          g.add("test.txt")
          g.commit("Initial commit")
          File.write("test.txt", "modified content")
          g.add("test.txt")
          g.commit("Second commit")
        end
        g = Git.open(expand_path("repos/test-cassette"))
        expect(g.log.count).to eq(2)
        expect(g.log.first.message).to eq("Second commit")
        expect(g.log.last.message).to eq("Initial commit")
      end
    end
  end

  describe ".configure" do
    it "allows configuration of cassette and repo directories" do
      in_current_directory do
        custom_cassette_dir = File.join(expand_path("."), "custom_cassettes")
        custom_repo_dir = File.join(expand_path("."), "custom_repos")
        GitCassette.configure do |config|
          config.cassette_dir = custom_cassette_dir
          config.repo_dir = custom_repo_dir
        end
        GitCassette.record("test-cassette") {}
        expect(directory?("custom_cassettes")).to be true
        expect(directory?("custom_repos")).to be true
      end
    end
  end
end

