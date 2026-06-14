#!/usr/bin/env bash
# norml-wp-developer — pop a native macOS dialog to capture a secret
# (SSH passphrase or GitHub Personal Access Token), then store it in
# Keychain.
#
# Designed to be called from Claude (via the Bash tool) or from
# setup-macos.sh. The user never has to type the secret into a terminal
# prompt — a normal macOS dialog window opens in front of them.
#
# Usage:
#   bash prompt-secret-macos.sh <kind> <slug>
#
# Where <kind> is:
#   ssh-passphrase   — SSH key passphrase (for ssh-add to Keychain)
#   github-pat       — GitHub Personal Access Token
#
# Exit codes:
#   0  stored OK
#   1  user cancelled the dialog or pasted an empty string
#   2  bad arguments

set -euo pipefail

KIND="${1:-}"
SLUG="${2:-}"

if [[ -z "$KIND" || -z "$SLUG" ]]; then
  echo "ERROR: usage: $0 <kind> <slug>" >&2
  echo "  kind: ssh-passphrase | github-pat" >&2
  exit 2
fi

case "$KIND" in
  ssh-passphrase)
    KEYCHAIN_SERVICE="norml-wp-dev-${SLUG}-ssh-passphrase"
    DIALOG_TITLE="norml-wp-developer — SSH passphrase for ${SLUG}"
    DIALOG_BODY="Paste the passphrase for your SSH key.

It will be stored in macOS Keychain so ssh-add can use it silently. You won't be prompted again for this key on this machine."
    ;;
  github-pat)
    KEYCHAIN_SERVICE="norml-wp-dev-${SLUG}-github-pat"
    DIALOG_TITLE="norml-wp-developer — GitHub PAT for ${SLUG}"
    DIALOG_BODY="Paste your GitHub Personal Access Token.

It will be stored in macOS Keychain. Make sure the token has 'repo' scope (and 'workflow' if you'll use Actions)."
    ;;
  *)
    echo "ERROR: unknown kind '$KIND'. Use ssh-passphrase or github-pat." >&2
    exit 2
    ;;
esac

# Pop the dialog with hidden input.
DIALOG_OUT=$(osascript <<APPLESCRIPT 2>/dev/null || true
on run
  try
    set theResult to display dialog "$DIALOG_BODY" ¬
      default answer "" ¬
      with hidden answer ¬
      with title "$DIALOG_TITLE" ¬
      buttons {"Cancel", "Store"} ¬
      default button "Store"
    return text returned of theResult
  on error
    return "__WPDEV_CANCELLED__"
  end try
end run
APPLESCRIPT
)

if [[ -z "$DIALOG_OUT" || "$DIALOG_OUT" == "__WPDEV_CANCELLED__" ]]; then
  echo "Cancelled." >&2
  exit 1
fi

# Strip trailing whitespace only (passphrases may include spaces
# intentionally; PATs definitely don't).
SECRET=$(printf '%s' "$DIALOG_OUT" | sed 's/[[:space:]]*$//')
DIALOG_OUT=""

if [[ -z "$SECRET" ]]; then
  echo "Empty secret. Aborting." >&2
  exit 1
fi

# Replace any prior entry under the same service.
security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 || true

security add-generic-password \
  -s "$KEYCHAIN_SERVICE" \
  -a "norml-wp-developer" \
  -l "norml-wp-developer: $SLUG ($KIND)" \
  -D "$KIND" \
  -w "$SECRET" >/dev/null

SECRET=""

echo "Stored ${KIND} under Keychain service '${KEYCHAIN_SERVICE}'."
