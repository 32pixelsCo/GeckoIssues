---
name: approve
description: Verify checks and merge an approved PR.
argument-hint: "[pr-number]"
---

## Instructions

When the `/approve` command is invoked, follow these steps:

### 1. Identify the PR

If a PR number is provided as an argument, use it. Otherwise:

- Get current branch: `git branch --show-current`
- Find the PR for this branch: `gh pr view --json number,title,url,state`
- If no PR exists, inform user and exit

### 2. Check CI Status

Check if CI checks have run and passed:

```bash
gh pr checks [PR-number]
```

**If no CI is configured yet** (CI is planned but not set up):

- Run local checks instead:
  ```bash
  xcodebuild -scheme GeckoIssues -destination 'platform=macOS' build
  xcodebuild -scheme GeckoIssuesTests -destination 'platform=macOS' test
  ```
- If local checks fail:
  - Announce: "Cannot merge — build/tests failed"
  - Ask: "Would you like me to fix the failures, or would you prefer to investigate manually?"
  - Do NOT proceed with merge
  - If user asks to fix: investigate, fix, commit, push, and re-check

**If CI is configured and checks fail:**

- Announce: "Cannot merge — CI checks failed"
- Show which checks failed and why
- Ask: "Would you like me to fix the failing checks?"
- Do NOT proceed with merge

### 3. Check for Outstanding Feedback

Before merging, verify no unresolved feedback exists:

```bash
gh pr view [PR-number]
gh api repos/{owner}/{repo}/pulls/{PR-number}/comments
```

Look for:
- Review comments requesting changes
- Unresolved conversation threads
- Questions that haven't been answered

**If outstanding feedback exists:**

- List all unresolved comments with context
- Ask: "There are unresolved comments on the PR. How would you like to handle these?"
  - Address them now
  - Merge anyway (if non-blocking)
  - Wait and handle in a follow-up
- Wait for user decision before proceeding

### 4. Update Task Lists

Before merging, update task list checkboxes:

- **Update PR description:** Read current PR body, mark completed acceptance criteria with `[x]`
  ```bash
  gh pr edit [PR-number] --body "[updated body]"
  ```

- **Update GitHub issue:** Read current issue body, mark completed criteria with `[x]`
  ```bash
  gh issue edit [issue-number] --body "[updated body]"
  ```

### 5. Merge the PR

```bash
gh pr merge [PR-number] --squash --delete-branch
```

### 6. Post-Merge Cleanup

```bash
# Switch back to main and pull latest
git checkout main
git pull origin main
```

### 7. Close the Issue

If the PR body contains `Closes #[number]`, GitHub auto-closes the issue on merge. If not:

```bash
gh issue close [issue-number]
```

### 8. Update Roadmap

Update the roadmap in the `docs/planning` branch to mark the completed task:

```bash
git checkout docs/planning
git pull origin docs/planning

# Find and check off the task in Product/roadmap.md
# Change `- [ ]` to `- [x]` for the relevant line

git add Product/roadmap.md
git commit -m "Mark #[issue-number] as complete in roadmap"
git push origin docs/planning

git checkout main
```

**Note:** If the task is not found in the roadmap, skip this step silently.

### 9. Report Completion

- Announce: "Completed: #[issue-number] - [Title]"
- Show merged PR URL
- Ask: "Would you like to run `/next-task` to continue with the next task?"

---

## Usage

```
/approve            # Merge PR for current branch
/approve 42         # Merge PR #42
```

Also triggers when user says: "approved", "LGTM", "looks good", "ship it"

---

## Notes

- **Dependencies:**
  - GitHub CLI (`gh`) must be installed and authenticated
  - Must be on a feature branch with an open PR (unless PR number provided)
- **Safety:**
  - Will not merge if checks are failing
  - Verifies no outstanding feedback exists before merging
  - If unresolved comments found, asks user how to proceed
  - Uses squash merge to keep `main` history clean
  - Deletes feature branch after merge
