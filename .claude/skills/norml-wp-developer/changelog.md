# changelog

## [1.2.0] — Aug 28, 2026 — Max Tymoshyn

Published the human-facing name **Norml WordPress Copilot Advanced** while keeping
`norml-wp-developer` as the stable installed slug. Clarified the hard runtime
boundary: Advanced runs only in Claude Code, Codex, or Gemini CLI and requires a
local theme repo, GitHub, SSH, and remote WP-CLI.

Added generated `capabilities.md`, `architecture.md`, and docs-index templates to
the theme-local `.claude/` project layer. Added real macOS/Linux and Windows
architecture scanners that combine local theme/Git evidence with fixed read-only
WP-CLI commands over production SSH. The scan records runtime versions, site URLs,
themes, plugins, update signals, post types, taxonomies, counts, menus, stack
signals, GitHub/SSH/WP-CLI verification, and current blockers without reading
secrets.

Onboarding now requires a readable GitHub origin, verified production SSH, working
WP-CLI in the configured WordPress root, and a successful first capability +
architecture scan. Removed the old optional/TODO scrape contract and the unsupported
multi-provider remote path from the public onboarding flow. Removed the obsolete
standalone `install.html`; the maintained install source is `install.md`, while
`readme.html` remains the visual one-pager.

The paired human guides now include a representative installed-package architecture
with exact path-to-role explanations, kept separate from the generated theme-local
project record.

## [1.1.0] — Jun 22, 2026 — Max Tymoshyn

Depth expansion of the reference layer. **No behavior change** to setup,
develop, or deploy — the skill now carries the full architecture + CI/CD
knowledge inline instead of compressing it into two single files. All
ported from Norml's internal dev skills and genericized for any
WordPress developer (zero Norml-ecosystem dependencies, no private repo
references, no brand-locked class prefixes).

**New `references/conventions/` folder** — the deep build conventions the
old single `dev-conventions.md` only summarized:

- `sage-stack.md` — the Sage + Acorn + Blade + Tailwind v4 + Vite +
  Alpine + ACF Pro foundation (what Sage ships, Acorn boot, Blade↔WP
  hierarchy, the Vite pipeline, build + post-deploy sequence).
- `component-system.md` — section / component / partial anatomy, the
  core component catalog, the Alpine.js integration pattern, layout.
- `css-architecture.md` — the 3-layer CSS model (tokens → shared
  components → per-block layout) for **both** Sage (Tailwind v4
  `@theme`/`@layer`) and vanilla themes; the forbidden per-page-stylesheet
  rule; the audit-first rule + pre-flight checklist.
- `acf-blocks.md` — ACF block registration (Sage `view()` and vanilla
  `get_template_part()` paths), custom block category, block previews
  (live `example` + static-screenshot fallback), ACF JSON sync.
- `inherited-projects.md` — working inside a non-Sage / handed-over
  theme: respect-existing decision flow, may/must-not-introduce-silently,
  the phased-refactor approach.
- `README.md` — folder index + read order by mode.

`dev-conventions.md` is now a slim **router** into `conventions/` plus
the genuinely-global rules (Conventional Commits, don't-commit
artifacts/secrets, ACF JSON sync caveat).

**New `references/ci-cd/` folder** — replaces the single
`ci-cd-patterns.md`:

- `patterns.md` — the three deploy patterns (relocated; database +
  backup depth delegated to the strategy files below).
- `database-strategies.md` — four content/DB strategies (`single-env`,
  `prod-is-source-of-truth`, `selective-sync`, `full-sync`), the `wp`
  commands, and the rules that stop you clobbering live data.
- `backup-strategies.md` — four backup provider types (managed host,
  shared host, VPS-with-script incl. the nightly backup script,
  cloud-custom), verify + restore runbooks, mapped onto the
  `host-automatic` / `manual-before-deploy` / `none-warned` tiers.
- `README.md` — folder index.

**New `references/qa-gates.md`** — the pre-merge / pre-deploy /
post-deploy QA checkpoints, adapted to all three patterns (staging-based
for `full-pipeline`, local-based pre-deploy for the prod-direct patterns;
post-deploy always on the production URL). Smoke test + Core Web Vitals
checks are inline manual checklists — no external skill dependencies.

**SKILL.md** — bumped to 1.1.0; the knowledge-baseline table now lists
every new reference; the Develop phase routes to the `conventions/`
files by mode; the Deploy phase points at `qa-gates.md` +
`backup-strategies.md`.

**Docs** — adopted the `readme.html` one-pager approach (the same one
`norml-wp-manager` uses): replaced the old `human.md` with `readme.md`
(deep guide) + `readme.data.json` + `readme.html` (the self-contained
visual one-pager, rendered from the data). Added `install.html` — a
visual, **prompt-first** install page (the first in the shared-skills
set): every step leads with a copy-pastable prompt for Claude Code, plus
a one-paste block that bootstraps the whole install + first-project
setup, with copy-to-clipboard buttons (clipboard API + `file://`
fallback).

No script, template, onboarding, or credential-handling changes. Existing
projects need nothing — the new references are purely additive.

## [1.0.0] — May 20, 2026 — Max Tymoshyn

Initial release. The developer counterpart to `norml-wp-manager`.

**Scope:** local-first WordPress theme development with SSH-based
deploys, Git as the source of truth, GitHub Actions (or Bitbucket
Pipelines) for CI/CD. Bundles three concerns into one shareable skill:

1. **Project init** — scaffolds `.claude/` inside the theme repo
   (CLAUDE.md, ci-cd.md, rolling changelog, optional 5-file
   architecture scrape) and wires Git + remote on first run.
2. **Development conventions** — Norml's Sage architecture (Roots
   Sage + Acorn + Blade + Tailwind v4 + Vite + Alpine + ACF Pro) for
   new projects; framework-agnostic core principles (sections /
   components / partials, ACF block registration, 3-layer CSS model)
   for inherited themes.
3. **CI/CD pattern catalog** — three patterns: `full-pipeline`
   (staging → prod, the canonical full flow), `prod-direct-with-git`
   (single env with Git safety net), `prod-direct-no-ci` (rsync from
   local).

**Authentication model:** SSH key + ssh-agent backed by the OS secret
store (macOS Keychain on Mac, Windows DPAPI on Windows). GitHub auth
via `gh` CLI or PAT in the OS secret store. Setup script uses native
OS dialogs to capture passphrases; the developer never types a secret
into the terminal.

**Backup model:** **the skill does NOT make backups for you.** Every
production write (rsync to prod, `wp db import` on prod, `wp
search-replace` on prod) gates on an explicit acknowledgement that a
backup exists. Default answer is "abort." No autopilot, no skipping
the prompt. The skill assumes the production host has automatic
backups enabled, or that the developer takes manual backups before
destructive operations.

**Direct-on-server work:** permitted but always flagged. Edits made
directly on the production server via SSH are logged as
`[DIRECT-PROD]` in the project changelog and trigger a warning that
the change isn't in Git and will be overwritten by the next deploy.
Default flow is local-first → commit → push → deploy.

**Local WP environment:** WP Local (Flywheel / WP Engine) is the
default. DDEV, Lando, Local Lightning, Valet+ recognized as alternates.
At least one running local WP install is required to finish project
onboarding.

**File layout:**

```
~/.claude/skills/norml-wp-developer/
├── SKILL.md                    primary skill instructions
├── install.md                  one-time install for the skill
├── onboarding.md               per-project setup (~30 min)
├── human.md                    narrative overview for the recipient
├── changelog.md                (this file)
├── references/
│   ├── dev-conventions.md      Sage + Inherited conventions
│   ├── git-workflow.md         GitHub Flow + Conventional Commits
│   ├── ci-cd-patterns.md       The 3 patterns
│   ├── safety-rules.md         Safe / Confirm / Confirm+backup
│   └── wp-local-setup.md       Local env detection + setup
├── scripts/
│   ├── lib/credman.ps1         Win32 Credential Manager P/Invoke
│   ├── prompt-secret-macos.sh  Native macOS dialog for secrets
│   ├── prompt-secret-windows.ps1
│   ├── setup-macos.sh          Per-project setup orchestrator
│   ├── setup-windows.ps1
│   ├── test-ssh.sh             SSH alias smoke test
│   ├── test-ssh.ps1
│   ├── init-claude.sh          Scaffold .claude/ inside a theme repo
│   ├── init-claude.ps1
│   ├── sync-from-prod.sh       Pull production DB + uploads to local
│   ├── sync-from-prod.ps1
│   ├── deploy-to-staging.sh    Push to staging (rsync or git)
│   ├── deploy-to-staging.ps1
│   ├── deploy-to-prod.sh       Promote to production (with backup prompt)
│   └── deploy-to-prod.ps1
└── templates/
    ├── config.template.json    Per-project config shape
    ├── claude-md-template.md   .claude/CLAUDE.md scaffold
    ├── ci-cd-template.md       .claude/ci-cd.md scaffold
    ├── changelog-readme-template.md  Rolling-three-tier protocol
    ├── github-workflow-staging.template.yml
    └── github-workflow-prod.template.yml
```

**Companion skill:** `norml-wp-manager` v2.2.0+ (renamed from
`wp-manager` in the same release). The two share no state and are
designed to live side by side — content owners install the manager,
developers install this skill. Both follow the same path conventions:
per-machine config at `~/.config/norml-{skill}/`, per-project knowledge
in a `docs/`-style folder, secrets in the OS secret store.
