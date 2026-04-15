---
name: next-task
description: Picks the next GitHub issue, implements it, and opens a PR.
---

## Instructions

When the `/next-task` command is invoked, follow these steps:

### 1. Determine Current Milestone

Read the roadmap from the `docs/planning` branch:

```bash
git show docs/planning:Product/roadmap.md
```

Identify the current milestone and what work remains.

**Note:** Planning docs live in the orphan `docs/planning` branch. Use `git show` to read them without switching branches.

### 2. Check for Open PRs with Unresolved Comments

Before selecting a new task, check for open PRs that need attention:

```bash
gh pr list --author @me --state open
```

For each open PR, check for unresolved review comments:

```bash
gh pr view [PR-number]
gh api repos/{owner}/{repo}/pulls/{number}/comments
```

Look for:
- Review comments requesting changes
- Unresolved conversation threads
- Questions from reviewers

If found:
- List all PRs with unresolved comments
- Ask: "The following PRs have unresolved comments. Would you like to address one of them?"
- Show: PR number, title, and comment preview
- Wait for user to select one or say "no" to continue with new tasks
- If user selects a PR, proceed to Step 6 with that issue

### 3. Query GitHub for Tasks

List issues in the current milestone that are ready to work on:

```bash
gh issue list --milestone "[milestone]" --label "todo" --state open
```

If no issues have a "todo" label, fall back to listing all open issues in the milestone:

```bash
gh issue list --milestone "[milestone]" --state open
```

Also check the "Gecko Issues Dev" project board for issues in the "Todo" column.

**If no issues are available:**

- Announce: "No tasks are currently ready to pick up."
- List how many issues exist in other states
- Prompt: "Please move some issues to Todo, then run `/next-task` again."
- Do NOT automatically start work on non-ready issues

### 4. Select Task

Pick the oldest issue from the list (by creation date).

### 5. Start Task

- Get the issue details:
  ```bash
  gh issue view [number]
  ```
- Announce to the user: "Starting task: #[number] - [Title]"
- Display the issue description and acceptance criteria

### 6. Switch Git Branches

**If switching from another task:**

- Check current Git branch: `git branch --show-current`
- If not on the target branch:
  - Stash any uncommitted changes: `git stash` (if any exist)
  - Note which branch we're leaving
  - Announce: "Switching from [old-branch] to [new-branch]"

**Create or checkout the branch:**

Branch naming format: `[issue-number]-[slug]` (e.g., `123-github-oauth-app`)

- Check if branch already exists: `git branch --list [branch-name]`
- If branch exists:
  - Checkout existing branch: `git checkout [branch-name]`
  - Pull latest changes: `git pull origin [branch-name]`
  - Announce: "Resuming work on existing branch: [branch-name]"
- If branch doesn't exist:
  - Ensure on main branch: `git checkout main`
  - Pull latest: `git pull origin main`
  - Create and checkout new branch: `git checkout -b [branch-name]`
  - Announce: "Created new branch: [branch-name]"

### 7. Execute the Task

Based on the task type, take appropriate action:

**For bug fixes (TDD approach):**

1. **Read and understand** — Read the relevant code to understand the root cause
2. **Write a failing test** — Write a test that reproduces the bug
3. **Run tests and confirm failure** — The new test(s) must fail
4. **Commit the failing test** — Commit only the test file(s)
5. **Write the fix** — Modify the source code to fix the bug
6. **Run tests and confirm all pass** — All tests must pass
7. **Commit the fix** — Commit the source code changes separately

If the bug cannot be reproduced in an automated test, skip TDD and note why in the commit message.

**For feature implementation tasks:**

- Read relevant files to understand the codebase
- Write or modify code to implement the feature
- Add tests for new behavior where appropriate
- Run tests to verify nothing is broken

**For setup/configuration tasks:**

- Follow the acceptance criteria step by step
- Document any configuration changes
- Verify the setup works correctly

### 8. Commit Changes

After completing the implementation:

- Stage relevant files (prefer naming specific files over `git add .`)
- Use descriptive commit messages:

  ```
  Brief description (#issue-number)

  Detailed explanation of changes made.

  Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
  ```

- Commit: `git commit -m "$(cat <<'EOF' ... EOF)"`
- Push to origin: `git push -u origin [branch-name]`

### 9. Create or Update Pull Request

**If this is a new PR:**

```bash
gh pr create --title "Brief description (#issue-number)" --body "$(cat <<'EOF'
## Summary
- Change 1
- Change 2

Closes #[issue-number]

## Acceptance Criteria
- [x] Criterion 1
- [x] Criterion 2

## Test Plan
- [ ] Test step 1
- [ ] Test step 2

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**If updating an existing PR:**

- Changes are automatically added when pushed to the same branch
- Add a comment to the PR with the update:
  ```bash
  gh pr comment [PR-number] --body "Updated based on review feedback:
  - Change 1
  - Change 2"
  ```

### 10. Request Review

After creating/updating the PR:

- Display the PR URL
- Display the issue URL
- Show a summary of what was implemented
- **Generate a manual test checklist:** 3-7 concrete action → expected result pairs
- Ask: "**Ready for review!** Please review the changes. Say 'approved' when ready to merge, or let me know what changes you need."
- Wait for user feedback

### 11. Handle Review Feedback

**If user approves** (says 'approved', 'LGTM', 'looks good', or similar):

- Run the `/approve` skill to handle merging

**If user requests changes:**

- Acknowledge the requested changes
- Make the changes in the same branch
- Return to Step 8 (Commit Changes)
- Continue the review loop

**If blocked:**

- Announce the blocker clearly
- Add a comment to the issue and PR explaining what's blocked
- Ask user for guidance

### 12. Error Handling

If any step fails:

- Clearly explain what went wrong
- Don't change the issue status
- Ask user how to proceed

---

## Usage

```
/next-task              # Pick next available task
/next-task 42           # Work on specific issue #42
/next-task --continue   # Continue current in-progress task
```

---

## Notes

- **Dependencies:**
  - GitHub CLI (`gh`) must be installed and authenticated
  - Git repository must be initialized with a remote
- **Permissions:**
  - Will create Git branches and commits
  - Will push to GitHub and create/update PRs
- **Planning docs** live in the orphan `docs/planning` branch — read via `git show`
- **Branch naming:** `[issue-number]-[slug]` (e.g., `123-github-oauth-app`)
- **Merge strategy:** Squash merge, delete branch after merge
- **Project:** Issues are tracked in the "Gecko Issues Dev" GitHub project
