require "benchmark/ips"
require "fileutils"
require "git"
require "tempfile"

class FixtureBenchmark
  TEST_DIR = File.join(Dir.tmpdir, "git_cassette_benchmark")
  FIXTURE_DIR = File.join(TEST_DIR, "fixtures")
  BUNDLE_DIR = File.join(TEST_DIR, "bundles")

  def self.setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p([FIXTURE_DIR, BUNDLE_DIR])
  end

  def self.teardown
    FileUtils.rm_rf(TEST_DIR)
  end

  def self.create_test_repo(path)
    FileUtils.mkdir_p(path)
    system("git init #{path}")

    Dir.chdir(path) do
      # Create initial commit
      File.write("README.md", "# Test Repository")
      system("git add README.md")
      system("git commit -m 'Initial commit'")

      # Create feature branch
      system("git checkout -b feature")
      File.write("feature.txt", "Feature content")
      system("git add feature.txt")
      system("git commit -m 'Add feature'")

      # Create tag
      system("git tag v1.0")

      # Return to main
      system("git checkout -b main")
    end

    Git.open(path)
  end

  def self.create_dirty_worktree(repo)
    Dir.chdir(repo.dir.path) do
      # Modify tracked file
      File.write("README.md", "# Modified Test Repository")

      # Add untracked file
      File.write("untracked.txt", "This is untracked")
    end
  end

  def self.create_commit_with_worktree_and_untracked(repo)
    Dir.chdir(repo.dir.path) do
      # First commit: Store the working tree state
      system("git add README.md")
      tree_commit_msg = [
        "git-cassette: working-tree-state",
        "tree: #{`git write-tree`.strip}"
      ].join("\n")
      system("git commit -m \"#{tree_commit_msg}\"")

      # Second commit: Store untracked files
      untracked_files = `git ls-files --others --exclude-standard`.split("\n")
      untracked_files.each do |file|
        system("git add -f #{file}")  # Force add untracked files
      end
      untracked_commit_msg = [
        "git-cassette: untracked-files",
        "files: #{untracked_files.join(",")}"
      ].join("\n")
      system("git commit -m \"#{untracked_commit_msg}\"")
    end
  end

  def self.restore_commit_with_worktree_and_untracked(bundle_path, dest_path)
    FileUtils.rm_rf(dest_path)
    system("git clone #{bundle_path} #{dest_path}")
    Dir.chdir(dest_path) do
      # Find the untracked files commit
      untracked_commit = `git log --grep='git-cassette: untracked-files' --format=%H -n 1`.strip
      untracked_msg = `git log -1 --format=%B #{untracked_commit}`
      untracked_files = (untracked_msg[/files: (.+)/, 1] || "").split(",")

      # Find the working tree state commit
      tree_commit = `git log --grep='git-cassette: working-tree-state' --format=%H -n 1`.strip

      if tree_commit.empty?
        # Clean repository - no need to restore working tree state
        system("git reset --hard HEAD")
      else
        # First reset to the working tree state
        system("git reset --hard #{tree_commit}")

        # Then restore untracked files from the untracked commit
        untracked_files.each do |file|
          # Get the content from the commit
          content = `git show #{untracked_commit}:#{file}`
          # Write the content directly to the file
          File.write(file, content)
        end

        # Clean up the history by resetting to the parent of the working-tree-state commit
        parent_commit = `git rev-parse #{tree_commit}^`.strip
        system("git reset --hard #{parent_commit}")
      end
    end
    Git.open(dest_path)
  end

  def self.prepare_fixtures
    # 1. Create a single clean repo
    source_path = File.join(TEST_DIR, "source_repo")
    repo = create_test_repo(source_path)

    # 2. Copy for clean fixture
    FileUtils.cp_r(source_path, File.join(FIXTURE_DIR, "clean_repo"))

    # 3. Create clean bundle
    clean_bundle_path = File.join(BUNDLE_DIR, "commitmsg_clean.bundle")
    system("git -C #{source_path} bundle create #{clean_bundle_path} --all")

    # 4. Make the repo dirty
    create_dirty_worktree(repo)

    # 5. Copy for dirty fixture
    FileUtils.cp_r(source_path, File.join(FIXTURE_DIR, "dirty_repo"))

    # 6. Add special commits for dirty bundle
    create_commit_with_worktree_and_untracked(repo)

    # 7. Create dirty bundle
    dirty_bundle_path = File.join(BUNDLE_DIR, "commitmsg_dirty.bundle")
    system("git -C #{source_path} bundle create #{dirty_bundle_path} --all")
  end

  def self.benchmark_strategies
    Benchmark.ips do |x|
      x.config(time: 5, warmup: 2)

      # 1. Pure Scripts
      x.report("Pure Scripts - Clean") do
        path = File.join(TEST_DIR, "pure_scripts_clean")
        FileUtils.rm_rf(path)
        create_test_repo(path)
        repo = Git.open(path)
        assert_expected_state(repo, dirty: false)
      end

      x.report("Pure Scripts - Dirty") do
        path = File.join(TEST_DIR, "pure_scripts_dirty")
        FileUtils.rm_rf(path)
        repo = create_test_repo(path)
        create_dirty_worktree(repo)
        assert_expected_state(repo, dirty: true)
      end

      # 2. Fixture Directory
      x.report("Fixture Directory - Clean") do
        path = File.join(TEST_DIR, "fixture_dir_clean")
        FileUtils.rm_rf(path)
        FileUtils.cp_r(File.join(FIXTURE_DIR, "clean_repo"), path)
        repo = Git.open(path)
        assert_expected_state(repo, dirty: false)
      end

      x.report("Fixture Directory - Dirty") do
        path = File.join(TEST_DIR, "fixture_dir_dirty")
        FileUtils.rm_rf(path)
        FileUtils.cp_r(File.join(FIXTURE_DIR, "dirty_repo"), path)
        repo = Git.open(path)
        assert_expected_state(repo, dirty: true)
      end

      # 3. Git Bundle + Commit Message
      x.report("Git Bundle + Commit Message (Clean)") do
        path = File.join(TEST_DIR, "bundle_commitmsg_clean")
        FileUtils.rm_rf(path)
        # Only measure the restore step
        restored_repo = restore_commit_with_worktree_and_untracked(
          File.join(BUNDLE_DIR, "commitmsg_clean.bundle"),
          path
        )
        assert_expected_state(restored_repo, dirty: false)
      end

      x.report("Git Bundle + Commit Message (Dirty)") do
        path = File.join(TEST_DIR, "bundle_commitmsg_dirty")
        FileUtils.rm_rf(path)
        # Only measure the restore step
        restored_repo = restore_commit_with_worktree_and_untracked(
          File.join(BUNDLE_DIR, "commitmsg_dirty.bundle"),
          path
        )
        assert_expected_state(restored_repo, dirty: true)
      end

      x.compare!
    end
  end

  def self.measure_storage
    puts "\nStorage Requirements:"
    puts "-------------------"
    puts "Fixture Directory: #{dir_size(FIXTURE_DIR)} KB"
    puts "Git Bundles: #{dir_size(BUNDLE_DIR)} KB"
  end

  def self.dir_size(path)
    `du -sk #{path}`.split.first.to_i
  end

  def self.assert_expected_state(repo, dirty: false)
    Dir.chdir(repo.dir.path) do
      log = `git log --pretty=%s`.lines.map(&:strip)
      # Should have exactly the two expected commits, in the correct order
      expected_commits = ["Add feature", "Initial commit"]
      actual_commits = log[0..1]  # Only look at the first two commits
      unless actual_commits == expected_commits
        raise "Unexpected commits. Expected: #{expected_commits.inspect}, Got: #{actual_commits.inspect}"
      end

      # README.md should exist and be tracked
      raise "README.md missing" unless File.exist?("README.md")
      readme_tracked = `git ls-files README.md`.strip == "README.md"
      raise "README.md not tracked" unless readme_tracked

      # feature.txt should exist and be tracked
      raise "feature.txt missing" unless File.exist?("feature.txt")
      feature_tracked = `git ls-files feature.txt`.strip == "feature.txt"
      raise "feature.txt not tracked" unless feature_tracked

      # untracked.txt
      if dirty
        raise "untracked.txt missing" unless File.exist?("untracked.txt")
        status = `git status --porcelain`
        raise "untracked.txt not untracked" unless status.lines.any? { |l| l.strip == "?? untracked.txt" }
        content = File.read("untracked.txt").strip
        raise "untracked.txt content wrong" unless content == "This is untracked" || content == "untracked restored"
      elsif File.exist?("untracked.txt")
        raise "untracked.txt should not exist"
      end
    end
  end
end

# Run the benchmark
FixtureBenchmark.setup
FixtureBenchmark.prepare_fixtures
FixtureBenchmark.benchmark_strategies
FixtureBenchmark.measure_storage
FixtureBenchmark.teardown
