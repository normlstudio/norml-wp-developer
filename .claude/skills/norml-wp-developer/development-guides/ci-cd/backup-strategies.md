# Backup Strategies — Reference

The catalog of backup providers and how to verify + restore each. The
deep layer behind the "Backup strategy" block every project declares in
its per-project `.claude/ci-cd.md`.

## How this maps to the acknowledgement model

The skill recognizes three backup-acknowledgement **tiers** (the values
that go in `ci-cd.md` → "Backup strategy → Provider"):

| Tier value | Meaning | Acknowledgement phrase |
|---|---|---|
| `host-automatic` | Host or a script makes backups on a schedule; you've verified recently | `host backups verified` |
| `manual-before-deploy` | No reliable automatic backup — you take one by hand before each prod write | `I have a backup from {date}` |
| `none-warned` | No backup strategy at all — stronger warning on every prod write | `I have a backup from {date}` (after the no-strategy warning) |

The four providers below map onto those tiers:

| Provider | Default tier | Why |
|---|---|---|
| `managed-host` (WP Engine, Kinsta, SiteGround, Cloudways…) | `host-automatic` | Daily auto + panel restore |
| `shared-host` (cPanel / Plesk / Beget-style panels) | `host-automatic` *(manual verify)* | Daily snapshots, but no API to confirm them |
| `vps-script` (Vultr, DO, Hetzner — you build it) | `host-automatic` *(once the cron exists)* | Your nightly script *is* the automation |
| `cloud-custom` (AWS / GCP / Azure — you design it) | `host-automatic` *(strict)* | Snapshots + monitoring you operate |

A project with **none** of these configured is `none-warned`.

### The unbreakable rule

> **The skill NEVER makes a backup silently.** A backup the user doesn't
> know about is worse than none — it manufactures false confidence.

Every production write gates on the backup-acknowledgement prompt in
`../safety-rules.md`. These providers tell you *what* the user is
acknowledging and *how* to check it's real before they type the phrase.
For the DIY paths (`vps-script`, `cloud-custom`): **a backup that hasn't
been restore-tested is theatre.** Quarterly restore tests are mandatory;
a stale test is grounds to refuse a destructive op.

### What each provider fills in `ci-cd.md`

Every provider populates the same fields in the project's
`.claude/ci-cd.md` "Backup strategy" section — this skill's per-project
contract, committed to git, **with no secrets**:

```markdown
## Backup strategy
- **Provider:** host-automatic | manual-before-deploy | none-warned
- **Restore method:** {one line — panel path, or "see restore runbook below"}
- **Last verified:** YYYY-MM-DD
- **Notes:** {host, frequency, retention, gotchas; + Last restore test for DIY paths}
```

Secrets (B2/AWS/SSH keys) never go in this file — they live in macOS
Keychain / Windows Credential Manager / ssh-agent, referenced by name.
Connection config (host alias, paths) lives in
`~/.config/norml-wp-developer/projects/{slug}.json` (per-machine, no
secrets).

---

## `managed-host` — built-in WordPress backups → `host-automatic`

> Hosts with a real backup system baked in: WP Engine, Kinsta,
> SiteGround Cloud, Cloudways, Flywheel, Pantheon, Pressable.

### What you get

| Host | Frequency | Retention | Restore UI | Notes |
|---|---|---|---|---|
| **WP Engine** | Daily auto + on-demand | 60 days | User Portal → site → Backup Points | Atomic restore (files + DB); points tied to environments |
| **Kinsta** | Daily auto + 5 manual slots | 14–30 days (plan) | MyKinsta → site → Backups | Manual backups don't expire; downloadable as ZIP |
| **SiteGround** | Daily auto | 30 days (Cloud), 7 (lower) | Site Tools → Security → Backups | Granular: full / files only / DB only |
| **Cloudways** | Hourly–daily (configurable) | 7–30 days | Server panel → Backups | Can off-store to AWS S3 |
| **Flywheel** | Nightly | 30 days | Flywheel dashboard → Backups | Restore creates a new point |
| **Pantheon** | Hourly–daily | 30 (Live) / 90 (Multidev) | Pantheon dashboard → Backups | Workflow-aware (dev/test/live) |
| **Pressable** | Daily auto + on-demand | 30 days | Pressable dashboard → Backups | Atomic restore |

### `ci-cd.md` fields

- **Provider:** `host-automatic`
- **Restore method:** `WP Engine Portal → site → Backup Points → Restore (~5 min full)`
- **Notes:** `WP Engine, daily auto, 60-day retention. Points tied to env
  (prod vs staging) — restoring prod from a staging point is possible but
  needs explicit confirmation in the panel.`

### Verify it's current

Per-host check (the answer the user gives before typing `host backups
verified`):

- **WP Engine:** User Portal → site → Backup Points → latest "Daily"
  timestamp.
- **Kinsta:** MyKinsta API `GET /sites/{site_id}/backups` → check
  `created_at` (or the panel).
- **SiteGround:** Site Tools → Security → Backups → Date column.
- **Cloudways:** API `GET /api/v1/server/{server_id}/backup` →
  `last_backup_timestamp`.

If the host exposes a CLI/API, record the exact verify command in
`ci-cd.md`.

### On-demand backup before a risky change

| Host | How |
|---|---|
| WP Engine | Portal → "Back up now" |
| Kinsta | "Manual backup" (uses 1 of 5 slots) |
| SiteGround | Site Tools → Security → Backups → "Create Backup" |
| Cloudways | "Take Backup Now" |

Wait for completion — don't deploy on top of an in-progress backup;
restore points can come out inconsistent.

### Restore

1. Pick the target backup (timestamp ~1 minute before the breaking
   change).
2. Click "Restore" in the panel.
3. Most hosts restore atomically (files + DB) — watch for DB-only
   options if that's all you need.
4. Wait (typically 5–15 min), confirm recent content is visible, flush
   caches if not automatic.

### Limitations

- **Restore takes minutes, not seconds.** Don't promise zero downtime.
- **Retention is finite** — 60 days (WP Engine) vs 7 (low SiteGround).
  Know the window.
- **Inter-environment restores** (prod from a staging point) are usually
  possible but easy to misclick.
- **Backups aren't auto-tested** — schedule a quarterly restore-to-
  staging test even on managed hosts.

---

## `shared-host` — panel snapshots → `host-automatic` (manual verify)

> Shared hosting with panel-based daily snapshots: cPanel, Plesk,
> ISPmanager, Beget-style panels. Daily auto, short retention, no API.

### What you get

- **Daily automatic snapshots** of files + DB.
- **Retention:** typically 7–14 days (plan-dependent).
- **Panel restore UI** (cPanel / JetBackup, Plesk, ISPmanager, Beget).
- **Manual snapshot triggers** sometimes available, usually rate-limited
  (e.g. 1/day).

### `ci-cd.md` fields

- **Provider:** `host-automatic`
- **Restore method:** `hosting panel → Backups → pick date → Restore (~10 min)`
- **Notes:** host name, daily auto, retention; **NO API — verification is
  manual, Claude must ask the user to confirm a recent snapshot before any
  prod write.**

### Verify it's current (manual — no API)

- **cPanel:** JetBackup (or built-in Backups) → latest backup timestamp.
- **Plesk:** Websites & Domains → Backup Manager → latest entry.
- **Beget-style:** panel → Backups / Снимки → confirm a snapshot within
  the last 24 h.

There's usually **no CLI or API**, so the skill **cannot** auto-verify —
it must **ask the user to confirm a recent backup exists** before any
prod write (then they type `host backups verified`), and record the
snapshot timestamp in the session note so the restore target is
unambiguous. If they can't confirm one, have them take a manual snapshot
via the panel first.

### On-demand backup

- **cPanel + JetBackup:** Manage → "Generate Backup".
- **Beget-style:** "Create backup" / "Создать копию" (if the plan
  allows).

If manual triggers aren't available, the daily auto-snapshot is the only
net — schedule destructive changes shortly after the daily backup window
(usually early morning) so the freshest snapshot is recent.

### Restore

1. Panel → Backups → pick the snapshot by timestamp.
2. Choose scope: **full** (files + DB, easiest), **files only**, or **DB
   only**.
3. Restore, wait 5–15 min, verify, flush caches.

> **Account-wide restore caution (common on these panels):** restore may
> overwrite the *entire account* to that snapshot with **no preview** —
> once clicked, it's committed, and if one account hosts several sites,
> all of them revert. Take a manual snapshot **right before** any restore
> so you can undo the restore itself. Check the host's granularity.

### Download for off-site insurance

- **cPanel:** Files → Backup Wizard → Download Full / Partial.
- **Beget-style:** Backups → pick snapshot → Download (some plans), or
  SSH in and copy the backup dir down.

Useful before a known-risky change.

### Limitations

- **No API** — panel-only; Claude asks, can't check.
- **Short retention** (7 days common) — bugs that surface later have no
  easy restore path.
- **Restore may be account-wide, not per-site**, and manual triggers are
  rate-limited (you may not get 5 in 5 hours).
- Snapshots include `wp-content/uploads/`, so they're large and slow to
  restore.

---

## `vps-script` — you build the backup → `host-automatic` (once it exists)

> VPS hosts with no built-in WordPress backup: Vultr, DigitalOcean,
> Hetzner, Linode, OVH. You write the script. You own the restore. Until
> the cron exists and is verified, treat the project as `none-warned`.

### What you DON'T get by default

The provider gives you the server, not: automatic WP backups, a restore
UI, or point-in-time recovery. Some sell a **paid disk-snapshot add-on**:

| Provider | Add-on | Frequency | Cost |
|---|---|---|---|
| **Vultr** | Auto Backups | Daily (rolling 4) | +20% of plan |
| **DigitalOcean** | Backups | Weekly | +20% of plan |
| **Hetzner** | Backups | Daily (rolling 7) | +20% of plan |
| **Linode** | Backups | Daily + weekly + bi-weekly | small flat add-on |

These are **whole-disk** snapshots, not WordPress-aware — restore is
VM-level, not per-site. Useful, not granular. The real backup is the
script below.

### What you must build

1. **A nightly cron** that exports the DB, tars `wp-content/uploads/`,
   and (optionally) the theme/plugins — or trust git for code.
2. **Off-site storage** — Backblaze B2 / S3 / Wasabi / Cloudflare R2.
   **Never** another folder on the same VPS (one failure takes out both).
3. **A retention policy** — e.g. 14–30 daily + monthly archives.
4. **A documented restore runbook** in `ci-cd.md`.
5. **A quarterly restore test.** Non-negotiable.

### `ci-cd.md` fields

- **Provider:** `host-automatic`
- **Restore method:** `see Restore runbook below (~30 min full restore)`
- **Notes:** `Hetzner CX21. Nightly cron 03:00 UTC → Backblaze B2 bucket
  backups-{project-slug} (B2 creds in Keychain entry b2-backups-{project-slug},
  never in this file). 14-day daily + first-of-month kept. Script:
  /home/deploy/backup-{project-slug}.sh. Last restore test: 2026-04-12.`

### Example backup script

```bash
#!/bin/bash
set -euo pipefail

PROJECT="{project-slug}"
SITE_PATH="/var/www/{project-slug}"
B2_BUCKET="backups-${PROJECT}"
DATE=$(date +%Y%m%d-%H%M)
BACKUP_DIR="/tmp/backup-${DATE}"

mkdir -p "$BACKUP_DIR"

# DB
cd "$SITE_PATH"
wp db export "$BACKUP_DIR/${PROJECT}-db-${DATE}.sql" --default-character-set=utf8mb4

# Uploads
tar czf "$BACKUP_DIR/${PROJECT}-uploads-${DATE}.tar.gz" -C "$SITE_PATH/wp-content" uploads

# Upload off-site to B2 (creds from ~/.config/rclone or the B2 CLI env — never hard-coded here)
b2 sync "$BACKUP_DIR/" "b2://$B2_BUCKET/${DATE}/"

# Cleanup local staging copy
rm -rf "$BACKUP_DIR"

# Prune: keep the last 14 daily + every first-of-month forever
b2 ls "b2://$B2_BUCKET/" | awk '{print $NF}' | sort -r | tail -n +15 | while read -r prefix; do
  day=$(echo "$prefix" | cut -c7-8)
  if [ "$day" != "01" ]; then
    b2 rm --recursive "b2://$B2_BUCKET/$prefix"
  fi
done
```

Schedule:

```cron
0 3 * * * /home/deploy/backup-{project-slug}.sh >> /var/log/backup-{project-slug}.log 2>&1
```

### Verify it's current

1. SSH to the VPS.
2. `tail -50 /var/log/backup-{project-slug}.log` — last line is success.
3. `b2 ls "b2://backups-{project-slug}/" | tail -5` — latest entry is
   within the last 24 h.

Automate it: a cron that alerts if the newest backup is older than 26 h.

### On-demand backup

```bash
ssh {vps} '/home/deploy/backup-{project-slug}.sh'
```

Wait for completion before proceeding.

### Restore runbook (generic shape — write the exact steps in `ci-cd.md`)

1. Spin up a fresh VPS (or wipe the current one).
2. Install the LEMP stack + WP-CLI.
3. Pull the latest theme code from your git remote.
4. Download the target backup:
   ```bash
   b2 sync "b2://backups-{project-slug}/{date}/" /tmp/restore/
   ```
5. Import the DB:
   ```bash
   wp db import /tmp/restore/{project-slug}-db-{date}.sql
   ```
6. Extract uploads:
   ```bash
   tar xzf /tmp/restore/{project-slug}-uploads-{date}.tar.gz -C /var/www/{project-slug}/wp-content/
   ```
7. Fix permissions, flush caches, smoke test.

### Limitations & refusal rule

- **You own the script** — if it breaks, only you will notice.
- **You own the bucket** — pay for storage, rotate credentials, watch
  egress.
- **No granular restore** — single-file recovery means extracting from
  the tarball by hand.
- **Restore is slower** than managed hosts (you're rebuilding the box).
- **Refuse destructive ops when the safety net is stale:** if `Last
  verified` is older than 7 days, **or** the last restore test is older
  than 90 days, flag it loudly to the user before any production write.
  A backup that hasn't been tested may not work when you need it.

---

## `cloud-custom` — enterprise cloud, fully DIY → `host-automatic` (strict)

> WordPress on AWS / GCP / Azure with no built-in WP backup: EC2 / GCE /
> Azure VM with attached storage, managed-K8s, or Lightsail without
> snapshots configured. You design and operate the entire flow.

### The hard truth

The most expensive and most failure-prone backup pattern — custom
systems break **silently** more often than they work. **If at all
possible, use `managed-host` or `vps-script` with a snapshot add-on
instead.** You usually land here only because the client mandated AWS /
GCP / Azure for compliance (HIPAA, GDPR, SOC2 — restore must be
auditable). When stuck with it, proceed with maximum rigor.

### What must be designed

- **Orchestration:** EBS snapshots (AWS) / Persistent Disk snapshots
  (GCP) for full-disk capture; **DB** via RDS / Cloud SQL managed
  snapshots, or `mysqldump` + object-store upload for MySQL-on-VM;
  **uploads** via S3 versioning if already on S3, else covered by the
  disk snapshot; **config** captured by IaC (Terraform/Ansible) or by
  snapshotting `/etc/nginx`, `/etc/php`, etc.
- **Storage:** S3 / GCS / Azure Blob in a **different region** than
  primary; lifecycle rules for retention (e.g. 30 days standard → Glacier
  for monthly archives); **encryption at rest**.
- **Scheduling:** AWS EventBridge → Lambda; GCP Cloud Scheduler → Cloud
  Function; Azure Automation runbook; or a VM cron (simpler, less
  auditable).
- **Monitoring:** CloudWatch / Stackdriver alarm on a missed window;
  daily summary to email / Slack; paging via PagerDuty / OpsGenie.
- **Documented restore + quarterly tests**, with the result recorded in
  `ci-cd.md`.

### `ci-cd.md` fields

- **Provider:** `host-automatic`
- **Restore method:** `see Restore runbook below (~2–4 h full restore)`
- **Notes:** `AWS eu-west-1. Hourly RDS + daily EBS snapshots; uploads on S3
  (versioning + Glacier at 30 days); EventBridge + Lambda; CloudWatch. AWS
  creds in Keychain entry aws-backups-{project-slug}. Restore needs console
  access + DBA on call. Last restore test: 2026-04-12. Escalation: infra
  lead → on-call DBA.`

### Mandatory `ci-cd.md` content for this provider

This produces the **longest** `ci-cd.md` of any pattern — appropriately,
because restoring under pressure is when mistakes happen. It MUST
include:

1. **Backup architecture** — every component (ASCII diagram or a linked
   one), so an on-call engineer sees the whole picture.
2. **Verification command** — how to confirm the latest snapshot is fresh
   and healthy.
3. **Restore runbook** — full step-by-step, written for someone who has
   never done it.
4. **Escalation** — DBA, infra lead, on-call rotation.
5. **Compliance notes** — retention rules, when backups may be deleted,
   right-to-erasure handling.

### Verify it's current (project-specific examples)

**AWS RDS:**
```bash
aws rds describe-db-snapshots \
  --db-instance-identifier {instance} \
  --query 'reverse(sort_by(DBSnapshots,&SnapshotCreateTime))[0]' \
  | jq '{id: .DBSnapshotIdentifier, time: .SnapshotCreateTime, status: .Status}'
```
Confirm `time` is recent and `status` is `available`.

**AWS EBS:**
```bash
aws ec2 describe-snapshots \
  --filters Name=tag:Project,Values={project-slug} \
  --query 'reverse(sort_by(Snapshots,&StartTime))[0]' \
  | jq '{id: .SnapshotId, time: .StartTime, state: .State}'
```

**GCP Persistent Disk:**
```bash
gcloud compute snapshots list --filter="labels.project={project-slug}" --sort-by=~creationTimestamp --limit=1
```

### On-demand backup (example — RDS)

```bash
aws rds create-db-snapshot \
  --db-instance-identifier {instance} \
  --db-snapshot-identifier manual-pre-deploy-$(date +%Y%m%d-%H%M)
```
Wait for `status: available` before proceeding.

### Restore (generic — the real runbook lives in `ci-cd.md`)

1. Verify the target snapshot is healthy
   (`describe-snapshots` / `describe-db-snapshots`).
2. Coordinate with infra / DBA — restore needs console access and may
   carry a compliance review.
3. **DB:** RDS → restore snapshot to a new instance, point WP at it,
   decommission the old; MySQL-on-VM → `mysql < dump.sql` after stopping
   WP.
4. **Files:** EBS → create a volume from the snapshot, mount, rsync to
   target; S3 versioning → restore to the specific version.
5. Smoke test.
6. Document the incident: trigger, what was restored, lessons.

### Refusal rule

Strictest of any provider, because custom logic breaks silently:

- `Last verified` older than 24 h → refuse, ask the user to verify.
- Last restore test older than 90 days → flag loudly, consider refusing.
- **Backup architecture undocumented in `ci-cd.md` → refuse all
  destructive ops until it's documented.**

---

## `none-warned` — no backup strategy at all

When a project has none of the above — no host backups, no script, no
cloud flow — its `ci-cd.md` declares **Provider:** `none-warned`,
**Restore method:** `NONE`, **Last verified:** `n/a`, **Notes:** "no
automatic backups and no manual workflow; every prod write is
at-your-own-risk until a real strategy is configured."

Under this tier, every production write produces the stronger warning
from `../safety-rules.md` — the skill spells out that if something
breaks, the data is gone, suggests enabling host backups or taking a
manual one on the spot, and proceeds only on `I have a backup from
{date}`. **It still never makes the backup for the user silently.**

---

## Cross-references

- `./patterns.md` — the three deploy patterns; each one's "Backup
  discipline" subsection points here.
- `../safety-rules.md` — the backup-acknowledgement prompt, the
  `host-automatic` / `manual-before-deploy` / `none-warned` tiers, the
  "never back up silently" rule, and the 30-day re-verify nudge.
- `./database-strategies.md` — the destructive DB operations that these
  backups are the safety net for.
