require "git"
require "fileutils"
require "aruba/rspec"
require_relative "../lib/git_cassette"

RSpec.describe GitCassette do
  include Aruba::Api

  around do |example|
    setup_aruba
    in_current_directory { example.run }
  end

  describe ".record" do
    let(:cassette_dir) { File.join(expand_path("."), "cassettes") }
    let(:repo_dir) { File.join(expand_path("."), "repos") }

    let(:cassette_path) { File.join(cassette_dir, "test-cassette.bundle") }
    let(:repo_path) { File.join(repo_dir, "test-cassette") }

    before do
      GitCassette.configure do |config|
        config.cassette_dir = cassette_dir
        config.repo_dir = repo_dir
      end
    end

    it "creates necessary directories" do
      expect { GitCassette.record("test-cassette") {} }
        .to change { directory?("cassettes") }.from(false).to(true)
        .and change { directory?("repos") }.from(false).to(true)
        .and change { directory?("repos/test-cassette") }.from(false).to(true)
    end

    it "records initial repository state" do
      expect do
        GitCassette.record("test-cassette") do
          write_file("test.txt", "initial content")
          g = Git.init(Dir.pwd)
          g.add("test.txt")
          g.commit("Initial commit")
        end
      end.to change { exist?("cassettes/test-cassette.bundle") }.from(false).to(true)
        .and change { directory?("repos/test-cassette") }.from(false).to(true)
    end

    it "records modified tracked files" do
      GitCassette.record("test-cassette") do
        write_file("test.txt", "initial content")
        g = Git.init(Dir.pwd)
        g.add("test.txt")
        g.commit("Initial commit")
        write_file("test.txt", "modified content")
      end
      g = Git.open(expand_path("repos/test-cassette"))
      expect(g.status.changed.keys).to include("test.txt")
    end

    it "records untracked files" do
      GitCassette.record("test-cassette") do
        write_file("test.txt", "initial content")
        g = Git.init(Dir.pwd)
        g.add("test.txt")
        g.commit("Initial commit")
        write_file("untracked.txt", "untracked content")
      end
      g = Git.open(expand_path("repos/test-cassette"))
      expect(g.status.untracked.keys).to include("untracked.txt")
    end

    it "records git history" do
      GitCassette.record("test-cassette") do
        write_file("test.txt", "initial content")
        g = Git.init(Dir.pwd)
        g.add("test.txt")
        g.commit("Initial commit")
        write_file("test.txt", "modified content")
        g.add("test.txt")
        g.commit("Second commit")
      end
      g = Git.open(expand_path("repos/test-cassette"))
      expect(g.log.count).to eq(2)
      expect(g.log.first.message).to eq("Second commit")
      expect(g.log.last.message).to eq("Initial commit")
    end
  end

  describe ".configure" do
    it "allows configuration of cassette and repo directories" do
      custom_cassette_dir = File.join(expand_path("."), "cassetes")
      custom_repo_dir = File.join(expand_path("."), "repositório")

      GitCassette.configure do |config|
        config.cassette_dir = custom_cassette_dir
        config.repo_dir = custom_repo_dir
      end

      expect { GitCassette.record("test-cassette") {} }
        .to change { directory?("cassetes") }.from(false).to(true)
        .and change { directory?("repositório") }.from(false).to(true)
        .and change { directory?("repositório/test-cassette") }.from(false).to(true)
    end
  end
end
