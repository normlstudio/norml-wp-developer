# Norml WordPress Copilot Advanced

Installed skill: `norml-wp-developer`.

Develop, understand, and deploy a WordPress theme from a CLI runtime. Advanced
connects the local theme, GitHub, and the hosting server; analyzes the project once;
and keeps its capability contract and architecture documentation beside the code.

## The problem

WordPress development knowledge is often scattered between a developer's laptop,
hosting notes, GitHub, SSH config, and memory. A new session can see the files but
not know which server is canonical, how deployment works, or what changed recently.

That missing context is risky. Theme edits, database commands, and production
deploys are not interchangeable operations, and inherited themes should not be
quietly rebuilt around a new stack.

Advanced creates one project contract. It verifies the real connections, captures
the current architecture, and stores the durable knowledge in the theme repo.

## What it does

- Develops WordPress theme code locally in Sage or inherited-project mode.
- Connects and verifies GitHub, production SSH, optional staging SSH, and remote
  WP-CLI.
- Generates a visible `.claude/capabilities.md` and architecture dossier before
  development begins.
- Implements ACF blocks, templates, components, styles, and WordPress data models.
- Runs Git branches, commits, CI/CD, staging verification, and production promotion.
- Synchronizes approved database/uploads workflows and records project history.

## When to reach for it

Use Advanced when a request includes code or infrastructure:

- create or change a theme, template, component, block, CPT, or taxonomy;
- inspect WordPress through WP-CLI;
- connect GitHub or a hosting server;
- pull production data to a local environment;
- configure or run CI/CD;
- deploy to staging or production;
- diagnose architecture that the REST API cannot see.

For routine content/admin work through WordPress's REST API, use Norml WordPress
Copilot (`norml-wp-manager`).

## How it works

1. **Install in a CLI runtime.** Claude Code, Codex, or Gemini CLI only.
2. **Connect the project.** Onboarding records local/theme metadata, requires a
   readable GitHub origin, builds an SSH alias, and verifies remote WP-CLI.
3. **Analyze once.** Fixed read-only commands capture the live WordPress
   application; a bounded local scan captures the theme's structure.
4. **Explain.** The skill writes `.claude/capabilities.md`,
   `.claude/architecture.md`, and five generated architecture files.
5. **Develop locally.** It follows the recorded project mode and existing stack.
6. **Ship through gates.** GitHub, CI/CD, QA, explicit confirmation, and backup
   acknowledgement control staging and production.
7. **Write back.** Decisions and completed work remain in the committed project
   layer for the next session.

## Project documentation

```text
{theme-root}/.claude/
├── CLAUDE.md                  # durable project decisions
├── capabilities.md           # generated operating boundary
├── architecture.md           # generated summary and read order
├── ci-cd.md                  # durable deployment contract
├── changelog/                # durable work history
├── docs/                     # generated read-only architecture snapshot
│   ├── 01-infrastructure.md
│   ├── 02-application.md
│   ├── 03-theme-architecture.md
│   ├── 04-content-structure.md
│   └── 05-issues.md
└── skills/                   # project-specific extensions
```

Generated files can be replaced by a rescan. Durable decisions belong in
`CLAUDE.md`; durable history belongs in `changelog/`. Everything in `.claude/` is
safe to commit because secrets are stored elsewhere.

## Inside the skill

| Path | Role |
|---|---|
| `SKILL.md` | CLI development boundary, project modes, onboarding gates, and delivery workflow. |
| `onboarding.md` | Required GitHub, SSH, WP-CLI, scanner, and project-documentation sequence. |
| `scripts/` | Cross-platform initialization, architecture scans, sync, SSH checks, and staged deployment. |
| `development-guides/` | Development conventions, Git workflow, QA, safety, and local WordPress guidance. |
| `templates/` | Theme-local capabilities, architecture, CI/CD, changelog, docs, and workflow contracts. |
| `install.md` | Supported CLI runtimes, prerequisites, first run, and credential rules. |

This is the installed `norml-wp-developer/` source. It stays separate from the
theme-local `.claude/` project record above, which Advanced generates and commits
with the connected theme.

## Say this to the Copilot

| Need | Example request |
|---|---|
| First connection | “Set up this project for Norml WordPress Copilot Advanced.” |
| Explain the project | “Explain this architecture and the limits in capabilities.md.” |
| Build within the theme | “Add a testimonial ACF block following the existing component system.” |
| Implement structure | “Build a case-study CPT with its archive and single templates.” |
| Refresh evidence | “Rescan the WordPress and theme architecture.” |
| Stage a release | “Ship this branch to staging and run the documented QA gate.” |
| Promote | “Promote the verified staging release to production.” |

## Requirements

- Claude Code, Codex, or Gemini CLI with terminal and filesystem access.
- Local theme repo and local WordPress environment.
- GitHub origin with valid authentication.
- Production SSH access and remote WP-CLI in the exact WordPress root.
- A declared CI/CD and backup strategy.

Claude Desktop / Cowork is not supported by Advanced.

## Credential safety

- GitHub authentication stays in GitHub CLI, SSH, or the OS credential store.
- SSH private keys stay under `~/.ssh/`; passphrases stay in ssh-agent and the OS
  secret store.
- Per-machine config contains connection metadata only.
- `.claude/`, Git commits, workflow files, command arguments, and chat never contain
  tokens, passwords, private keys, or database credentials.

## Safety boundary

Read-only inspection runs directly. Local writes and Git state changes require
confirmation. Staging deploys require confirmation and QA. Every production write
requires explicit confirmation plus a verified backup acknowledgement. A direct
production edit is elevated, logged as `[DIRECT-PROD]`, and must be mirrored into
GitHub immediately.

## Where it sits

- **Norml WordPress Copilot** — REST/API content and administration; works in
  Desktop / Cowork and terminal runtimes; stores a local site dossier.
- **Norml WordPress Copilot Advanced** — CLI development and deployment; requires
  GitHub + SSH + WP-CLI; stores project docs in the theme repo.

## What changed in 1.2.1

- Renamed the public repository to `norml-wordpress-copilot-advanced` while
  retaining the installed `norml-wp-developer` slug for compatibility.
- Renamed the bundled source folder from `references/` to the descriptive
  `development-guides/` path and updated its links.
- Kept runtime behavior, theme-local project records, configuration paths, and
  credential references unchanged.

## What changed in 1.2.0

- Added the public Advanced product title while retaining the installed slug.
- Made the CLI-only boundary and GitHub requirement explicit.
- Added generated `capabilities.md` and `architecture.md` templates.
- Added real macOS/Linux and Windows read-only architecture scanners.
- Made the first GitHub + SSH + WP-CLI verification and architecture scan required
  during onboarding.
- Added exact installed-package path/role documentation, kept separate from the
  generated theme-local project record.

---

_Covers SKILL.md v1.2.1 | Last changelog entry: v1.2.1 | Generated: 2026-08-29. If
the skill behaves differently, trust `SKILL.md` and regenerate this guide._
