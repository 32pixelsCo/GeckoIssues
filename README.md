# GeckoIssues

**A blazing-fast native Mac app for GitHub Issues.**

GeckoIssues gives GitHub Issues and Projects a beautiful, modern interface. It mirrors GitHub's data model faithfully — no invented abstractions, just a dramatically better experience. Offline-capable with a companion CLI for LLM workflows.

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

2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

3. Open in Xcode:
   ```bash
   open GeckoIssues.xcodeproj
   ```

4. Build and run (Cmd+R)

### Building the CLI

```bash
swift build --product gecko
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
├── GeckoIssuesCLI/            # Companion CLI (`gecko`)
├── GeckoIssuesTests/          # Unit tests
├── .claude/                   # Claude Code settings
└── project.yml                # XcodeGen configuration
```

---

## Dependencies

Managed via Swift Package Manager (defined in `project.yml`):

| Package | Purpose |
|---------|---------|
| [GRDB](https://github.com/groue/GRDB.swift) | SQLite local data store |
| [ArgumentParser](https://github.com/apple/swift-argument-parser) | CLI command parsing |

---

## Planning Documentation

Planning docs live in a [ContextStore](https://github.com/32pixelsCo/ContextStore) space on the [`docs/planning` branch](https://github.com/32pixelsCo/GeckoIssues/tree/docs/planning), covering product vision, roadmap, and technical architecture.

---

## License

TBD
