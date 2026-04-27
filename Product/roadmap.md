# Roadmap

Each milestone delivers a complete, usable slice of value — a baby elephant, not a layer.
Issues within each milestone are ordered so the app never feels broken mid-milestone.

## M1: Foundation ✅

*Read-only snapshot of issues from GitHub.*

- [x] Project setup (XcodeGen, targets, GRDB, dependencies) [#1](https://github.com/32pixelsCo/GeckoIssues/issues/1)
- [x] OAuth Device Flow authentication with github.com [#2](https://github.com/32pixelsCo/GeckoIssues/issues/2)
- [x] Keychain credential storage [#3](https://github.com/32pixelsCo/GeckoIssues/issues/3)
- [x] GitHub GraphQL client [#4](https://github.com/32pixelsCo/GeckoIssues/issues/4)
- [x] Local SQLite schema (repos, issues, labels, milestones, assignees, comments) [#5](https://github.com/32pixelsCo/GeckoIssues/issues/5)
- [x] Initial full sync of repositories and issues [#6](https://github.com/32pixelsCo/GeckoIssues/issues/6)
- [x] Repository list in sidebar [#7](https://github.com/32pixelsCo/GeckoIssues/issues/7)
- [x] Issue list view with basic sorting (updated, created, title) [#8](https://github.com/32pixelsCo/GeckoIssues/issues/8)
- [x] Issue detail view (title, body rendered as markdown, state, labels, assignees, milestone) [#9](https://github.com/32pixelsCo/GeckoIssues/issues/9)
- [x] Comments list on issue detail [#10](https://github.com/32pixelsCo/GeckoIssues/issues/10)
- [x] Org-based sidebar nav — active org switcher with repos listed beneath

## M2: Curated, Live Sync

*User controls which orgs and repos are tracked and trusts the data is always fresh.*

End state: open the app, complete a guided setup, pick your org and repos, and their issues stay current automatically.

- [x] Onboarding wizard — 4-step wizard on first launch: (1) Connect GitHub via OAuth, (2) Select your first org, (3) Select repos to sync, (4) Initial sync
- [x] Settings — add/remove organizations; adding an org reuses the onboarding wizard from step 2
- [x] Selective sync — only sync repos you've added
- [x] Incremental sync — use `updatedAt` cursors instead of full re-fetch
- [x] Background refresh — poll on a configurable interval while app is active
- [x] Sync status indicator — show sync state (idle / syncing / error / offline) in the UI
- [x] Online/offline detection — detect network loss, degrade gracefully to reads

## M3: Issue Management

*Full read-write on issues.*

End state: create, edit, and close issues without leaving the app.

- [ ] Create new issue (title, body, labels, assignee, milestone)
- [ ] Edit issue title and body (markdown editor)
- [ ] Open/close issue
- [ ] Add and remove labels, assignees, milestone
- [ ] Add comments
- [ ] Sub-issues and parent issue linking

## M4: Projects & Kanban

*Add the workflow layer on top of issues.*

End state: manage work on a board, drag cards to change status, see issues in project context.

- [ ] Sync projects, project fields, project views, and project items
- [ ] Project list in sidebar (with add/remove project tracking)
- [ ] Kanban board view mapped to project Status field
- [ ] Drag-and-drop to change status (write to GitHub)
- [ ] Table view for projects
- [ ] Filtering by label, assignee, milestone
- [ ] Grouping and sorting options

## M5: CLI & MCP

*Terminal and LLM-accessible interface sharing the same local store.*

End state: `gecko` CLI works in the terminal; `gecko mcp` exposes issues to AI agents.

- [ ] CLI target with Swift Argument Parser
- [ ] `gecko repos` — list synced repositories
- [ ] `gecko issues` — list and filter issues
- [ ] `gecko issue` — show issue detail
- [ ] `gecko projects` — list projects
- [ ] `gecko create` — create an issue
- [ ] `gecko comment` — add a comment
- [ ] `gecko sync` — trigger sync
- [ ] `gecko auth` — authenticate
- [ ] `gecko mcp` — MCP server over stdio
- [ ] Embed CLI in app bundle with symlink install

## M6: Search & Command Palette

*App feels instant and keyboard-driven — find anything without touching the mouse.*

End state: Cmd+K opens a fast, full-text palette that searches issues, repos, and actions.

- [ ] Full-text search index via SQLite FTS5
- [ ] Cmd+K command palette (search issues, repos, projects, actions)
- [ ] Arrow key navigation in issue list, Enter to open
- [ ] Cmd+N new issue, Cmd+F filter current view
- [ ] Quick switcher between repos and projects
- [ ] Recent items / history

## M7: Polish & Launch

*Ship a 1.0 that people love.*

- [ ] App icon and branding
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
