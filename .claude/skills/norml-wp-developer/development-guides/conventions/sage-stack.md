# Sage Stack — Reference

The Sage stack is the baseline for every new WordPress project this skill manages
in **Mode A**. This document covers what Sage is, how to scaffold it, what ships
out of the box, and exactly what the recommended additions layer on top. Read this
before opening any other reference.

Source: <https://roots.io/sage/docs/>

---

## What Sage is

**Sage** (from Roots) is a WordPress starter theme — not a plugin, builder, or block
library. It replaces the default PHP template system with a Laravel-style architecture:

- **Composer** for PHP dependency management and PSR-4 autoloading
- **Acorn** — a Laravel IoC container adapted to run inside WordPress
- **Blade** as the template engine (compiled, cached, component-based)
- **Vite** for the asset build pipeline (dev server with HMR, production manifest)
- **Tailwind CSS v4** wired into the build with WordPress editor integration
- An opinionated `app/` / `resources/` / `public/` directory layout

Everything covered in the other reference files — SCSS alongside CSS, ACF Pro,
Alpine.js, Splide, custom image helpers, the responsive image size grid, the 3-layer
CSS model — sits on top of this framework. The framework is the floor; your
conventions are the walls.

---

## Required versions

| Dependency | Version |
|---|---|
| PHP | ≥ 8.2 |
| WordPress | ≥ 6.6 |
| Composer | 2.x |
| Node.js | ≥ 20.0.0 |
| Roots Acorn | ^5.0 |
| Sage | 11.x (tracks latest release or `dev-main`) |

Confirm these in `composer.json` (`"require": { "php": ">=8.2", "roots/acorn": "^5.0" }`)
and `package.json` (`"engines": { "node": ">=20.0.0" }`). If the host server doesn't
meet the PHP or Node versions, the build won't run and Acorn will fail to boot.

---

## Scaffolding a new theme

From `wp-content/themes/`:

```bash
# Latest stable release
composer create-project roots/sage {theme-name}

# Or the development version
composer create-project roots/sage {theme-name} dev-main

cd {theme-name}
npm install
npm run build           # produces public/build/manifest.json
```

**Failure to run `npm run build` before activating the theme produces:**

> `Vite manifest not found at [/path/to/sage/public/build/manifest.json]`

After scaffolding:

1. Edit the `base` path in `vite.config.js` to match the theme's URL on the server
   (see "Asset enqueue pattern" below for the dev/prod split).
2. Activate the theme: `wp theme activate {theme-name}` or WP Admin → Themes.
3. Replace `style.css` header with the project-specific name, version, and author.

---

## What Sage ships — stock directory layout

```
{theme-name}/
├── app/                          # PHP application logic (namespaced App\)
│   ├── Providers/
│   │   └── ThemeServiceProvider.php   # Acorn service provider
│   ├── View/
│   │   ├── Components/                # Class-based Blade components
│   │   └── Composers/                 # View composers (data → views)
│   ├── filters.php                    # WordPress filters
│   └── setup.php                      # Theme setup: enqueues, menus, supports
│
├── resources/                    # Source assets + Blade templates
│   ├── css/
│   │   ├── app.css                    # Primary stylesheet
│   │   └── editor.css                 # Block editor styles
│   ├── fonts/
│   ├── images/
│   ├── js/
│   │   ├── app.js                     # Primary JS entry
│   │   └── editor.js                  # Block editor JS
│   └── views/
│       ├── layouts/
│       │   └── app.blade.php          # Root layout
│       ├── components/                # Anonymous Blade components
│       ├── forms/
│       ├── partials/                  # Loop content fragments
│       ├── 404.blade.php
│       ├── index.blade.php
│       ├── page.blade.php
│       ├── search.blade.php
│       └── single.blade.php
│
├── public/                       # Vite build output — NEVER hand-edit
│   └── build/
│       ├── manifest.json
│       └── assets/
│           └── theme.json             # Auto-generated from Tailwind config
│
├── vendor/                       # Composer deps (gitignored)
├── node_modules/                 # Node deps (gitignored, never uploaded)
├── composer.json
├── functions.php                 # Bootloader only — autoload + Acorn boot
├── index.php                     # WordPress template wrapper
├── package.json
├── screenshot.png
├── style.css                     # Theme metadata ONLY (no actual styles)
├── theme.json                    # Preprocessed — real one generated at build
└── vite.config.js
```

**Structural rules from Sage docs:**

- `app/` is namespaced under `App\` via Composer PSR-4 autoloading.
- `public/` is never hand-edited — it's Vite output, fully regenerated on `npm run build`.
- `node_modules/` and `vendor/` are never uploaded to production directly. Run
  `composer install --no-dev --optimize-autoloader` on the server, or produce
  `vendor/` in CI and upload it.
- `functions.php` is a **bootloader only** — its only jobs: require Composer autoloader,
  boot Acorn, and include theme PHP files. Feature logic never goes here.
- `index.php` is the WordPress template wrapper. Sage's layout renders inside it.

---

## Acorn — the Laravel container inside WordPress

Acorn provides: service providers, Blade compiled templates, view composers, class-based
components, and the `wp acorn ...` WP-CLI namespace.

### How it boots

`functions.php` has exactly three responsibilities:

```php
<?php
use Roots\Acorn\Application;

// 1. Load the Composer autoloader
if (! file_exists($composer = __DIR__.'/vendor/autoload.php')) {
    wp_die(__('Error locating autoloader. Please run <code>composer install</code>.', 'sage'));
}
require $composer;

// 2. Boot Acorn with your theme's service provider
Application::configure()
    ->withProviders([App\Providers\ThemeServiceProvider::class])
    ->boot();

// 3. Include theme PHP files (one per concern)
collect(['setup', 'filters', 'helpers', 'forms' /* add yours */])
    ->each(function ($file) {
        if (! locate_template($file = "app/{$file}.php", true, true)) {
            wp_die(sprintf(__('Error locating <code>%s</code>.', 'sage'), $file));
        }
    });
```

### `ThemeServiceProvider`

Extends `Roots\Acorn\Sage\SageServiceProvider`. Override `register()` to bind services,
`boot()` to run code after all providers are ready. Keep this minimal — only override
when you genuinely need a custom binding or Blade directive.

### WP-CLI commands

| Command | When to run |
|---|---|
| `wp acorn view:cache` | Pre-compile all Blade templates — required post-deploy |
| `wp acorn view:clear` | Clear compiled templates when debugging stale views |
| `wp acorn optimize:clear` | Clear Acorn's config/view/route cache |
| `wp acorn optimize` | Cache config + views for production (do NOT run after `view:cache`) |
| `wp acorn make:component Name` | Scaffold a class-based Blade component + view |
| `wp acorn make:composer Name` | Scaffold a View Composer |

**WP Engine note:** run `wp acorn view:cache` as the LAST Acorn command in post-deploy.
Running `wp acorn optimize` after `view:cache` invalidates the view cache.

**Kinsta / other managed hosts:** Kinsta does not handle Blade file security at the
platform level. Verify the Blade security rule (below) after every migration.

---

## Blade — WordPress template hierarchy

Sage maps one-to-one onto WordPress's template hierarchy. Every hierarchy file becomes
a `.blade.php` in `resources/views/`:

| WordPress hierarchy | Sage Blade file |
|---|---|
| 404 | `404.blade.php` |
| Index (archives, blog) | `index.blade.php` |
| Search | `search.blade.php` |
| Single post | `single.blade.php` |
| Page | `page.blade.php` |
| Front page | `front-page.blade.php` |
| Home (blog index) | `home.blade.php` |
| Category archive | `category.blade.php` |
| Author archive | `author.blade.php` |
| CPT single | `single-{post_type}.blade.php` |
| CPT archive | `archive-{post_type}.blade.php` |
| Named page template | `page-{slug}.blade.php` or `template-{name}.blade.php` |

All of these extend the base layout:

```blade
@extends('layouts.app')

@section('content')
    {{-- page-specific content --}}
@endsection
```

### Blade components — two flavors

**Anonymous** — a `.blade.php` file at `resources/views/components/name.blade.php`,
with a `@props([])` directive at the top. No PHP class. Used via `<x-name />`. This
is the default — use it unless you need PHP logic.

**Class-based** — a Blade file plus a class at `app/View/Components/Name.php`
extending `Roots\Acorn\View\Component`. Use when you need non-trivial PHP (fetching,
transforming data). Scaffold with `wp acorn make:component Name`.

**Naming in class-based components:** constructor args use `camelCase`, HTML
attributes use `kebab-case`:

```blade
<x-image-card :image-id="$image" />
```

```php
public function __construct($imageId = null) { /* ... */ }
```

### View composers

Inject data into a Blade view automatically, regardless of who renders it:

```php
namespace App\View\Composers;

use Roots\Acorn\View\Composer;

class App extends Composer
{
    protected static $views = ['*'];    // or a specific view: 'sections.header'

    public function with(): array
    {
        return ['siteName' => get_bloginfo('name', 'display')];
    }
}
```

Public methods or values from `with()` become template variables (`$siteName` in Blade).
PSR-4 autoloading discovers them — file path and namespace must match `composer.json`.

---

## Vite pipeline — dev, build, theme.json

Sage ships with three Vite plugins:

- **`laravel-vite-plugin`** — entry points, HMR refresh on Blade + PHP changes
- **`@roots/vite-plugin`** — WordPress-aware asset URLs, generates `theme.json` from
  the Tailwind config
- **`@tailwindcss/vite`** — Tailwind CSS v4 integration (replaces v3 PostCSS)

### Commands

| Command | Purpose |
|---|---|
| `npm run dev` | Vite dev server with HMR. `vite.config.js` must match the local dev URL. |
| `npm run build` | Production build. Writes `public/build/` + `manifest.json` + `theme.json`. |
| `npm run watch` | Rebuild on file change (no dev server). |
| `npm run preview` | Preview the production build locally. |

### Entry points

`vite.config.js` declares an array of entry files. Stock Sage: `resources/css/app.css`,
`resources/js/app.js`, `resources/css/editor.css`, `resources/js/editor.js`.

The recommended additions extend this with an SCSS pair (`resources/scss/app.scss`,
`resources/scss/editor.scss`) for parts of the system that aren't Tailwind-native.

### The manifest

After `npm run build`, `public/build/manifest.json` maps source paths to hashed
output files. The recommended enqueue pattern reads this manifest directly (see
"Asset enqueue pattern" below) rather than using the `Vite` facade, to support
dev-server detection.

Referencing built assets in Blade via the official facade:

```blade
<img src="{{ Vite::asset('resources/images/example.svg') }}">
```

In CSS:

```css
.bg { background-image: url("@images/example.svg"); }
```

(`@images/` is a `resolve.alias` in `vite.config.js`.)

### `theme.json` is auto-generated

The `theme.json` at the theme root is a **preprocessed template**. The real one that
WordPress reads is generated during `npm run build` at `public/build/assets/theme.json`.
Sage filters WP to load it from there:

```php
add_filter('theme_file_path', function ($path, $file) {
    return $file === 'theme.json' ? public_path('build/assets/theme.json') : $path;
}, 10, 2);
```

The generator copies Tailwind colors, font families, and font sizes into `theme.json`
so the block editor palette matches the frontend. Because `theme.json` is generated,
**never hand-edit the copy WordPress reads.** Edit the preprocessed `theme.json` at
the theme root, or edit the Tailwind config, then rebuild.

### Block editor (Gutenberg)

- Sage enqueues `resources/js/editor.js` and `resources/css/editor.css` in the
  editor context. Editor-only CSS goes in `editor.css`.
- All blocks must support block API version 3, or the editor won't iframe and styles
  break.
- Because `theme.json` is generated from Tailwind, `add_theme_support()` calls for
  palette, font sizes, etc. are **ignored** — configure those via Tailwind + the
  preprocessed `theme.json`.

---

## Deployment

### Pre-deploy (local or CI)

```bash
npm run build
composer install --no-dev --optimize-autoloader
```

### What to upload

Upload the theme directory **without** `node_modules/`. Upload `public/build/` (Vite
output) and `vendor/` (production Composer deps). Everything else uploads normally.

### Post-deploy (on the server)

```bash
# Ensure Acorn's storage scaffolding exists
mkdir -p storage/framework/{cache,sessions,testing,views}
mkdir -p storage/logs
chmod -R 755 storage

# Activate the theme if it isn't already
wp theme is-active {theme-name} || wp theme activate {theme-name}

# Clear Acorn caches, then pre-compile views — view:cache goes LAST
wp acorn optimize:clear
wp acorn view:cache

# Flush WP caches + rewrite rules
wp cache flush
wp rewrite flush
```

Save this as `post-deploy.sh` at the theme root and commit it. Don't reinvent
per-project.

### Blade file security

Every file in the theme folder is publicly accessible by default. Block `.blade.php`
files from being served:

**Nginx:**

```nginx
location ~* \.(blade\.php)$ { deny all; }
```

**Apache / `.htaccess`:**

```apache
<FilesMatch ".+\.(blade\.php)$">
  <IfModule mod_authz_core.c>
    Require all denied
  </IfModule>
</FilesMatch>
```

WP Engine handles this at the platform level. Kinsta and most other managed hosts do
not — verify after every migration or server change.

---

## Recommended additions on top of stock Sage

These additions represent a proven, production-tested layer. Frame them as defaults
you reach for on new projects, not mandates — inherited themes stay in Mode B.

### PHP / `app/` additions

| File | Purpose |
|---|---|
| `app/helpers.php` | Global helpers (`bg_image`, `acf_responsive_image`, `acf_picture`, `custom_breadcrumbs`). Autoloaded via Composer `"files"`. |
| `app/acf-blocks-{developer}.php` | ACF block registrations. One file per developer (optional team convention — keeps merge conflicts minimal). |
| `app/forms.php` | AJAX form handlers. |
| `app/block-patterns.php` | WordPress block patterns. |
| `app/Helpers/NavigationHelper.php` | Menu/nav data transformation. |
| `app/Walkers/{Name}Walker.php` | Custom menu walkers. |

Add each to the `collect([...])` array in `functions.php`.

### Resource pipeline additions

| Addition | Why |
|---|---|
| SCSS entry (`resources/scss/app.scss`, `resources/scss/editor.scss`) alongside CSS | Legacy SCSS pipeline alongside Tailwind v4 CSS entry. Both are Vite entry points. |
| `resources/components/{name}/` | JS + CSS co-located with their Blade component. |
| `resources/icons/` + `vite-plugin-svg-icons` | SVG sprite, rendered via `<x-icon>`. |
| `resources/animations/` | Lottie JSON files. |
| `resources/fonts/` + `@font-face` in `resources/css/fonts.css` | Custom fonts. |
| `vite-imagetools` in `vite.config.js` | Generates WebP + JPEG/PNG variants at build time. |
| `resolve.alias` (`@scripts`, `@styles`, `@scss`, `@fonts`, `@images`, `@components`) | Cleaner imports across Blade/CSS/JS. |

### Complete expanded directory layout

```
{theme-name}/
├── acf-json/                          # ACF JSON sync (source of truth for field groups)
├── app/
│   ├── acf-blocks-{developer}.php     # ACF block registrations (one per developer)
│   ├── block-patterns.php
│   ├── filters.php                    # ACF JSON sync filters live here
│   ├── forms.php
│   ├── helpers.php                    # Autoloaded global functions
│   ├── setup.php                      # Enqueues, image sizes, menus, supports
│   ├── Helpers/NavigationHelper.php
│   ├── Providers/ThemeServiceProvider.php
│   ├── View/Composers/                # App.php, Post.php, Comments.php
│   └── Walkers/                       # NavWalker.php, FooterMenuWalker.php
├── resources/
│   ├── components/{name}/             # {name}.js + {name}.css per component
│   ├── css/
│   │   ├── app.css                    # Tailwind v4 entry, @import chain
│   │   ├── theme-colors.css           # @theme directive: --color-{project}-*
│   │   ├── theme-breakpoints.css      # Breakpoint definitions
│   │   ├── fonts.css                  # @font-face declarations
│   │   ├── components.css             # @layer components — shared classes
│   │   ├── utilities.css              # @layer utilities
│   │   ├── animations.css             # @keyframes
│   │   ├── editor.css
│   │   └── editor-styles.css
│   ├── scss/                          # Supplementary SCSS pipeline
│   │   ├── app.scss
│   │   ├── editor.scss
│   │   └── abstracts/ + base/
│   ├── js/
│   │   ├── app.js                     # Alpine init + all component imports
│   │   ├── editor.js
│   │   └── utils/                     # helpers.js, form-api.js
│   ├── views/
│   │   ├── layouts/app.blade.php
│   │   ├── sections/                  # Full-width page blocks
│   │   ├── components/                # Reusable UI components
│   │   ├── partials/                  # WordPress loop fragments
│   │   ├── blocks/                    # ACF block render templates
│   │   └── *.blade.php                # WP template hierarchy files
│   ├── fonts/
│   ├── icons/                         # SVG sprite source
│   ├── images/
│   ├── animations/                    # Lottie JSON
│   └── video/
├── public/                            # Vite output — gitignored
├── storage/                           # Acorn cache + logs
├── vendor/                            # Composer deps — gitignored
├── post-deploy.sh                     # Post-deployment script
├── composer.json
├── package.json
├── vite.config.js
├── tailwind.config.js
├── theme.json                         # Preprocessed; real copy generated by build
└── style.css                          # Theme metadata only
```

### Asset enqueue pattern (dev-server detection)

The recommended pattern in `app/setup.php` replaces Sage's stock enqueue with a
function that auto-detects whether the Vite dev server is running:

1. Pings `/@vite/client` with a 0.5s timeout.
2. **Dev mode:** injects `<script type="module">` tags for `@vite/client` and each
   entry, bypassing `wp_enqueue_script` (which can't handle `type="module"` ordering).
3. **Prod mode:** reads `public/build/manifest.json` and enqueues CSS/JS via
   `wp_enqueue_style` / `wp_enqueue_script` with hashed filenames.
4. Localizes the script bundle with `ajaxParams` (`ajax_url`, nonce).

`vite.config.js` `base` path switches accordingly:

```js
const basePath = isProduction
    ? '/wp-content/themes/{theme-name}/public/build/'
    : '/app/themes/{theme-name}/public/build/';   // adjust to your local WP path
```

### ACF Pro conventions

Sage doesn't require ACF — these are additions:

- JSON sync enabled in `app/filters.php` — save/load from `acf-json/`.
- Field group keys: `group_{descriptive_name}` (e.g. `group_hero_block`).
- Field keys: `field_{descriptive_name}` (e.g. `field_hero_title`).
- CPTs registered via ACF's CPT UI, synced as `post_type_{hash}.json`.
- Blocks registered via `acf_register_block_type()` in `app/acf-blocks-{developer}.php`.

See `acf-blocks.md` for full block registration patterns and preview conventions.

### Responsive image sizes

Register a standard grid in `app/setup.php`:

```php
add_action('after_setup_theme', function () {
    add_image_size('responsive-xl',      1920, 1080, false);
    add_image_size('responsive-xl-crop', 1920, 1080, true);
    add_image_size('responsive-lg',      1200,  675, false);
    add_image_size('responsive-md',       992,  558, false);
    add_image_size('responsive-sm',       768,  432, false);
    add_image_size('responsive-xs',       576,  324, false);
});
```

### JavaScript stack

Sage ships zero JS framework. Recommended additions, all imported through
`resources/js/app.js`:

- **Alpine.js** + `@alpinejs/collapse` — interactivity
- **GSAP** — animations
- **Splide.js** — carousels
- **lottie-web** — JSON animations

No jQuery. No vanilla DOM manipulation for interactive features.

### CSS: Tailwind v4 + 3-layer model

Use `@tailwindcss/vite` + `tailwindcss@^4`. Design tokens via the `@theme` directive
in `theme-colors.css` and `theme-breakpoints.css`.

The 3-layer CSS model (tokens → shared components → per-block layout) is described in
`css-architecture.md`. Follow it strictly — don't duplicate it here.

---

## Quick troubleshooting

| Symptom | First check |
|---|---|
| `Vite manifest not found` | Run `npm run build`. |
| Styles missing in dev, work in build | Dev server not reachable. Check `vite.config.js` `base`, `server.host`, `server.port`, HTTPS cert. |
| Changes to Blade/PHP don't trigger HMR refresh | Confirm `laravel-vite-plugin`'s `refresh:` array includes the path. |
| Editor styles broken | Check `editor.css` is enqueued via `enqueue_block_editor_assets` AND all blocks are API v3. |
| `wp acorn ...` command not found | `composer install` didn't complete, or `roots/acorn ^5.0` missing from `composer.json`. |
| Views render stale after deploy | `wp acorn view:clear` then `wp acorn view:cache`. |
| `theme.json` palette doesn't match frontend | Rebuild — `theme.json` is regenerated from Tailwind on `npm run build`. |
| ACF field groups missing on another machine | They're in `acf-json/` — commit the JSON. Check `app/filters.php` has the ACF save/load filters. |
| Post-deploy: white screen or Blade errors | Storage dirs missing. Run `mkdir -p storage/framework/{cache,sessions,testing,views} storage/logs && chmod -R 755 storage`. |

---

## Cross-references

- `css-architecture.md` — the 3-layer CSS model (tokens → components → per-block)
- `acf-blocks.md` — full ACF block registration, modes, preview conventions
- `component-system.md` — sections / components / partials, core components, Alpine pattern
- `inherited-projects.md` — Mode B (non-Sage themes): matching existing architecture
- `../git-workflow.md` — branch, commit, push, and tag rules
- `../ci-cd/patterns.md` — deploy command sequences per CI/CD pattern
- `../dev-conventions.md` — full Mode A / Mode B decision and naming conventions
