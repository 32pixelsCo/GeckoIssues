# Vision

## The Problem

GitHub Issues is the most widely used issue tracker in software development, but its web interface feels dated compared to modern tools like Linear. Teams that want a fast, polished experience end up paying for a separate product and fragmenting their workflow. The issue tracker they already have — free, integrated with their code — gets left behind.

## The Vision

GeckoIssues is a native Mac app that provides a beautiful, blazing-fast interface on top of GitHub Issues and Projects. It doesn't reinvent GitHub's model or add new concepts. It simply gives you the best possible view of what's already there.

Think of it as Linear's speed and polish, applied to the tool you already use.

## The Name

Jira is the overgrown lizard — Godzilla. Gecko is light and quick. It climbs over walls and fits easily in tight spaces.

## Core Principles

- **Faithful to GitHub.** GeckoIssues mirrors GitHub's data model: repositories, issues, projects, views, labels, milestones, assignees. No invented abstractions. If it doesn't exist in GitHub, it doesn't exist in Gecko.

- **Fast above all else.** A native Mac app with a local data store. Everything you've synced is available instantly. Cmd+K gets you anywhere. No spinners, no waiting on network round-trips for basic navigation.

- **Offline first.** All synced issues, projects, and metadata are available offline. Read everything, even without a connection. (Queued offline writes are a future milestone.)

- **AI-ready.** A companion CLI (`gecko`) ships alongside the app, sharing the same local data store. LLMs and agent workflows can read, search, create, and update issues at the speed of local disk — no API rate limits, no network latency.

## What It Is (and Isn't)

GeckoIssues is a **viewer and editor** for GitHub Issues and Projects. It is not a project management tool with its own opinions about workflow.

| In scope                              | Out of scope                  |
| ------------------------------------- | ----------------------------- |
| Issue list, detail, and creation      | Workflow automation           |
| Project kanban boards and table views | Project templates             |
| Multi-repo, multi-project support     | GitHub Enterprise (at launch) |
| Labels, milestones, assignees         | Admin and org management      |
| Sub-issues and parent issues          | Notifications / inbox         |
| Filtering, sorting, grouping          | CI/CD integration             |
| Companion CLI for LLM workflows       |                               |

## Architecture at a Glance

- **Native Mac app** built in SwiftUI
- **Local data store** synced from GitHub via the GraphQL API
- **OAuth App** for authentication against github.com
- **Companion CLI** (`gecko`) that reads and writes the same local store
- **MCP server** support for direct integration with AI agents

## Launch Slice

Broad but shallow. The first release covers the core objects — repositories, issues, projects, and project views — with a clean, fast UI. Power-user and admin features (templates, automations, enterprise support) come later.

The goal at launch: open the app, see your issues across repos and projects, navigate instantly, and never want to go back to the web UI.
