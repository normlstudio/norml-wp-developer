# CSS Architecture — 3-Layer Model

The 3-layer model is the single CSS rule that applies to every block, every
page, and both Sage and inherited themes. It's not optional. It's not a
"nice to have for big projects." It's the default from the first line of CSS
you write.

---

## Why the model exists

The alternative is per-page stylesheets — a `css/blocks-{page}-page.css`
that re-defines buttons, cards, eyebrows, and palette tokens for one page.
That pattern fragments a site's visual system. After two pages it's visible
to the human eye: different button radii, different shades of "primary," text
that reads as "amateurish" because it came from a different design system
than the one three screens ago. After five pages, a full refactor costs more
than the original build.

A real example (genericized): one inherited project had grown a 700-line
per-page stylesheet for a single campaign page. It re-defined `.btn`, `.card`,
`.eyebrow`, `.accordion`, and introduced a parallel palette of page-scoped
tokens (`--pi-dark`, `--pi-gold-dark`, `--pi-accent`) that mirrored the
global palette with slight drifts. Refactoring it to the 3-layer model
produced a ~455-line shared `components.css` and small per-block layout
files. Seven of nine blocks required ZERO Layer 3 file — they composed
Layer 2 entirely.

That's the goal: most blocks have no Layer 3 file at all.

---

## The model

| Layer | What it holds | Where it lives | When it loads |
|---|---|---|---|
| **1 — Tokens** | CSS custom properties at `:root` (palette, typography, spacing, radii) | Theme-level tokens file or `:root` block in foundational stylesheet | Always |
| **2 — Components** | One shared stylesheet of reusable visual primitives — buttons, cards, sections, eyebrows, accordions, banners, stats | `css/components.css` (vanilla) or `resources/css/components.css` (Sage) | Always, globally enqueued on every page |
| **3 — Block layout** | Per-block layout only — grid, flex, positioning, decorative pseudo-elements, responsive breakpoints unique to the block | `css/blocks/{slug}.css` (vanilla) or `resources/css/blocks/{slug}.css` (Sage) | Conditionally, only on pages that contain the block (`has_block()`) |

---

## Layer 1 — Tokens

Single source of truth for every design primitive. Never scatter hex literals
across block files. Every color, font stack, spacing scale, and radius is a
token first.

**Vanilla / inherited theme:**

```css
/* css/tokens.css (or :root in style.css / css/variables.css — match what's there) */
:root {
    /* Palette */
    --color-primary:        #1a56db;
    --color-primary-dark:   #1040b0;
    --color-neutral-900:    #0d1317;
    --color-neutral-100:    #f5f5f5;
    --color-surface:        #ffffff;
    --color-danger:         #dc2626;

    /* Typography */
    --font-display:  'Barlow', sans-serif;
    --font-body:     'Inter', sans-serif;
    --font-size-base: 1rem;
    --leading-body:  1.6;

    /* Spacing */
    --spacing-section:  clamp(3rem, 6vw, 5.5rem);
    --spacing-block:    clamp(1.5rem, 3vw, 2.5rem);

    /* Radii */
    --radius-sm:  4px;
    --radius-md:  8px;
    --radius-lg:  16px;
}
```

**Sage / Tailwind v4:**

```css
/* resources/css/app.css — Tailwind v4 entry */
@import "theme-colors.css";
@import "theme-breakpoints.css";
@import "fonts.css";
@import "components.css";
```

```css
/* resources/css/theme-colors.css */
@theme {
    --color-primary:        #1a56db;
    --color-primary-dark:   #1040b0;
    --color-neutral-900:    #0d1317;
    --color-surface:        #ffffff;

    --font-display: 'Barlow', sans-serif;
    --font-body:    'Inter', sans-serif;
}
```

**Pick a namespace prefix for every shared-component class.** One per project,
used consistently. Options: `.app-*`, `.{theme-slug}-*`, `.{client-initials}-*`.
Use it for every class that belongs to Layer 2 (e.g., `.app-card`, `.app-btn`,
`.app-eyebrow`). This isolates your authored classes from theme, plugin, and
page-builder classes. The examples in this document use `.app-*`; substitute
your chosen prefix.

**Before introducing a new token:** confirm no existing token covers it. If
you genuinely need a new semantic role, add it to the tokens file with a
one-line comment. Never add page-scoped tokens (`--pricing-gold`,
`--landing-accent`, `--hero-dark`).

---

## Layer 2 — Shared components (always enqueued)

One file. Holds every visual primitive that could appear on more than one page.

```css
/* css/components.css (vanilla) or resources/css/components.css (Sage) */

/* --- Section wrappers --- */
.app-section {
    padding-block: var(--spacing-section);
}
.app-section--alt    { background: var(--color-neutral-100); }
.app-section--dark   { background: var(--color-neutral-900); color: var(--color-surface); }

.app-container {
    width: min(1200px, 100% - 2 * clamp(1rem, 4vw, 3rem));
    margin-inline: auto;
}

/* --- Typography helpers --- */
.app-eyebrow {
    font-family:    var(--font-display);
    font-size:      0.75rem;
    font-weight:    700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color:          var(--color-primary);
}

.app-display {
    font-family: var(--font-display);
    font-weight: 700;
    line-height: 1.1;
}

/* --- Buttons --- */
.app-btn {
    display:         inline-flex;
    align-items:     center;
    gap:             0.5rem;
    padding:         0.75rem 1.5rem;
    font-family:     var(--font-display);
    font-weight:     700;
    border-radius:   var(--radius-md);
    text-decoration: none;
    transition:      background 0.2s, color 0.2s;
}
.app-btn--primary   { background: var(--color-primary); color: var(--color-surface); }
.app-btn--outline   { border: 2px solid currentColor; }
.app-btn--lg        { padding: 1rem 2rem; font-size: 1.125rem; }

/* --- Cards --- */
.app-card {
    background:    var(--color-surface);
    border-radius: var(--radius-lg);
    padding:       var(--spacing-block);
    box-shadow:    0 1px 3px rgba(0,0,0,0.08);
}

.app-card-grid {
    display:               grid;
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
    gap:                   var(--spacing-block);
}

/* --- Stats --- */
.app-stats-bar  { display: flex; flex-wrap: wrap; gap: var(--spacing-block); }
.app-stat__num  { font-size: clamp(2rem, 5vw, 3.5rem); font-weight: 700; }
.app-stat__label { font-size: 0.875rem; color: inherit; opacity: 0.75; }

/* --- Accordion --- */
.app-accordion details { border-bottom: 1px solid rgba(0,0,0,0.1); }
.app-accordion summary { padding: 1rem 0; cursor: pointer; font-weight: 600; }
```

**In Sage / Tailwind v4**, keep classes here too — in `@layer components` so
Tailwind utilities still win specificity battles:

```css
/* resources/css/components.css */
@layer components {
    .app-section {
        @apply py-16 md:py-24;
    }
    .app-container {
        @apply w-full max-w-6xl mx-auto px-4 md:px-8;
    }
    .app-btn {
        @apply inline-flex items-center gap-2 px-6 py-3 font-bold rounded-lg transition;
    }
    .app-btn--primary {
        @apply bg-primary text-white hover:bg-primary-dark;
    }
}
```

**Audit-first rule — run this before writing any new styling:**

1. Does `components.css` already have the pattern (button, card, eyebrow,
   accordion, banner, stat)? If yes — use it.
2. Would another block or another page also need this pattern? If yes — add
   it to `components.css` before touching a block file.
3. Only if genuinely unique to this one block → proceed to Layer 3.

---

## Layer 3 — Per-block layout (conditionally enqueued)

`css/blocks/{slug}.css` — **layout only.** Grid structure, flex alignment,
positioning, decorative pseudo-elements, block-specific responsive rules.

Class naming: `.{slug}__{element}` (e.g., `.benefits__grid`, `.hero__trust-strip`).
The block-slug prefix prevents collisions between blocks that share element names.

```css
/* css/blocks/benefits.css */
.benefits__grid {
    display:               grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap:                   2rem;
    margin-block-start:    var(--spacing-block);
}

.benefits__icon {
    width:  3rem;
    height: 3rem;
    margin-block-end: 0.75rem;
}

@media (max-width: 640px) {
    .benefits__grid { grid-template-columns: 1fr; }
}
```

Notice: no hex values, no `font-family`, no `.btn` re-definitions. The block
composes `app-section`, `app-eyebrow`, and `app-card` from Layer 2 in its
template; this file handles only what's unique to this block's layout.

**A block with no unique layout needs no Layer 3 file.** Resist the urge to
create one if the block's entire layout works with Layer 2 classes. That's
the system working correctly.

---

## Enqueuing — vanilla / inherited theme

```php
<?php
// inc/enqueue.php (or wherever the theme handles asset loading)

add_action('wp_enqueue_scripts', function () {

    // Layer 1 tokens (if a separate file; else they live in style.css / components.css)
    wp_enqueue_style(
        'theme-tokens',
        get_stylesheet_directory_uri() . '/css/tokens.css',
        [],
        filemtime(get_stylesheet_directory() . '/css/tokens.css')
    );

    // Layer 2 — always, every page
    wp_enqueue_style(
        'theme-components',
        get_stylesheet_directory_uri() . '/css/components.css',
        ['theme-tokens'],
        filemtime(get_stylesheet_directory() . '/css/components.css')
    );

    // Layer 3 — conditional, per block
    $blocks = [
        'benefits'      => 'acf/benefits',
        'hero'          => 'acf/hero',
        'pricing-table' => 'acf/pricing-table',
    ];

    foreach ($blocks as $slug => $block_name) {
        $file = get_stylesheet_directory() . '/css/blocks/' . $slug . '.css';
        if (file_exists($file) && has_block($block_name)) {
            wp_enqueue_style(
                'block-' . $slug,
                get_stylesheet_directory_uri() . '/css/blocks/' . $slug . '.css',
                ['theme-components'],
                filemtime($file)
            );
        }
    }
});

// Mirror in the editor so block previews match the front end
add_action('enqueue_block_editor_assets', function () {
    wp_enqueue_style(
        'theme-components-editor',
        get_stylesheet_directory_uri() . '/css/components.css',
        [],
        filemtime(get_stylesheet_directory() . '/css/components.css')
    );
    // Optionally enqueue all block stylesheets unconditionally in the editor
    // so the editor preview is always accurate (no block detection needed):
    foreach (glob(get_stylesheet_directory() . '/css/blocks/*.css') as $file) {
        $slug = basename($file, '.css');
        wp_enqueue_style(
            'block-' . $slug . '-editor',
            get_stylesheet_directory_uri() . '/css/blocks/' . $slug . '.css',
            ['theme-components-editor'],
            filemtime($file)
        );
    }
});
```

`filemtime()` is the cache-bust mechanism — no query-string version bumping
needed; the file's own modified timestamp handles it.

---

## Enqueuing — Sage / Tailwind v4

In Sage, Vite handles the build. `app.css` imports everything via
`@import`. Per-block CSS lives in `resources/css/blocks/{slug}.css` and is
either:

a) Imported unconditionally in `app.css` (simplest; fine for small themes)
b) Enqueued conditionally via PHP for larger builds where payload matters:

```php
// app/setup.php
add_action('wp_enqueue_scripts', function () {
    // Vite handles app.css (Layers 1 + 2) via its own enqueue
    // Conditionally add block sheets produced by Vite:
    $blocks = ['hero', 'benefits', 'pricing-table'];
    foreach ($blocks as $slug) {
        if (has_block('acf/' . $slug)) {
            wp_enqueue_style(
                'block-' . $slug,
                asset('css/blocks/' . $slug . '.css')->uri(),
                [],
                null // Vite output is content-hashed
            );
        }
    }
}, 20);
```

---

## The forbidden pattern — per-page stylesheets

**Never create these:**

```
css/blocks-home-page.css
css/blocks-pricing-page.css
css/landing-contact.css
style-about.css
resources/css/pages/services.css
```

Detect them with:

```bash
find css resources/css -name "*page*.css" -o -name "page-*.css" -o -name "blocks-*-page.css"
# Any non-empty result = violation
```

If you find yourself reaching for one, stop. Diagnose why. Nine times out of
ten the real answer is: the pattern belongs in `components.css` (Layer 2) and
you haven't audited it yet. The other time: the styling is block-specific
layout and belongs in `css/blocks/{slug}.css` (Layer 3) with no page scope.

---

## Don't / do cheat sheet

| Don't | Do |
|---|---|
| `css/blocks-{page}-page.css` for any page | Put reusable patterns in `components.css`; unique layout in `css/blocks/{slug}.css` |
| `--pi-dark`, `--pricing-gold`, `--landing-accent` (page-scoped tokens) | Use the global palette tokens; add semantic extensions to `tokens.css` if missing |
| `font-family: 'Poppins'` inside a block file | `font-family: var(--font-display)` |
| New `.cta-button` in a block file | Extend or compose `app-btn` from Layer 2 |
| Hex literals in block files (`#1a56db`) | `var(--color-primary)` |
| Copy-paste mockup CSS verbatim | Audit mockup → map every color/font/size to a token or Layer 2 class → only ship the layout delta |
| `wp_enqueue_style('block-hero', ..., [])` with hardcoded version string | `filemtime(get_stylesheet_directory() . '/css/blocks/hero.css')` |

---

## Pre-flight checklist before writing any new block's CSS

Run this before opening `css/blocks/{slug}.css`:

1. Every color references a token (`var(--color-*)`) — zero hex literals.
2. No `font-family` declaration in the block file — use `var(--font-*)`.
3. Buttons compose from the shared button class (`app-btn` or equivalent) — no bespoke `.cta-button`.
4. The block's section wrapper, container, and eyebrow use Layer 2 classes — look before you build.
5. The block layout file is ≤80 lines for a typical block (more is a smell; comment why if justified).
6. No `css/blocks-{page}-page.css` created — not even "just to prototype."

---

## Refactoring an existing per-page stylesheet

If you inherit a theme with one (or several) per-page CSS files:

1. **Propose it as a separate scope** — don't refactor silently while adding a feature.
2. **Phase 1: extract shared patterns.** Move every button, card, eyebrow,
   accordion, and typography helper to `components.css`. Use a consistent
   namespace prefix throughout (`app-*`). Map page-scoped tokens to their
   global equivalents or add proper semantic tokens to `tokens.css`.
3. **Phase 2: strip the block files.** For each block that used the old
   per-page file, create `css/blocks/{slug}.css` with layout only.
   Most blocks will need no Layer 3 file at all.
4. **Phase 3: delete the per-page file and update the enqueue.** Verify
   visually across the affected pages before committing.

Expect: a 600–800 line per-page CSS file condenses to a ~450-line
`components.css` plus several small (30–80 line) block files, with most
blocks using zero Layer 3 CSS.

---

## Cross-references

- `../dev-conventions.md` — 3-layer model summary and forbidden patterns
- `../conventions/acf-blocks.md` — per-block conditional enqueue wired to block registration
- `../conventions/sage-stack.md` — Tailwind v4 `@theme` / `@layer` conventions in depth
- `../conventions/inherited-projects.md` — decision flow before touching an inherited theme's CSS
