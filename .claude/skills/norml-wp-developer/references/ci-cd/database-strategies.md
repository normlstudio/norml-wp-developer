# Database Strategies — Reference

How content and the database are handled per project. The deep catalog
behind the "Database strategy" line each pattern declares in its
per-project `.claude/ci-cd.md`.

## The skill's DB stance (read this first)

One rule governs everything below:

> **Code lives in git. Content lives on production. The DB never flows
> local → production through this skill.**

- **Code** (theme, tracked plugins, ACF field-group JSON) moves forward:
  local → (staging) → production, as files, via the deploy pipeline.
- **Content** (posts, pages, options, media, form submissions, users) is
  born on production and stays there. To work against real content
  locally you pull it **DOWN**: `scripts/sync-from-prod.sh` copies prod's
  DB + uploads to local and runs `wp search-replace` to rewrite the prod
  URL to your local one. The local DB is throwaway.

Pushing a local/staging DB *up* onto a live site is the dangerous
direction: **launch-only**, gated, explicit, clobbers accumulated prod
data. The two "sync up" strategies below (`full-sync`, `selective-sync`)
exist for that narrow case and refuse everywhere else.

Hard rules for *every* strategy:

- **Never `sed`/`awk` a `.sql` dump with WordPress data.** Serialized PHP
  in `wp_options`/post meta corrupts silently. `wp search-replace`
  understands serialization; text tools don't.
- **Always `--skip-columns=guid`** on every search-replace — `guid` is a
  permanent identifier; rewriting it breaks RSS and other consumers.
- **No `.sql` dumps in git, ever** (user data, huge, unmergeable). ACF
  JSON (`acf-json/*.json`) *is* source — schema, not data — and *does*
  belong in git.
- **Backup before any destructive write, then verify the backup is real**
  before touching the DB (see `../safety-rules.md` — prod writes also
  gate on the backup-acknowledgement prompt).

## Strategy → pattern map

| Strategy | `full-pipeline` | `prod-direct-with-git` | `prod-direct-no-ci` |
|---|---|---|---|
| `single-env` (prod is the only DB) | — | ✅ default | ✅ default |
| `prod-is-source-of-truth` (editors own content) | ✅ default | — | — |
| `selective-sync` (push specific slices up) | ✅ launch + rare | gated, rare | gated, rare |
| `full-sync` (replace prod DB wholesale) | ✅ **launch only** | launch only | launch only |

The two prod-direct patterns are single-environment, so `single-env`
is their home. `full-pipeline` has staging, so it can refresh staging
from prod and (at launch) push a built DB up — but its steady state is
`prod-is-source-of-truth`.

---

## `single-env` — one environment, backup-before-every-write

> The only DB is production. No sync. Every DB change happens on prod,
> always preceded by a verified backup.

**Patterns:** `prod-direct-with-git`, `prod-direct-no-ci` (and any
`full-pipeline` project whose staging is a code preview only, not a DB
mirror).

### The core rule

Back up before **every destructive DB operation**. "Destructive" is
broad: anything that writes, updates, deletes, or restructures — not
just `DROP`. A plugin uninstall with "delete data" is destructive.
`wp search-replace` is destructive. `wp option update` is destructive
for the row it touches.

### Tools

| Action | Command |
|---|---|
| Full DB dump | `wp db export {project-slug}-{YYYY-MM-DD-HHmm}.sql --default-character-set=utf8mb4` |
| Single-table dump | `wp db export {prefix}_{table}-{date}.sql --tables={prefix}_{table}` |
| Verify dump is real | `ls -la {dump}` (size > 1 KB) **and** `head -50 {dump}` (contains real `INSERT INTO`, not an error string) |
| Search-replace (URL or value change) | `wp search-replace 'old' 'new' --skip-columns=guid --all-tables-with-prefix` |
| Cache flush after a content change | `wp cache flush && wp transient delete --all` |
| Restore from dump | `wp db import {dump}` |

### Process for any DB write

1. **Back up:** `wp db export pre-{change}-{date}.sql --default-character-set=utf8mb4`
2. **Verify the backup:** size > 1 KB, head contains `INSERT INTO`.
3. **Execute** the change (`wp` command, REST API, or WP admin).
4. **Verify** the change — read back the affected row / option / post.
5. **If it looks wrong:** `wp db import pre-{change}-{date}.sql`.
6. **Keep the dump** until the change is clearly stable (24–48 h).
7. Then archive or delete it.

### When to refuse

If the backup step fails or the dump is suspiciously small, **refuse
the change**. A change with no verified backup is one you can't recover
from. Tell the user; let them fix the backup first.

---

## `prod-is-source-of-truth` — editors own content, devs own code

> Content lives only on production, owned by whoever publishes (editorial
> team, SEO team, client editor). Devs ship code and never touch the prod
> DB in normal work. Staging exists for code preview; its DB is a stale
> copy of prod, not a source of truth.

**Pattern:** `full-pipeline` — the steady state for any mature site with
an active content team. The maturity endpoint: sites arrive here from
`selective-sync` as content ownership transfers to editors, and rarely
leave.

### The principle

**Devs ship code. Editors ship content. The two never mix.**

- **Devs do:** push code (theme, plugins, ACF JSON schema) to staging;
  verify against staging's stale DB; promote to prod **file-only, no DB
  sync**.
- **Devs do NOT:** `wp post create` on prod; `wp option update` on prod
  for anything content-shaped (titles, descriptions, ACF *values*);
  `wp search-replace` on prod without explicit approval (genuine URL
  migrations only); `wp db import` a staging dump onto prod.
- **Editors do:** publish/edit/schedule posts, set ACF *values*, manage
  media, tune per-post SEO meta, moderate comments, manage forms — all
  via WP admin.

### Code changes that need new content

When a deploy makes new content *possible* (e.g. a new CPT is
registered):

1. Deploy the code (registers the CPT).
2. **Tell the editor** what's now available; let them add content via
   WP admin.
3. Do **not** bulk-create it with `wp post create` on prod — that
   bypasses the editor's workflow and audit trail.

### ACF schema changes (the clean path)

```bash
# Dev edits the field group locally → acf-json/{group}.json changes
# commit + push + deploy to staging
# ACF on staging sees newer JSON → editor reviews on staging
# deploy to prod
# ACF on prod sees newer JSON → editor clicks "Sync Changes"
# new fields exist; editors fill in VALUES via WP admin
```

No DB sync. Schema flows through code; values come from editors. If the
project uses ACF Pro: `wp acf sync --all` automates the sync click.

### Keeping staging's DB useful

Staging drifts as prod gains content. Refresh it periodically
(monthly / quarterly) from a recent prod backup. **This is the only
full DB sync this strategy allows, and it only ever runs prod → staging
(down/sideways), never the reverse:**

```bash
# On prod
wp db export prod-snapshot-$(date +%Y%m%d).sql --default-character-set=utf8mb4

# Transfer to staging
scp prod:./prod-snapshot-*.sql staging:./

# On staging
wp db import prod-snapshot-{date}.sql
wp search-replace 'https://{domain}' 'https://staging.{domain}' --skip-columns=guid --all-tables-with-prefix
wp cache flush
```

### Gotchas

- **"Just one wp command on prod" is a strong temptation. Resist it.**
  Even a one-off dev command on prod erodes editor trust.
- **Staging DB drift:** months without a refresh means staging tests no
  longer reflect reality. Schedule refreshes.
- **Editors don't always announce changes** — a plugin they activated,
  a setting they tweaked is invisible to dev until something breaks.
  Keep a `## Editor changes since last sync` note in
  `{theme_root}/.claude/changelog/daily.md` and check it periodically.

### When to refuse

If anyone asks you to run a destructive `wp` command on prod under this
strategy → refuse, point here, escalate to the content owner.

---

## `selective-sync` — push specific slices up (gated, rare)

> Sync only named post types, options, or tables from local/staging up
> to production. For the rare case where prod has live data that must
> NOT be clobbered but a specific new slice needs to ship.

**Patterns:** `full-pipeline` (mostly at launch, occasionally after);
the prod-direct patterns can but rarely do. Every run is **Confirm +
backup** (production write). It exists because `full-sync` would destroy
real user data — when prod has submissions/comments/editor content and
you only need to move *three pages* or *one settings blob* up, slice it.

### Declare the eligible slices

In `ci-cd.md` under "Database strategy", list what's eligible and the
exact commands. Common, safe slices:

- **Specific post types:** `pages`, `case_study` — but NOT `post`, NOT
  `comments`.
- **Specific options:** `theme_mods_*`, `acf_options_*` — but NOT
  `siteurl`, NOT `home`, NOT user accounts.
- **Specific taxonomies:** `services_category`, `case_study_type`.
- **ACF schema** — prefer the `acf-json/` code path over any DB sync.

### Pre-flight (always)

```bash
# Full prod backup first — this is a production write
ssh {prod} 'cd {site_path} && wp db export pre-selective-sync-$(date +%Y%m%d-%H%M).sql --default-character-set=utf8mb4'
# verify the dump (size + head), then proceed
```

### Pattern A — specific tables

```bash
# On the source — dump only the relevant tables
ssh {source} 'wp db export slice-$(date +%Y%m%d).sql --tables={prefix}_posts,{prefix}_postmeta,{prefix}_term_relationships'

# Rewrite URLs on the source BEFORE export (wp search-replace), or on a sandbox — never sed the dump

# On prod — import (replaces only the listed tables, leaves the rest intact)
ssh {prod} 'wp db import slice-rewritten-{date}.sql'
```

**Catch:** `{prefix}_posts` holds `post`, `page`, *and* your CPT — a
table import brings all of them. To move only one type, filter the dump
with `wp db export --where="post_type='case_study'"`.

### Pattern B — specific records (WXR)

```bash
# On the source — export individual posts as WXR
ssh {source} 'wp export --post__in=123,456,789 --filename_format={slug}.xml'

# Transfer, then on prod
ssh {prod} 'wp import {file}.xml --authors=skip'
```

WXR carries post + meta + featured image + taxonomy. It does **not**
carry attachment files unless they're in the export — sync uploads
separately if needed, then search-replace any staging URLs in the
imported attachments.

### Pattern C — options / settings only

```bash
# On the source
ssh {source} 'wp option get theme_mods_{theme-slug} --format=json > theme-mods.json'

# On prod
ssh {prod} 'wp option update theme_mods_{theme-slug} "$(cat theme-mods.json)" --format=json'
```

### Pattern D — ACF schema via JSON (preferred for schema)

ACF JSON in `acf-json/` is source code (lives in git). On deploy, ACF
detects newer JSON than the DB and offers a sync — the cleanest way to
move field-group changes, with **zero DB operations**. In WP admin:
ACF → Field Groups → "Sync"; or `wp acf sync --all` (ACF Pro).

### Post-sync verification

1. The synced records exist on prod.
2. Spot-check one in WP admin — fields are right.
3. **Prod-only data is INTACT** — open a form-submission table, the
   comments list, etc.
4. Cache flush + smoke test (`curl -sf https://{domain}/` returns 200).

### Gotchas

- **`wp import` can duplicate records.** Use `--authors=skip`; confirm
  slugs don't collide.
- **A CPT must be registered on prod before importing posts of that
  type** — ensure the theme deploy precedes the DB sync.
- **Taxonomy term IDs differ between environments.** Filter by slug,
  never by ID.
- **Plugin-managed tables** (WooCommerce orders, membership data)
  usually shouldn't be selectively synced. Treat them as
  `prod-is-source-of-truth`.

### When to refuse

- "Just sync everything" on a selective-sync project → refuse, point at
  `full-sync` below, confirm they truly mean full replacement.
- Pre-sync backup fails to verify → refuse.

---

## `full-sync` — replace the production DB wholesale (LAUNCH ONLY)

> Copy a complete DB up onto production, replacing everything there.
> Legitimate **only at initial launch** of a site built locally or on
> staging. After launch, this destroys every form submission, comment,
> and editor change prod has accumulated.

**Patterns:** `full-pipeline` and the prod-direct patterns — **all at
launch only.** Every run is **Confirm + backup**; the bar post-launch is
"the whole team explicitly agreed to clobber prod."

### Strong refusal

> If prod already has live user data and someone casually says "promote
> to prod" / "push my DB up" / "sync everything" — **refuse.** Spell out
> that this replaces *all* prod content (submissions, comments, editor
> edits, analytics — gone), offer `selective-sync`, and proceed only on
> an explicit, informed "yes, replace the entire production database, I
> accept the data loss."

`full-sync` never merges — it overwrites. Treat any request to run it
against a populated prod as `selective-sync` until the user proves they
mean total replacement.

### Process

**Pre-flight**

1. **Confirm with a human** that a full replacement is intended.
2. **Back up production** (DB + uploads) — this is the rollback path:
   ```bash
   ssh {prod} 'cd {site_path} && wp db export pre-full-sync-$(date +%Y%m%d-%H%M).sql --default-character-set=utf8mb4'
   rsync -a {prod}:{site_path}/wp-content/uploads/ ./prod-uploads-backup-$(date +%Y%m%d)/
   ```
3. **Back up / prepare the source DB** and verify both dumps (size +
   `INSERT INTO` in head).

**Sync**

1. **Rewrite URLs on the source first** (never on the `.sql` file):
   ```bash
   ssh {source} "wp search-replace 'https://staging.{domain}' 'https://{domain}' --skip-columns=guid --all-tables-with-prefix --dry-run"
   # review the dry-run, drop --dry-run to execute, then re-export
   ```
   Also rewrite paths if they differ (`/staging/{site}/` → `/{prod}/`).
2. **Import onto prod** (the destructive step):
   ```bash
   ssh {prod} 'cd {site_path} && wp db import source-rewritten.sql'
   ```
3. **Sync uploads up:**
   ```bash
   rsync -av --no-delete {source}:{src_path}/wp-content/uploads/ {prod}:{site_path}/wp-content/uploads/
   ```
   `--no-delete` so any prod-only upload survives.
4. **Flush prod caches:** `wp cache flush && wp transient delete --all`.

**Verify**

1. Load the prod homepage; smoke test 3–5 key URLs (home, primary CTA
   target, contact form, blog index).
2. Confirm uploads load (2–3 images on different pages).
3. **If broken, roll back from the pre-sync backup:**
   ```bash
   ssh {prod} 'wp db import pre-full-sync-{date}.sql'
   ```

### Gotchas

- **`--skip-columns=guid` is mandatory** on the search-replace. Always.
- **Collations can differ** between source and prod hosts. On a
  collation error, re-export with `--default-character-set=utf8mb4`.
- **Don't run during peak hours** — prod is inconsistent for the
  duration.
- **Warn the team** before prod content changes, if real users might
  notice.

> Note on `wp db reset` / `wp db drop`: the skill **refuses** these on
> any environment (see `../safety-rules.md`). The launch import above
> writes over the existing DB via `wp db import`; if a true reset is
> genuinely required, the user runs it themselves over a manual SSH
> session — the skill does not proxy a DB reset.

---

## Cross-references

- `./patterns.md` — the three deploy patterns; each one's "Database
  strategy" subsection points here.
- `../safety-rules.md` — the Safe / Confirm / Confirm+backup / Stop
  buckets, the backup-acknowledgement prompt, and the refused DB ops
  (`wp db reset`, `wp db drop`, `DROP TABLE` / `TRUNCATE` on prod).
- `./backup-strategies.md` — the backup providers that supply the
  pre-write/pre-sync safety net referenced throughout this file.
