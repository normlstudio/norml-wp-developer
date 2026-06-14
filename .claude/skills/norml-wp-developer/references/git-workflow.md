# Git Workflow — Reference

GitHub Flow + Conventional Commits. Simple, opinionated, ships well.

## Branching model — GitHub Flow

One long-lived branch: `main` (production-ready code). For projects
with staging, `develop` is also long-lived. Everything else is short-
lived feature branches.

### Branch naming

- Features: `feat/{ticket-or-slug}-{short-description}` →
  `feat/123-add-hero-block` or `feat/add-hero-block` (no ticket).
- Fixes: `fix/{slug}-{description}` → `fix/hero-padding-on-mobile`.
- Refactors: `refactor/{slug}` → `refactor/blade-component-cleanup`.
- Chores: `chore/{slug}` → `chore/update-tailwind-v4-2`.

Slug = kebab-case, lowercase.

### When to branch

Every meaningful change starts a branch. Quick rule:

- More than one commit's worth of work → branch.
- Touches more than one file → branch.
- Anyone else might want to review → branch.

Don't branch for typo fixes, one-line config bumps, single-paragraph
README edits. Commit those directly to the relevant base branch (`main`
on prod-direct projects, `develop` on staged projects).

### PR vs direct-merge

- Solo project, no review process → direct merge (`git push origin
  develop` is the same as the PR).
- Team project, code review expected → PR. Even solo, a PR is useful
  for the audit trail.

## Commit conventions — Conventional Commits

Every commit message follows:

```
<type>(<scope>): <summary>

<optional body>

<optional footer>
```

### Types

| Type | Use for |
|---|---|
| `feat` | New feature or capability (a new block, new CPT, new endpoint) |
| `fix` | Bug fix |
| `refactor` | Code rework, no behavior change |
| `docs` | Documentation only (README, comments, `.claude/CLAUDE.md`) |
| `style` | Formatting, white-space, lint fixes — no logic change |
| `perf` | Performance improvement |
| `test` | Adding/modifying tests |
| `chore` | Tooling, dep updates, build script changes |
| `ci` | CI/CD config changes |
| `build` | Build system or external dep changes (Vite config, Composer) |

### Scope

Optional. Use to narrow: `feat(blocks): add hero block`,
`fix(acf): correct field key`, `chore(deps): bump tailwind to v4.0.5`.

### Summary

- Imperative present: "add," not "added" or "adds."
- Lowercase.
- No period at the end.
- ≤72 chars.

### Body

- Wrapped at 72 chars.
- Explains WHY, not WHAT (the diff already shows what).
- Use blank lines to separate paragraphs.

### Footer

- `BREAKING CHANGE: ...` for breaking changes (also bumps major
  version on tagged releases).
- `Closes #123` or `Refs #123` to link issues.

### Examples

```
feat(blocks): add testimonials block with 3-row repeater

Adds an ACF block with a repeater field for testimonial entries
(quote, author, role). Renders a 3-column grid on desktop, stacks
on mobile. JSON sync registered the group at field_testimonials.

Closes #42
```

```
fix(acf): correct field key for hero subtitle

The field group used field_hero_subitle (typo) which silently
no-op'd writes from the REST API. Renamed to field_hero_subtitle.
Existing values migrated via a one-off WP-CLI script (committed
in scripts/migrate-2026-05-20-hero-subtitle.php).
```

```
refactor(css): apply 3-layer model to footer block

Moved footer-specific layout from style.css into
css/blocks/footer.css. Shared button styles already live in
components.css — removed duplicate .footer-cta-btn class in favor
of .btn-outlined.
```

```
chore: scaffold .claude/ via norml-wp-developer

Initial project context layer: CLAUDE.md, ci-cd.md
(prod-direct-with-git pattern), rolling changelog, empty docs/
and skills/. Architecture scrape pending — production not yet
provisioned.
```

## The `develop` → `main` flow (for full-pipeline projects)

1. Branch from `develop`: `git checkout -b feat/my-feature`.
2. Commit, push, open PR back to `develop`.
3. Merge to `develop` → CI/CD deploys to staging.
4. QA on staging.
5. When ready for prod: tag a release on `develop` → CI/CD deploys
   to production.

```bash
# Tag a production release after staging QA passes
git checkout develop
git pull
git tag v1.2.3 -m "Release v1.2.3 — testimonials + footer redesign"
git push origin v1.2.3
# CI/CD now deploys v1.2.3 to production
```

Use semver: `v{major}.{minor}.{patch}`. Increment per the change kind:

- `fix` → patch
- `feat` → minor
- breaking change → major

## The single-branch flow (for prod-direct-with-git projects)

1. Commit on `main` (small projects don't need branches for every
   change).
2. `git push origin main` → CI/CD or post-receive hook deploys to
   production.
3. Backup-acknowledgement prompt fires before the deploy command
   runs.

For larger changes on prod-direct projects, still use a feature
branch and squash-merge to `main` for clean history.

## Hooks the skill writes

When the skill scaffolds a project, it installs:

- `.gitignore` with WordPress + Vite + Composer + OS-specific defaults.
- `.gitattributes` with normalize-EOL rules + `*.png binary` etc.
- (Optional) a pre-commit hook that runs `pint` and `eslint` if those
  are wired up in `composer.json` / `package.json`.

Pre-commit hooks are local-only (`.git/hooks/pre-commit`) and not
committed. The skill installs them via `husky` or `lefthook` if the
project already uses one; otherwise leaves them alone.

## What to commit, what NOT to commit

### Commit

- Theme source: `app/`, `resources/`, `inc/`, etc.
- `composer.json`, `composer.lock`
- `package.json`, `package-lock.json` (or `yarn.lock` / `pnpm-lock.yaml`)
- `vite.config.js`, `tailwind.config.js`, `.eslintrc`, etc.
- `style.css`, `functions.php`, `index.php`
- `.claude/` folder (the project knowledge layer)
- `.github/workflows/` (CI/CD definitions)
- `.gitignore`, `.gitattributes`
- `acf-json/` (ACF field group definitions in Sage projects)

### DO NOT commit

- `node_modules/`, `vendor/`
- `public/`, `dist/`, `build/` (built assets — produced by CI/CD)
- `.env`, `.env.local`, anything matching `*.env*` (except
  `.env.example`)
- SSH keys, GPG keys, API tokens, application passwords, anything
  remotely secret
- IDE files: `.idea/`, `.vscode/` (unless explicitly shared with the
  team)
- macOS `.DS_Store`, Windows `Thumbs.db`
- WordPress core (`wp-admin/`, `wp-includes/`) — the theme repo is
  the theme, not the whole WP install
- `wp-content/uploads/` — the media library is content, not code
- Database dumps (`*.sql`) — they're content, they shouldn't be in
  the code repo

## Resolving conflicts

The skill does NOT auto-resolve conflicts. When `git pull --rebase` or
a merge produces a conflict:

1. Stop. Show the user the conflicting files.
2. For each conflict, present both sides ("incoming" vs "current").
3. Let the user pick. Apply their choice.
4. `git add` the resolved files. Continue the rebase / finish the
   merge.

Don't `git checkout --theirs` or `--ours` without explicit instruction
— it can silently drop work.

## Reverting

To undo a commit that's already pushed:

```bash
git revert <sha>   # creates a new commit that undoes <sha>
git push
```

NOT `git reset --hard` on a shared branch — that rewrites history and
breaks teammates' clones.

To rollback a production deploy: re-deploy the previous Git tag.
`git checkout v1.2.2`, build, deploy — or run the production workflow
manually against the previous tag.

## Force-push policy

Never force-push to `main` or `develop`. Force-push to short-lived
feature branches is fine (e.g. after `git rebase -i` for cleaning up
commit history before opening a PR).

If you absolutely must force-push to a long-lived branch (rare,
usually because a secret leaked), coordinate with the team first.

## Tags

Production releases get tagged with semver. The CI/CD workflow for
`full-pipeline` projects triggers on tag push:

```yaml
on:
  push:
    tags:
      - 'v*'
```

For `prod-direct-with-git` and `prod-direct-no-ci` projects, tags are
optional but recommended — they give you a known-good commit to
roll back to.

## Cross-references

- `references/dev-conventions.md` → coding style + the 3-layer CSS
  model — every commit should honor those.
- `references/ci-cd-patterns.md` → how the three deploy patterns
  consume git state (branch push vs tag push vs ad-hoc rsync).
- `references/safety-rules.md` → the secret-leak exposure protocol.
