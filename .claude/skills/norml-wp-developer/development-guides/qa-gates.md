# QA Gates — Reference

What you check, and when, before code lands in production. Three
checkpoints — none of them optional. The aim: bugs and regressions get
caught before users see them. "It looked fine on my machine" is not a
QA gate.

A change that doesn't pass all three checkpoints that apply to its
pattern doesn't ship.

## The three gates × the three patterns

The catch: this skill supports three deploy patterns
(`ci-cd/patterns.md`), and **only one of them has staging**. The
classic QA model assumes a staging URL always exists. Here it usually
doesn't — so the gates adapt by pattern.

| Gate | `full-pipeline` (has staging) | `prod-direct-with-git` (no staging) | `prod-direct-no-ci` (no staging) |
|---|---|---|---|
| **Pre-merge** | CI green + reviewer + test-plan | local pre-commit self-check | local pre-commit self-check |
| **Pre-deploy** | manual QA on the **staging URL** | manual QA on **LOCAL** before prod | manual QA on **LOCAL** before prod |
| **Post-deploy** | on the **production URL** | on the **production URL** | on the **production URL** |

The headline difference: with no staging, **pre-deploy QA runs against
your local site** before the production deploy. There is no staging URL
to sweep, so the local site is the last line before real users.
Post-deploy is identical for all three — it always runs on production,
minutes after the deploy.

Resolve the project's pattern from `{theme_root}/.claude/ci-cd.md`
before you start. If it's missing → hard-stop (see `ci-cd/patterns.md`).

---

## Pre-merge gate

Blocks the PR (or the local commit, for solo projects) from landing.

### `full-pipeline` / any project with CI

Runs automatically on every PR via `.github/workflows/pr-validate.yml`,
plus a manual review by another teammate.

**Automated checks — CI must pass:**

- **PHP lint** — `vendor/bin/pint --test` clean (Sage projects). For
  non-Sage / inherited themes, whatever linter the repo declares.
- **JS/CSS lint** — `npm run lint` clean (ESLint + Stylelint if
  configured).
- **Build** — `npm run build` (production asset build) succeeds with no
  errors.
- **Tests** — `vendor/bin/phpunit` if `tests/` exists; all green.
- **Secrets scan** — no `wp-config.php`, `.env`, key files, or
  `password = "..."`-shaped strings added. Wire `gitleaks` or
  `trufflehog` into the workflow. See `safety-rules.md` for what never
  gets committed.

**Manual reviewer checks** — the reviewer (someone other than the
author) walks the diff:

- **Correctness** — does the PR description match the diff? Are the
  test-plan boxes plausibly true?
- **Conventions** — file paths, naming, Blade/partial separation, ACF
  JSON, Tailwind utilities follow `dev-conventions.md`.
- **Security smell test** — escaped output (`esc_html`, `esc_attr`,
  `wp_kses`), sanitized input, capability checks, nonces on POST
  endpoints, no concatenated SQL.
- **Performance smell test** — no queries in loops, transients for
  expensive lookups, bounded `WP_Query` results, no synchronous
  external-API calls in the render path.
- **Accessibility smell test** — semantic HTML, `alt` on images,
  keyboard nav on interactive components, focus styles preserved.

If the reviewer can't verify a claim from the diff alone, they ask for
a screenshot or a render — don't approve on faith.

### Solo / no-CI projects — collapses to a local self-check

On `prod-direct-no-ci`, and on any solo project with no second reviewer
and no GHA, the pre-merge gate becomes a **local pre-commit
self-check** you run by hand before committing. Same spirit, no
automation:

```bash
# From the theme root, before you commit:
vendor/bin/pint --test            # PHP style (Sage projects)
npm run lint                      # JS/CSS, if configured
npm run build                     # production build must succeed
vendor/bin/phpunit                # if tests/ exists
git diff --staged                 # eyeball the diff — secrets? debug code? dd()/var_dump()?
```

Self-review the staged diff the way a reviewer would: escaping,
sanitization, no leftover `console.log` / `error_log` / `dd()`, no
hardcoded URLs, no committed secret. You are the reviewer now; be
stricter, not looser.

---

## Pre-deploy gate

This is the **manual QA pass** — the most important gate, and the one
that branches hardest by pattern.

> **Where it runs**
> - `full-pipeline` → on the **staging URL**, after `develop` has
>   auto-deployed to staging, before you tag a production release.
> - `prod-direct-with-git` and `prod-direct-no-ci` → on your **LOCAL
>   site**, before the production deploy. There is no staging; local is
>   the rehearsal.

Set `{url}` to the staging URL (full-pipeline) or your local URL
(`https://{slug}.local`) for everything below.

### Required checks

**1. Smoke test — HTTP + must-pass URLs**

No external skill. Curl the homepage for a 200, then walk a short list
of must-pass URLs in a browser and confirm each renders without a
fatal:

```bash
# HTTP status check — expect 200
curl -sf -o /dev/null -w "%{http_code}\n" "https://{url}/"

# REST API is alive — expect 200 and JSON
curl -sf -o /dev/null -w "%{http_code}\n" "https://{url}/wp-json/"
```

Must-pass URL list (open each, confirm no white screen / no PHP
notice / layout intact):

| URL | What it proves |
|---|---|
| `https://{url}/` | Homepage + global header/footer render |
| `https://{url}/{cpt-archive}/` | A CPT archive template works (e.g. `/projects/`, `/team/`) |
| `https://{url}/{a-single-post}/` | A single template + its blocks render |
| `https://{url}/wp-admin/` | wp-admin login screen loads (then log in) |
| `https://{url}/wp-json/` | REST API responds with JSON, not an error page |

If the site has no CPTs, substitute the blog index and one post.

**2. Viewport sweep** — open each new/modified page and section at three
breakpoints and look for breakage:

- **375px** (mobile)
- **768px** (tablet)
- **1280px+** (desktop)

Scan for: layout shifts (CLS), missing images, broken icons/fonts, text
overflowing containers, stacking-order (z-index) bugs, and dark text on
dark backgrounds (the classic AI-built regression).

You can drive this with Playwright if you want screenshots for the
record:

```bash
npx playwright screenshot --viewport-size=375,800  "https://{url}/" mobile.png
npx playwright screenshot --viewport-size=768,1024 "https://{url}/" tablet.png
npx playwright screenshot --viewport-size=1280,900 "https://{url}/" desktop.png
```

**3. Interaction smoke** — for every new interactive element (button,
accordion, modal, slider, filter, form), actually click/tap/submit and
verify behavior. Watch the browser console for errors during the
interaction. A component that renders but throws on click is a
ship-blocker.

**4. ACF field check** — if new ACF fields were added:

- Open the relevant post type in wp-admin, confirm fields render in the
  editor.
- Fill them, save, reload the front end, confirm values appear.
- Confirm JSON synced from `acf-json/` — the **Custom Fields → "Sync
  available"** notice in wp-admin must be empty. A pending sync means
  the field group exists in code but the DB hasn't picked it up.

```bash
# Quick CLI confirmation the group is registered:
wp acf get_field_groups --allow-root 2>/dev/null | grep -i "{group-title}"
```

**5. Manual performance pass** — if the change touches a heavy page
(landing, blog index, search, anything with a hero or a big query), run
Lighthouse or PageSpeed Insights by hand and confirm Core Web Vitals
didn't regress. No external skill — open it yourself:

- Chrome DevTools → **Lighthouse** tab → Analyze page load, **or**
- PageSpeed Insights → `https://pagespeed.web.dev/?url=https://{url}/`

Thresholds (treat as a pass/fail checklist):

| Metric | Target |
|---|---|
| **LCP** (Largest Contentful Paint) | ≤ 2.5s |
| **CLS** (Cumulative Layout Shift) | < 0.1 |
| **INP** (Interaction to Next Paint) | ≤ 200ms |

Lab Lighthouse can't measure INP directly — use Total Blocking Time
(TBM) as the proxy in the lab and confirm real INP later in the
post-deploy field check. A score drop > 10 points vs the prior build =
investigate before deploying.

> **Local caveat for the no-staging patterns:** a local site is faster
> than production (no network latency, no shared host). Treat local
> CWV as a *floor* — if it regresses locally it'll be worse live.
> Re-confirm the real numbers in the post-deploy field check.

**6. Reviewer / client sign-off** — for user-visible content or design
changes, capture the page (screenshot or the local/staging URL) and get
a thumbs-up in writing before you deploy.

### Optional checks (project-dependent)

- **Cross-browser** — Safari, Firefox, Chrome at minimum. WebKit-only
  bugs are real.
- **Email** — if a form changed, submit a test entry and confirm the
  email arrived. Use a real address, never `test@test.com`.

### When to fail the gate

Failing pre-deploy is **not** a personal failing — it's the gate doing
its job. Fix it, re-run the pass (re-deploy staging for full-pipeline;
just re-test local for the prod-direct patterns), then proceed. Don't
skip.

---

## Post-deploy gate

Runs in the minutes after **every** production deploy, for **all three
patterns**. Confirms the deploy actually worked on the live box. Set
`{url}` to the production URL.

### Required checks on production

**1. Smoke test on production** — same HTTP + must-pass URLs as
pre-deploy, but the URL is real:

```bash
curl -sf -o /dev/null -w "%{http_code}\n" "https://{url}/"
curl -sf -o /dev/null -w "%{http_code}\n" "https://{url}/wp-json/"
```

Then walk the same must-pass URL table above (homepage, a CPT archive,
a single, `/wp-admin/`, `/wp-json/`) on the production domain.

**2. Visit the top pages by traffic** — home + the 3–4 most-visited
(for most sites: home, primary service/product page, blog index,
contact). Confirm they render correctly with production data.

**3. wp-admin + DB integrity** — log into wp-admin, open the
most-edited post type list, confirm it loads and a sample post opens for
editing. Catches `acf_get_field_groups()` errors and ACF JSON sync
issues that only surface against the production DB.

**4. ACF values render** — pick a page that uses the new/changed ACF
fields and confirm the real production values appear on the front end
(not placeholder/empty).

**5. Sitemap + robots** — both must match a production environment:

```bash
curl -sf "https://{url}/sitemap.xml"      | head -c 200   # valid XML, not a 404
curl -sf "https://{url}/robots.txt"                       # must NOT contain "Disallow: /"
```

A production `robots.txt` with `Disallow: /` means the env flag is
wrong (`WP_ENV` left as staging, or search visibility off) — that's a
ship-blocker, fix immediately.

**6. Analytics / tag manager fires** — load a page with DevTools →
Network open and confirm GA4 / GTM / Plausible / whatever the project
uses actually sends its beacon.

### Time budget

Five to ten minutes total. If you find an issue, **don't fix-forward**
unless the fix is trivial (typo, swapped image). Roll back per the
project's rollback method in `ci-cd.md` (re-deploy the previous tag, or
restore from the host backup), then fix and re-deploy properly.

### Log the deploy

After the post-deploy gate passes, write a one-line entry to
`{theme_root}/.claude/changelog/daily.md`: what shipped, the tag (if
any), who QA'd it, any caveats. Tag production deploys `[DEPLOY-PROD]`
and direct-on-server edits `[DIRECT-PROD]` (see `safety-rules.md`).
Future sessions read this when something starts misbehaving days later.

---

## Hotfixes don't skip gates — they go faster by being minimal

A hotfix bypasses the *cadence*, not the *gates*. The way you make a
hotfix fast is by keeping the change tiny — one file, one line — so each
gate takes seconds, not by skipping verification.

A hotfix still:

- Passes **pre-merge** (CI + reviewer, or the local self-check on solo
  projects).
- Passes **pre-deploy** — on staging for full-pipeline, on local for
  the prod-direct patterns. Yes, even a one-liner: build it, load the
  affected page, confirm the fix.
- Passes **post-deploy** on production.

"Just push it, it's one line" is how production gets worse, not better.
Five extra minutes of verification beats a 3am rollback.

---

## Direct-on-server edits still get a post-deploy check

Editing files directly on the production server via SSH (a content
typo, an emergency one-liner) is permitted but always flagged — it's a
Confirm + backup operation (`safety-rules.md`). It does **not** escape
the post-deploy gate:

1. Make the edit (after the backup acknowledgement).
2. Run the **post-deploy gate** against production — smoke test, the
   affected page, wp-admin loads.
3. Log it `[DIRECT-PROD]` in `{theme_root}/.claude/changelog/daily.md`
   with the file path and the change, flagged **NOT in git**.
4. Warn inline: *"This change is not in Git. The next deploy from Git
   will overwrite it. Mirror it to your local repo and commit ASAP."*

Doing real development directly on production is an anti-pattern — the
gate won't refuse it, but the `[DIRECT-PROD]` trail makes the habit
obvious to whoever audits later.

---

## Production deploys gate on the backup acknowledgement

Independent of QA, **every production write also gates on the
backup-acknowledgement prompt** in `safety-rules.md`. Order of
operations for a prod deploy:

1. Pre-deploy QA passes (on staging or local, per pattern).
2. **Backup acknowledgement prompt** — the developer types
   `I have a backup from {date}` or `host backups verified`, or
   `abort`.
3. Deploy runs.
4. Post-deploy QA on production.
5. Log `[DEPLOY-PROD]` to `daily.md`.

A green QA pass does **not** waive the backup gate, and a backup
acknowledgement does **not** waive QA. They're orthogonal — both must
clear.

---

## Common bugs the gates catch

Recurring categories. Train yourself to scan for them during QA:

- **Wrong env in `wp-config.php`** — production serving with
  `WP_ENV=staging`, or `Disallow: /` left on. Caught by the
  post-deploy robots.txt check.
- **ACF JSON not synced** — fields exist in code but the "Sync
  available" notice is non-empty. Author forgot to re-sync. Caught by
  the ACF field check.
- **Image URLs hardcoded to local/staging** — Gutenberg blocks pasted
  with full URLs from another env. Caught by the viewport sweep
  (broken images) on production.
- **Form mailer using the wrong domain** — from-address still
  `noreply@staging.example.com`. Caught by the optional email test.
- **Plugin update missed on production** — Composer-managed plugins
  deployed but a manually-installed one is stale. Caught by wp-admin's
  update notices in the post-deploy admin check.
- **Caching layer not flushed** — stale assets served because
  Cloudflare / LiteSpeed / WP Rocket cached aggressively. Always purge
  the edge cache after a production deploy (`wp cache flush` is in the
  post-deploy hooks; the CDN is separate — purge it in the dashboard).

---

## Cross-references

- `ci-cd/patterns.md` — the three deploy patterns; which one a project
  uses decides where pre-deploy QA runs (staging vs local).
- `safety-rules.md` — the Safe / Confirm / Confirm + backup buckets,
  the backup-acknowledgement prompt, and the `[DEPLOY-PROD]` /
  `[DIRECT-PROD]` changelog conventions.
- `git-workflow.md` — branch / commit / push / tag rules; the pre-merge
  gate sits on top of the PR flow defined there.
- `dev-conventions.md` — what the reviewer checks the diff against
  (file structure, components, ACF JSON, what gets committed).
