# Architecture

## Overview

GeckoIssues is a native macOS app built in SwiftUI with a companion CLI. It syncs GitHub Issues and Projects to a local data store and provides a fast, offline-capable interface on top of them.

```
┌──────────────────────────────────────┐
│     UI Layer (SwiftUI)               │
│     Kanban · Issue Detail · Lists    │
├──────────────────────────────────────┤
│     Observable Stores                │
│     App · Navigation · Sync · Auth   │
├──────────────────────────────────────┤
│     Local Data Store (GRDB/SQLite)   │
├──────────────────────────────────────┤
│     GitHub Sync Engine               │
│     (GraphQL API)                    │
└──────────────────────────────────────┘
        ↕               ↕
    github.com      CLI (`gecko`)
```

## Targets

| Target | Type | Purpose |
|--------|------|---------|
| **GeckoIssuesApp** | SwiftUI App | Main macOS application |
| **GeckoIssuesCLI** | Executable | Companion CLI (`gecko`) for terminal and LLM use |

The CLI is compiled as a pre-build step and embedded in the app bundle at `GeckoIssues.app/Contents/Helpers/gecko`. Users symlink it into their PATH.

Both targets share the same local data store — the CLI reads and writes the same SQLite database as the app.

## Data Model

GeckoIssues mirrors GitHub's data model. No invented abstractions.

### Core Entities

```
ACCOUNT (GitHub user or org)
 |
 |-- REPOSITORY
 |     |-- ISSUE
 |     |     |-- labels, milestone, assignees
 |     |     |-- comments
 |     |     |-- state (open/closed)
 |     |     |-- sub-issues / parent issue
 |     |
 |     |-- LABEL (definitions)
 |     |-- MILESTONE (definitions)
 |
 |-- PROJECT (v2)
       |-- PROJECT FIELD (Status, Iteration, custom...)
       |-- PROJECT VIEW (Board, Table)
       |-- PROJECT ITEM (join entity)
             |-- field values (status per project, etc.)
             |-- references ISSUE or PR
```

**Key relationship:** Issues live on repositories. Projects are org/user-scoped overlays that add workflow metadata (Status, Iterations, custom fields) via ProjectItem. A single issue can appear in multiple projects.

### Local Storage

All synced data lives in a SQLite database managed by GRDB:

- `~/.gecko/data.db` (or App Sandbox container equivalent)
- Migrations managed via GRDB's migrator
- Full-text search via SQLite FTS5

The local store is the source of truth for reads. Writes go to GitHub first, then update local state on confirmation.

## State Management

Following the same patterns as ContextStore:

### Observable Stores

All stores are `@MainActor @Observable` classes, created in the root view as `@State` and passed explicitly as parameters. Never injected via `.environment()`.

| Store | Responsibility |
|-------|---------------|
| **AppStore** | Current account, selected repo/project, navigation state |
| **NavigationStore** | Sheet/alert routing, UI state (sidebar, search overlay, Cmd+K) |
| **SyncStore** | Sync lifecycle, background refresh, conflict detection, online/offline state |
| **AuthStore** | OAuth flow, token management, Keychain storage |

### Patterns

- **Local state** (`@State`) when only one view needs it
- **Shared state** via stores, passed as explicit parameters
- **`@Bindable`** for two-way bindings to store properties
- **Sheet routing** via enum (`SheetRoute`) with a single `.sheet(item:)` in the root view
- **Async work** via `.task` on views, not `onAppear` + `Task {}`

## Sync Engine

### GitHub API

All GitHub communication uses the **GraphQL API** (v4) for efficiency — fewer round-trips, precise field selection, and native support for Projects v2.

### Sync Strategy

1. **Initial sync** — Full fetch of all repos, issues, projects, and metadata for the authenticated account
2. **Incremental sync** — Poll for changes using `updatedAt` cursors and ETags
3. **Background refresh** — Periodic fetch while app is active (configurable interval)
4. **Offline reads** — Everything synced is available instantly from SQLite
5. **Writes** — Mutations go to GitHub via GraphQL, local store updates on success

### Sync State Machine

```
 ┌─────────────────────────────────────────────┐
 │                                             │
 ▼                                             │
NOT_CONNECTED ──▶ SYNCING ──▶ IDLE ──▶ SYNCING │
                    │                          │
                    ▼                          │
                  ERROR ───────────────────────┘
                    │
                    ▼
                  OFFLINE (network unavailable, reads still work)
```

## Authentication

**OAuth App** using the GitHub Device Flow:

1. App requests a device code from GitHub
2. User visits `github.com/login/device` and enters the code
3. App polls for authorization
4. Access token stored in macOS Keychain via a `CredentialStore` protocol

Only github.com is supported at launch.

## CLI (`gecko`)

Built with Swift Argument Parser. Designed for both human use and LLM agent workflows.

### Commands

**Reading:**
- `gecko repos` — List synced repositories
- `gecko issues [repo]` — List issues, with filters
- `gecko issue [repo] [number]` — Show issue detail
- `gecko projects` — List projects
- `gecko search [query]` — Full-text search across issues

**Writing:**
- `gecko create [repo] --title "..." --body "..."` — Create an issue
- `gecko edit [repo] [number] --status "..."` — Update an issue
- `gecko comment [repo] [number] --body "..."` — Add a comment

**System:**
- `gecko sync` — Trigger a sync
- `gecko auth` — Authenticate with GitHub
- `gecko mcp` — Start MCP server (JSON-RPC over stdio)

### MCP Server

The CLI can run as an MCP server for direct integration with AI agents:

```bash
gecko mcp
```

This exposes issue reading, searching, creation, and updates as MCP tools over stdio.

## UI Structure

### Root Navigation

`NavigationSplitView` with three columns:

1. **Sidebar** — Account, repositories, projects
2. **Content** — Issue list or kanban board (depending on context)
3. **Detail** — Issue detail view

### Key Views

| View | Purpose |
|------|---------|
| **KanbanBoardView** | Project board with draggable columns mapped to Status field |
| **IssueListView** | Filterable, sortable issue table |
| **IssueDetailView** | Full issue view with comments, metadata, and editing |
| **CommandPaletteView** | Cmd+K overlay for quick navigation and actions |

### Keyboard Shortcuts

- `Cmd+K` — Command palette
- `Cmd+N` — New issue
- `Cmd+F` — Filter/search
- Arrow keys — Navigate issue list
- `Enter` — Open selected issue

## Dependencies

| Package | Purpose |
|---------|---------|
| **GRDB** | SQLite database and migrations |
| **ArgumentParser** | CLI command parsing |

Minimize dependencies. Use Foundation and SwiftUI built-ins wherever possible.

## Build System

- **XcodeGen** generates `.xcodeproj` from `project.yml` (never edit `.xcodeproj` directly)
- Pre-build script compiles CLI and embeds in app bundle
- Deployment target: macOS 15.0+
- Swift 6.0 with strict concurrency

## Conventions

- `@Observable` (not `ObservableObject` / `@Published`)
- `@MainActor` on all stores
- Stores passed as explicit parameters, never via `.environment()`
- `guard` for early returns
- `// MARK: -` for section organization
- `.task` for async work, not `onAppear` + `Task {}`
- Enum-based sheet routing with `.sheet(item:)`
