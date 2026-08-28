# Norml WordPress Copilot Advanced

Public product name: **Norml WordPress Copilot Advanced**. Installed skill:
`norml-wp-developer`.

The CLI-only Norml WordPress Copilot for theme development, GitHub, SSH, WP-CLI,
environment sync, CI/CD, staging, and production deployment. It connects a project
once, analyzes the live WordPress application plus the local theme, and stores the
durable project knowledge inside the theme repository.

## What it does

- Connects a local WordPress theme to its GitHub repository and hosting server.
- Verifies production SSH and remote WP-CLI before onboarding can finish.
- Generates `.claude/capabilities.md`, `.claude/architecture.md`, and a five-file
  architecture snapshot inside the theme repo.
- Develops Sage or inherited themes using the correct project mode.
- Runs GitHub-backed staging and production workflows with explicit QA and backup
  gates.
- Maintains a committed project changelog so later sessions and teammates inherit
  the decisions.

## When to reach for it

Use Advanced for theme/plugin code, ACF block definitions, WordPress data-model
implementation, Git branches and commits, SSH, WP-CLI, database/environment sync,
CI/CD, staging, and production deployment.

Use **Norml WordPress Copilot** (`norml-wp-manager`) for content and administration
through the REST API, especially in Claude Desktop / Cowork.

## Runtime boundary

Advanced requires a terminal and local filesystem. Supported: Claude Code, Codex,
and Gemini CLI. It does not run in Claude Desktop / Cowork.

## Install

Claude Code:

```bash
npx skills@latest add normlstudio/norml-wp-developer --skill=norml-wp-developer -g -a claude-code
```

Codex:

```bash
npx skills@latest add normlstudio/norml-wp-developer --skill=norml-wp-developer -g -a codex
```

Gemini CLI:

```bash
npx skills@latest add normlstudio/norml-wp-developer --skill=norml-wp-developer -g -a gemini-cli
```

Then open the CLI in a theme root and say:

> Set up this project for Norml WordPress Copilot Advanced.

See [`install.md`](.claude/skills/norml-wp-developer/install.md) and
[`onboarding.md`](.claude/skills/norml-wp-developer/onboarding.md).

## What onboarding creates

```text
{theme-root}/.claude/
├── CLAUDE.md
├── capabilities.md
├── architecture.md
├── ci-cd.md
├── changelog/
├── docs/
│   ├── README.md
│   ├── 01-infrastructure.md
│   ├── 02-application.md
│   ├── 03-theme-architecture.md
│   ├── 04-content-structure.md
│   └── 05-issues.md
└── skills/
```

Connection metadata stays in
`~/.config/norml-wp-developer/projects/{slug}.json`; secrets stay in GitHub's auth
store, ssh-agent, the OS secret store, and `~/.ssh/`. No secret enters `.claude/`.

## First analysis

The bundled scanner uses fixed, read-only WP-CLI commands over SSH and a bounded
local theme inventory. It records WordPress/PHP/WP-CLI versions, site URLs, active
theme, plugins, updates, post types, taxonomies, counts, menus, stack signals,
GitHub access, SSH access, and current blockers.

Onboarding fails closed if GitHub, production SSH, or remote WP-CLI cannot be
verified. Run the scan again after infrastructure or architecture changes.

## Safety boundary

- Local-first development is the default.
- Git state changes and staging deploys require confirmation.
- Every production write requires explicit confirmation plus a verified backup
  acknowledgement.
- Direct production edits are elevated, logged, and mirrored back to GitHub.
- The skill never invents SSH paths or asks for secrets in chat.

## Documentation

- [Human guide](.claude/skills/norml-wp-developer/readme.md)
- [Visual one-pager](.claude/skills/norml-wp-developer/readme.html)
- [Installation](.claude/skills/norml-wp-developer/install.md)
- [Onboarding](.claude/skills/norml-wp-developer/onboarding.md)
- [Changelog](.claude/skills/norml-wp-developer/changelog.md) — current version 1.2.0

## License

[MIT](LICENSE) © Norml Studio
