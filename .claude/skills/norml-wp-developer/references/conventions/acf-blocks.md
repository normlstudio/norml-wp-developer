# ACF Blocks — Registration, Previews, and JSON Sync

Every editor-facing content section is an ACF block. This file covers the
canonical registration pattern, render-callback split between Sage and vanilla
PHP, custom block categories, block support declarations, block previews (live
and static), ACF JSON sync, and the most common ACF-block gotchas.

---

## Prerequisites

- ACF PRO 6.0+ (required for `acf_register_block_type()`)
- Gutenberg (the block editor) active
- Block registration must happen on the `acf/init` action, not `init` or
  `after_setup_theme`

---

## Canonical registration

```php
<?php
// inc/acf-blocks.php (vanilla) or app/acf-blocks-{dev}.php (Sage)

add_action('acf/init', function () {
    if (! function_exists('acf_register_block_type')) {
        return; // ACF PRO not active — bail gracefully
    }

    acf_register_block_type([
        'name'        => 'benefits',
        'title'       => __('Benefits', 'theme-textdomain'),
        'description' => __('Three-column benefits grid with icon, heading, and body.', 'theme-textdomain'),
        'category'    => 'theme-blocks',   // see custom category below
        'icon'        => 'star-filled',    // dashicon slug or custom SVG string
        'keywords'    => ['benefits', 'features', 'grid'],
        'mode'        => 'preview',        // editor shows the rendered preview by default
        'supports'    => [
            'align'  => false,             // no wide / full align handles
            'anchor' => true,              // lets editors link directly to a section
            'jsx'    => false,             // set true only if the block uses InnerBlocks
            'mode'   => false,             // hide the Edit / Preview toggle (optional)
        ],
        'example'     => [
            'attributes' => [
                'mode' => 'preview',
                'data' => ['is_example' => true],
            ],
        ],
        'render_callback' => function ($block) {
            // See "Render callback" section below for both patterns
        },
    ]);
});
```

**Rules that hold across both Sage and vanilla:**

- Always guard with `function_exists('acf_register_block_type')`.
- Register inside `acf/init`, never earlier.
- Each block gets its own registration call — never merge two blocks into one
  registration with a conditional.
- Keep `description` honest — it appears in the block inserter.
- Use `mode: 'preview'` so the editor sees the rendered block on first insert,
  not an empty field UI.
- Every block must support `anchor` — it's zero cost and lets editors create
  `#section-id` deep links without developer involvement.
- Set `jsx: true` only when the block template uses `<InnerBlocks />`.

---

## Render callback — Sage vs. vanilla PHP

### Sage (Blade)

```php
'render_callback' => function ($block) {
    echo view('sections.benefits', ['block' => $block]);
},
```

`view()` is Acorn's Blade renderer. The `$block` array contains the block's
registered name, className, alignment, anchor, and the `data` payload used
by previews.

### Vanilla PHP (`get_template_part`)

`get_template_part()` doesn't accept arbitrary variables. Use `set_query_var()`
to pass `$block` into the template:

```php
'render_callback' => function ($block) {
    set_query_var('block', $block);
    get_template_part('template-parts/sections/benefits');
},
```

Inside the template, retrieve it:

```php
<?php
// template-parts/sections/benefits.php
$block = get_query_var('block');
```

WordPress 5.5+ supports a third argument to `get_template_part()` (`$args`),
which is cleaner — avoid `set_query_var` if you're on WP 5.5+:

```php
// Registration:
'render_callback' => function ($block) {
    get_template_part('template-parts/sections/benefits', null, ['block' => $block]);
},

// Template:
$block = $args['block'] ?? [];
```

### `render_template` (alternative to `render_callback`)

For simpler blocks with no Sage dependency, `render_template` is an
acceptable alternative. The file is included directly and has access to
`$block`, `$content`, `$is_preview`, and `$post_id` as local variables:

```php
'render_template' => 'template-parts/sections/benefits.php',
```

Use `render_callback` when you need to pass extra computed data or when
you're in Sage and want Blade. Use `render_template` for simple vanilla
blocks where the local variables are sufficient.

---

## Custom block category

Register a project-specific category so all ACF blocks group together in the
block inserter, separate from WordPress core blocks and third-party plugin blocks.

Register once per theme — in the same file as block registrations, or in a
dedicated `inc/block-categories.php`:

```php
add_filter('block_categories_all', function ($categories) {
    array_unshift($categories, [
        'slug'  => 'theme-blocks',              // matches 'category' in each registration
        'title' => __('Theme Blocks', 'theme-textdomain'),
        'icon'  => null,
    ]);
    return $categories;
});
```

Use the project's own name for the category slug and title (e.g.
`'slug' => 'acme-blocks'`, `'title' => 'Acme Blocks'`). The slug must match
the `'category'` key in every `acf_register_block_type()` call.

---

## Block supports

```php
'supports' => [
    'align'  => false,   // or ['wide', 'full'] if the block needs wide/full alignment
    'anchor' => true,    // almost always true — free section deep-link
    'jsx'    => false,   // true only for InnerBlocks
    'mode'   => false,   // hides the Edit / Preview toggle from the block toolbar (optional)
],
```

**Align:** set `false` unless the block genuinely needs to break out of the
content column. Most section-level blocks do not — their container handles
width internally.

**Anchor:** always `true`. It costs nothing and lets editors add `#my-section`
IDs in the block settings panel without a developer.

**JSX / InnerBlocks:** set `jsx: true` when the block template contains
`<InnerBlocks />` so the editor can nest other Gutenberg blocks inside it.
Don't set it by default — it enables an empty inner-block drop zone in blocks
that don't need it.

---

## Block previews

**Every ACF block must have a preview in the block inserter.** An editor
choosing between twelve blocks should see what each one looks like — not a
generic dashicon. This is non-negotiable.

Two paths: live preview (default) and static screenshot (fallback).

### Live preview (default)

The block registers an `example` payload. When the Gutenberg inserter renders
the block thumbnail, it calls `render_callback` (or renders `render_template`)
with the example data. The template detects `is_example` and renders
hardcoded realistic sample content — no database queries, no ACF field reads.

**Registration (already shown above):**

```php
'mode'    => 'preview',
'example' => [
    'attributes' => [
        'mode' => 'preview',
        'data' => ['is_example' => true],
    ],
],
```

**Template — vanilla PHP:**

```php
<?php
// template-parts/sections/benefits.php
$block      = get_query_var('block');
$is_example = ! empty($block['data']['is_example']);

if ($is_example) {
    // Hardcoded realistic content — no get_field() calls
    $headline = 'Why teams choose this platform';
    $items    = [
        ['icon' => 'bolt',    'title' => 'Fast',     'body' => 'Deploys in seconds.'],
        ['icon' => 'shield',  'title' => 'Secure',   'body' => 'SOC 2 Type II certified.'],
        ['icon' => 'refresh', 'title' => 'Reliable', 'body' => '99.99% uptime SLA.'],
    ];
} else {
    $headline = get_field('headline') ?: 'Our benefits';
    $items    = get_field('items')    ?: [];
}

// Block wrapper class (supports ACF custom className + align)
$class = 'benefits app-section ' . ($block['className'] ?? '');
if (! empty($block['anchor'])) {
    echo '<div id="' . esc_attr($block['anchor']) . '"></div>';
}
?>

<section class="<?= esc_attr(trim($class)); ?>">
    <div class="app-container">
        <h2 class="app-display"><?= esc_html($headline); ?></h2>
        <div class="benefits__grid">
            <?php foreach ($items as $item) : ?>
                <div class="app-card">
                    <p class="app-eyebrow"><?= esc_html($item['title']); ?></p>
                    <p><?= esc_html($item['body']); ?></p>
                </div>
            <?php endforeach; ?>
        </div>
    </div>
</section>
```

**Template — Sage / Blade:**

```blade
{{-- resources/views/sections/benefits.blade.php --}}
@php
    $isExample = ! empty($block['data']['is_example']);
    $headline  = $isExample ? 'Why teams choose this platform' : (get_field('headline') ?: 'Our benefits');
    $items     = $isExample
        ? [
            ['title' => 'Fast',     'body' => 'Deploys in seconds.'],
            ['title' => 'Secure',   'body' => 'SOC 2 Type II certified.'],
            ['title' => 'Reliable', 'body' => '99.99% uptime SLA.'],
          ]
        : (get_field('items') ?: []);
    $class = trim('benefits app-section ' . ($block['className'] ?? ''));
@endphp

@if(! empty($block['anchor']))
    <div id="{{ $block['anchor'] }}"></div>
@endif

<section class="{{ $class }}">
    <div class="app-container">
        <h2 class="app-display">{{ $headline }}</h2>
        <div class="benefits__grid">
            @foreach ($items as $item)
                <x-card :title="$item['title']" :body="$item['body']" />
            @endforeach
        </div>
    </div>
</section>
```

**Example content quality:** use realistic copy that looks like a real client
site, not lorem ipsum. An editor comparing five blocks in the inserter should
be able to tell what each one is for.

### Static screenshot (fallback)

For blocks too heavy to live-render — complex sliders, blocks that depend on
external API responses, blocks with long JS initialization — place a PNG at
`{theme}/assets/blocks/previews/{block-name}.png` and serve it in the
example branch of `render_callback`:

```php
'render_callback' => function ($block) {
    if (! empty($block['data']['is_example'])) {
        $url = get_stylesheet_directory_uri()
             . '/assets/blocks/previews/'
             . $block['name']
             . '.png';
        echo '<img src="' . esc_url($url) . '"'
           . ' alt="' . esc_attr($block['title']) . ' preview"'
           . ' style="width:100%;height:auto;display:block;" />';
        return;
    }
    // Real render path
    set_query_var('block', $block);
    get_template_part('template-parts/sections/' . $block['name']);
},
```

**Rules for static screenshots:**

- Capture from a staging environment at desktop width (≥1440px), cropped
  tight to the block edges with no surrounding page chrome.
- Save as PNG, ≤300KB. Run `pngquant --quality 70-90 {slug}.png` if heavier.
- File name must match the block's registered `name` exactly:
  `benefits.png`, `pricing-table.png`.
- Re-capture whenever the block's design changes — a stale screenshot actively
  misleads editors about what they're inserting.
- Document in the theme README which blocks use screenshot fallback so the
  next developer knows to refresh them after a redesign.

---

## Block registration file organization

| Theme scale | Organization |
|---|---|
| ≤5 blocks | All in a single `inc/acf-blocks.php` |
| 6–15 blocks | One file per feature group: `inc/acf-blocks-content.php`, `inc/acf-blocks-marketing.php`, `inc/acf-blocks-layout.php` |
| 16+ blocks | One file per block: `inc/blocks/benefits.php`, `inc/blocks/hero.php` — include via `glob()` in `functions.php` |

Sage convention: all block registrations in `app/acf-blocks-{dev}.php`,
included via `functions.php`'s `collect()` array. In team projects, each
developer maintains their own file and one is designated the canonical file
at hand-off.

---

## ACF JSON sync

ACF JSON sync keeps field group definitions in version control so they travel
with the codebase and deploy with the next push.

### Enable sync (Sage)

```php
// app/filters.php
add_filter('acf/settings/save_json', function () {
    return get_stylesheet_directory() . '/acf-json';
});

add_filter('acf/settings/load_json', function ($paths) {
    unset($paths[0]);
    $paths[] = get_stylesheet_directory() . '/acf-json';
    return $paths;
});
```

### Enable sync (vanilla PHP)

```php
// inc/acf-json.php — include from functions.php
add_filter('acf/settings/save_json', function () {
    return get_stylesheet_directory() . '/acf-json';
});

add_filter('acf/settings/load_json', function ($paths) {
    unset($paths[0]);
    $paths[] = get_stylesheet_directory() . '/acf-json';
    return $paths;
});
```

Ensure `acf-json/` exists in the theme root and is committed to git
(not gitignored). ACF writes one JSON file per field group whenever you save
a group in wp-admin.

### The most common ACF JSON bug

**Developer edits a field group in wp-admin on staging. Forgets to commit
the JSON. The next deploy from main "loses" the field group changes.**

This happens because:

1. wp-admin write → `acf-json/group_{hash}.json` updated on the server's disk
2. Developer pushes unrelated code from local → deploy overwrites `acf-json/`
   from git → the field group reverts to the last committed version

**Habit to prevent it:**

```bash
# After any wp-admin field group edit on staging, immediately:
cd {theme_root}
git status acf-json/        # should show modified or new JSON file(s)
git add acf-json/
git commit -m "chore(acf): update {field-group-name} field group"
git push
```

If you open a project and `acf-json/` shows uncommitted changes, flag it
before doing anything else. Those are live field group definitions that will
vanish on the next deploy.

---

## Field key conventions

| Sage (new projects) | Vanilla / inherited |
|---|---|
| `group_{descriptive_name}` — e.g. `group_benefits_block` | Match the existing theme's convention — if it uses ACF's auto-generated `group_5fc83e...` hashes, continue that pattern |
| `field_{descriptive_name}` — e.g. `field_benefits_headline` | Same — match existing keys |

On new Sage projects: descriptive keys are required because the ACF JSON is
the source of truth and files need to be human-readable.

On inherited projects: match the existing convention, even if it's opaque
hashes. Changing key naming conventions mid-project is a migration with
real risk (existing saved field values are tied to field keys).

---

## Accessing field data in templates

```php
// Post-level field
$headline = get_field('headline') ?: 'Default headline';

// Repeater
$items = get_field('items') ?: [];
foreach ($items as $item) {
    $title = $item['title'] ?? '';
}

// Options page field
$phone = get_field('phone_number', 'option');

// Sub-field inside have_rows() loop
if (have_rows('team_members')) {
    while (have_rows('team_members')) {
        the_row();
        $name = get_sub_field('name');
    }
}
```

Always provide a fallback default — `get_field()` returns `false` when a
field has no value, and a `false` passed to `esc_html()` renders as an empty
string silently. Being explicit about the fallback makes templates readable.

---

## Block template output escaping

```php
// Text / HTML attribute
echo esc_html($variable);
echo esc_attr($variable);

// URLs (links, src, href)
echo esc_url($url);

// Trusted HTML (WYSIWYG field output)
echo wp_kses_post($content);

// Block class string (often contains user-added classNames)
echo esc_attr(trim('benefits ' . ($block['className'] ?? '')));
```

Never echo `$variable` or `get_field()` directly. Every output is escaped.
`wp_kses_post()` for WYSIWYG fields; `esc_html()` for everything else.

---

## Checklist — new block

Before marking a block registration done:

1. Registered inside `acf/init`, guarded by `function_exists`.
2. `mode: 'preview'` set so the editor sees the rendered block on first insert.
3. `anchor: true` in `supports`.
4. Custom block category registered and matching.
5. Preview works: hover the block in the inserter and see styled content, not an empty dashicon.
6. If live preview: `is_example` branch renders realistic hardcoded content with no `get_field()` calls.
7. If static screenshot: PNG ≤300KB in `assets/blocks/previews/{name}.png`, filename matches block `name`.
8. Template escapes all output.
9. ACF field group saved and `acf-json/` JSON committed.
10. Conditional CSS enqueue added in `inc/enqueue.php` (see `css-architecture.md`).

---

## Cross-references

- `../dev-conventions.md` — ACF field key rules and quick reference
- `../conventions/css-architecture.md` — per-block conditional CSS enqueue (Layer 3)
- `../conventions/sage-stack.md` — Blade render pattern and `view()` helper in depth
- `../conventions/component-system.md` — section / component / partial boundaries; when a block delegates to components
- `../conventions/inherited-projects.md` — matching the existing ACF pattern in an inherited theme
