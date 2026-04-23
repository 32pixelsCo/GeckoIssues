# Contributing to GeckoIssues

Thanks for your interest in contributing to GeckoIssues! This guide will help you get set up and familiar with our workflow.

## Getting Started

1. Fork the repository and clone your fork
2. Install prerequisites: **macOS 15.0+**, **Xcode 16+**, and **XcodeGen** (`brew install xcodegen`)
3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
4. Build and run:
   ```bash
   open GeckoIssues.xcodeproj
   ```

## Development Workflow

We use [Claude Code](https://claude.ai/claude-code) with [custom skills](https://32pixels.co/blog/how-i-manage-my-dev-workflow-with-three-agent-skills) to manage the development lifecycle:

- **`/next-task`** picks the next GitHub issue, implements it, and opens a PR
- **`/approve`** verifies checks and merges an approved PR
- **`/new-issue`** creates a well-structured GitHub issue from a plain-English description

You're welcome to use these skills or work through the traditional GitHub flow — either way works.

### Branching

- Work on feature branches, never commit directly to `main`
- Open a pull request for review when your work is ready

### Building

```bash
# Generate the Xcode project (required after changes to project.yml)
xcodegen generate

# Build from the command line
xcodebuild -project GeckoIssues.xcodeproj -scheme GeckoIssues -destination 'platform=macOS' build

# Run tests
xcodebuild -project GeckoIssues.xcodeproj -scheme GeckoIssues -destination 'platform=macOS' test
```

## Code Conventions

- **Swift 6.0** with strict concurrency
- **SwiftUI** for all UI — no UIKit/AppKit unless absolutely necessary
- **`@Observable`** for state management (not `ObservableObject` / `@Published`)
- Pass stores as **explicit parameters**, not via `.environment()`
- Use **`.sheet(item:)`** with `SheetRoute` enum for modal presentation
- Use **`.task`** for async work on view appearance
- Add **accessibility labels** on interactive controls
- Mirror **GitHub's data model** faithfully — no invented abstractions

### Project Configuration

The Xcode project is generated from `project.yml` via XcodeGen. Never edit `GeckoIssues.xcodeproj` directly — your changes will be overwritten. To add dependencies or targets, modify `project.yml` and regenerate.

## Planning Docs

Planning documentation lives in a [ContextStore](https://contextstore.app) space on the `docs/planning` orphan branch. Read docs without switching branches:

```bash
git ls-tree -r --name-only docs/planning
git show docs/planning:Product/Vision.md
```

## Submitting a Pull Request

1. Create a feature branch from `main`
2. Make your changes, following the code conventions above
3. Run the tests and make sure they pass
4. Push your branch and open a PR against `main`
5. Describe what you changed and why in the PR description

## Reporting Issues

Found a bug or have a feature request? Open an issue on GitHub. Include steps to reproduce for bugs, or a clear description of the desired behavior for features.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE.md).
