# Conventions — Reference Folder

How to build inside a WordPress theme this skill manages. **The first decision
on every task is project mode** (`sage` vs `inherited`, declared in
`{theme_root}/.claude/CLAUDE.md`). Read the files for your mode first.

## Files

| File | What it owns |
|---|---|
| `sage-stack.md` | The Sage foundation for **new** projects: Roots Sage + Acorn + Blade + Tailwind v4 + Vite + Alpine + ACF Pro. What Sage ships, how Acorn boots, the Blade↔WP template hierarchy, the Vite pipeline, the build/deploy command sequence. |
| `component-system.md` | Sections / components / partials anatomy, the core component catalog (`<x-icon>`, `<x-picture>`, `<x-accordion>`, `<x-slider>`, `<x-modal>`), the Alpine.js integration pattern, page-template and layout rules. (Sage-Blade-centric; the same separation principles apply to non-Sage themes per `inherited-projects.md`.) |
| `css-architecture.md` | The 3-layer CSS model (tokens → shared components → per-block layout), expressed for **both** Sage (Tailwind v4 `@theme`/`@layer`) and vanilla themes. The forbidden per-page-stylesheet rule, the audit-first rule, the don't/do cheat sheet, the pre-flight checklist. **Single home for the CSS model — both modes.** |
| `acf-blocks.md` | ACF block registration (Sage `view()` and vanilla `get_template_part()` render paths), the custom block category, block previews (live `example` + static-screenshot fallback), and the ACF JSON sync workflow. **Single home for ACF blocks — both modes.** |
| `inherited-projects.md` | Working inside a theme you didn't scaffold (non-Sage, client/agency handoff): respect-existing decision flow, framework-agnostic core principles, the CPT blocks-based pattern, what you may/may-not introduce silently, and the phased-refactor approach. |

## Read order by mode

**Sage / new project:** `sage-stack.md` → `component-system.md` → `css-architecture.md` → `acf-blocks.md`

**Inherited / non-Sage:** `inherited-projects.md` first → then `css-architecture.md` + `acf-blocks.md` (both modes live here) for the specifics.

## The router

The parent `../dev-conventions.md` is the quick router into this folder plus
the genuinely-global rules (Conventional Commits, don't-commit-artifacts /
-secrets, the ACF JSON sync caveat). Start there if you're unsure which file
you need.
