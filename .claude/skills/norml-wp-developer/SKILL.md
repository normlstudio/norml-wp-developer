---
name: norml-wp-developer
version: 1.1.0
requires_onboarding: true
description: >
  Develop WordPress themes locally and deploy to staging + production
  via SSH + Git + GitHub Actions. WP Local is the default local env
  (DDEV / Lando / Valet recognized too). Per-project setup is ~30 min
  one-time (local WP, Git repo, GitHub remote, SSH credentials, CI/CD
  pattern, .claude/ scaffold in the theme repo); everyday workflow is
  fast — edit locally, commit, push, CI/CD ships to staging, smoke
  test, promote to prod. **Does NOT make backups.** Every production
  write gates on a backup acknowledgement. Direct-on-server work is
  permitted but flagged and logged. Local-first is the default. Use
  when the user says "build a WordPress theme," "develop a WP site,"
  "set up a new WP project," "init this WP project," "ship to
  staging," "deploy to production," "promote to prod," "set up CI/CD
  for WordPress," "what's the deploy flow," "pull production DB,"
  "rescan architecture," "norml-wp-developer," or
  "/norml-wp-developer." Companion: `norml-wp-manager` (REST-only
  content mgmt). The two share no state.
metadata:
  author: "Norml Studio"
---

# norml-wp-developer

> **Requires onboarding.** Before this skill can do anything, the user must
> run `onboarding.md` once per project on their machine. If
> `~/.config/norml-wp-developer/projects/{slug}.json` is missing for the
> project they're asking about, hard-stop and point at `onboarding.md`.
> Never improvise the SSH connection by asking for host/port/passphrase in
> chat.

> ## ⛔ HARD WARNING — backups are not optional and not provided
>
> This skill does **not** make backups for you. The flows here — `rsync`
> over SSH, `wp db import`, theme deploys, `wp search-replace` — can lose
> data if a step fails or a wrong path is passed. You are expected to:
>
> - Keep host-side automatic backups on (most managed hosts have this on
>   by default; verify in your hosting panel).
> - Or take a manual backup before any destructive operation. A safe
>   manual backup is two things: a database dump and a `wp-content/`
>   archive. Both must live OFF the server you're deploying to.
>
> Every deploy command in this skill prints a backup-acknowledgement
> prompt — you confirm a backup exists before the command runs. The
> default answer is "no, abort." There is no autopilot here. **If you
> lose data, you lose data.** No skill can recover it.

> ## 🟡 Working directly on the production server is elevated risk
>
> The skill supports two modes:
>
> 1. **Local-first (recommended).** Develop locally against WP Local /
>    DDEV / similar. Commit to Git. Push. CI/CD ships to staging, you
>    smoke test, then promote to production. Mistakes stay local until
>    you explicitly promote them. **This is the pattern setup defaults
>    to.**
> 2. **Direct-on-server.** Edit theme files on the production server via
>    SSH. Faster for one-line hotfixes; risky because there's no
>    local copy to fall back to and the next CI/CD deploy can
>    overwrite your live edit if it isn't mirrored to Git. Permitted
>    but every direct-on-server write is logged as `[DIRECT-PROD]` in
>    the project changelog and triggers a warning that the change is
>    not in Git.
>
> Default to local-first. Reach for direct-on-server only when the
> developer has explicitly chosen it for a specific operation.

## When to use

Any request to **build, modify, or deploy theme code** for a WordPress
site. Typical asks:

- *"Set up a new WordPress project from scratch."*
- *"Initialize this WordPress theme repo — scaffold `.claude/`, set up
  Git, wire it to GitHub."*
- *"Build a hero block with ACF fields."*
- *"Add a new ACF block to the existing theme."*
- *"Ship this to staging."*
- *"Promote staging to production."*
- *"Hot-fix a typo on production — direct on the server."*
- *"Pull production database down to my local."*
- *"What's the CI/CD pattern for this project?"*

## Skip if

- The work is **content management on a deployed site** (posts, ACF
  values, media, users, settings). → use `norml-wp-manager`. That skill
  is REST-API-only, doesn't require SSH, and is safer to hand to
  non-developers.
- The work is **fixing the WordPress install itself** (broken database,
  corrupted core files, hosting migration). → escalate to the hosting
  provider's support or use a dedicated migration skill.
- The work is **security testing / penetration testing**. → use a
  dedicated security skill.

## Three-phase mental model

Every interaction with this skill falls into one of three phases. Each
phase has its own rules + safety posture.

### 1. Setup (one-time per project, ~30 minutes)

Done once per project. Outputs:

- `~/.config/norml-wp-developer/projects/{slug}.json` — per-project
  connection config (no secrets).
- SSH key (existing or generated) registered with `ssh-agent`.
- SSH passphrase (if any) in macOS Keychain / Windows Credential Manager.
- Local WordPress environment detected (WP Local default; DDEV / Lando /
  Valet / Local Lightning recognized as alternates).
- Git repo initialized in the theme folder, first commit made.
- Remote configured (GitHub default; Bitbucket / GitLab supported).
- `.claude/` scaffolded inside the theme repo with `CLAUDE.md`,
  `ci-cd.md`, rolling changelog, and an empty `docs/` for the
  architecture scrape.
- CI/CD pattern chosen + `.github/workflows/` (or
  `.bitbucket-pipelines.yml`) scaffolded.
- Optional first-time architecture scrape via `wp-cli` over SSH.

See `references/wp-local-setup.md` for the local environment details and
`onboarding.md` for the step-by-step.

### 2. Develop (the everyday workflow)

After setup, building is the bulk of the work. Rules vary by project mode:

- **New / Sage-based project (Norml-authored):** Roots Sage + Acorn +
  Blade + Tailwind v4 + Vite + Alpine.js + ACF Pro. Read
  `references/dev-conventions.md` → Mode A, which routes to
  `conventions/sage-stack.md`, `component-system.md`,
  `css-architecture.md`, and `acf-blocks.md`.
- **Inherited project (non-Sage, handed to us):** respect the existing
  architecture. Apply the framework-agnostic core principles
  (section/component/partial separation, ACF block registration,
  block previews, 3-layer CSS model) inside the existing theme.
  Read `references/dev-conventions.md` → Mode B, which routes to
  `conventions/inherited-projects.md` (+ `css-architecture.md` and
  `acf-blocks.md` for the cross-cutting specifics).

Git workflow + commit conventions are the same for both:
GitHub Flow + Conventional Commits. See `references/git-workflow.md`.

### 3. Deploy (the gated, backup-required workflow)

The deploy phase runs:

- `npm run build` (or yarn / pnpm equivalent) → produces production
  assets.
- `git push` → triggers CI/CD if configured.
- Or `rsync -avz --delete` over SSH for direct deploys (no CI/CD).
- `wp cache flush` + `wp acorn view:cache` (Sage projects) on the
  server after deploy.
- Smoke test (HEAD on the homepage, follow-up GET on a CPT archive).
- For staging→prod promotions: re-run the staging deploy steps against
  the production server.

Every deploy gates on the **backup acknowledgement prompt** described in
the HARD WARNING block above. Without acknowledgement, the deploy
aborts. See `references/ci-cd/patterns.md` for the three supported
patterns and their command sequences, `references/qa-gates.md` for the
pre-deploy and post-deploy QA checkpoints (staging-based for
`full-pipeline`, local-based for the prod-direct patterns), and
`references/ci-cd/backup-strategies.md` for the per-provider backup +
restore detail behind the acknowledgement.

## Pre-flight (every session, before the first dev/deploy operation)

1. **Resolve the project slug** from the user's request, the working
   directory, or by asking. Slugs are kebab-cased.

2. **Read `~/.config/norml-wp-developer/projects/{slug}.json`.**
   - If missing → hard-stop. Tell the user the project isn't
     configured and point them at `onboarding.md`. Do NOT improvise SSH
     details in chat.

3. **Read the project's `.claude/CLAUDE.md` and `.claude/ci-cd.md`**
   from the theme repo path in the project JSON.
   - If `.claude/` is missing → tell the user the project isn't
     initialized and offer to run init (scripts/init-claude.sh /
     init-claude.ps1) to scaffold it. Don't proceed with dev work
     against an un-initialized repo.

4. **Read the project changelog** at
   `{theme_root}/.claude/changelog/daily.md` (or `changelog.md` if the
   project skipped the rolling-three-tier setup). Surface the most
   recent entries — they tell you what was just done.

5. **Identify the project mode** from `.claude/CLAUDE.md`:
   - `mode: sage` → New / Norml-authored. Apply Sage conventions.
   - `mode: inherited` → Respect the existing theme. Apply
     framework-agnostic principles.

6. **Resolve the SSH alias** to the production server from the project
   JSON. Confirm the alias exists in `~/.ssh/config` (the setup script
   writes it; if it's missing, re-run setup).

7. **Identify the deploy pattern** from `.claude/ci-cd.md`:
   - `full-pipeline` — Git push → CI/CD → staging → manual promote → prod
   - `prod-direct-with-git` — Git push → server pulls from Git → prod
   - `prod-direct-no-ci` — rsync from local → prod (no Git push step)

You now have everything needed to operate. **Never** ask for SSH
passphrases, GitHub tokens, or server passwords in chat. If anything's
missing, point back at onboarding.

## Project knowledge layer — inside the theme repo

Every project carries its own `.claude/` directory **inside the theme
repository** (not in the user's project folder, not on Drive — inside
the repo, so it travels with the code).

```
{theme_root}/.claude/
├── CLAUDE.md                 # Project overview, mode (sage/inherited), pointers
├── ci-cd.md                  # Per-project deploy contract (pattern, envs, hooks)
├── changelog/
│   ├── README.md             # The rolling-three-tier protocol
│   ├── daily.md              # Today's raw entries
│   ├── weekly.md             # Compressed week
│   └── changelog.md          # Long-term history
├── docs/                     # 5-file architecture scrape (optional but recommended)
│   ├── 01-infrastructure.md
│   ├── 02-application.md
│   ├── 03-theme-architecture.md
│   ├── 04-content-structure.md
│   └── 05-issues.md
└── skills/                   # Project-specific skills (empty by default)
```

This is the **canonical knowledge layer for this project**. Both the
human developer and Claude read from it at every session. It is **in
git, committed with the theme code, travels everywhere the repo
travels.**

### Why `.claude/` lives in the theme repo (not in `~/.config/` or on
Drive)

| Concern | Where it lives | Why |
|---|---|---|
| Connection details (host, port, SSH key path, Git remote URL) | `~/.config/norml-wp-developer/projects/{slug}.json` | Per-machine, private. Doesn't travel with the code. |
| Project knowledge (architecture, conventions, decisions, changelog) | `{theme_root}/.claude/` | Lives with the code, travels in git, available to anyone who clones the repo. |
| Secrets (SSH passphrase, GitHub PAT) | macOS Keychain / Windows Credential Manager / ssh-agent | OS-managed. Claude never sees the value. |

This split is non-negotiable. **Never write a secret into
`{theme_root}/.claude/` — those files are committed to git.** Never write
deploy state or build artifacts into `~/.config/` either — they're
per-machine config, not knowledge.

## Write-back rules — how the skill compounds knowledge per-project

The point of `.claude/` is that **every session leaves it richer**. Three
write-back triggers:

### `daily.md` — close-of-session changelog (always)

Append an entry to `{theme_root}/.claude/changelog/daily.md` before
ending any session that:

- Wrote theme code (component, block, template, function)
- Ran a deploy to staging or production
- Performed a direct-on-server edit
- Pulled production DB / uploads to local
- Made a non-trivial decision the next session would benefit from
  knowing

Tags:

- `[CODE]` — theme code change
- `[BUILD]` — Vite / Composer / NPM build ran
- `[DEPLOY-STAGING]` — push or deploy to staging
- `[DEPLOY-PROD]` — promote to prod (gated by backup acknowledgement)
- `[DIRECT-PROD]` — edit made directly on the production server (high
  risk, flag the un-mirrored-to-git status)
- `[PULL-DB]` — production DB pulled to local
- `[PULL-UPLOADS]` — production uploads pulled to local
- `[DECISION]` — architectural choice worth recording
- `[LEARNED]` — non-obvious fact about this project

The daily file compresses to `weekly.md` weekly and to `changelog.md`
when the calendar quarter rolls over — see
`{theme_root}/.claude/changelog/README.md` for the protocol the init
flow scaffolds.

### `.claude/CLAUDE.md` — project-level decisions

When the user makes a project-level decision ("from now on this site
uses BEM for component class names," "we always set `show_in_rest:
true` on ACF field groups"), update the relevant section of
`CLAUDE.md`. This file is the durable answer to "how do we work on
this project."

### `.claude/docs/` — architecture scrape (rescan only)

The 5-file architecture scrape is generated by the
`scripts/scrape-architecture.sh` flow over SSH+WP-CLI. It's a snapshot,
overwritten on rescan. Anything that should survive a rescan goes in
`CLAUDE.md` or `daily.md`, never edited by hand into `docs/`.

## Safety classification — every operation buckets

Three buckets:

- **Safe** — read-only or low-risk single-item operations. Run
  immediately. Examples: `git status`, `git log`, `wp post list` on
  local, reading any file under the theme repo, listing the active
  plugin set.

- **Confirm** — anything that writes to the local repo, to staging, or
  changes git state. Show the exact command, show the diff if relevant,
  ask for "yes" before running. Examples: `git commit`, `git push`,
  `git rebase`, `rsync` to staging, `wp plugin install` on local,
  database imports.

- **Confirm + backup** — anything that writes to the production server.
  Show the exact command, **show the backup-acknowledgement prompt**,
  refuse without an explicit "I have a backup from {date}" reply.
  Examples: `rsync` to production, `wp db import` on production,
  `wp search-replace` on production, deleting plugin/theme files on
  production, direct file edits over SSH on production.

The backup-acknowledgement prompt is mandatory for every production
write. There is no "skip the prompt" flag. If the project's
`.claude/ci-cd.md` declares the host has automatic backups (and we
trust the host), the prompt may be answered with "yes, host backups
verified" — but only if `ci-cd.md` says so, and only after the user
explicitly types that phrase.

## Output style

- Default to terse. The user wants the result.
- When you ran a command, show the command first (one line, monospaced).
- For `Confirm + backup` operations, the backup prompt is mandatory and
  shown verbatim. Don't paraphrase it.
- For diffs, prefer `git diff --stat` for summary + the full diff on
  request rather than dumping 500 lines unprompted.

## Error handling

- **SSH refused / timeout** → don't retry. Suggest the user run
  `scripts/test-ssh.sh` and check their `~/.ssh/config` alias.
- **`wp: command not found` on the remote** → WP-CLI not installed on
  the server. Stop, tell the user, suggest contacting their host.
- **`Composer detected ... platform_check.php`** → server PHP < theme's
  Composer floor. Stop, point at the `composer.json` `require.php`
  line, tell the user to either bump the server PHP or lower the
  theme's floor.
- **Git conflicts** → don't auto-resolve. Show the conflicting files,
  let the user pick the side. Conventional Commit rules in
  `references/git-workflow.md`.
- **Build failures** → show the full Vite / Composer / NPM error, stop,
  do not deploy with a failing build.
- **Deploy failures mid-flight** → stop immediately. Tell the user the
  exact step that failed. Do not auto-retry — partial deploys are the
  most common cause of broken production.

In all cases, **fail loudly and stop**. No improvised destructive
recovery.

## Knowledge baseline — what the skill reads

| File | When to read |
|---|---|
| `references/dev-conventions.md` | At the start of any session that touches theme code. The **router** — routes to the right `conventions/` files by project mode, plus the global rules (Conventional Commits, don't-commit artifacts/secrets, ACF JSON sync caveat). |
| `references/conventions/sage-stack.md` | Sage / new projects, before building. The Sage + Acorn + Blade + Tailwind v4 + Vite + Alpine + ACF Pro foundation. |
| `references/conventions/component-system.md` | Before building a section / component / block in a Sage project. Anatomy + core component catalog + the Alpine pattern + layout. |
| `references/conventions/css-architecture.md` | Before writing ANY CSS, **either mode**. The 3-layer model + the forbidden per-page-stylesheet rule. |
| `references/conventions/acf-blocks.md` | Before registering an ACF block or its preview, **either mode**. Registration + previews + ACF JSON sync. |
| `references/conventions/inherited-projects.md` | FIRST, whenever you open a non-Sage / inherited theme. Respect-existing decision flow + framework-agnostic principles. |
| `references/git-workflow.md` | Before any `git commit`, `git push`, branch creation, or PR. GitHub Flow + Conventional Commits. |
| `references/ci-cd/patterns.md` | Before any deploy or any CI/CD configuration task. The three supported patterns and the per-project `ci-cd.md` contract. |
| `references/ci-cd/database-strategies.md` | When content / the database moves (or must not move) between environments. |
| `references/ci-cd/backup-strategies.md` | Before any production write — backup provider, verification, restore runbook, acknowledgement tier. |
| `references/qa-gates.md` | Before merging, before deploying, and right after deploying. The pre-merge / pre-deploy / post-deploy checkpoints. |
| `references/safety-rules.md` | At session start. The full Safe / Confirm / Confirm+backup classification with examples. |
| `references/wp-local-setup.md` | During onboarding, or if the local environment is unclear. WP Local default, DDEV / Lando / Valet / Local Lightning as alternates. |
| `{theme_root}/.claude/CLAUDE.md` | At session start. Project mode (sage / inherited), live URLs, deploy hints. |
| `{theme_root}/.claude/ci-cd.md` | Before any deploy. Per-project pattern, deploy commands, pre/post hooks. |
| `{theme_root}/.claude/changelog/daily.md` | At session start. The last ~20 entries — what the last sessions touched. |

## Hard rules

1. **Never deploy without an acknowledged backup.** The backup-
   acknowledgement prompt is mandatory for every production write.
2. **Never write secrets into committed files.** SSH keys, GitHub
   PATs, database passwords belong in the OS secret store or
   `ssh-agent` — never in `.claude/`, never in `.env` checked into
   git, never in commit messages.
3. **Never silently overwrite production.** Every prod write shows the
   exact command and waits for explicit "yes."
4. **Never introduce a new framework on an inherited project** without
   explicit, in-session approval. Match the existing architecture.
5. **Always log production writes** as `[DEPLOY-PROD]` or
   `[DIRECT-PROD]` in `daily.md` before closing the response.
6. **Stop on any unexpected error.** No improvised recovery.
7. **`.claude/` is committed to git.** Never write secrets to it.
   `~/.config/norml-wp-developer/projects/*.json` is per-machine and
   never committed.
8. **Local-first is the default.** Direct-on-server is permitted but
   explicit per-operation. Never default to it.

## Related skills

**Companion (install both for a full WordPress workflow):**

- `norml-wp-manager` — REST-API-only content management on a deployed
  site. Use it for posts, pages, ACF values, media. This skill
  (`norml-wp-developer`) is for theme code; `norml-wp-manager` is for
  content. They share no state.

## What lives where (recap)

| What | Where | Why |
|---|---|---|
| The skill itself | `~/.claude/skills/norml-wp-developer/` | Claude Code auto-loads it. |
| **Per-project connection config** | **`~/.config/norml-wp-developer/projects/{slug}.json`** | Per-machine. Host, SSH alias, theme repo path, remote URL, deploy pattern. **No secrets.** |
| **Per-project knowledge** | **`{theme_root}/.claude/`** | Lives in the git repo. Travels with the code. CLAUDE.md, ci-cd.md, changelog, architecture docs. |
| SSH key | `~/.ssh/{key}` | Owned by the user; ssh-agent holds the passphrase. |
| SSH passphrase | macOS Keychain (via `ssh-add --apple-use-keychain`) / Windows ssh-agent (DPAPI-backed) | OS-managed. Claude never reads it. |

The split is intentional: `~/.config/` is per-machine connection state;
`{theme_root}/.claude/` is portable per-project knowledge; the OS
secret store is for secrets.
