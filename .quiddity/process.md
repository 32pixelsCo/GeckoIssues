# Development Process

## Branching strategy

You use GitHub Flow with short-lived feature branches off `main`.

- Base branch: `main`
- Branch naming: issue number + kebab-case description (e.g., `123-github-oauth-app`, `45-kanban-drag-drop`)
- Feature branches are short-lived — merge and delete after PR is accepted
- Planning docs live in an orphan `docs/planning` branch (never merged to main)

## Code review

You are the sole developer. PRs are used for all changes to keep a clean history and enable AI-assisted review.

- All changes go through PRs — never commit directly to `main`
- Claude Code creates PRs and can review/approve them
- Squash merge to keep `main` history clean

## Issue workflow

You use GitHub Issues for tracking, organized by milestones.

- Issues live in the GitHub repo, tracked via milestones (M1, M2, etc.)
- Workflow: **Backlog → Todo → In Progress → In Review → Done**
- Issues are moved to "Todo" when ready to be picked up
- Bugs and features are distinguished by labels

## Commit and PR conventions

- Commit messages: short, descriptive summary
- PR titles: short (under 70 characters)
- PR descriptions: summary bullets + test plan
- Squash merge PRs into `main`

## Testing

- Tests live in `GeckoIssuesTests/`
- Inject dependencies rather than using singletons
- Tests expected for non-trivial logic (sync, data layer, models)

## Release and deployment

- Milestone-based releases
- Direct download or Mac App Store distribution (TBD)
- No CI/CD configured yet — will be added as the project matures

## Team structure

You are a solo developer using Claude Code as an AI development partner.
