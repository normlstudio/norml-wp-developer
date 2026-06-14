# Dev Conventions — Reference

How to build inside a WordPress theme this skill manages. **The first
decision on every task is project mode.** Read the relevant section
below FIRST.

## Mode A — Sage / Norml-authored new project

Roots Sage + Acorn + Blade + Tailwind CSS v4 + Vite + Alpine.js + ACF
Pro. Strict, opinionated, the same in every Norml-authored project.

### File layout (Sage)

```
{theme_root}/
├── app/                          PHP classes (Composer-autoloaded under App\)
│   ├── Providers/                Service providers
│   ├── View/Composers/           Blade view composers
│   ├── setup.php                 Theme setup, supports, menus
│   ├── filters.php               WordPress filter hooks
│   └── acf-blocks-{dev}.php      ACF block registration
├── resources/
│   ├── views/
│   │   ├── layouts/app.blade.php
│   │   ├── sections/             @include'd partials (hero, footer, etc.)
│   │   ├── components/           <x-component-name /> components
│   │   ├── blocks/               ACF block templates
│   │   └── partials/             Tiny re-usable snippets
│   ├── css/
│   │   ├── app.css               Tailwind v4 entry, @theme directive
│   │   ├── components.css        @layer components — shared classes
│   │   ├── blocks/{slug}.css     Per-block layout, conditionally enqueued
│   │   ├── theme-colors.css      Design tokens (--color-{project}-{name})
│   │   ├── theme-breakpoints.css
│   │   └── fonts.css
│   ├── js/
│   │   ├── app.js                Entry; imports Alpine, component JS
│   │   └── ...
│   ├── components/{name}/{name}.js
│   ├── images/
│   ├── icons/                    SVG sprite source
│   └── fonts/
├── acf-json/                     ACF JSON sync (field group definitions)
├── public/                       Built assets (Vite output) — gitignored
├── composer.json
├── package.json
├── vite.config.js
├── tailwind.config.js            (Tailwind v4 may be config-less; check)
├── style.css                     Theme metadata (Theme Name:, etc.)
└── .claude/                      Project context for Claude (committed)
```

### Conventions

**PHP**
- Namespace: `App\` with PSR-4 autoload.
- PHP 8.2+ features: named args, enums, readonly, match.
- Format with Laravel Pint (`composer pint` or `vendor/bin/pint`).
- Helper functions wrap in `if (! function_exists('name'))` guard.
- ACF fields accessed via `get_field()` with fallback defaults.

**Blade**
- Templates in `resources/views/`.
- Layouts extend `layouts.app`.
- Pages: `@extends('layouts.app')` + `@section('content')`.
- Sections: `@include('sections.name')`.
- Components: `<x-component-name />` syntax with `@props([])`.
- Pass data to components via props, not globals.
- Comment every component with its props at the top of the file.

**CSS / Tailwind v4 (the 3-layer model)**

Layer 1 — Design tokens in `resources/css/theme-colors.css` and
`theme-breakpoints.css` via Tailwind v4's `@theme` directive.

Layer 2 — Shared components in `resources/css/components.css` via
`@layer components`. Examples: `.btn`, `.section-container`,
`.content-container`, typography helpers like `.text-body-lead`.

Layer 3 — Per-block layout in `resources/css/blocks/{slug}.css`,
conditionally enqueued only on pages that use the block (via
`has_block()` check in `enqueue_block_assets`).

**Forbidden:** per-page stylesheets like `css/blocks-{page}-page.css`,
hex literals inside block CSS files, `font-family` overrides outside
the theme tokens, bespoke button styles that don't compose from
`.btn`.

**JavaScript**
- Alpine.js for interactivity (`Alpine.data()` registrations).
- GSAP for animations, Splide.js for sliders, Lottie for JSON
  animations.
- One JS file per component in `resources/components/{name}/{name}.js`.
- All imports flow through `resources/js/app.js`.
- **No jQuery.** No vanilla DOM manipulation for interactive features.

**ACF**
- JSON sync ON: `acf-json/` is the source of truth for field groups
  in Sage projects.
- Field group keys: `group_{descriptive_name}` (e.g.
  `group_hero_block`).
- Field keys: `field_{descriptive_name}` (e.g. `field_hero_title`).
- CPTs registered via ACF JSON (not PHP code).
- Blocks registered via `acf_register_block_type()` in
  `app/acf-blocks-{dev}.php`.
- Every block has a preview (live `mode: 'preview'` + `example`, or
  static screenshot at `assets/blocks/previews/{name}.png`).

**Images & assets**
- Static images in `resources/images/`.
- Icons as SVG sprite in `resources/icons/`, used as
  `<x-icon name="icon-name" />`.
- Use `<x-picture>` for images with WebP support.
- Use the `asset()` helper for built assets.
- Use the `bg_image()` helper for CSS background images with WebP.

### Build commands (Sage)

```bash
composer install         # PHP deps
npm install              # JS deps
npm run dev              # Vite dev server (HMR)
npm run build            # Production build
composer pint            # Format PHP
vendor/bin/phpstan       # Static analysis (if configured)
```

## Mode B — Inherited / non-Sage theme

You did NOT write this theme. A client or another agency did. The
**first rule** is *respect the existing architecture — don't silently
rewrite it.*

### What "respect" looks like

- Match the existing folder layout, file naming, and templating
  engine. If it uses plain PHP templates with `get_header()`,
  `the_content()`, don't introduce Blade. If it uses BEM CSS, don't
  introduce Tailwind utilities mid-file.
- Match the existing JS pattern. If it uses jQuery and inline
  `<script>`, don't introduce Alpine without explicit approval.
- Match the existing build setup, if any. If there's a `gulpfile.js`
  in use, don't replace it with Vite.
- Match the existing PHP style. If it uses procedural functions in
  `functions.php`, don't introduce PSR-4 classes.

**You MAY suggest a refactor.** Show the user the cost/benefit and let
them say yes or no. Never refactor silently.

### Framework-agnostic core principles (apply inside any theme)

These principles apply to inherited themes too — they're tooling-
agnostic.

**1. Section / component / partial separation.** Even in a plain-PHP
theme, every page should be assembled from clearly named partials
under (say) `partials/`, `sections/`, or `template-parts/`. One file
= one section. No 500-line `page.php`.

**2. ACF block registration.** Wherever ACF blocks live in this
theme, use the same registration pattern:

```php
acf_register_block_type([
  'name'            => 'block-slug',
  'title'           => __('Block Title'),
  'description'     => __('What this block is for.'),
  'category'        => 'theme-name',  // group blocks by theme in the inserter
  'icon'            => 'star-filled',
  'mode'            => 'preview',
  'example'         => [
    'attributes' => [
      'mode' => 'preview',
      'data' => [ 'is_example' => true ],
    ],
  ],
  'render_template' => 'template-parts/blocks/block-slug.php',
  'supports'        => [ 'mode' => false, 'jsx' => false ],
]);
```

Every block has a preview visible from the block inserter. If the
block is too heavy to render live, fall back to a static screenshot
at `assets/blocks/previews/{slug}.png`.

**3. CPT blocks-based pattern.** When the project needs a CPT
(`case_study`, `team_member`, etc.), build the single + archive views
as blocks the user can drop into a regular page — not as hard-coded
template files. Easier to redesign later, easier to compose.

**4. The 3-layer CSS model — framework-agnostic.**

Inherited projects almost always violate this. You apply it gradually:

- Layer 1: design tokens. In a plain-PHP theme, this is a `:root`
  block in `style.css` or a dedicated `css/tokens.css` with custom
  properties. `--color-primary`, `--font-body`, `--spacing-section`.
- Layer 2: shared components. `css/components.css` (or whatever
  `style.css` already does) — `.btn`, `.container`, typography
  helpers. ALWAYS enqueued.
- Layer 3: per-block layout. `css/blocks/{slug}.css`. Conditionally
  enqueued on pages that use the block via `has_block()` check.

**Don't create per-page stylesheets** (`css/blocks-{page}-page.css`).
That's the inheritance trap.

Block files contain NO hex literals (compose from tokens), NO
`font-family` overrides (compose from typography helpers), NO bespoke
button styles (use the theme's existing `.btn`).

When introducing the model on an inherited project: do it gradually,
one new block at a time. Don't refactor existing blocks without
approval.

**5. WordPress hook discipline.** Hooks belong in dedicated files,
not scattered through templates. A `functions.php` that's 2000 lines
of `add_action()` calls is a code smell. Group hooks by concern:
`inc/blocks.php`, `inc/cpts.php`, `inc/enqueue.php`, `inc/cleanup.php`.

### Decision flow — refactor vs match existing

When you're about to add new code to an inherited theme:

1. **Does this concern already have a file in the theme?** If yes,
   add to it.
2. **Does this concern have a clear precedent in the theme?** (Other
   blocks, other CPTs, other enqueues.) If yes, match the precedent.
3. **No precedent?** Use the framework-agnostic principles above. The
   first time you introduce the pattern, leave a `// NORML: ...`
   comment explaining what you've done so the next developer
   understands the pattern came from outside.

**Never introduce a new framework, build system, or templating engine
silently.** That requires explicit, in-session approval.

## Both modes — global rules

### Conventional Commits

All commits follow Conventional Commits:

```
<type>(<scope>): <summary>

<body — explains WHY, not WHAT>
```

Types: `feat`, `fix`, `refactor`, `docs`, `style`, `perf`, `test`,
`chore`, `ci`, `build`. Scope optional. See `git-workflow.md` for the
full convention.

### Don't commit build artifacts

`public/`, `dist/`, `node_modules/`, `vendor/` — all gitignored.
Built assets are produced fresh by CI/CD on deploy.

### Don't commit `.env` files

Use `.env.example` checked in, `.env` gitignored. Real credentials
never in git.

### Don't commit secrets, ever

If you suspect a secret got into a commit, see the rotation flow in
`safety-rules.md`. Quick version: revoke immediately, rotate, force-
push the cleaned history. Then take stock.

### ACF JSON sync caveat (Sage)

The `acf-json/` folder is the source of truth for field group
definitions in Sage projects. Editing a field group in wp-admin
writes a JSON file into `acf-json/`. **That JSON file must be
committed to git** so the change ships with the next deploy.

Common bug: developer edits a field group in wp-admin staging, never
commits the JSON, the next deploy "loses" the change. Always check
`git status` in `acf-json/` after wp-admin field-group edits.

### Block thumbnails

Every ACF block should have a thumbnail in the block inserter — either:

- A live preview (cheap blocks): `mode: 'preview'` + an `is_example`
  branch in the render template that produces a static, dependency-
  free version of the block.
- A static screenshot: PNG at `assets/blocks/previews/{slug}.png`
  (typically 600×400), wired up via the block's
  `'example' => [ 'image' => get_template_directory_uri() . '/assets/blocks/previews/' . $name . '.png' ]`.

Either way: the editor should not see "this block has no preview"
empty state.
