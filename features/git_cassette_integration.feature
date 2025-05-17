Feature: Record and replay git commands with git-cassette
  As a developer
  I want to record and replay git commands in my tests
  So that I can have deterministic and fast test runs

  Background:
    Given a file named "spec/git_cassette_spec.rb" with:
      """
      require 'git'

      $LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
      require 'git_cassette'

      RSpec.describe 'GitCassette' do
        before(:all) do
          GitCassette.configure do |config|
            config.cassette_dir = File.join(Dir.pwd, 'cassettes')
            config.repo_dir = File.join(Dir.pwd, 'repos')
          end
        end

        it 'records and replays a git repository state' do
          GitCassette.record('test-cassette') do
            File.write('test.txt', 'initial content')
            g = Git.init(Dir.pwd)
            g.add('test.txt')
            g.commit('Initial commit')

            # Modify tracked file
            File.write('test.txt', 'modified content')
            # Add untracked file
            File.write('untracked.txt', 'untracked content')
          end

          # Verify git status output
          g = Git.open(Dir.pwd)
          status = g.status
          expect(status.changed.keys).to include('test.txt')
          expect(status.untracked.keys).to include('untracked.txt')
          expect(g.log.first.message).to eq('Initial commit')
        end
      end
      """

  Scenario: Basic recording and replaying
    When I run `bundle exec rspec spec/git_cassette_spec.rb`
    And the output should contain "1 example, 0 failures"
    And a directory named "cassettes" should exist
    And a directory named "repos" should exist
    And a file named "cassettes/test-cassette.bundle" should exist
    And a directory named "repos/test-cassette" should exist

    When I remove the directory "repos"
    And I run `bundle exec rspec spec/git_cassette_spec.rb`
    And the output should contain "1 example, 0 failures"
    And a directory named "repos/test-cassette" should exist