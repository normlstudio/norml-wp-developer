# changelog

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
├── INSTALL.md                  one-time install for the skill
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
    ├── claude-md.template.md   .claude/CLAUDE.md scaffold
    ├── ci-cd.template.md       .claude/ci-cd.md scaffold
    ├── changelog-readme.template.md  Rolling-three-tier protocol
    ├── github-workflow-staging.template.yml
    └── github-workflow-prod.template.yml
```

**Companion skill:** `norml-wp-manager` v2.2.0+ (renamed from
`wp-manager` in the same release). The two share no state and are
designed to live side by side — content owners install the manager,
developers install this skill. Both follow the same path conventions:
per-machine config at `~/.config/norml-{skill}/`, per-project knowledge
in a `docs/`-style folder, secrets in the OS secret store.
