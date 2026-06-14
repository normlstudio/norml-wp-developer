#!/usr/bin/env bash
# Deploy the theme to staging via rsync over SSH.
# No backup-acknowledgement gate — staging is intentionally low-stakes.
#
# Usage:
#   bash deploy-to-staging.sh <project-slug>

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
SSH_ALIAS="$(parse .staging.ssh_alias)"
THEME_PATH="$(parse .staging.theme_path)"
WP_PATH="$(parse .staging.wp_path)"
STAGING_URL="$(parse .staging.url)"

if [[ -z "$SSH_ALIAS" || "$SSH_ALIAS" == "null" ]]; then
  echo "ERROR: no staging environment configured for $SLUG." >&2
  echo "Re-run setup with staging enabled, or use deploy-to-prod.sh instead." >&2
  exit 1
fi

cd "$THEME_ROOT"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

# Build + composer install (same as prod)
if [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
  bold "Building..."
  npm run build
fi
if [[ -f composer.json ]] && command -v composer >/dev/null 2>&1; then
  bold "Composer install (no-dev)..."
  composer install --no-dev --optimize-autoloader --no-interaction
fi

bold "Rsyncing to staging..."
rsync -avz --delete \
  --exclude='.git' --exclude='.github' --exclude='.claude' \
  --exclude='node_modules' --exclude='.env' --exclude='.env.*' \
  --exclude='.DS_Store' --exclude='Thumbs.db' --exclude='*.log' \
  ./ "$SSH_ALIAS:$THEME_PATH/"

bold "Post-deploy..."
ssh "$SSH_ALIAS" "cd '$WP_PATH' && wp cache flush 2>&1 || true"
if [[ -f composer.json ]] && grep -q '"roots/acorn"' composer.json 2>/dev/null; then
  ssh "$SSH_ALIAS" "cd '$WP_PATH' && wp acorn view:cache 2>&1 || true"
fi

bold "Smoke test..."
curl -sfL -o /dev/null -w "  HTTP %{http_code} from %{url_effective}\n" "$STAGING_URL/" || true

# Log
CHANGELOG="$THEME_ROOT/.claude/changelog/daily.md"
if [[ -f "$CHANGELOG" ]]; then
  TODAY=$(date '+%Y-%m-%d')
  TIME=$(date '+%H:%M')
  python3 - "$CHANGELOG" "$TODAY" "$TIME" <<'PYEOF'
import sys, re, pathlib
path, today, time = sys.argv[1], sys.argv[2], sys.argv[3]
line = f"- {time} — [DEPLOY-STAGING] Theme rsync'd to staging."
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
PYEOF
fi

echo
bold "Done."
