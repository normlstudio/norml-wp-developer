# Norml WordPress Copilot Advanced — onboarding

Installed skill: `norml-wp-developer`.

Run onboarding once per WordPress theme repository. It connects the local theme,
GitHub, and the production server; verifies WP-CLI; chooses a deployment contract;
then stores the project knowledge inside the theme's committed `.claude/` folder.

## Runtime boundary

This skill is **CLI only**. Use Claude Code, Codex, or Gemini CLI with terminal and
filesystem access. It does not run in Claude Desktop / Cowork. Desktop users who
need content/admin work should use Norml WordPress Copilot (`norml-wp-manager`).

## Prerequisites

- A local WordPress theme folder containing `style.css`.
- A running or configured local WordPress environment: WP Local, DDEV, Lando,
  Valet, or a manually supplied local URL.
- Git and a GitHub repository you are authorized to use.
- SSH access to the production server, with the public key accepted by the host.
- WP-CLI available from the configured production WordPress root.
- `python3` on macOS/Linux. Windows uses PowerShell 5.1+.

Never paste an SSH passphrase, GitHub token, hosting password, or database password
into chat. Use GitHub's supported login flow, ssh-agent, and the OS secret store.

## Start

Open the CLI runtime in the local theme root and say:

> Set up this project for Norml WordPress Copilot Advanced.

Or run the platform script directly.

macOS:

```bash
bash <skill-folder>/scripts/setup-macos.sh
```

Windows PowerShell:

```powershell
& <skill-folder>\scripts\setup-windows.ps1
```

## What setup verifies

### 1. Theme and project mode

The current folder must contain `style.css`. Choose:

- `sage` for a Roots Sage / Acorn project;
- `inherited` for an existing non-Sage theme whose conventions must be preserved.

When uncertain, choose `inherited`.

### 2. Local WordPress

Setup detects WP Local, DDEV, or Lando when possible and records the local URL.
It never writes database credentials into project documentation.

### 3. GitHub

The theme must be a Git repository with an `origin` on `github.com`. Setup performs
a read-only `git ls-remote origin` check. An origin on another provider, a missing
origin, or failed GitHub authentication blocks onboarding.

Authenticate through a supported GitHub path—such as `gh auth login` or an SSH key
attached to GitHub—then rerun setup. No GitHub token belongs in chat or `.claude/`.

### 4. Production SSH

Setup records the SSH host, port, user, key path, production WordPress path, and
production theme path in the private per-machine project config. If a new key is
needed, setup generates it and shows only the public key for the hosting panel.

The SSH alias is written under `~/.ssh/config`; the private key remains under
`~/.ssh/`; a passphrase remains in ssh-agent and the OS secret store.

### 5. Optional staging and CI/CD contract

Staging is optional. The deployment contract is one of:

| Pattern | Shape |
|---|---|
| `full-pipeline` | GitHub → staging → verified promotion to production |
| `prod-direct-with-git` | GitHub-backed production deployment without staging |
| `prod-direct-no-ci` | Local rsync deployment, still backed by GitHub source history |

Production writes always require explicit confirmation and a verified backup
acknowledgement, regardless of pattern.

### 6. Theme-local project documentation

Setup creates:

```text
{theme-root}/.claude/
├── CLAUDE.md
├── capabilities.md
├── architecture.md
├── ci-cd.md
├── changelog/
│   ├── README.md
│   ├── daily.md
│   ├── weekly.md
│   └── changelog.md
├── docs/
│   ├── README.md
│   ├── 01-infrastructure.md
│   ├── 02-application.md
│   ├── 03-theme-architecture.md
│   ├── 04-content-structure.md
│   └── 05-issues.md
└── skills/
    └── README.md
```

This folder is committed with the theme. It contains project knowledge, never
secrets.

### 7. Required first analysis

Onboarding ends by running the bundled architecture scanner. It verifies GitHub,
production SSH, remote WP-CLI, and optional staging SSH. It then uses fixed,
read-only WP-CLI commands to collect:

- WordPress, PHP, and WP-CLI versions;
- site/home URLs and active theme;
- themes, plugins, and update signals;
- post types, taxonomies, content counts, and menus;
- local theme stack signals and a bounded source inventory.

The output is the generated `capabilities.md`, the `architecture.md` index, and the
five detailed files under `.claude/docs/`. Missing GitHub, SSH, or WP-CLI is a hard
onboarding blocker rather than a partially configured success.

## After onboarding

Ask:

> Explain this WordPress project, its architecture, and what you can safely do.

The answer must come from `.claude/capabilities.md`, `.claude/architecture.md`, and
the detailed snapshot—not assumptions. Then work normally:

- “Add a hero ACF block following this theme's architecture.”
- “Build a case-study post type with archive and single templates.”
- “Ship this branch to staging.”
- “Rescan the WordPress architecture.”

## Storage model

| Data | Location | Committed? |
|---|---|---|
| Connection metadata | `~/.config/norml-wp-developer/projects/{slug}.json` | No |
| Theme/project knowledge | `{theme-root}/.claude/` | Yes |
| GitHub auth | GitHub CLI or SSH agent / OS credential store | No |
| SSH private key | `~/.ssh/` | No |
| SSH passphrase | ssh-agent + OS secret store | No |

## Rescan

After plugins, themes, content types, server versions, repository access, or
deployment topology changes:

```bash
bash <skill-folder>/scripts/scrape-architecture.sh <project-slug>
```

```powershell
& <skill-folder>\scripts\scrape-architecture.ps1 <project-slug>
```

Generated capability and architecture files are replaced. Durable decisions remain
in `.claude/CLAUDE.md`; work history remains in `.claude/changelog/`.

## Troubleshooting

| Symptom | Resolution |
|---|---|
| GitHub origin is rejected | Change `origin` to the authorized `github.com` repository. |
| GitHub remote cannot be read | Complete GitHub authentication, then rerun setup. |
| `Permission denied (publickey)` | Add the generated public key to the exact hosting account and verify the SSH alias. |
| `wp: command not found` | Ask the host to provide WP-CLI or install it in the configured server environment. |
| Wrong WordPress path | Correct `production.wp_path` in the private project config and rescan. |
| Staging fails but production works | Correct the staging SSH alias; production onboarding can remain valid, but staging deploys stay blocked. |

## Safety boundary

The first scan is read-only. Development writes require confirmation. Every
production write requires confirmation plus backup acknowledgement. Direct
production edits are elevated, logged, and must be mirrored back to GitHub so live
code never remains ahead of source control.
