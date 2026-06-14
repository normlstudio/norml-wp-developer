#!/usr/bin/env bash
# Deploy the theme to production via rsync over SSH.
# Gated by the backup-acknowledgement prompt.
#
# Usage:
#   bash deploy-to-prod.sh <project-slug>
#
# Run from anywhere — the script reads ~/.config/norml-wp-developer/
# projects/{slug}.json to know where the theme lives and where to
# rsync to.

set -euo pipefail

CONFIG_DIR="$HOME/.config/norml-wp-developer/projects"
SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "ERROR: usage: $0 <project-slug>" >&2
  exit 2
fi

CONFIG_FILE="$CONFIG_DIR/${SLUG}.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE missing." >&2
  exit 1
fi

parse() {
  if command -v jq >/dev/null 2>&1; then
    jq -r "$1" "$CONFIG_FILE"
  else
    python3 -c "
import json
d = json.load(open('$CONFIG_FILE'))
keys = '$1'.lstrip('.').split('.')
for k in keys:
    if isinstance(d, dict):
        d = d.get(k, '')
    else:
        d = ''
        break
print(d if d is not None else '')
"
  fi
}

THEME_ROOT="$(parse .theme_root)"
SSH_ALIAS="$(parse .production.ssh_alias)"
THEME_PATH="$(parse .production.theme_path)"
WP_PATH="$(parse .production.wp_path)"
PROD_URL="$(parse .production.url)"
BACKUP_STRATEGY="$(parse .ci_cd.backup_strategy)"

if [[ -z "$THEME_ROOT" || -z "$SSH_ALIAS" || -z "$THEME_PATH" ]]; then
  echo "ERROR: project config is incomplete. Re-run setup." >&2
  exit 1
fi

cd "$THEME_ROOT"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }

# ---- Pre-deploy: build assets if a build step exists ---------------------

if [[ -f package.json ]]; then
  echo
  bold "Running build..."
  if command -v npm >/dev/null 2>&1; then
    npm run build || { warn "Build failed — aborting deploy."; exit 1; }
  else
    warn "package.json exists but npm not on PATH. Skipping build."
  fi
fi

# ---- Pre-deploy: Composer install (no-dev) -------------------------------

if [[ -f composer.json ]]; then
  echo
  bold "Composer install (no-dev)..."
  if command -v composer >/dev/null 2>&1; then
    composer install --no-dev --optimize-autoloader --no-interaction
  else
    warn "composer.json exists but composer not on PATH. Skipping."
  fi
fi

# ---- Backup acknowledgement gate -----------------------------------------

echo
bold "═══════════════════════════════════════════════════════════════"
bold " PRODUCTION DEPLOY — BACKUP ACKNOWLEDGEMENT REQUIRED"
bold "═══════════════════════════════════════════════════════════════"
echo
echo "About to rsync:"
echo "  FROM:  $THEME_ROOT/"
echo "  TO:    $SSH_ALIAS:$THEME_PATH/"
echo "  URL:   $PROD_URL"
echo
case "$BACKUP_STRATEGY" in
  host-automatic)
    echo "Backup strategy (from .claude/ci-cd.md): host-automatic"
    echo "Verify your host's backup panel shows a recent snapshot."
    ;;
  manual-before-deploy)
    echo "Backup strategy: manual-before-deploy"
    echo "You should have taken a backup just now."
    ;;
  none-warned)
    warn "Backup strategy: NONE. This project has no backups configured."
    warn "If something breaks, the data is gone."
    ;;
esac
echo
echo "Type one of the following to proceed:"
echo "  • I have a backup from {date}     (you took a manual backup)"
echo "  • host backups verified            (host backups confirmed in panel)"
echo "  • abort                            (default — do not deploy)"
echo
read -rp "Your answer: " ACK
ACK_LOWER=$(echo "$ACK" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//')

PROCEED="false"
case "$ACK_LOWER" in
  "i have a backup from "*) PROCEED="true";;
  "host backups verified")   PROCEED="true";;
  *) PROCEED="false";;
esac

if [[ "$PROCEED" != "true" ]]; then
  echo
  warn "Aborted. No deploy performed."
  exit 1
fi

# ---- The deploy ----------------------------------------------------------

echo
bold "Rsyncing to production..."

RSYNC_EXCLUDES=(
  --exclude='.git'
  --exclude='.github'
  --exclude='.claude'
  --exclude='node_modules'
  --exclude='.env'
  --exclude='.env.*'
  --exclude='.DS_Store'
  --exclude='Thumbs.db'
  --exclude='*.log'
)

# --delete makes destination match source. Be careful with this — but on
# the theme folder it's correct: removed files locally should be removed
# on the server too.
rsync -avz --delete "${RSYNC_EXCLUDES[@]}" \
  ./ "$SSH_ALIAS:$THEME_PATH/"

# ---- Post-deploy hooks ---------------------------------------------------

echo
bold "Post-deploy hooks..."

# Cache flush (always safe)
ssh "$SSH_ALIAS" "cd '$WP_PATH' && wp cache flush 2>&1 || true"

# Acorn view cache (Sage projects)
if [[ -f composer.json ]] && grep -q '"roots/acorn"' composer.json 2>/dev/null; then
  echo "  Sage project detected — clearing Acorn view cache..."
  ssh "$SSH_ALIAS" "cd '$WP_PATH' && wp acorn view:cache 2>&1 || true"
fi

# Smoke test
echo
bold "Smoke testing..."
if curl -sfL -o /dev/null -w "  HTTP %{http_code} from %{url_effective}\n" "$PROD_URL/"; then
  echo "  OK"
else
  warn "Smoke test failed — site may be down. Check manually."
fi

# ---- Log to .claude/changelog/daily.md -----------------------------------

CHANGELOG="$THEME_ROOT/.claude/changelog/daily.md"
if [[ -f "$CHANGELOG" ]]; then
  TODAY=$(date '+%Y-%m-%d')
  TIME=$(date '+%H:%M')
  python3 - "$CHANGELOG" "$TODAY" "$TIME" "$ACK" <<'PYEOF'
import sys, re, pathlib
path, today, time, ack = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
line = f"- {time} — [DEPLOY-PROD] Production deploy via rsync. Backup ack: \"{ack}\"."
p = pathlib.Path(path)
content = p.read_text()
heading = re.compile(r'^## ' + re.escape(today) + r'.*$', re.MULTILINE)
m = heading.search(content)
if m:
    insert_at = m.end()
    while insert_at < len(content) and content[insert_at] == '\n':
        insert_at += 1
    content = content[:insert_at] + line + '\n' + content[insert_at:]
else:
    first = re.search(r'^## ', content, re.MULTILINE)
    new = f"## {today}\n\n{line}\n\n"
    content = (content[:first.start()] + new + content[first.start():]) if first else (content.rstrip() + '\n\n' + new)
p.write_text(content)
print(f"Logged [DEPLOY-PROD] to {path}")
PYEOF
fi

echo
bold "Done."
