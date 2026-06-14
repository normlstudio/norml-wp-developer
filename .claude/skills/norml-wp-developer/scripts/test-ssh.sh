#!/usr/bin/env bash
# Verify the SSH alias for a configured project works. Read-only.
#
# Usage:
#   bash test-ssh.sh <project-slug>           # tests production
#   bash test-ssh.sh <project-slug> staging   # tests staging

set -euo pipefail

CONFIG_DIR="$HOME/.config/norml-wp-developer/projects"
SLUG="${1:-}"
ENV="${2:-production}"

if [[ -z "$SLUG" ]]; then
  echo "ERROR: usage: $0 <project-slug> [production|staging]" >&2
  exit 2
fi

CONFIG_FILE="$CONFIG_DIR/${SLUG}.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE missing. Run setup-macos.sh first." >&2
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

SITE="$(parse .slug)"
URL="$(parse .${ENV}.url)"
ALIAS="$(parse .${ENV}.ssh_alias)"
WP_PATH="$(parse .${ENV}.wp_path)"

if [[ -z "$ALIAS" || "$ALIAS" == "null" ]]; then
  echo "ERROR: no ssh_alias configured for ${ENV} on ${SITE}." >&2
  echo "Re-run setup or pass a different environment." >&2
  exit 1
fi

echo "Project:  $SITE"
echo "Env:      $ENV"
echo "URL:      $URL"
echo "Alias:    $ALIAS"
echo "WP path:  $WP_PATH"
echo

echo "1. SSH handshake..."
if ssh -o BatchMode=yes -o ConnectTimeout=10 "$ALIAS" "echo ok" >/dev/null 2>&1; then
  echo "   OK"
else
  echo "   FAIL — check ~/.ssh/config alias '$ALIAS'." >&2
  echo "   Try: ssh -v $ALIAS" >&2
  exit 1
fi

echo "2. WP-CLI on remote..."
if WP_INFO=$(ssh "$ALIAS" "cd '$WP_PATH' && wp --info 2>&1" 2>&1); then
  echo "$WP_INFO" | head -8
  echo
  echo "OK — SSH and WP-CLI both working."
else
  echo "   FAIL — wp-cli unavailable or wrong path." >&2
  echo "$WP_INFO" >&2
  exit 1
fi
