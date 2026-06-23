# CI/CD Patterns — Reference

Three supported deploy patterns. One is picked at onboarding and written into
the per-project `{theme_root}/.claude/ci-cd.md`. Every deploy reads that
contract before running.

This folder holds the full CI/CD knowledge for the skill:

| File | What it covers |
|---|---|
| `patterns.md` (this file) | The three deploy patterns + the per-project `ci-cd.md` contract |
| `database-strategies.md` | How content / the database is handled per pattern (sync direction, the rules) |
| `backup-strategies.md` | Backup providers, how to verify each, restore runbooks, the acknowledgement tiers |

Read `patterns.md` to pick the deploy shape; read the other two for the
database and backup depth each pattern points at.

---

## Pattern 1 — `full-pipeline` (recommended)

The canonical full flow: staging gates production, CI/CD enforced.

### When to use

- Serious client project with paying users on production
- More than one developer touches the codebase
- You can tolerate a ~5-minute deploy cycle in exchange for safety
- The host supports SSH deploys (almost all do)

### Environments

- **Local** — WP Local (or DDEV / Lando / Valet)
- **Staging** — separate URL + database from production, ideally same host
- **Production** — live site

### Branch model

- `main` → production
- `develop` → staging
- Feature branches → PR into `develop`

### Workflow

```
Local dev
   ↓
git push origin feat/my-feature  →  PR against develop  →  (reviewer LGTM)
   ↓
Merge into develop
   ↓
GHA: .github/workflows/staging.yml  →  SSH-deploy to staging
   ↓
QA on staging URL (see ../qa-gates.md — pre-deploy gate)
   ↓
git tag v1.2.3 + git push --tags
   ↓
GHA: .github/workflows/production.yml
   ↓
[BACKUP ACKNOWLEDGEMENT PROMPT]
   ↓
SSH-deploy to production  →  post-deploy hooks + smoke test (../qa-gates.md — post-deploy gate)
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
        run: |
          ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no "${{ secrets.STAGING_HOST }}" \
            "cd ${{ secrets.STAGING_WP_PATH }} && wp cache flush && wp acorn view:cache || true"
      - name: Smoke test
        run: curl -sf -o /dev/null "https://${{ secrets.STAGING_URL }}/" || exit 1
```

The production workflow is the same shape, triggered on `tags: ['v*']`, with
secrets prefixed `PRODUCTION_*`, and the backup-acknowledgement gate as its
first step (see `backup-strategies.md`).

### Secrets in GitHub

Add these once at `https://github.com/{owner}/{repo}/settings/secrets/actions`
(the setup script tells you which after onboarding):

- `STAGING_SSH_KEY` — the deployer's private key (full file content)
- `STAGING_HOST` — `user@host`
- `STAGING_THEME_PATH` — absolute path to the theme folder on staging
- `STAGING_WP_PATH` — absolute path to the WP install root on staging
- `STAGING_URL` — e.g. `staging.acme.com`
- Same with `PRODUCTION_*` prefix.

The setup script generates a fresh SSH key for the deployer (separate from
your personal key) and tells you what to paste where.

### Database & backup

- **Database:** `prod-is-source-of-truth` — code flows up (git → staging →
  prod), content lives on production, staging is refreshed *down* from prod.
  Full detail + the `wp` commands in **`database-strategies.md`**.
- **Backup:** production deploys gate on the backup-acknowledgement prompt.
  Provider + restore runbook in **`backup-strategies.md`**.

---

## Pattern 2 — `prod-direct-with-git`

Single environment (production), git as the safety net. No staging.

### When to use

- Small marketing sites with low publish frequency
- Internal tools where downtime is annoying but not catastrophic
- Solo developer projects
- No budget for a staging environment

### Environments

- **Local** — WP Local
- **Production** — live site

### Branch model

- `main` → production
- Feature branches → squash-merge into `main`

### Workflow

```
Local dev
   ↓
Commit + push to main
   ↓
GHA: .github/workflows/production.yml fires
   ↓
[BACKUP ACKNOWLEDGEMENT PROMPT]
   ↓
SSH-deploy to production  →  cache flush + smoke test
```

The workflow YAML is the same shape as the staging one above, deploying to
the `PRODUCTION_*` secrets.

### Database & backup

- **Database:** `single-env` — content lives on production; `sync-from-prod.sh`
  refreshes local; the DB never flows local → production via the skill. See
  **`database-strategies.md`**.
- **Backup:** every push to `main` triggers the production deploy, whose first
  step is the backup-acknowledgement gate. For day-to-day pushes where you
  don't want to type the acknowledgement every time, the common compromise is
  host-automatic backups + a documented `host-automatic` strategy in
  `.claude/ci-cd.md`. See **`backup-strategies.md`**.

---

## Pattern 3 — `prod-direct-no-ci`

No CI/CD. `rsync` from local to production on demand. Lowest overhead, most
dangerous.

### When to use

- Tiniest sites, solo developer, no team
- Throwaway projects, prototypes, demos
- You really don't want to set up GitHub Actions

### Environments

- **Local** — WP Local
- **Production** — live site

### Branch model

- `main` only (tags optional but recommended as known-good markers)

### Workflow

```
Local dev  →  Commit  →  [BACKUP ACKNOWLEDGEMENT PROMPT]
   ↓
bash scripts/deploy-to-prod.sh {slug}
   ↓
rsync over SSH to production theme folder  →  ssh prod 'wp cache flush'  →  smoke test
```

The deploy script's core:

```bash
rsync -avz --delete \
  --exclude='.git' --exclude='node_modules' --exclude='.claude' --exclude='.env' \
  ./ "$PROD_HOST:$PROD_THEME_PATH"
```

(Built from the per-project `.claude/ci-cd.md`.)

### Database & backup

- **Database:** `single-env`, same as Pattern 2. See **`database-strategies.md`**.
- **Backup:** every `deploy-to-prod.sh` run prints the acknowledgement prompt
  and refuses without it. See **`backup-strategies.md`**.

---

## Per-project `.claude/ci-cd.md` contract

Every project carries a `ci-cd.md` in its `.claude/` folder declaring the
pattern, environments, database + backup strategy, a permissions matrix, the
exact deploy commands, pre/post-deploy hooks, and known gotchas. The setup
script scaffolds it from `templates/ci-cd.template.md`, substituting values
from the per-project JSON. The developer edits it freely afterward — it's
project knowledge, committed to git. See the template for the full shape.

## How the rest of the skill consumes this

When a deploy is requested:

1. Read `~/.config/norml-wp-developer/projects/{slug}.json` for the theme path.
2. Read `{theme_root}/.claude/ci-cd.md` for the pattern + commands.
3. Run the pattern's pre-deploy hooks + the pre-deploy QA gate (`../qa-gates.md`).
4. Print the backup-acknowledgement prompt for production deploys (`backup-strategies.md`).
5. Run the deploy commands.
6. Run the post-deploy hooks + the post-deploy QA gate (`../qa-gates.md`).
7. Log `[DEPLOY-STAGING]` or `[DEPLOY-PROD]` to `{theme_root}/.claude/changelog/daily.md`.

If `ci-cd.md` is missing → hard-stop; tell the user to run setup / init.

## Switching patterns later

The setup script's "reconfigure CI/CD" option:

1. Backs up the current `.claude/ci-cd.md` to `.claude/ci-cd.{date}.bak.md`
2. Re-asks the pattern questions
3. Writes the new `ci-cd.md`
4. Updates / removes / adds `.github/workflows/*.yml` to match
5. Updates the per-project JSON

The git history of `ci-cd.md` shows the evolution.

## Cross-references

- `database-strategies.md` — the database / content handling for each pattern
- `backup-strategies.md` — backup providers, verification, restore, acknowledgement tiers
- `../qa-gates.md` — the pre-merge / pre-deploy / post-deploy checkpoints
- `../safety-rules.md` — the Safe / Confirm / Confirm+backup buckets
- `../git-workflow.md` — branch / commit / tag mechanics
