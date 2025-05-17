# Git Cassette: VCR for Git Working Directories

## Problem

Setting up test git repositories with specific states is slow, taking 1-2 seconds even for simple test repos. This is because it requires executing multiple git commands and file operations sequentially:

1. Initializing a new repo
2. Creating and committing initial files
3. Creating branches and tags
4. Modifying tracked files
5. Adding untracked files
6. Managing the staging area

While having this clear sequence of steps makes the setup process easy to understand and modify, the execution time adds up quickly when running many tests. As shown in the benchmark code, even a basic test repository setup can require 30+ lines of setup code and take 1-2 seconds to execute.

This performance overhead becomes significant in large test suites, where setting up git repositories is a common requirement. Fast and reliable test execution is important both during local development and in continuous integration environments.

## Solution

Git Cassette provides a way to record and replay git repository states, similar to how VCR works for HTTP interactions. It uses a layered approach that combines the benefits of multiple strategies:

### Explicit Setup as Source of Truth
- Provides clear, readable setup steps that are easy to modify
- Acts as documentation for the expected repository state
- Used to initially create and update repository states

### Git Bundles for Storage
- Efficiently stores repository states through git's built-in compression
- Preserves complete history and metadata
- Used to persist and share repository states

### Fixture Directory for Performance
- Delivers fastest test execution through direct file copies
- Avoids overhead of git operations during test runs
- Used at runtime to maximize test speed

This layered approach gives you:
- Clear setup code that's easy to modify
- Efficient storage and sharing
- Fast test execution

Git Cassette automatically manages these layers, so you get all the benefits without having to think about the implementation details.

## Development

To run the benchmark:

```bash
bundle install
ruby examples/fixture_strategies_benchmark.rb
```

## Key Features

1. **VCR-like API**: Simple, familiar interface for Ruby developers
2. **Complete State Capture**: Preserves both tracked and untracked files
3. **Efficient Operation**: Fast playback with minimal storage overhead
4. **CI Integration**: Designed to work in automated environments (coming soon)

## Inspiration from VCR

Git Cassette is inspired by VCR, the popular Ruby gem for recording and replaying HTTP interactions in tests. While VCR handles HTTP requests, Git Cassette applies the same "record and replay" concept to git repository states.

Just like VCR makes HTTP testing easier, Git Cassette aims to simplify testing code that interacts with git repositories by providing a familiar interface for Ruby developers.

## Next Steps

1. Implement the core Git Cassette functionality
2. Add support for different storage strategies
3. Create a simple API for recording and replaying git states
4. Add support for CI environments
5. Create documentation and examples