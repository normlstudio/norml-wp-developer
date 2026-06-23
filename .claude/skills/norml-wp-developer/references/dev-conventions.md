# Dev Conventions — Router

How to build inside a WordPress theme this skill manages. **The first decision
on every task is project mode.** It's declared in `{theme_root}/.claude/CLAUDE.md`
as `mode: sage` or `mode: inherited`. Route to the right depth, then apply the
global rules at the bottom of this file to both.

The deep conventions live in `conventions/` — this file is the map.

## Mode A — Sage / new project (Norml-style)

Roots Sage + Acorn + Blade + Tailwind CSS v4 + Vite + Alpine.js + ACF Pro.
Strict, opinionated, the same in every new project you scaffold.

Read, in order:

1. **`conventions/sage-stack.md`** — the framework foundation. What Sage ships,
   how Acorn boots, the Blade↔WP template hierarchy, the Vite pipeline, the
   build + post-deploy command sequence. Read this FIRST or you'll fight the
   framework.
2. **`conventions/component-system.md`** — sections / components / partials
   anatomy, the core component catalog, the Alpine.js pattern, page templates,
   the layout.
3. **`conventions/css-architecture.md`** — the 3-layer CSS model in Tailwind v4
   terms (`@theme` tokens, `@layer components`, per-block layout).
4. **`conventions/acf-blocks.md`** — ACF block registration, block previews,
   ACF JSON sync.

## Mode B — Inherited / non-Sage theme

You did NOT write this theme — a client or another agency did. The first rule
is *respect the existing architecture; don't silently rewrite it.*

Read, in order:

1. **`conventions/inherited-projects.md`** — read this FIRST whenever you open
   a theme you didn't scaffold. Respect-existing decision flow, the
   framework-agnostic core principles, what you may vs must-not introduce
   silently, the phased-refactor approach.
2. **`conventions/css-architecture.md`** — the same 3-layer CSS model, in its
   vanilla-theme expression (`css/components.css`, conditional `has_block()`
   enqueue). Applies inside any theme.
3. **`conventions/acf-blocks.md`** — ACF block registration in the
   `get_template_part()` render path, plus previews.

**Never introduce a new framework, build system, or templating engine on an
inherited project without explicit, in-session approval.** Match the existing
architecture; surface refactors as their own scope.

---

## Both modes — global rules

These apply regardless of mode.

### Conventional Commits

All commits follow Conventional Commits:

```
<type>(<scope>): <summary>

<body — explains WHY, not WHAT>
```

Types: `feat`, `fix`, `refactor`, `docs`, `style`, `perf`, `test`, `chore`,
`ci`, `build`. Scope optional. Full convention in `git-workflow.md`.

### Don't commit build artifacts

`public/`, `dist/`, `node_modules/`, `vendor/` — all gitignored. Built assets
are produced fresh by CI/CD (or the local build) on deploy.

### Don't commit `.env` files

`.env.example` checked in, `.env` gitignored. Real credentials never in git.

### Don't commit secrets, ever

If you suspect a secret got into a commit, see the rotation flow in
`safety-rules.md`. Quick version: revoke immediately, rotate, force-push the
cleaned history, then take stock.

### ACF JSON sync caveat

In Sage projects the `acf-json/` folder is the source of truth for field group
definitions. Editing a field group in wp-admin writes a JSON file into
`acf-json/`. **That JSON file must be committed to git** so the change ships
with the next deploy. Common bug: developer edits a field group in wp-admin on
staging, never commits the JSON, the next deploy "loses" the change. Always
check `git status` in `acf-json/` after wp-admin field-group edits. (Full ACF
workflow in `conventions/acf-blocks.md`.)

### Block thumbnails

Every ACF block gets a preview in the inserter — a live `mode: 'preview'` +
`example` render, or a static screenshot at
`assets/blocks/previews/{slug}.png`. The editor should never see the "no
preview" empty state. Details in `conventions/acf-blocks.md`.

## Cross-references

- `conventions/README.md` — the conventions folder index + read order by mode
- `git-workflow.md` — branch / commit / push / tag rules
- `ci-cd/patterns.md` — deploy patterns
- `qa-gates.md` — pre-merge / pre-deploy / post-deploy checkpoints
- `safety-rules.md` — Safe / Confirm / Confirm+backup buckets
