#!/usr/bin/env bash
# norml-wp-developer — per-project setup on macOS.
#
# Orchestrates the full onboarding flow described in onboarding.md:
# project slug + URLs, local env detection, git init + remote, SSH
# credentials, CI/CD pattern selection, .claude/ scaffold, optional
# first scrape.
#
# Run from inside the theme folder (the folder containing style.css
# with the Theme Name header and functions.php).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/norml-wp-developer"
PROJECTS_DIR="$CONFIG_DIR/projects"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '  %s\n' "$*"; }
warn()  { printf '\033[33m  %s\033[0m\n' "$*"; }
err()   { printf '\033[31m  %s\033[0m\n' "$*" >&2; }

ask() {
  local prompt="$1" default="${2:-}" val
  if [[ -n "$default" ]]; then
    read -rp "$prompt [$default]: " val
    printf '%s' "${val:-$default}"
  else
    read -rp "$prompt: " val
    printf '%s' "$val"
  fi
}

confirm() {
  local prompt="$1" val
  read -rp "$prompt (y/N): " val
  [[ "$val" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# ---- Banner --------------------------------------------------------------

bold "norml-wp-developer — per-project setup (macOS)"
echo
echo "This walks through a one-time ~30-minute setup for one WordPress"
echo "project. It:"
info "1. Captures project basics (slug, URL, mode)"
info "2. Detects your local WP environment"
info "3. Initializes git + wires a remote (GitHub by default)"
info "4. Captures SSH details for production (and optionally staging)"
info "5. Captures any SSH passphrase via macOS dialog -> Keychain"
info "6. Lets you pick a CI/CD pattern (full pipeline / prod-direct / no-CI)"
info "7. Scaffolds .claude/ inside this theme repo"
info "8. (Optional) runs the first architecture scrape over SSH"
echo
echo "Run me from inside the theme folder (the folder with style.css)."
echo
read -rp "Press Enter to continue, Ctrl-C to cancel..."

# ---- Verify we're in a theme folder --------------------------------------

THEME_ROOT="$(pwd)"
if [[ ! -f "$THEME_ROOT/style.css" ]]; then
  err "Not in a theme folder. Expected style.css in $THEME_ROOT."
  err "cd into the theme folder (contains style.css and functions.php) and re-run."
  exit 1
fi

THEME_NAME=$(grep -E '^[[:space:]]*Theme Name:' style.css | head -1 | sed -E 's/^[^:]*:[[:space:]]*//' | sed -E 's/[[:space:]]*$//' || true)
if [[ -z "$THEME_NAME" ]]; then
  warn "style.css has no 'Theme Name:' header. Continuing anyway."
  THEME_NAME="(unnamed theme)"
fi

info "Detected theme: $THEME_NAME"
info "Theme root:     $THEME_ROOT"

mkdir -p "$PROJECTS_DIR"
chmod 700 "$CONFIG_DIR"

# ---- Project basics ------------------------------------------------------

echo
bold "Project basics"

DEFAULT_SLUG=$(basename "$THEME_ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
SLUG="$(ask "Project slug (kebab-case)" "$DEFAULT_SLUG")"
if [[ ! "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  err "Slug must be kebab-case (lowercase letters / digits / hyphens)."
  exit 1
fi

CONFIG_FILE="$PROJECTS_DIR/${SLUG}.json"
if [[ -f "$CONFIG_FILE" ]]; then
  warn "$CONFIG_FILE already exists. Re-running setup will overwrite it."
  if ! confirm "Continue?"; then
    exit 1
  fi
fi

PROD_URL="$(ask "Production URL")"
PROD_URL="${PROD_URL%/}"
if [[ ! "$PROD_URL" =~ ^https?:// ]]; then
  err "URL must start with http:// or https://"
  exit 1
fi

echo
echo "Project mode — picks which dev conventions apply:"
echo "  sage      — new project, Norml-authored, Roots Sage stack"
echo "  inherited — non-Sage theme handed to us by client / another agency"
MODE="$(ask "Project mode (sage / inherited)" "inherited")"
if [[ "$MODE" != "sage" && "$MODE" != "inherited" ]]; then
  err "Mode must be 'sage' or 'inherited'."
  exit 1
fi

# ---- Local environment detection -----------------------------------------

echo
bold "Local environment"

LOCAL_TOOL="unknown"
LOCAL_URL=""

if [[ "$THEME_ROOT" == */Local\ Sites/* ]]; then
  LOCAL_TOOL="wp-local"
  LOCAL_SITE_DIR=$(echo "$THEME_ROOT" | sed -E 's|(.*/Local Sites/[^/]+).*|\1|')
  info "Detected WP Local at: $LOCAL_SITE_DIR"
  LOCAL_URL="$(ask "Local URL (from WP Local UI)" "https://${SLUG}.local")"
elif [[ -f "$THEME_ROOT/../../../../.ddev/config.yaml" ]] || [[ -f "$THEME_ROOT/.ddev/config.yaml" ]]; then
  LOCAL_TOOL="ddev"
  info "Detected DDEV project."
  LOCAL_URL="$(ask "Local URL (from ddev describe)")"
elif [[ -f "$THEME_ROOT/../../../../.lando.yml" ]] || [[ -f "$THEME_ROOT/.lando.yml" ]]; then
  LOCAL_TOOL="lando"
  info "Detected Lando project."
  LOCAL_URL="$(ask "Local URL (from lando info)")"
else
  warn "No known local-WP tool detected (looked for WP Local / DDEV / Lando)."
  info "That's OK — you can fill in details manually."
  LOCAL_TOOL="$(ask "Local tool (wp-local/ddev/lando/valet/manual)" "manual")"
  LOCAL_URL="$(ask "Local URL")"
fi

# ---- Git setup -----------------------------------------------------------

echo
bold "Git"

if [[ -d "$THEME_ROOT/.git" ]]; then
  info "This folder is already a git repo."
  CURRENT_BRANCH=$(git -C "$THEME_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(no commits yet)")
  info "Current branch: $CURRENT_BRANCH"
else
  if confirm "Initialize git here?"; then
    git -C "$THEME_ROOT" init -b main
    info "Initialized empty git repo."

    # Scaffold .gitignore
    cat > "$THEME_ROOT/.gitignore" <<'GITIGN'
# Build artifacts
public/
dist/
build/

# Dependencies
node_modules/
vendor/

# Env files
.env
.env.local
.env.*.local

# OS junk
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/

# Logs
*.log
npm-debug.log*
yarn-debug.log*

# Optional: cache directories
.cache/
.parcel-cache/
GITIGN
    info "Wrote .gitignore"

    # Don't auto-commit yet — let the user inspect first.
    info "(Did not run first commit — you can review the staging area, then commit yourself.)"
  fi
fi

# ---- Remote --------------------------------------------------------------

GIT_REMOTE_URL=""
GIT_PROVIDER="github"
if [[ -d "$THEME_ROOT/.git" ]]; then
  EXISTING_REMOTE=$(git -C "$THEME_ROOT" remote get-url origin 2>/dev/null || true)
  if [[ -n "$EXISTING_REMOTE" ]]; then
    GIT_REMOTE_URL="$EXISTING_REMOTE"
    info "Existing remote: $GIT_REMOTE_URL"
    if echo "$GIT_REMOTE_URL" | grep -q bitbucket; then
      GIT_PROVIDER="bitbucket"
    elif echo "$GIT_REMOTE_URL" | grep -q gitlab; then
      GIT_PROVIDER="gitlab"
    fi
  else
    GIT_PROVIDER="$(ask "Git provider (github/bitbucket/gitlab)" "github")"
    GIT_REMOTE_URL="$(ask "Remote URL (or leave blank to set later)")"
    if [[ -n "$GIT_REMOTE_URL" ]]; then
      git -C "$THEME_ROOT" remote add origin "$GIT_REMOTE_URL" 2>/dev/null || \
        git -C "$THEME_ROOT" remote set-url origin "$GIT_REMOTE_URL"
      info "Configured origin → $GIT_REMOTE_URL"
    fi
  fi
fi

# ---- SSH details — production --------------------------------------------

echo
bold "SSH to production"

PROD_SSH_HOST="$(ask "Production SSH host")"
PROD_SSH_PORT="$(ask "Production SSH port" "22")"
PROD_SSH_USER="$(ask "Production SSH username")"

DEFAULT_SSH_KEY="$HOME/.ssh/id_ed25519"
if [[ ! -f "$DEFAULT_SSH_KEY" ]]; then
  DEFAULT_SSH_KEY="$HOME/.ssh/norml-wp-dev-$SLUG"
fi
PROD_SSH_KEY="$(ask "Production SSH key path" "$DEFAULT_SSH_KEY")"
PROD_SSH_KEY="${PROD_SSH_KEY/#\~/$HOME}"

if [[ ! -f "$PROD_SSH_KEY" ]]; then
  warn "$PROD_SSH_KEY does not exist."
  if confirm "Generate a new ed25519 key at $PROD_SSH_KEY?"; then
    mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$PROD_SSH_KEY" -C "norml-wp-dev-$SLUG"
    echo
    bold "Add this public key to your production server"
    echo "---------- BEGIN PUBLIC KEY ----------"
    cat "${PROD_SSH_KEY}.pub"
    echo "----------  END PUBLIC KEY  ----------"
    echo
    read -rp "Press Enter once the public key is added to your hosting panel / ~/.ssh/authorized_keys..."
  else
    err "Need an SSH key to continue. Aborting."
    exit 1
  fi
fi

PROD_WP_PATH="$(ask "WordPress path on the production server (absolute, e.g. /var/www/html)")"
PROD_THEME_PATH_DEFAULT="${PROD_WP_PATH}/wp-content/themes/$(basename "$THEME_ROOT")"
PROD_THEME_PATH="$(ask "Theme path on the production server" "$PROD_THEME_PATH_DEFAULT")"

# Write ~/.ssh/config alias
SSH_ALIAS="norml-wp-dev-${SLUG}"
SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
touch "$SSH_CONFIG"; chmod 600 "$SSH_CONFIG"

if grep -q "^Host $SSH_ALIAS$" "$SSH_CONFIG" 2>/dev/null; then
  warn "SSH alias '$SSH_ALIAS' already in ~/.ssh/config. Skipping (edit it manually if needed)."
else
  cat >> "$SSH_CONFIG" <<EOF

# Added by norml-wp-developer setup for project: $SLUG
Host $SSH_ALIAS
  HostName $PROD_SSH_HOST
  Port $PROD_SSH_PORT
  User $PROD_SSH_USER
  IdentityFile $PROD_SSH_KEY
  AddKeysToAgent yes
  UseKeychain yes
EOF
  info "Wrote SSH alias '$SSH_ALIAS' to $SSH_CONFIG"
fi

# Add key to ssh-agent + Keychain
if pgrep -x ssh-agent >/dev/null 2>&1; then :; else
  eval "$(ssh-agent -s)" >/dev/null
fi
if ssh-add --apple-use-keychain "$PROD_SSH_KEY" 2>/dev/null; then
  info "Added SSH key to ssh-agent (passphrase, if any, captured in Keychain)."
else
  warn "Could not auto-add to ssh-agent. You may need to:"
  warn "  ssh-add --apple-use-keychain $PROD_SSH_KEY"
fi

# ---- SSH details — staging (optional) ------------------------------------

STAGING_CONFIGURED="false"
echo
if confirm "Does this project have a staging environment?"; then
  STAGING_CONFIGURED="true"
  bold "SSH to staging"
  STAGING_URL="$(ask "Staging URL")"
  STAGING_URL="${STAGING_URL%/}"
  STAGING_SSH_HOST="$(ask "Staging SSH host" "$PROD_SSH_HOST")"
  STAGING_SSH_PORT="$(ask "Staging SSH port" "$PROD_SSH_PORT")"
  STAGING_SSH_USER="$(ask "Staging SSH username" "$PROD_SSH_USER")"
  STAGING_SSH_KEY="$(ask "Staging SSH key path" "$PROD_SSH_KEY")"
  STAGING_SSH_KEY="${STAGING_SSH_KEY/#\~/$HOME}"
  STAGING_WP_PATH="$(ask "WordPress path on staging" "$PROD_WP_PATH")"
  STAGING_THEME_PATH_DEFAULT="${STAGING_WP_PATH}/wp-content/themes/$(basename "$THEME_ROOT")"
  STAGING_THEME_PATH="$(ask "Theme path on staging" "$STAGING_THEME_PATH_DEFAULT")"

  STAGING_SSH_ALIAS="norml-wp-dev-${SLUG}-staging"
  if grep -q "^Host $STAGING_SSH_ALIAS$" "$SSH_CONFIG" 2>/dev/null; then
    warn "SSH alias '$STAGING_SSH_ALIAS' already in ~/.ssh/config. Skipping."
  else
    cat >> "$SSH_CONFIG" <<EOF

# Added by norml-wp-developer setup for project: $SLUG (staging)
Host $STAGING_SSH_ALIAS
  HostName $STAGING_SSH_HOST
  Port $STAGING_SSH_PORT
  User $STAGING_SSH_USER
  IdentityFile $STAGING_SSH_KEY
  AddKeysToAgent yes
  UseKeychain yes
EOF
    info "Wrote SSH alias '$STAGING_SSH_ALIAS' to $SSH_CONFIG"
  fi
fi

# ---- CI/CD pattern -------------------------------------------------------

echo
bold "CI/CD pattern"
echo "Three options:"
echo "  full-pipeline         — staging gates prod, GitHub Actions enforced"
echo "  prod-direct-with-git  — single env (prod) with git as safety net"
echo "  prod-direct-no-ci     — rsync from local, no CI/CD"
echo
PATTERN_DEFAULT="full-pipeline"
[[ "$STAGING_CONFIGURED" != "true" ]] && PATTERN_DEFAULT="prod-direct-with-git"
PATTERN="$(ask "Pattern (full-pipeline / prod-direct-with-git / prod-direct-no-ci)" "$PATTERN_DEFAULT")"
case "$PATTERN" in
  full-pipeline|prod-direct-with-git|prod-direct-no-ci) ;;
  *) err "Unknown pattern: $PATTERN"; exit 1 ;;
esac

# ---- Backup strategy -----------------------------------------------------

echo
bold "Backup strategy"
echo "  host-automatic       — host has automatic backups (Kinsta, WPE, etc.)"
echo "  manual-before-deploy — you take a backup before each prod write"
echo "  none-warned          — no backups; every prod write extra-warns"
BACKUP="$(ask "Backup strategy (host-automatic / manual-before-deploy / none-warned)" "host-automatic")"

# ---- Write per-project config JSON ---------------------------------------

cat > "$CONFIG_FILE" <<EOF
{
  "slug": "$SLUG",
  "theme_name": "$THEME_NAME",
  "theme_root": "$THEME_ROOT",
  "mode": "$MODE",
  "local": {
    "tool": "$LOCAL_TOOL",
    "url": "$LOCAL_URL"
  },
  "production": {
    "url": "$PROD_URL",
    "ssh_alias": "$SSH_ALIAS",
    "ssh_host": "$PROD_SSH_HOST",
    "ssh_port": $PROD_SSH_PORT,
    "ssh_user": "$PROD_SSH_USER",
    "ssh_key": "$PROD_SSH_KEY",
    "wp_path": "$PROD_WP_PATH",
    "theme_path": "$PROD_THEME_PATH"
  },$(if [[ "$STAGING_CONFIGURED" == "true" ]]; then cat <<EOFS

  "staging": {
    "url": "$STAGING_URL",
    "ssh_alias": "$STAGING_SSH_ALIAS",
    "ssh_host": "$STAGING_SSH_HOST",
    "ssh_port": $STAGING_SSH_PORT,
    "ssh_user": "$STAGING_SSH_USER",
    "ssh_key": "$STAGING_SSH_KEY",
    "wp_path": "$STAGING_WP_PATH",
    "theme_path": "$STAGING_THEME_PATH"
  },
EOFS
fi)
  "git": {
    "provider": "$GIT_PROVIDER",
    "remote_url": "$GIT_REMOTE_URL"
  },
  "ci_cd": {
    "pattern": "$PATTERN",
    "backup_strategy": "$BACKUP"
  },
  "created_at": "$(date -u +%FT%TZ)",
  "version": 1
}
EOF
chmod 600 "$CONFIG_FILE"
info "Wrote $CONFIG_FILE"

# ---- Scaffold .claude/ inside the theme repo -----------------------------

echo
bold "Scaffolding .claude/ inside the theme repo..."
bash "$SCRIPT_DIR/init-claude.sh" "$SLUG"

# ---- Verify SSH ----------------------------------------------------------

echo
bold "Testing SSH..."
bash "$SCRIPT_DIR/test-ssh.sh" "$SLUG" production || warn "Production SSH test failed — see error above."
if [[ "$STAGING_CONFIGURED" == "true" ]]; then
  bash "$SCRIPT_DIR/test-ssh.sh" "$SLUG" staging || warn "Staging SSH test failed."
fi

# ---- Done ----------------------------------------------------------------

echo
bold "Setup complete."
info "Config file:     $CONFIG_FILE"
info "Theme root:      $THEME_ROOT"
info "Project mode:    $MODE"
info "CI/CD pattern:   $PATTERN"
info "Backup strategy: $BACKUP"
info "SSH alias:       $SSH_ALIAS"
[[ "$STAGING_CONFIGURED" == "true" ]] && info "Staging alias:   $STAGING_SSH_ALIAS"
echo
echo "Next steps:"
info "  • Review the scaffolded .claude/ folder and commit it to git."
info "  • If you picked full-pipeline, configure the GitHub Actions secrets"
info "    listed in .claude/ci-cd.md."
info "  • Ask Claude: 'pull production database to my local' (optional)."
info "  • Start building: 'add a hero block to this theme.'"
