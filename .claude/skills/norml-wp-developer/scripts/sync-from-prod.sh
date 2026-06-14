#!/usr/bin/env bash
# Pull the production database and (optionally) uploads down to local.
# One-way: production -> local. Never the reverse.
#
# Usage:
#   bash sync-from-prod.sh <project-slug> [--no-uploads]

set -euo pipefail

CONFIG_DIR="$HOME/.config/norml-wp-developer/projects"
SLUG="${1:-}"
NO_UPLOADS="false"
if [[ "${2:-}" == "--no-uploads" ]]; then NO_UPLOADS="true"; fi

if [[ -z "$SLUG" ]]; then
  echo "ERROR: usage: $0 <project-slug> [--no-uploads]" >&2
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
PROD_SSH="$(parse .production.ssh_alias)"
PROD_WP="$(parse .production.wp_path)"
PROD_URL="$(parse .production.url)"
LOCAL_URL="$(parse .local.url)"
LOCAL_TOOL="$(parse .local.tool)"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }

# Find the local WP root from the theme root.
LOCAL_WP_ROOT="$(cd "$THEME_ROOT/../../.." && pwd)"
if [[ ! -f "$LOCAL_WP_ROOT/wp-config.php" ]]; then
  warn "Could not infer local WP root from theme path."
  warn "Expected wp-config.php at: $LOCAL_WP_ROOT/wp-config.php"
  exit 1
fi

echo
bold "Pull production data → local"
echo "  Production: $PROD_URL  (alias: $PROD_SSH)"
echo "  Local:      $LOCAL_URL  ($LOCAL_TOOL)"
echo "  Local WP:   $LOCAL_WP_ROOT"
echo

read -rp "This will REPLACE your local database with production. Proceed? (y/N): " GO
[[ "$GO" =~ ^[Yy] ]] || { warn "Aborted."; exit 1; }

# ---- DB export on production --------------------------------------------

REMOTE_DUMP="/tmp/norml-wp-dev-${SLUG}-$(date +%s).sql"
echo
bold "Exporting production DB..."
ssh "$PROD_SSH" "cd '$PROD_WP' && wp db export '$REMOTE_DUMP'"
echo "  Wrote $REMOTE_DUMP on production."

# ---- Pull dump down -----------------------------------------------------

LOCAL_DUMP="/tmp/norml-wp-dev-${SLUG}-$(date +%s).sql"
echo
bold "Downloading DB dump..."
rsync -avz "$PROD_SSH:$REMOTE_DUMP" "$LOCAL_DUMP"
ssh "$PROD_SSH" "rm -f '$REMOTE_DUMP'"

# ---- Import locally -----------------------------------------------------

echo
bold "Importing into local DB..."
(cd "$LOCAL_WP_ROOT" && wp db import "$LOCAL_DUMP")
rm -f "$LOCAL_DUMP"
echo "  Imported and cleaned up."

# ---- search-replace URLs -----------------------------------------------

echo
bold "Running search-replace ($PROD_URL → $LOCAL_URL)..."
PROD_NO_PROTO=$(echo "$PROD_URL" | sed 's|^https\?://||')
LOCAL_NO_PROTO=$(echo "$LOCAL_URL" | sed 's|^https\?://||')

(cd "$LOCAL_WP_ROOT" && wp search-replace "$PROD_URL" "$LOCAL_URL" --all-tables --skip-columns=guid --report-changed-only)
(cd "$LOCAL_WP_ROOT" && wp search-replace "$PROD_NO_PROTO" "$LOCAL_NO_PROTO" --all-tables --skip-columns=guid --report-changed-only)

# ---- Uploads -----------------------------------------------------------

if [[ "$NO_UPLOADS" == "true" ]]; then
  warn "Skipping uploads (--no-uploads)."
else
  echo
  bold "Pulling production uploads..."
  rsync -avz --info=progress2 \
    "$PROD_SSH:$PROD_WP/wp-content/uploads/" \
    "$LOCAL_WP_ROOT/wp-content/uploads/"
fi

# ---- Log ---------------------------------------------------------------

CHANGELOG="$THEME_ROOT/.claude/changelog/daily.md"
if [[ -f "$CHANGELOG" ]]; then
  TODAY=$(date '+%Y-%m-%d')
  TIME=$(date '+%H:%M')
  python3 - "$CHANGELOG" "$TODAY" "$TIME" "$NO_UPLOADS" <<'PYEOF'
import sys, re, pathlib
path, today, time, no_uploads = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
uploads = "without uploads" if no_uploads == "true" else "including uploads"
line = f"- {time} — [PULL-DB] Production DB pulled to local ({uploads}). search-replace done."
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
