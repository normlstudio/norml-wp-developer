# WP Local Setup — Reference

The skill expects **one running local WordPress environment** per
project. WP Local (Flywheel / WP Engine) is the default and what the
skill optimizes for. Alternates are recognized when detected.

## WP Local (the default)

Download: https://localwp.com

### Why WP Local

- Free, GUI-based, zero-config for the common case.
- Each site is isolated (Lightning runtime, per-site PHP/MySQL).
- Built-in SSL via `Trust` button.
- Live links feature for quick previews.
- Built-in MailHog for testing email.

### Where sites live

By default: `~/Local Sites/{site-slug}/` on macOS,
`%USERPROFILE%\Local Sites\{site-slug}\` on Windows.

Inside each site:

```
~/Local Sites/{site}/
├── app/
│   ├── public/                  ← WordPress root lives HERE
│   │   ├── wp-admin/
│   │   ├── wp-content/
│   │   │   └── themes/
│   │   │       └── {theme}/    ← your theme repo
│   │   ├── wp-includes/
│   │   └── wp-config.php
│   └── sql/
├── conf/
└── logs/
```

The setup script asks for the **theme folder path** and infers the
site's local URL + DB credentials from WP Local's metadata.

### Local URLs

WP Local sites get a `.local` URL by default. E.g. `acme.local`. The
URL is in WP Local → Site → Overview → "Site Host."

### Local DB credentials

WP Local writes them into the site's `wp-config.php`. The skill reads
them from there:

```bash
grep -E "DB_NAME|DB_USER|DB_PASSWORD|DB_HOST" \
  "$LOCAL_SITES/{site}/app/public/wp-config.php"
```

### Starting / stopping

In the WP Local UI, click the site → "Start site." Or via the
`local` CLI if installed (`local start {site}`).

The setup script verifies the site is running via mysql process check.
If not running, it tells you to start it and pauses.

## Alternates — recognized by the setup script

### DDEV

- https://ddev.com
- Docker-based.
- Project root has a `.ddev/` folder with `config.yaml`.
- DDEV exposes the site at `https://{project}.ddev.site`.

The setup script detects DDEV via `.ddev/config.yaml`. DB creds are
in the DDEV config; the site is started with `ddev start`.

### Lando

- https://lando.dev
- Docker-based.
- Project root has `.lando.yml`.

Detected via `.lando.yml`. Started with `lando start`.

### Local Lightning

- The previous version of WP Local. Same layout, same detection
  (`~/Local Sites/`).

### Valet+

- https://github.com/weprovide/valet-plus
- macOS-only, PHP+nginx+mysql via Homebrew.
- Sites are parked via `valet park` from a directory.

Detected if the theme folder is under a parked Valet directory and a
matching `.test` URL responds.

### MAMP / XAMPP

- Older stacks. The skill recognizes them via the presence of
  `htdocs/` parents but doesn't auto-detect DB creds.
- Setup falls back to "manual entry" mode — you provide the local URL
  and DB creds yourself.

## What the setup script needs to know

Whatever the local environment, the script captures:

| Field | Purpose |
|---|---|
| Theme folder path (absolute) | The git repo root + `wp-content/themes/{theme}` |
| WordPress root path (absolute) | One level up from `wp-content/` — used for WP-CLI commands |
| Local URL | For `wp search-replace` when pulling production DB |
| Local DB host, name, user, password | For optional DB pulls/pushes — only if you use them |

If detection fails, the script asks for these explicitly.

## Recommended local-dev setup

Once your local WP is running and the theme is in place:

1. `composer install` in the theme folder (Sage projects).
2. `npm install` in the theme folder.
3. `npm run dev` — Vite dev server starts; refresh local URL to see
   HMR.
4. Make changes, see them live, commit when ready.

For non-Sage / inherited projects: just edit files, refresh the
browser. No build step usually needed unless the theme has its own
gulp / webpack config.

## DB sync workflow

The `scripts/sync-from-prod.sh` flow pulls production data down:

```
Production server (DB + uploads)
   ↓ wp db export over SSH
   ↓ rsync uploads/ over SSH
Local /tmp
   ↓ wp db import on local
   ↓ rsync uploads/ to local wp-content/uploads/
   ↓ wp search-replace production-url → local-url
Local WP site now mirrors production
```

Takes a few minutes for small sites, much longer for large media
libraries. The script offers a `--no-uploads` flag to skip media.

**Reverse direction (push local DB to production) is not provided.**
That's almost always wrong — content lives on production, code lives
in git. If you genuinely need to push DB the other way (e.g. seeding
a fresh production), do it manually, with extra care, and a backup
beforehand.

## Common gotchas

**HMR / Vite dev server doesn't refresh the page.**
WP Local's URL is `acme.local` — the Vite config needs to match.
Check `vite.config.js`'s `server.host` and `server.hmr.host`. The
setup script offers to wire this up automatically.

**`composer install` fails with PHP version error.**
Sage requires PHP 8.2+. WP Local lets you pick PHP per site
(Site → Settings → PHP Version). Bump it.

**The local site is HTTPS but Vite serves HTTP.**
The setup script can configure Vite to use HTTPS via WP Local's
generated cert. Or you can disable HTTPS on the WP Local site
(Settings → SSL → switch off).

**Pulled production DB but the site looks broken.**
Usually because `wp search-replace` didn't catch all URL variants.
Try `wp search-replace 'http://prod.com' 'http://local.test'` and
`wp search-replace 'https://prod.com' 'https://local.test'` and
`wp search-replace 'prod.com' 'local.test'`.

**Some plugins behave differently locally vs production.**
E.g. payment gateways have sandbox vs production keys; CDN plugins
serve assets from CDN-only on production. Make sure the local
environment has dummy / sandbox credentials where applicable.

## Cross-references

- `onboarding.md` — uses this reference during step 4 (local env
  detection).
- `references/ci-cd/patterns.md` — pulls + pushes between environments
  are the deploy pattern's responsibility.
- `scripts/sync-from-prod.sh` — the DB + uploads pull flow.
