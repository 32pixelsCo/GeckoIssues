# AGENTS.md

GeckoIssues — native macOS app (Swift 6.0, SwiftUI) for managing GitHub Issues and Projects with a local-first, offline-capable interface.

**Platform:** macOS 15.0+ · **Build:** XcodeGen (`project.yml`) + SPM

## Commands

```bash
# Build (generate project first if .xcodeproj is missing or stale)
xcodegen generate
xcodebuild -project GeckoIssues.xcodeproj -scheme GeckoIssues -destination 'platform=macOS' build

# Test
xcodebuild -project GeckoIssues.xcodeproj -scheme GeckoIssues -destination 'platform=macOS' test

# Build CLI only
cd GeckoCLI && swift build --product gecko
```

## Planning Docs

Planning documentation lives in the orphan `docs/planning` branch as a ContextStore space. Read docs without switching branches:

```bash
# List all planning docs
git ls-tree -r --name-only docs/planning

# Read a specific doc
git show docs/planning:Product/Vision.md
git show docs/planning:Product/roadmap.md
git show docs/planning:Engineering/Architecture.md
```

Structure:

```
docs/planning branch (orphan — never merge to main)
├── .contextstore/settings.yml    # Space: "GeckoIssues"
├── Product/
│   ├── Vision.md
│   └── roadmap.md
└── Engineering/
    └── Architecture.md
```

## Boundaries

**Always:**

- Read existing code before modifying it
- Pass stores as explicit parameters, not `.environment()`
- Keep state local (`@State`) when only one view needs it — only use stores for shared state
- Use `@MainActor` for main-thread work (not `DispatchQueue.main.async`)
- Use `.sheet(item:)` with `SheetRoute` enum, never `.sheet(isPresented:)`
- Use `.task` for async work on view appearance (not `onAppear` with `Task {}`)
- Add accessibility labels on interactive controls (buttons, pickers, text fields)
- Run `xcodegen generate` after changing `project.yml`
- Mirror GitHub's data model faithfully — no invented abstractions

**Ask first:**

- Adding new SPM dependencies (update `project.yml`, not `.xcodeproj`)
- Creating new stores or significantly changing store responsibilities
- Changing the local database schema

**Never:**

- Modify main directly, but create PRs and merge
- Edit `GeckoIssues.xcodeproj` directly — it's generated from `project.yml`
- Use `ObservableObject` / `@Published` — we use `@Observable`
- Use `.environment()` to inject stores — pass as parameters
- Use `if let` inside a `.sheet` body — unwrap via the `SheetRoute` enum instead
- Commit secrets, API keys, or credentials

## Architecture

Four `@MainActor @Observable` stores own all shared state. The root view creates them as `@State` and passes them down:

| Store | Responsibility |
|-------|---------------|
| **AppStore** | Current account, selected repo/project, navigation state |
| **NavigationStore** | Sheet/alert routing, command palette, UI state |
| **SyncStore** | GitHub sync lifecycle, background refresh, online/offline |
| **AuthStore** | OAuth flow, token management, Keychain storage |

```swift
// Pass to children — never use .environment()
SidebarView(appStore: appStore, navigationStore: navigationStore)
```

**Sheet routing** — all sheets go through `SheetRoute` enum in `NavigationStore`:

```swift
navigationStore.activeSheet = .newIssue(repo: repo)
```

**Data layer** — GRDB/SQLite local store synced from GitHub GraphQL API. CLI shares the same database.

**New view checklist:** (1) define state and where it lives (`@State` local vs store), (2) inject dependencies via parameters, (3) extract repeated parts into subviews in `Views/Components/`, (4) use `.task` with explicit loading/error states for async work, (5) add accessibility labels on interactive controls.

## Code Style

```swift
// Stores: @MainActor @Observable final class
@MainActor @Observable
final class AppStore { ... }

// Sections within files
// MARK: - Section Name

// Doc comments on types and non-obvious members
/// Manages GitHub sync lifecycle and offline state.

// Prefer guard for early returns
guard let repo = appStore.selectedRepository else { return }
```

## Testing

Tests in `GeckoIssuesTests/`. Inject dependencies rather than using singletons.

## Commit Messages

```
Short description
```

## Known Debt

None currently tracked.
