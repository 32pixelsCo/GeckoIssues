---
name: new-issue
description: Creates a new GitHub issue in the current milestone with description, wireframes, and acceptance criteria.
argument-hint: "[description]"
---

## Instructions

When the `/new-issue [description]` command is invoked, follow these steps:

### 1. Parse the Description

Extract from the user's description:

- **Type**: Is this a bug or a feature? Look for keywords like "bug", "broken", "not working", "should", "fix", "instead of", "wrong", "incorrect", "error"
- **Title**: A concise summary of the issue
- **Scope**: What part of the app is affected (UI, sync, CLI, data layer, etc.)
- **UI Impact**: Does this change impact the user interface?

### 2. Get Project Context

Read `.quiddity/tools.json` to confirm the issue tracker configuration.

Check the current milestone by listing milestones:

```bash
gh milestone list --state open
```

Use the active milestone for the issue.

### 3. Generate Wireframe Options (if UI impact)

If the issue impacts the UI, generate **2-3 different wireframe options** using ASCII box-drawing characters. Each option should represent a meaningfully different approach to the UI — not just minor variations. For example:

- Option A might use a modal dialog
- Option B might use an inline editing pattern
- Option C might use a sidebar panel

Present all options to the user using the AskUserQuestion tool. Ask them to choose which wireframe to use (or describe a different approach). Wait for their response before proceeding.

If the issue has no UI impact, skip this step.

### 4. Generate Issue Content

Using the selected wireframe (if applicable), create a well-structured issue:

#### For Features:

```markdown
[Brief description of the feature]

## Wireframes

[The wireframe option the user selected]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] ...
```

#### For Bugs:

```markdown
[Brief description of the bug]

## Current Behavior

[What currently happens, with ASCII mockup if UI-related]

## Expected Behavior

[What should happen, using selected wireframe if UI-related]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] ...
```

### 5. Create the Issue

Use the `gh` CLI to create the issue:

```bash
gh issue create \
  --title "[Generated title]" \
  --body "[Generated description]" \
  --label "bug" \           # if it's a bug
  --label "feature" \       # if it's a feature
  --milestone "[milestone]" \
  --project "Gecko Issues Dev"
```

### 6. Confirm Creation

Display to the user:

- Issue number (e.g., #12)
- Issue title
- Link to the issue on GitHub

---

## Wireframe Guidelines

When the issue impacts UI, include ASCII wireframes using box-drawing characters:

### Basic Elements

```
Box:           ┌────────────────┐
               │ Content        │
               └────────────────┘

Dropdown:      ┌────────────────┐
               │ Selected     ▼ │
               └────────────────┘
                 ┌──────────────┐
                 │ Option 1     │
                 │ Option 2     │
                 └──────────────┘

Button:        [Cancel]  [Save]

Input:         ┌────────────────┐
               │ placeholder    │
               └────────────────┘

Checkbox:      - [ ] Unchecked
               - [x] Checked
```

### Sidebar Navigation Example

```
┌──────────┬───────────────────────────────┐
│ Sidebar  │ Content                       │
│          │                               │
│ ▼ Repo   │  Issue Title                  │
│   #1     │  ┌─────────────────────────┐  │
│   #2     │  │ Issue body rendered as  │  │
│   #3     │  │ markdown...             │  │
│          │  └─────────────────────────┘  │
│ ▼ Repo 2 │                               │
│   #10    │  Labels: [bug] [feature]      │
│   #11    │  Assignee: @user              │
│          │                               │
└──────────┴───────────────────────────────┘
```

### Kanban Board Example

```
┌──────────────┬──────────────┬──────────────┐
│ Todo         │ In Progress  │ Done         │
├──────────────┼──────────────┼──────────────┤
│ ┌──────────┐ │ ┌──────────┐ │ ┌──────────┐ │
│ │ #5 Title │ │ │ #3 Title │ │ │ #1 Title │ │
│ │ [bug]    │ │ │ @user    │ │ │ [feature]│ │
│ └──────────┘ │ └──────────┘ │ └──────────┘ │
│ ┌──────────┐ │              │ ┌──────────┐ │
│ │ #6 Title │ │              │ │ #2 Title │ │
│ │ [feature]│ │              │ │ @user    │ │
│ └──────────┘ │              │ └──────────┘ │
└──────────────┴──────────────┴──────────────┘
```

### Modal Dialog Example

```
┌────────────────────────────────────────┐
│  Modal Title                           │
├────────────────────────────────────────┤
│                                        │
│  Content goes here...                  │
│                                        │
│                    [Cancel]  [Action]  │
└────────────────────────────────────────┘
```

---

## Acceptance Criteria Guidelines

- Start each criterion with an action verb
- Make criteria testable and specific
- Include edge cases and error states
- For UI changes, include visual feedback criteria
- For destructive actions, include confirmation requirements

## Bug Detection Keywords

The following keywords suggest the issue is a bug:

- "bug", "broken", "not working", "doesn't work"
- "should be", "should show", "should display"
- "fix", "wrong", "incorrect", "error"
- "instead of", "rather than"
