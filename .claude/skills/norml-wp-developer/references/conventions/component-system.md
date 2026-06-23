# Component System — Reference

> **Non-Sage themes:** apply the same section / component / partial separation
> described here using plain PHP templates. See `inherited-projects.md`
> for how the three-type model maps onto inherited project patterns.

This document defines how to build Blade templates in Sage WordPress themes. There are
three distinct template types — sections, components, and partials. Use each one for
its declared purpose. Never conflate them.

---

## Three Template Types

### 1. Sections — `resources/views/sections/`

Full-width page blocks. These are the structural units that pages are composed from.

**Create a section when:**
- It represents a visually distinct block on a page (hero, benefits grid, FAQ, CTA)
- It may be backed by ACF fields (either as a Gutenberg block or via page fields)
- It's included in a page template via `@include('sections.name')`

**Section anatomy:**

```blade
{{--
  Hero Section
  ACF fields: section_title, section_subtitle, cta_link
  Used in: front-page.blade.php, template-landing.blade.php
--}}
@props([
    'containerClass' => '',     // Optional class override from parent
    'isStackItem'    => false,
])

@php
    // 1. Retrieve ACF data with fallback defaults
    $title    = get_field('section_title')    ?: 'Default Heading';
    $subtitle = get_field('section_subtitle') ?: '';
    $cta      = get_field('cta_link')         ?: [];

    // 2. Computed values
    $hasSubtitle = ! empty($subtitle);
    $hasCta      = ! empty($cta);
@endphp

<section class="py-20 {{ $containerClass }}"
    {!! isset($block['anchor']) ? 'id="' . esc_attr($block['anchor']) . '"' : '' !!}>
    <div class="section-container">

        <h1 class="text-{project}-primary-blue">{{ $title }}</h1>

        @if ($hasSubtitle)
            <p class="text-body-lead">{{ $subtitle }}</p>
        @endif

        @if ($hasCta)
            <a href="{{ esc_url($cta['url']) }}" class="btn btn-primary">
                {{ esc_html($cta['title']) }}
            </a>
        @endif

    </div>
</section>
```

**Section rules:**
- Retrieve ACF data at the top of the `@php` block — never mid-template.
- Always provide fallback defaults: `get_field('name') ?: 'default'`.
- Use `section-container` for the main width constraint.
- Use semantic HTML: `<section>`, not `<div>`.
- Support block anchor: `{!! isset($block['anchor']) ? 'id="..."' : '' !!}`.
- Mobile-first responsive classes.
- Accept `@props` for override customization from parent templates.

**Including sections in page templates:**

```blade
@extends('layouts.app')

@section('content')
    @include('sections.hero')

    {{-- With prop overrides --}}
    @include('sections.logo-bar', [
        'containerClass' => 'border-t border-t-{project}-border-light'
    ])

    {{-- Gutenberg content zone (renders ACF blocks) --}}
    @while (have_posts())
        @php(the_post())
        {!! the_content() !!}
    @endwhile

    @include('sections.cta')
@endsection
```

---

### 2. Components — `resources/views/components/`

Reusable UI elements used across multiple sections via `<x-name />` syntax.

**Create a component when:**
- It's used in 2+ places.
- It encapsulates a distinct UI pattern (button, card, modal, accordion, icon).
- It accepts props and renders consistently regardless of context.

**Component anatomy:**

```blade
{{--
  Benefit Card
  @param string $title       Card heading
  @param string $description Body copy
  @param string $type        'default' | 'highlight'
  @param string $class       Additional classes (optional)
--}}

@props([
    'title'       => '',
    'description' => '',
    'type'        => 'default',
    'class'       => '',
])

@php
    $typeClasses = [
        'default'   => 'bg-white text-{project}-primary-blue',
        'highlight' => 'bg-{project}-primary-blue text-white',
    ];
    $classes = $typeClasses[$type] ?? $typeClasses['default'];
@endphp

<div class="rounded-2xl p-6 {{ $classes }} {{ $class }}">
    @if ($title)
        <h5 class="mb-2">{{ $title }}</h5>
    @endif
    @if ($description)
        <p class="text-body-medium">{{ $description }}</p>
    @endif
    {{ $slot ?? '' }}
</div>
```

**Component rules:**
- Always declare `@props([])` at the top with defaults.
- Document props in a comment block above `@props`.
- Components are **stateless** — they receive data via props. Never call `get_field()`
  inside a component. ACF data retrieval belongs in the calling section.
- Use `$slot` for flexible content injection.
- Use the `$attributes` bag to pass through HTML attributes transparently.
- Compute variant classes in `@php`, not inline in the markup.

**Using components:**

```blade
{{-- Simple --}}
<x-icon name="arrow-right" class="w-4 h-4" />

{{-- With props --}}
<x-benefit-card :title="$item['title']" :description="$item['description']" type="highlight" />

{{-- With slot --}}
<x-modal id="get-started">
    <p>Modal content here.</p>
</x-modal>

{{-- With Alpine.js attributes passed through --}}
<x-icon name="plus" x-show="!expanded" class="w-6 h-6" />
```

---

### 3. Partials — `resources/views/partials/`

Template fragments for WordPress loop content. These are NOT reusable UI components —
they're the conventional WordPress "content-{context}.php" equivalents.

**Create a partial when:**
- It's a content template used inside the WordPress loop.
- It's rendered by `index.blade.php`, `single.blade.php`, `search.blade.php`, etc.

**Standard partial naming:**

| File | Purpose |
|---|---|
| `content.blade.php` | Default post content (used by `index.blade.php`) |
| `content-page.blade.php` | Page content |
| `content-single.blade.php` | Single post content |
| `content-search.blade.php` | Search result item |
| `entry-meta.blade.php` | Post metadata (date, author, categories) |
| `footer-content.blade.php` | Footer inner content |

---

## Core Components

Every Sage theme built with this skill ships these components. Treat them as always
available — don't re-implement them.

### `<x-icon>` — SVG sprite

```blade
<x-icon name="arrow-right" class="w-4 h-4 text-{project}-primary-blue" />
<x-icon name="plus" size="lg" />           {{-- size presets: xs sm md lg xl --}}
<x-icon name="close" width="32" height="32" />
```

SVG source files live in `resources/icons/`. The build compiles them into a sprite
via `vite-plugin-svg-icons`. Add a new icon by dropping an `.svg` into that folder
and referencing it by filename (without extension) as the `name` prop.

### `<x-picture>` — responsive image with WebP

```blade
{{-- Static image from the Vite manifest --}}
<x-picture src="resources/images/hero.jpeg" alt="Hero" class="w-full h-full object-cover" />

{{-- ACF image field (pass the full ACF image array) --}}
<x-picture :acf-field="get_field('image')" alt="Feature" size="responsive-lg" class="rounded-2xl" />

{{-- ACF image ID --}}
<x-picture :acf-id="$item['image_id']" alt="Card" size="responsive-md" />
```

Available `size` values: `responsive-xl`, `responsive-xl-crop`, `responsive-lg`,
`responsive-md`, `responsive-sm`, `responsive-xs`. These correspond to the image
sizes registered in `app/setup.php` (see `sage-stack.md`).

### `<x-accordion>` — expandable content (Alpine.js)

```blade
<x-accordion
    :items="$items"
    :defaultExpanded="$items[0]['id']"
    containerClass="flex flex-col p-8"
    buttonText="Learn more"
    :showButton="true"
/>
```

Items array format (each element is a PHP array):

```php
$items = [
    [
        'id'          => 'unique-id',           // required
        'title'       => 'Item heading',        // required
        'description' => 'Item body content',   // required
        'link'        => '/optional-url',       // optional
        'titleTag'    => 'h5',                  // optional, default: h5
        'titleClass'  => 'h5 font-semibold',    // optional
        'image'       => $acf_image_array,      // optional ACF image
        'expanded'    => true,                  // optional default open state
    ],
];
```

### `<x-slider>` — Splide.js carousel

```blade
<x-slider
    sliderId="my-slider"
    :options="['perPage' => 3, 'gap' => '1rem', 'type' => 'loop']"
    externalPrevSelector="#prev-btn"
    externalNextSelector="#next-btn"
>
    @foreach ($items as $item)
        <li class="splide__slide">
            {{-- Slide content --}}
        </li>
    @endforeach
</x-slider>
```

Pass any valid [Splide options](https://splidejs.com/guides/options/) via `:options`.
Use `externalPrevSelector` / `externalNextSelector` to wire up custom nav arrows
placed outside the slider markup.

### `<x-modal>` — Alpine.js + custom events

```blade
{{-- Trigger (can live anywhere on the page) --}}
<button onclick="window.dispatchEvent(new CustomEvent('modal:open:my-modal'))">
    Open modal
</button>

{{-- Modal definition (include in sections.modals) --}}
<x-modal id="my-modal">
    <x-slot:header>Modal Title</x-slot:header>
    <x-slot:body>
        <p>Content here.</p>
    </x-slot:body>
    <x-slot:footer>
        <button class="btn btn-secondary">Submit</button>
    </x-slot:footer>
</x-modal>
```

All modals are collected in `resources/views/sections/modals.blade.php`, which is
included once in `layouts/app.blade.php` at the bottom of `<body>`. Never scatter
modal definitions across individual page templates.

---

## Alpine.js Integration Pattern

Use this pattern whenever a Blade component needs JavaScript interactivity. Three
steps, always in this order.

**Step 1 — Register the Alpine component** in `resources/components/{name}/{name}.js`:

```javascript
import Alpine from 'alpinejs';

Alpine.data('componentName', (config = {}) => ({
    // Reactive state
    isOpen:  config.defaultOpen || false,
    items:   config.items       || [],

    // Lifecycle hook
    init() {
        // one-time setup
    },

    // Methods
    toggle() {
        this.isOpen = ! this.isOpen;
    },

    // Computed property
    get isEmpty() {
        return this.items.length === 0;
    },
}));
```

**Step 2 — Import in `resources/js/app.js`:**

```javascript
import '../components/component-name/component-name.js';
```

**Step 3 — Use in the Blade template:**

```blade
<div x-data="componentName({ defaultOpen: true, items: @js($items) })">
    <button @click="toggle()" :aria-expanded="isOpen">Toggle</button>
    <div x-show="isOpen" x-collapse x-cloak>
        Content
    </div>
</div>
```

**Alpine.js rules:**
- Always initialize via `x-data`. Never create component state inline in the HTML.
- Use `@js()` Blade directive to pass PHP data into Alpine — it JSON-encodes safely.
- Add `[x-cloak] { display: none !important; }` to your CSS and use `x-cloak` on
  any element that should be hidden until Alpine initializes (prevents FOUC).
- Use `x-collapse` for animated show/hide (requires `@alpinejs/collapse` plugin).
- Cross-component communication via custom events:
  ```javascript
  window.dispatchEvent(new CustomEvent('modal:open:my-modal'));
  window.addEventListener('modal:open:my-modal', () => { /* ... */ });
  ```
- Register components via `Alpine.data()` — never embed complex logic in `x-data`
  attribute strings.

---

## Page Template Pattern

A page template is a `.blade.php` file in `resources/views/` that follows the
WordPress template hierarchy (e.g. `front-page.blade.php`, `template-about.blade.php`,
`page-contact.blade.php`).

**Standard structure:**

```blade
{{--
  Template Name: About Page
  Description: Company about page with team and values sections.
--}}

@extends('layouts.app')

@section('content')
    {{-- Hardcoded sections — layout is fixed, not editor-driven --}}
    @include('sections.hero')
    @include('sections.our-story')

    {{-- Gutenberg content zone — renders ACF blocks added in the editor --}}
    @while (have_posts())
        @php(the_post())
        {!! the_content() !!}
    @endwhile

    {{-- More fixed sections below the editor zone --}}
    @include('sections.cta')
@endsection
```

**Two approaches — choose per page:**

| Approach | When to use |
|---|---|
| Hardcoded sections | Pages with a fixed layout that editorial staff don't rearrange (homepage, about, contact) |
| Gutenberg blocks (`the_content()`) | Pages where the editor needs to reorder, add, or remove blocks (service pages, landing pages, flexible content areas) |

The hybrid is the most common production pattern: fixed header/hero and CTA at the
edges, Gutenberg block zone in the middle.

When using Gutenberg blocks, each ACF block's `render_callback` should call:

```php
echo view('sections.block-name', ['block' => $block, 'is_preview' => $is_preview]);
```

This means blocks render the same Blade sections as hardcoded `@include` calls — no
separate template vocabulary.

---

## Layout — `resources/views/layouts/app.blade.php`

The root layout wraps every page. Every hierarchy file extends it.

```blade
<!doctype html>
<html @php(language_attributes())>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ wp_title('|', true, 'right') }}</title>
    @php(do_action('get_header'))
    @php(wp_head())
</head>
<body @php(body_class())>
    @php(wp_body_open())

    {{-- Header: transparent on front page, solid background elsewhere --}}
    @if (is_front_page())
        @include('sections.header')
    @else
        @include('sections.header', [
            'bgClass'        => 'bg-white shadow-sm',
            'scrolledBgClass' => 'bg-{project}-primary-blue',
        ])
    @endif

    <main id="main" class="main">
        @yield('content')
    </main>

    {{-- Footer: yieldable so individual pages can override --}}
    @hasSection('footer')
        @yield('footer')
    @else
        @include('sections.footer')
    @endif

    {{-- All modals collected here — one include for the whole site --}}
    @include('sections.modals')

    @php(do_action('get_footer'))
    @php(wp_footer())
</body>
</html>
```

**Layout rules:**
- Header receives different props based on `is_front_page()` (transparent vs. solid).
- Footer is yieldable: a page template can `@section('footer')` ... `@endsection`
  to render a custom footer.
- Modals are included once at the bottom — never in individual templates.
- Never add `<script>` or `<style>` tags manually here. Everything goes through the
  Vite pipeline (`app/setup.php` enqueues).

---

## What Goes Where — Quick Reference

| You want to... | File location |
|---|---|
| Add a new page section | `resources/views/sections/{name}.blade.php` |
| Add a reusable UI component | `resources/views/components/{name}.blade.php` |
| Add component JavaScript | `resources/components/{name}/{name}.js` + import in `app.js` |
| Add component CSS | `resources/components/{name}/{name}.css` + import in `components.css` |
| Add a new icon | `resources/icons/{name}.svg` |
| Add a loop content fragment | `resources/views/partials/content-{context}.blade.php` |
| Add a page template | `resources/views/page-{slug}.blade.php` or `template-{name}.blade.php` |
| Add a new modal | `resources/views/sections/modals.blade.php` (add to the existing file) |

---

## Cross-references

- `sage-stack.md` — Sage framework, Acorn, Vite pipeline, scaffolding
- `css-architecture.md` — 3-layer CSS model (tokens → components → per-block)
- `acf-blocks.md` — ACF block registration, render callbacks, preview rules
- `inherited-projects.md` — applying section/component/partial separation in non-Sage themes
- `../dev-conventions.md` — full Mode A / Mode B decision, naming conventions, build commands
