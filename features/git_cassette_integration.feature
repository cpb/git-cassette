Feature: Git Cassette Integration with RSpec
  As a developer
  I want to use git-cassette in my RSpec tests
  So that I can verify git operations in a controlled environment

  Scenario: Running RSpec test with git-cassette
    Given I am in a new directory
    When I run `gem install rspec`
    And I create a file named "spec/example_spec.rb" with:
      """
      require 'git_cassette'

      RSpec.describe 'Git Cassette Example' do
        before do
          GitCassette.configure do |config|
            config.cassette_dir = 'cassettes'
            config.repo_dir = 'repos'
          end
        end

        it 'verifies git operations' do
          expect(Dir.exist?('cassettes')).to be true
          expect(Dir.exist?('repos')).to be true
        end
      end
      """
    And I run `rspec spec/example_spec.rb`
    Then the output should contain "1 example, 0 failures" 