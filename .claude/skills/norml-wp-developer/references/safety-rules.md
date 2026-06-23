# Safety Rules — Reference

Every operation falls into one of three buckets. The third bucket
gates on a mandatory backup acknowledgement. **Apply this on every
request.**

## Safe (run immediately, then report)

Read-only or low-risk local operations. No confirmation needed.

- `git status`, `git log`, `git diff`, `git branch`
- Reading any file under the theme repo
- `composer show`, `npm ls`, `composer info`
- `wp post list`, `wp option get`, `wp user list` against **local**
- Reading `.claude/CLAUDE.md`, `.claude/ci-cd.md`,
  `.claude/changelog/*`
- Listing the active plugins/themes (read-only)
- `ssh {alias} echo ok` (the SSH smoke test)
- `ssh {alias} 'cd $WP && wp --info'` (read-only on the server)
- Running `npm run dev`, `npm run build`, `composer install` locally
- Browsing local URLs via Playwright / curl

## Confirm (show the command, ask "yes" before running)

Anything that:

- Writes to the **local** repo (commits, branch creation, merges)
- Writes to **staging** (rsync, `wp` commands on staging)
- Changes git state on shared branches
- Installs / removes packages

Show the exact command. If a diff is relevant, show the diff. Ask for
"yes" before running.

### Examples — Confirm tier

- `git commit -m "feat(blocks): add hero"` — show the staged diff
  first.
- `git push origin feat/branch` — show what's being pushed.
- `git rebase main` — show the commits about to be rewritten.
- `git merge feat/branch` — show the commit graph.
- `rsync` to staging — show the source, destination, and `--delete`
  status.
- `ssh staging 'cd $WP && wp plugin install acf-pro --activate'` —
  show the exact command.
- `composer require {package}` — show the constraint.
- `npm install {package}` — show the dep.

## Confirm + backup (gates on explicit backup acknowledgement)

Anything that writes to **production**. The bar is higher and the
acknowledgement is **mandatory**.

The flow:

1. Show the exact command(s) about to run.
2. Print the backup-acknowledgement prompt verbatim:

   > **Production write — backup acknowledgement required.**
   >
   > This command will mutate the production server. If something
   > goes wrong, the only path back is your backup.
   >
   > Confirm one of the following by typing the matching phrase:
   >
   > - `I have a backup from {date}` — you took a manual backup
   >   recently.
   > - `host backups verified` — your host's automatic backups are
   >   on, you've checked them in the panel this week, and you know
   >   how to restore.
   > - `abort` — don't run the command (default).
   >
   > Type your answer and press Enter.

3. Wait for the response. Only proceed on a positive answer that
   matches one of the two acknowledgement phrases (case-insensitive,
   trimmed). Anything else aborts.
4. Log the operation as `[DEPLOY-PROD]` or `[DIRECT-PROD]` in
   `{theme_root}/.claude/changelog/daily.md` AFTER it completes.

### Examples — Confirm + backup

- `rsync` to production server
- `git push origin main` on a `prod-direct-with-git` project
- `git push --tags v1.2.3` on a `full-pipeline` project (triggers
  production GHA workflow)
- `ssh prod 'cd $WP && wp plugin install/activate/deactivate/update'`
- `ssh prod 'cd $WP && wp theme activate'`
- `ssh prod 'cd $WP && wp db import'`
- `ssh prod 'cd $WP && wp search-replace ...'`
- `ssh prod 'cd $WP && wp eval'` for arbitrary PHP
- Any edit of files on the production server via SSH (direct-on-server
  hotfix)

### The host-backups-verified path

`host backups verified` is intentionally harder to type than `yes`. It
forces the developer to consciously claim they've checked the host's
backup panel recently. The skill doesn't verify this claim — it trusts
the developer.

If the project's `.claude/ci-cd.md` declares the backup strategy as
`host-automatic` and includes a "last verified: YYYY-MM-DD" line within
the last 30 days, the prompt can mention this:

> Your `ci-cd.md` says host backups are automatic and were last
> verified on 2026-05-15. Type `host backups verified` to proceed.

If it's been longer than 30 days, the prompt nudges to re-verify:

> Your `ci-cd.md` says host backups are automatic but were last
> verified 47 days ago. Worth checking the hosting panel before
> proceeding. Type `host backups verified` if you've checked, or
> `I have a backup from {date}` if you took a manual one.

## Stop (refuse outright)

Operations the skill refuses to run even with explicit instruction:

### Database operations that drop or reset

- `wp db reset` on any environment
- `wp db drop` on any environment
- Direct SQL `DROP TABLE` / `TRUNCATE` against production
- Bulk delete of `wp_posts` rows on production

If the user really wants to do these, they have to SSH manually and
type the commands themselves. The skill doesn't proxy.

### Force-pushing to long-lived branches

- `git push --force` to `main` or `develop` (or whatever the long-
  lived branch is named per `.claude/ci-cd.md`)

Force-push to short-lived feature branches is allowed in the
Confirm bucket.

### Editing `wp-config.php`, `.htaccess`, `index.php`

- The skill never edits these via SSH. They're sacred — too much can
  break.
- If the user needs to edit them, they SSH manually.

### Disabling security plugins on production

- Wordfence, Solid Security, etc. — never via this skill.
- Same path: manual SSH if the user really insists.

### Removing the only administrator

- The skill verifies any user-deletion or role-change op leaves at
  least one admin. If the op would leave the site with zero admins,
  refuse.

## When you don't know what bucket

Default to **Confirm**, never to Safe. If you can't decide between
Confirm and Confirm+backup, treat it as Confirm+backup.

If you can't decide between Confirm+backup and Stop, treat it as Stop.

## Backup discipline — when the user has none

If `.claude/ci-cd.md` says `backup.provider: none-warned` (i.e. the
project has no automatic backups and no manual backup workflow), every
production write produces a stronger warning:

> **This project has no backup strategy configured.** Production
> writes are at-your-own-risk; if you break something, the data is
> gone.
>
> Strongly consider: enabling automatic backups in your hosting
> panel, OR taking a manual backup now via:
>
> ```bash
> # On the production server, via SSH:
> wp db export ~/backups/{date}.sql
> tar -czf ~/backups/{date}-uploads.tgz wp-content/uploads/
> # Then download the .sql and .tgz to a SAFE place OFF the server.
> ```
>
> Type one of:
> - `I have a backup from {date}` — to proceed despite the no-strategy
>   warning.
> - `abort` — to stop.

The skill never silently makes a backup. Making a backup that the user
doesn't know about is worse than no backup — it creates false
confidence.

## Direct-on-server work — the elevated risk path

The skill supports editing files directly on the production server via
SSH. This is **permitted but always flagged**:

1. The op is Confirm+backup (mandatory ack).
2. After the edit, log `[DIRECT-PROD]` in `daily.md` with the file
   path, the change made, and a flag that the change is NOT in git.
3. Warn the user inline: *"This change is not in Git. The next deploy
   from Git will overwrite it. Mirror this change to your local repo
   and commit it as soon as possible."*

Common direct-on-server use case: hotfix for a typo in production
content (one-line edit, takes 30 seconds, can't wait for the full
CI/CD cycle).

Anti-pattern: doing real development directly on production. The
skill will keep flagging it, won't refuse, but the changelog will
make the pattern obvious to whoever audits it later.

## Rotation — when a secret leaks

If a secret was committed, printed, or pasted somewhere it shouldn't
be:

### SSH key

1. Remove the public key from the server's `~/.ssh/authorized_keys` or
   from the hosting panel's SSH keys list.
2. Delete the local private key.
3. Generate a new key.
4. Add the new public key to the server.
5. If the key was committed to git, force-push the cleaned history
   (after coordinating with the team) and consider the repo
   compromised — anyone who cloned it has the key.

### GitHub PAT

1. Revoke at `github.com/settings/tokens`.
2. If it was committed: BFG Repo-Cleaner or `git filter-branch` to
   remove from history. Force-push.
3. Generate a new token. Update wherever it was stored (host secret
   store, GHA secrets, etc.).

### Database password

1. Change the DB user's password on the host.
2. Update `wp-config.php` on the affected server(s).
3. If `wp-config.php` was committed (it shouldn't be), purge it from
   history and force-push.

### Application password (norml-wp-manager)

Different skill, but if a developer accidentally exposes a manager-
skill app password: revoke at wp-admin → Users → Profile →
Application Passwords. Re-run that skill's onboarding to generate a
fresh one.

## Error escalation

When something goes wrong (SSH refused, push rejected, deploy failed
mid-flight):

- **Don't retry destructively.** Don't `git reset --hard`. Don't
  re-rsync without understanding what failed.
- **Stop. Show the exact error.**
- For deploy failures mid-flight: the production server may be in a
  partially-deployed state. Show the user what got deployed (which
  files made it via rsync) and what didn't. Let them decide whether
  to roll forward (re-run after fixing) or roll back (re-deploy
  previous tag / restore from backup).
- For mysterious failures: suggest `scripts/test-ssh.sh` to verify
  the basic connection works.

## Cross-references

- `references/git-workflow.md` — branch / commit / push / tag rules
- `references/ci-cd/patterns.md` — what each pattern's deploy
  commands look like
- `references/dev-conventions.md` — what gets committed vs not (some
  Stop-tier mistakes happen because secrets land in tracked files)
