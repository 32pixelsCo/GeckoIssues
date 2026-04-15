# Project Summary

## Overview

GeckoIssues is a native macOS app that provides a fast, modern interface on top of GitHub Issues and Projects. It mirrors GitHub's data model faithfully with no invented abstractions. The app includes a companion CLI (`gecko`) for terminal and LLM agent workflows, sharing the same local SQLite data store.

The project is in early stages — planning docs exist but no application code has been written yet.

## Tech stack

- **Language:** Swift 6.0
- **UI framework:** SwiftUI
- **Platform:** macOS 15.0+ (Sequoia)
- **Database:** GRDB (SQLite)
- **CLI:** Swift Argument Parser
- **API:** GitHub GraphQL API (v4)
- **Auth:** OAuth App (Device Flow)
- **Build system:** XcodeGen (`project.yml`) + SPM

## Project structure

The project has not been scaffolded yet. The planned structure is:

```
GeckoIssues/
├── GeckoIssuesApp/            # Main SwiftUI application
│   ├── Stores/                # @Observable state management
│   ├── Views/                 # SwiftUI views
│   ├── Models/                # Data models (mirroring GitHub)
│   ├── Sync/                  # GitHub GraphQL client and sync engine
│   └── Database/              # GRDB schema, migrations, queries
├── GeckoIssuesCLI/            # Companion CLI (`gecko`)
├── GeckoIssuesTests/          # Unit tests
└── project.yml                # XcodeGen configuration
```

## Key files

| File | Purpose |
|---|---|
| README.md | Project overview and setup instructions |
| AGENTS.md | Agent conventions, architecture, and boundaries |
| .claude/settings.json | Claude Code permissions and tool configuration |

## Planning docs

Planning documentation lives in an orphan `docs/planning` branch as a ContextStore space. Key documents:

| Document | Purpose |
|---|---|
| Product/Vision.md | Product vision, core principles, scope |
| Product/roadmap.md | Development milestones (M1–M7 + future) |
| Engineering/Architecture.md | Technical architecture, data model, patterns |

Read with: `git show docs/planning:<path>`

## Conventions

- XcodeGen generates `.xcodeproj` from `project.yml` — never edit `.xcodeproj` directly
- `@Observable` stores (not `ObservableObject`/`@Published`)
- Stores passed as explicit parameters, never via `.environment()`
- `@MainActor` on all stores
- Sheet routing via `SheetRoute` enum with `.sheet(item:)`
- `.task` for async work, not `onAppear` + `Task {}`
- Architecture modeled after the ContextStore app (sister project at `~/Workspaces/32pixels/ContextStore`)
