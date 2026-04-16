# Roadmap

## M1: Foundation

Get the app running with auth, sync, and basic issue browsing.

- [x] Project setup (XcodeGen, targets, GRDB, dependencies)
- [x] OAuth Device Flow authentication with github.com
- [x] Keychain credential storage
- [x] GitHub GraphQL client
- [x] Local SQLite schema (repos, issues, labels, milestones, assignees, comments)
- [x] Initial full sync of repositories and issues
- [x] Repository list in sidebar
- [x] Issue list view with basic sorting (updated, created, title)
- [x] Issue detail view (title, body rendered as markdown, state, labels, assignees, milestone)
- [ ] Comments list on issue detail

## M2: Projects & Kanban

Add GitHub Projects v2 support and the kanban board — the heart of the app.

- [ ] Sync projects, project fields, project views, and project items
- [ ] Project list in sidebar
- [ ] Kanban board view mapped to project Status field
- [ ] Drag-and-drop to change status (write to GitHub)
- [ ] Table view for projects
- [ ] Filtering by label, assignee, milestone
- [ ] Grouping and sorting options

## M3: Command Palette & Navigation

Make the app feel fast and keyboard-driven.

- [ ] Cmd+K command palette (search issues, repos, projects)
- [ ] Keyboard navigation (arrow keys, enter to open)
- [ ] Cmd+N to create a new issue
- [ ] Cmd+F to filter current view
- [ ] Quick switcher between repos and projects
- [ ] Recent items / history

## M4: Issue Editing

Full read-write support for issues.

- [ ] Create new issue (title, body, labels, assignee, milestone)
- [ ] Edit issue title and body (markdown editor)
- [ ] Change state (open/close)
- [ ] Add and remove labels
- [ ] Change assignees and milestone
- [ ] Add comments
- [ ] Sub-issues and parent issue linking

## M5: CLI & MCP

Ship the companion CLI and MCP server for LLM workflows.

- [ ] CLI target with Swift Argument Parser
- [ ] `gecko repos` — list synced repositories
- [ ] `gecko issues` — list and filter issues
- [ ] `gecko issue` — show issue detail
- [ ] `gecko projects` — list projects
- [ ] `gecko search` — full-text search across issues
- [ ] `gecko create` — create an issue
- [ ] `gecko comment` — add a comment
- [ ] `gecko sync` — trigger sync
- [ ] `gecko auth` — authenticate
- [ ] `gecko mcp` — MCP server over stdio
- [ ] Embed CLI in app bundle with symlink install

## M6: Offline & Sync Polish

Make offline reliable and sync seamless.

- [ ] Incremental sync with `updatedAt` cursors
- [ ] Background refresh on configurable interval
- [ ] Online/offline state detection
- [ ] Sync status indicator in UI
- [ ] Full-text search via SQLite FTS5
- [ ] Conflict handling for concurrent edits

## M7: Polish & Launch

Ship a 1.0 that people love to use.

- [ ] App icon and branding
- [ ] Onboarding flow (auth + first sync)
- [ ] Empty states for all views
- [ ] Loading states and sync progress
- [ ] Error handling and user-facing messages
- [ ] Accessibility labels on all interactive controls
- [ ] Performance profiling and optimization
- [ ] Website and distribution (direct download or Mac App Store)

## Future

- Queued offline writes (create/edit issues while disconnected)
- GitHub Enterprise support
- Notifications / inbox
- Multiple accounts
- Project templates and workflow automation
- iOS companion app
