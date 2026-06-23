# norml-wp-developer

> Build WordPress themes locally and ship them to staging and production through
> Claude Code — Git-backed, SSH-deployed, no credentials in chat. Setup is ~30
> minutes per project; everyday work is chat-driven. Pairs with
> [`norml-wp-manager`](https://github.com/Norml-Studio/norml-wp-manager) (content)
> so a developer and a content owner can each install the right tool.

## The problem

You're building a WordPress theme and you want the developer-friendly flow — work
locally, commit, push, watch CI/CD deploy to staging, smoke test, promote to prod.
But wiring that up by hand is half a day of yak-shaving: Git remote, GitHub auth,
SSH keys, GitHub Actions YAML, local WP config. And maintaining it across a dozen
client projects is its own tax.

This skill makes the per-project setup about 30 minutes, then turns the everyday
workflow basically chat-driven:

> *"Add a hero block with ACF fields."*
> *"Ship this branch to staging."*
> *"Promote staging to production."* — gated by a backup prompt.

After setup, each project carries its own committed `.claude/` folder, so the next
session — your future self, a teammate, or Claude again — starts with full context:
which CI/CD pattern is in play, which conventions to follow (Sage vs inherited), and
the recent changelog.

> ⚠️ **This skill does not make backups.** Production writes refuse to run without an
> explicit "I have a backup" acknowledgement. It assumes the host has automatic
> backups on, or that you take manual ones before destructive ops.

## How to use it

| When you want to… | Say something like… |
|---|---|
| Set up a new project | *"Set up this WordPress project."* (runs onboarding) |
| Add an ACF block | *"Add a hero block with title + subtitle + CTA fields."* |
| Build a CPT | *"Build a case-study CPT with an archive page."* |
| Deploy to staging | *"Ship this to staging."* |
| Promote to production | *"Promote staging to production."* (backup prompt fires) |
| Hot-fix on production | *"Edit footer.php directly on production to fix the year."* (flagged `[DIRECT-PROD]`) |
| Pull production DB | *"Pull production database to my local."* |
| See the changelog | *"What's in the recent changelog for this project?"* |
| Re-scan architecture | *"Rescan the architecture for this project."* |

## A typical run

1. You navigate to your theme folder in Claude Code.
2. Tell Claude: *"Add a testimonials block with 3 ACF rows."*
3. Claude reads `.claude/CLAUDE.md` (mode: sage), the relevant `conventions/`
   reference, and the recent changelog.
4. Claude creates the block files, registers the ACF field group via JSON, runs
   `npm run build`.
5. Claude shows you the result, asks you to test locally.
6. You say *"ship to staging."* Claude commits with a Conventional Commit message,
   pushes to `develop`. CI/CD runs.
7. Claude tails the CI run, reports success.
8. You smoke-test on staging, say *"promote to prod."*
9. Claude prints the backup-acknowledgement prompt. You confirm.
10. Claude tags the release, pushes, watches the production deploy run.
11. Claude appends `[DEPLOY-PROD]` to `.claude/changelog/daily.md` and closes out.

---

## Details

### Setup is involved. Everyday work is fast.

Setup per project: ~30 minutes the first time. It detects your local WP environment
(WP Local by default; DDEV, Lando, Local Lightning, Valet+, MAMP recognized),
initializes Git and wires a remote (GitHub default; Bitbucket / GitLab supported),
collects SSH credentials for production (and optionally staging), picks a CI/CD
pattern, scaffolds `.claude/` inside the theme repo, and optionally runs a first
architecture scrape via SSH + WP-CLI.

Everything is in `onboarding.md`. The setup script is interactive — Claude can drive
it from chat or you can run it from a terminal. Both flows use **native OS dialogs**
to capture secrets (SSH passphrases, GitHub PATs). You don't type them into the
terminal.

### What lives where

| What | Where | Why |
|---|---|---|
| The skill | `~/.claude/skills/norml-wp-developer/` | Claude Code auto-loads it. |
| Per-project config | `~/.config/norml-wp-developer/projects/{slug}.json` | Per-machine. Theme path, SSH alias, remote URL, deploy pattern. **No secrets.** |
| **Per-project knowledge** | **`{theme_root}/.claude/`** | **In the git repo.** Travels with the code. `CLAUDE.md`, `ci-cd.md`, rolling changelog, architecture docs. Next teammate clones the repo, gets all of it. |
| SSH key + passphrase | `~/.ssh/` + OS secret store (Keychain / Cred Mgr) | OS-managed, never in chat. |

The split is intentional: `~/.config/` is per-machine connection state; `.claude/`
is portable per-project knowledge; the OS secret store is for secrets.

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
├── docs/             (5-file architecture scrape — infra, plugins, theme, content, issues)
└── skills/           (project-specific skills if you write any)
```

Claude reads this at every session start and **writes back** to `daily.md` before
closing any non-trivial session (every code change, every deploy, every decision).
The folder gets richer with every session — your future self benefits.

### Project mode: Sage vs Inherited

The first decision on every task: which mode is this project in?

- **Sage** — new project, Roots Sage + Acorn + Blade + Tailwind v4 + Vite + Alpine +
  ACF Pro. Strict architecture rules. The depth lives in
  `references/conventions/`: `sage-stack.md` (the framework foundation),
  `component-system.md` (sections / components / partials), `css-architecture.md`
  (the 3-layer CSS model), `acf-blocks.md` (block registration + previews).
- **Inherited** — non-Sage theme handed to you by a client or another agency.
  Respect the existing architecture; apply the framework-agnostic core principles
  inside it (sections / components / partials, ACF block registration, the 3-layer
  CSS model). **Never silently introduce a new framework or build system.** See
  `references/conventions/inherited-projects.md`.

`references/dev-conventions.md` is the router into all of the above. Default to
"inherited" if uncertain.

### The three CI/CD patterns

| Pattern | Best for | What happens on push |
|---|---|---|
| `full-pipeline` | Serious client projects with staging | Push to `develop` → staging deploy. Tag a release → production deploy. Smoke tests after each. |
| `prod-direct-with-git` | Small site, no staging, Git as the safety net | Push to `main` → production deploy (with backup prompt). |
| `prod-direct-no-ci` | Tiny site, just you, no CI | `rsync` on demand from local to production (with backup prompt). |

`full-pipeline` is the default for serious projects. The full catalog lives in
`references/ci-cd/` — `patterns.md` (the three patterns), `database-strategies.md`
(how content / the database is handled, and the rules that stop you clobbering live
data), and `backup-strategies.md` (four provider types, restore runbooks, and how
each maps to the backup-acknowledgement tiers).

### QA gates

Every deploy runs through `references/qa-gates.md`: a **pre-merge** check (CI + review,
or a local self-check on solo projects), a **pre-deploy** gate (on the staging URL for
`full-pipeline`, on local for the prod-direct patterns), and a **post-deploy** gate
(always on the production URL — smoke test, top pages, ACF values render, analytics
fires). Hotfixes don't skip the gates; they go faster by being minimal.

### Backups — the loudest warning

This skill **does not back up for you**. Production writes (`rsync` to prod,
`wp db import` on prod, `wp search-replace` on prod) require an explicit
"I have a backup from {date}" reply. There's no autopilot.

What "having a backup" means:

- Your host has automatic backups on (most managed hosts do — verify in the panel).
- Or you've taken a manual backup: a DB dump + a `wp-content/` archive, both stored
  **off** the production server.

If you lose data without a backup, the skill can't recover it. No skill can.

### Working directly on production — permitted, flagged

The skill supports editing theme files directly on the production server via SSH.
It's faster for one-line hotfixes. It's also risky: the change isn't in Git (the next
CI/CD deploy can overwrite it), there's no rollback if it breaks, and your local copy
drifts out of sync. Every direct-on-server write is flagged `[DIRECT-PROD]` in
`.claude/changelog/daily.md` and triggers a warning. The default flow is
**local-first** — edit locally, commit, push, deploy.

### Common scenarios

**"I want to start a new Sage theme."**
Set up a fresh WP Local site, then ask: *"Set up this as a new Sage project."* Claude
runs `composer create-project roots/sage` (or walks you through it), initializes git,
wires GitHub, scaffolds `.claude/`, picks the full-pipeline CI/CD.

**"A client gave me their existing theme — non-Sage."**
Drop the theme into your WP Local site, then ask: *"Set up this inherited project."*
Claude scrapes the existing architecture into `.claude/docs/`, sets `mode: inherited`
in `.claude/CLAUDE.md`, picks a CI/CD pattern with you, and from then on respects the
existing architecture.

**"I broke production and need to roll back."**
The skill doesn't do rollback for you — that's a backup-restoration task. Use your
host's restore feature, or your manual backup. The skill CAN re-deploy the last
known-good Git tag if production has been kept in sync with Git.

**"I want a teammate to pick up where I left off."**
The teammate clones the theme repo. They run setup against it — their own SSH config,
their own connection JSON — but the committed `.claude/` folder gives them all the
project knowledge instantly.

### Related skills

- **`norml-wp-manager`** — REST-API content management on a deployed site. Install
  both. Non-overlapping scopes: this skill handles theme code + deploys; the manager
  skill handles content + ACF values on the live site. They share no state.

### Troubleshooting

| Issue | Fix |
|---|---|
| Setup says "no local WP detected" | Make sure your local WP environment is running. WP Local: green dot. DDEV: `ddev start`. |
| Push to GitHub failed | Run `gh auth status` to verify. If broken, `gh auth login`. |
| Deploy to staging failed | Check the GHA run. Most common: PHP version mismatch (theme's `composer.json` requires newer PHP than the server has). |
| `Permission denied (publickey)` | Re-add your public key to the server's SSH key panel. |
| Production write asks for backup acknowledgement every time | That's by design. There's no way to skip it. |

---

_Covers SKILL.md v1.1.0. The visual one-pager is `readme.html`. If Claude does
something different from what's written here, this file is stale — trust `SKILL.md`._
