# CI/CD Patterns — Reference

Three supported deploy patterns. Picked at onboarding, written into the
per-project `.claude/ci-cd.md`. Every deploy reads this contract before
running.

## Pattern 1 — `full-pipeline` (recommended)

The canonical full flow: staging gates production, CI/CD enforced.

### When to use

- Serious client project with paying users on production
- More than one developer touches the codebase
- You can tolerate a 5-minute deploy cycle in exchange for safety
- The host supports SSH deploys (almost all do)

### Environments

- **Local** — WP Local (or DDEV / Lando / etc.)
- **Staging** — separate URL + database from production, ideally on
  the same host
- **Production** — live site

### Branch model

- `main` → production
- `develop` → staging
- Feature branches → PR into `develop`

### Workflow

```
Local dev
   ↓
git push origin feat/my-feature
   ↓
PR opened against develop
   ↓
(reviewer LGTM)
   ↓
Merge into develop
   ↓
GHA workflow: .github/workflows/staging.yml fires
   ↓
SSH-deploy to staging
   ↓
QA on staging URL
   ↓
git tag v1.2.3 + git push --tags
   ↓
GHA workflow: .github/workflows/production.yml fires
   ↓
[BACKUP ACKNOWLEDGEMENT PROMPT]
   ↓
SSH-deploy to production
   ↓
Post-deploy: wp cache flush, smoke test
```

### What the GHA workflow does (staging)

```yaml
# .github/workflows/staging.yml
name: Deploy to staging
on:
  push:
    branches: [develop]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
      - name: Install Composer deps (no dev)
        run: composer install --no-dev --optimize-autoloader --no-interaction
      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install npm deps
        run: npm ci
      - name: Build assets
        run: npm run build
      - name: rsync to staging
        env:
          SSH_KEY: ${{ secrets.STAGING_SSH_KEY }}
          STAGING_HOST: ${{ secrets.STAGING_HOST }}
          STAGING_PATH: ${{ secrets.STAGING_THEME_PATH }}
        run: |
          mkdir -p ~/.ssh
          echo "$SSH_KEY" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          rsync -avz --delete \
            --exclude='.git' --exclude='node_modules' --exclude='.claude' \
            -e "ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no" \
            ./ "$STAGING_HOST:$STAGING_PATH"
      - name: Post-deploy hooks
        env:
          SSH_KEY: ${{ secrets.STAGING_SSH_KEY }}
          STAGING_HOST: ${{ secrets.STAGING_HOST }}
        run: |
          ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no "$STAGING_HOST" \
            "cd ${{ secrets.STAGING_WP_PATH }} && wp cache flush && wp acorn view:cache || true"
      - name: Smoke test
        run: curl -sf -o /dev/null "https://${{ secrets.STAGING_URL }}/" || exit 1
```

The production workflow is the same shape, triggered on `tags: ['v*']`,
with secrets prefixed `PRODUCTION_*`.

### Secrets in GitHub

The setup script tells you which secrets to add to your repo at
`https://github.com/{owner}/{repo}/settings/secrets/actions`:

- `STAGING_SSH_KEY` — the private key (paste the full file content)
- `STAGING_HOST` — `user@host:port` (port optional, defaults to 22)
- `STAGING_THEME_PATH` — absolute path to the theme folder on the
  staging server
- `STAGING_WP_PATH` — absolute path to the WP install root on staging
- `STAGING_URL` — e.g. `staging.acme.com`
- Same with `PRODUCTION_*` prefix.

You add these once. The setup script generates a fresh SSH key for the
deployer (separate from your personal key) and tells you what to paste
where.

### Database strategy

Code in git, content in the database. The two flow separately:

- **Code:** local → staging (push to develop) → production (tag).
- **Content:** wp-admin on production. To refresh staging with prod
  content, use `scripts/sync-from-prod.sh` (pulls DB + uploads from
  prod to local, then you push from local to staging if needed).

`wp search-replace` is automatic in `sync-from-prod` — production URL
gets replaced with the local URL.

### Backup discipline

Production deploys gate on the backup acknowledgement prompt. The
GHA workflow has a manual `workflow_dispatch` input that requires
typing "I have a backup" before the deploy step runs. See the template
workflow YAML.

## Pattern 2 — `prod-direct-with-git`

Single environment (production), git as the safety net. No staging.

### When to use

- Small marketing sites with low publish frequency
- Internal tools where downtime is annoying but not catastrophic
- Solo developer projects
- You don't have the budget for a staging environment

### Environments

- **Local** — WP Local
- **Production** — live site

### Branch model

- `main` → production
- Feature branches → merge into `main` (with squash-commit for clean
  history)

### Workflow

```
Local dev
   ↓
Commit + push to main
   ↓
GHA workflow: .github/workflows/production.yml fires
   ↓
[BACKUP ACKNOWLEDGEMENT PROMPT]
   ↓
SSH-deploy to production
   ↓
Post-deploy: wp cache flush, smoke test
```

The workflow YAML is the same as the staging one above, just deploying
to production secrets.

### Database strategy

Single environment — content lives on production. To refresh local:
`scripts/sync-from-prod.sh`. Local DB is throwaway. You never push DB
from local to production unless you really know what you're doing.

### Backup discipline

Every push to `main` triggers the production deploy. The workflow's
first step is the backup-acknowledgement gate — the dispatch input
"i_have_a_backup" must equal "yes" or the workflow fails immediately.

For day-to-day pushes you DON'T want to type the backup acknowledgement
on every change — common compromise: enable host-side automatic backups
and set the workflow input default to "yes (host backups enabled)" with
a comment in `ci-cd.md` documenting which host backups exist and how
to restore.

## Pattern 3 — `prod-direct-no-ci`

No CI/CD. `rsync` from local to production on demand. The lowest-
overhead option, and the most dangerous.

### When to use

- Tiniest sites, solo developer, no team
- Throwaway projects, prototypes, demos
- You really don't want to deal with GHA setup

### Environments

- **Local** — WP Local
- **Production** — live site

### Branch model

- `main` only (or no branches at all if you really want to commit
  directly)
- Tags optional but recommended for "known-good" markers

### Workflow

```
Local dev
   ↓
Commit
   ↓
[BACKUP ACKNOWLEDGEMENT PROMPT]
   ↓
bash scripts/deploy-to-prod.sh
   ↓
rsync over SSH to production theme folder
   ↓
ssh prod 'wp cache flush'
   ↓
Smoke test (curl on homepage)
```

The deploy script:

```bash
rsync -avz --delete \
  --exclude='.git' --exclude='node_modules' --exclude='.claude' \
  --exclude='.env' \
  ./ "$PROD_HOST:$PROD_THEME_PATH"
```

(Built from the per-project `.claude/ci-cd.md`.)

### Backup discipline

Same backup gate. Every `deploy-to-prod.sh` run prints the prompt and
refuses without acknowledgement.

## Per-project `.claude/ci-cd.md` contract

Every project has a `ci-cd.md` in its `.claude/` folder that declares:

```markdown
# CI/CD Contract — {Project}

## Pattern
- **Pattern:** `full-pipeline` | `prod-direct-with-git` | `prod-direct-no-ci`

## Environments
- **Local:** WP Local site `{slug}`, URL `https://{slug}.local`
- **Staging:** URL `https://staging.{domain}`, SSH `{alias}`, theme path `{path}`
- **Production:** URL `https://{domain}`, SSH `{alias}`, theme path `{path}`

## Database strategy
- (one of: `single-env`, `prod-is-source-of-truth`, `manual-promote`)
- (notes on `wp search-replace` URL handling)

## Backup strategy
- **Provider:** (one of: `host-automatic`, `manual-before-deploy`, `none-warned`)
- **Restore method:** {brief description, e.g. "hosting panel → backups → restore"}
- **Last verified:** YYYY-MM-DD
- **Notes:** {any project-specific gotchas}

## Permissions matrix
| Action | Claude can do autonomously? | Requires human go-ahead? |
|---|---|---|
| Push to feature branch | yes | — |
| Merge to develop | (yes if PR'd) | (yes if solo) |
| Tag a release | no | yes |
| Production deploy | no | yes |
| Direct-on-server edit | no | yes (and warn) |

## Deploy commands

### Push to staging
{exact command sequence, e.g. `git push origin develop` for full-pipeline}

### Promote to production
{exact command sequence, e.g. `git tag v{x.y.z} && git push --tags`}

### Rollback
{how to roll back — re-deploy previous tag, or restore from host backup}

## Pre-deploy hooks
- `npm run build`
- `composer install --no-dev`
- (optional) `vendor/bin/phpstan`
- (optional) `vendor/bin/pint --test`

## Post-deploy hooks
- `wp cache flush`
- `wp acorn view:cache` (Sage projects only)
- Smoke test: `curl -sf https://{url}/` returns 200

## Known gotchas
- {project-specific things, e.g. "Server PHP is 8.3, theme requires 8.2 — fine"}
```

The setup script scaffolds this file from `templates/ci-cd.template.md`,
substituting values from the per-project JSON. The developer edits it
freely after — it's project knowledge, committed to git.

## How other parts of the skill consume this

When a deploy command is requested:

1. Read `~/.config/norml-wp-developer/projects/{slug}.json` to get the
   theme path.
2. Read `{theme_root}/.claude/ci-cd.md` to get the pattern + commands.
3. Run the pattern's pre-deploy hooks.
4. Print the backup acknowledgement prompt for production deploys.
5. Run the deploy commands.
6. Run the post-deploy hooks.
7. Log `[DEPLOY-STAGING]` or `[DEPLOY-PROD]` to
   `{theme_root}/.claude/changelog/daily.md`.

If `ci-cd.md` is missing → hard-stop, tell the user to run setup or
the init flow.

## Switching patterns later

You can switch a project from one pattern to another. The setup script
has a "reconfigure CI/CD" option that:

1. Backs up the current `.claude/ci-cd.md` to
   `.claude/ci-cd.{date}.bak.md`
2. Asks the questions again to pick a new pattern
3. Writes the new `ci-cd.md`
4. Updates / removes / adds `.github/workflows/*.yml` to match
5. Updates the per-project JSON

The git history of `ci-cd.md` shows the evolution.
