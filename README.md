# GeckoIssues

**A blazing-fast native Mac app for GitHub Issues.**

GeckoIssues gives GitHub Issues and Projects a beautiful, modern interface. It mirrors GitHub's data model faithfully — no invented abstractions, just a dramatically better experience. Offline-capable with a companion CLI for LLM workflows.

<img src="/GeckoIssues%20Icon/gecko.png" alt="Gecko" width="512" height="512" />

---

## Quick Start

### Prerequisites

- **macOS 15.0+** (Sequoia)
- **Xcode 16+**
- **XcodeGen** — Install with `brew install xcodegen`

### Building the App

1. Clone the repository:

   ```bash
   git clone https://github.com/32pixelsCo/GeckoIssues.git
   cd GeckoIssues
   ```

2. Generate the Xcode project and build:

   ```bash
   xcodegen generate
   xcodebuild -project GeckoIssues.xcodeproj -scheme GeckoIssues -destination 'platform=macOS' build
   ```

3. Or open in Xcode and hit Cmd+R:
   ```bash
   open GeckoIssues.xcodeproj
   ```

### Building the CLI

The companion `gecko` CLI shares the same local database and can be used in terminal and LLM workflows:

```bash
cd GeckoCLI && swift build --product gecko
```

### Running Tests

```bash
xcodebuild -project GeckoIssues.xcodeproj -scheme GeckoIssues -destination 'platform=macOS' test
```

---

## Project Structure

```
GeckoIssues/
├── GeckoIssuesApp/            # Main application source
│   ├── Stores/                # @Observable state management
│   │   ├── AppStore.swift           # Account/repo/project state
│   │   ├── NavigationStore.swift    # Sheet routing, command palette
│   │   ├── SyncStore.swift          # GitHub sync lifecycle
│   │   └── AuthStore.swift          # OAuth flow, Keychain
│   ├── Views/                 # SwiftUI views
│   │   ├── Components/        # Reusable view components
│   │   ├── Sheets/            # Modal sheet dialogs
│   │   └── Settings/          # Settings window
│   ├── Models/                # Data models (mirroring GitHub)
│   ├── Sync/                  # GitHub GraphQL client and sync engine
│   └── Database/              # GRDB schema, migrations, queries
├── GeckoCLI/                  # Companion CLI (`gecko`)
├── GeckoIssuesTests/          # Unit tests
├── .claude/                   # Claude Code settings and skills
└── project.yml                # XcodeGen configuration
```

---

## Dependencies

Managed via Swift Package Manager (defined in `project.yml`):

| Package                                                              | Purpose                 |
| -------------------------------------------------------------------- | ----------------------- |
| [GRDB](https://github.com/groue/GRDB.swift)                          | SQLite local data store |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Secure token storage    |
| [ArgumentParser](https://github.com/apple/swift-argument-parser)     | CLI command parsing     |

---

## Development Workflow

This project uses [Claude Code](https://claude.ai/claude-code) with custom skills for a streamlined development workflow:

- **`/new-issue`** — Creates a new GitHub issue in the current milestone with description, wireframes, and acceptance criteria.
- **`/next-task`** — Picks the next GitHub issue, implements it, and opens a PR.
- **`/approve`** — Verifies checks and merges an approved PR.

These skills are defined in `.claude/skills/` and are made specifically for Gecko Issues. See [How I Manage My Dev Workflow with Three Agent Skills](https://32pixels.co/blog/how-i-manage-my-dev-workflow-with-three-agent-skills) for more on how they work.

---

## Planning Documentation

Planning docs live in a [ContextStore](https://contextstore.app) space on the [`docs/planning` branch](https://github.com/32pixelsCo/GeckoIssues/tree/docs/planning). This is an orphan branch (never merged to main) that holds product vision, roadmap, and technical architecture docs.

You can read planning docs without switching branches:

```bash
# List all planning docs
git ls-tree -r --name-only docs/planning

# Read a specific doc
git show docs/planning:Product/Vision.md
git show docs/planning:Product/roadmap.md
git show docs/planning:Engineering/Architecture.md
```

---

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to get started.

---

## License

This project is licensed under the MIT License — see [LICENSE.md](LICENSE.md) for details.
