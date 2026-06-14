# norml-wp-developer

> One-sentence pitch: build WordPress themes locally and ship them to
> production through Claude Code — Git-backed, SSH-deployed, no
> credentials in chat. Pairs with `norml-wp-manager` (content) so a
> developer + content owner can each install the right tool.

## The problem

You're building a WordPress theme. You want the developer-friendly
flow — work locally, commit, push, watch CI/CD deploy to staging,
smoke test, promote to prod — but setting it up by hand is a half-day
of yak-shaving (Git remote, GitHub auth, SSH keys, GitHub Actions YAML,
WP Local config). And then maintaining it across projects is a slog.

This skill makes the setup ~30 minutes per project and the everyday
workflow basically chat-driven:

> *"Add a hero block with ACF fields."*
> *"Ship this branch to staging."*
> *"Promote staging to production."* — gated by a backup prompt.

After setup the project carries its own `.claude/` folder (committed to
git) so the next session — your future self, or a teammate, or Claude
again — starts with full context: which CI/CD pattern is in play,
which conventions to follow (Sage vs inherited), the recent changelog.

## How to use it

| When you want to… | Say something like… |
|---|---|
| Set up a new project | *"Set up this WordPress project."* (Claude runs onboarding.) |
| Add a new ACF block | *"Add a hero block with title + subtitle + CTA fields."* |
| Build a CPT | *"Build a case-study CPT with an archive page."* |
| Deploy to staging | *"Ship this to staging."* |
| Promote to production | *"Promote staging to production."* (backup prompt fires) |
| Hot-fix on production | *"Edit footer.php directly on production to fix the year."* (flagged `[DIRECT-PROD]`) |
| Pull production DB | *"Pull production database to my local."* |
| See the changelog | *"What's in the recent changelog for this project?"* |
| Re-scan architecture | *"Rescan the architecture for this project."* |

## A typical run

1. You navigate to your theme folder in Terminal.
2. Tell Claude: *"Add a testimonials block with 3 ACF rows."*
3. Claude reads `.claude/CLAUDE.md` (mode: sage), reads
   `references/dev-conventions.md`, reads the recent changelog.
4. Claude creates the block files, registers the ACF field group via
   JSON, runs `npm run build`.
5. Claude shows you the result, asks you to test locally.
6. You say *"ship to staging."* Claude commits with a Conventional
   Commit message, pushes to `develop`. CI/CD runs.
7. Claude tails the CI run, reports success.
8. You smoke-test on staging, say *"promote to prod."*
9. Claude prints the backup-acknowledgement prompt. You confirm.
10. Claude tags the release, pushes, watches the production deploy run.
11. Claude appends `[DEPLOY-PROD]` to `.claude/changelog/daily.md` and
    closes out.

---

## Details

### Setup is involved. Everyday work is fast.

Setup per project: ~30 minutes the first time. Includes:

- Detecting your local WP environment (WP Local default).
- Initializing Git, wiring a remote (GitHub default).
- SSH credentials for production (and optionally staging).
- Picking a CI/CD pattern.
- Scaffolding `.claude/` inside the theme repo.
- (Optional) first architecture scrape via SSH+WP-CLI.

Everything is in `onboarding.md`. The setup script is interactive —
Claude can drive it from chat or you can run it from a terminal. Both
flows use **native OS dialogs** to capture secrets (SSH passphrases,
GitHub PATs). You don't type them into the terminal.

After that, daily work is:

- Edit code locally (or ask Claude to).
- Commit (Claude generates the Conventional Commit message).
- Push (Claude does it).
- Watch CI/CD.
- Smoke test on staging.
- Promote to production (gated).

### What lives where

| What | Where | Why |
|---|---|---|
| The skill | `~/.claude/skills/norml-wp-developer/` | Claude Code auto-loads it. |
| Per-project config | `~/.config/norml-wp-developer/projects/{slug}.json` | Per-machine. Theme path, SSH alias, remote URL, deploy pattern. No secrets. |
| **Per-project knowledge** | **`{theme_root}/.claude/`** | **In the git repo.** Travels with the code. CLAUDE.md, ci-cd.md, rolling changelog, architecture docs. Next teammate clones the repo, gets all of it. |
| SSH key + passphrase | `~/.ssh/` + OS secret store (Keychain / Cred Mgr) | OS-managed, never in chat. |

The split is intentional. `~/.config/` is per-machine; `.claude/` is
per-project and committed; secrets live in the OS.

### The compounding `.claude/` folder

Every project gets a `.claude/` folder inside the theme repo:

```
{theme_root}/.claude/
├── CLAUDE.md         (project overview — mode, URLs, hints)
├── ci-cd.md          (deploy contract — pattern, commands, hooks)
├── changelog/
│   ├── README.md
│   ├── daily.md      (today's work)
│   ├── weekly.md     (compressed)
│   └── changelog.md  (long-term history)
├── docs/             (5-file architecture scrape — plugins, theme, content, infra)
└── skills/           (project-specific skills if you write any)
```

Claude reads all of this at every session start. Claude **writes back**
to `daily.md` before closing any non-trivial session (every code change,
every deploy, every decision). The folder gets richer with every
session — your future self benefits.

### Project mode: Sage vs Inherited

The first decision on every task: which mode is this project in?

- **Sage** — new project, Norml-authored, Roots Sage + Acorn + Blade +
  Tailwind v4 + Vite + Alpine + ACF Pro. Strict architecture rules.
  See `references/dev-conventions.md → Sage section`.
- **Inherited** — non-Sage theme handed to you by a client or another
  agency. Respect the existing architecture; apply Norml's
  framework-agnostic core principles inside it (sections / components
  / partials, ACF block registration, 3-layer CSS model). Never
  silently introduce a new framework or build system. See
  `references/dev-conventions.md → Inherited section`.

Default to "inherited" if uncertain.

### The three CI/CD patterns

| Pattern | Best for | What happens on push |
|---|---|---|
| `full-pipeline` | Serious client projects with staging | Push to `develop` → staging deploy. Tag a release → production deploy. Smoke tests after each. |
| `prod-direct-with-git` | Small site, no staging, but you want Git as safety net | Push to `main` → production deploy (with backup prompt). |
| `prod-direct-no-ci` | Tiny site, just you, no CI | `rsync` on demand from local to production (with backup prompt). |

`full-pipeline` is the default for serious projects. The other two
exist for cases where staging isn't worth the cost.

### Backups — the loudest warning

This skill **does not back up for you**. Production writes
(`rsync` to prod, `wp db import` on prod, `wp search-replace` on
prod) require an explicit "I have a backup from {date}" reply. There's
no autopilot.

What "having a backup" means:

- Your host has automatic backups on (most managed hosts do — verify
  in the hosting panel).
- Or you've taken a manual backup: a DB dump + a `wp-content/` archive,
  both stored OFF the production server.

If you lose data without a backup, the skill can't recover it. No
skill can.

### Working directly on production — permitted, flagged

The skill supports editing theme files directly on the production
server via SSH. It's faster for one-line hotfixes. It's also risky:

- The change isn't in Git, so the next CI/CD deploy can overwrite it.
- There's no rollback if it breaks.
- Your local copy is now out of sync with production.

Every direct-on-server write is flagged `[DIRECT-PROD]` in
`.claude/changelog/daily.md` and triggers a warning. The skill's
default flow is **local-first** — edit locally, commit, push, deploy.
Reach for direct-on-server only for one-off hotfixes.

### Common scenarios

**"I want to start a new Sage theme."**
Set up a fresh WP Local site, then ask: *"Set up this as a new Sage
project."* Claude runs `composer create-project roots/sage` (or
walks you through it), initializes git, wires GitHub, scaffolds
`.claude/`, picks the full-pipeline CI/CD.

**"A client gave me their existing theme — non-Sage."**
Drop the theme into your WP Local site, then ask: *"Set up this
inherited project."* Claude scrapes the existing architecture into
`.claude/docs/`, sets `mode: inherited` in `.claude/CLAUDE.md`,
picks a CI/CD pattern with you, and from then on respects the
existing architecture.

**"I broke production and need to roll back."**
The skill doesn't do rollback for you — that's a backup-restoration
task. Use your host's backup restore feature, or your manual
backup. The skill CAN re-deploy the last known good Git tag if your
production has been kept in sync with Git.

**"I want a teammate to pick up where I left off."**
The teammate clones the theme repo. They run
`norml-wp-developer` setup against it — they get their own SSH
config, their own connection JSON, but the `.claude/` folder
(committed) gives them all the project knowledge instantly.

### Related skills

- `norml-wp-manager` — REST API content management on a deployed
  site. Install both. The two have non-overlapping scopes: the
  developer skill handles theme code + deploys; the manager
  skill handles content + ACF values on the live site.

### Troubleshooting

| Issue | Fix |
|---|---|
| Setup says "no local WP detected" | Make sure your local WP environment is running. WP Local: green dot. DDEV: `ddev start`. |
| Push to GitHub failed | Run `gh auth status` to verify. If broken, `gh auth login`. |
| Deploy to staging failed | Check the GHA run. Most common: PHP version mismatch (theme's composer.json requires newer PHP than server has). |
| `Permission denied (publickey)` | Re-add your public key to the server's SSH key panel. |
| Production write asks for backup acknowledgement every time | That's by design. There's no way to skip it. |

---

_Covers SKILL.md v1.0.0. If Claude does something different from
what's written here, this file is stale — trust `SKILL.md`._
