#!/usr/bin/env bash
# Scaffold .claude/ inside the theme repo for the configured project.
# Reads the project JSON to know which slug + theme root.
#
# Usage:
#   bash init-claude.sh <project-slug>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../templates" && pwd)"
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
THEME_NAME="$(parse .theme_name)"
MODE="$(parse .mode)"
PROD_URL="$(parse .production.url)"
STAGING_URL="$(parse .staging.url)"
LOCAL_URL="$(parse .local.url)"
PATTERN="$(parse .ci_cd.pattern)"
BACKUP="$(parse .ci_cd.backup_strategy)"
REMOTE_URL="$(parse .git.remote_url)"
PROD_SSH_ALIAS="$(parse .production.ssh_alias)"
PROD_THEME_PATH="$(parse .production.theme_path)"
PROD_WP_PATH="$(parse .production.wp_path)"
STAGING_SSH_ALIAS="$(parse .staging.ssh_alias)"
STAGING_THEME_PATH="$(parse .staging.theme_path)"
STAGING_WP_PATH="$(parse .staging.wp_path)"
GENERATED_AT="$(date -u +%FT%TZ)"
CLI_STATUS="Terminal filesystem + shell available"
if [[ -d "$THEME_ROOT/.git" ]]; then LOCAL_REPO_STATUS="Git repository detected"; else LOCAL_REPO_STATUS="BLOCKED — Git repository missing"; fi
GITHUB_STATUS="Pending first architecture scan"
SSH_STATUS="Pending first architecture scan"
WPCLI_STATUS="Pending first architecture scan"
if [[ -n "$STAGING_URL" && "$STAGING_URL" != "null" ]]; then STAGING_STATUS="Configured at $STAGING_URL"; else STAGING_STATUS="Not configured"; fi
BLOCKERS="- First architecture scan pending. GitHub, SSH, and remote WP-CLI have not been verified yet."
ARCHITECTURE_SUMMARY="First architecture scan pending. Run the bundled scraper after GitHub and SSH are connected."

if [[ -z "$THEME_ROOT" || ! -d "$THEME_ROOT" ]]; then
  echo "ERROR: theme_root '$THEME_ROOT' not on disk." >&2
  exit 1
fi

cd "$THEME_ROOT"

mkdir -p .claude/changelog .claude/docs .claude/skills

# Helper: render template by substituting {{PLACEHOLDER}} variables.
render_template() {
  local tpl="$1" out="$2"
  if [[ ! -f "$tpl" ]]; then
    echo "ERROR: template missing: $tpl" >&2
    return 1
  fi
  sed \
    -e "s|{{SLUG}}|$SLUG|g" \
    -e "s|{{THEME_NAME}}|$THEME_NAME|g" \
    -e "s|{{MODE}}|$MODE|g" \
    -e "s|{{PROD_URL}}|$PROD_URL|g" \
    -e "s|{{STAGING_URL}}|$STAGING_URL|g" \
    -e "s|{{LOCAL_URL}}|$LOCAL_URL|g" \
    -e "s|{{PATTERN}}|$PATTERN|g" \
    -e "s|{{BACKUP}}|$BACKUP|g" \
    -e "s|{{REMOTE_URL}}|$REMOTE_URL|g" \
    -e "s|{{PROD_SSH_ALIAS}}|$PROD_SSH_ALIAS|g" \
    -e "s|{{PROD_THEME_PATH}}|$PROD_THEME_PATH|g" \
    -e "s|{{PROD_WP_PATH}}|$PROD_WP_PATH|g" \
    -e "s|{{STAGING_SSH_ALIAS}}|$STAGING_SSH_ALIAS|g" \
    -e "s|{{STAGING_THEME_PATH}}|$STAGING_THEME_PATH|g" \
    -e "s|{{STAGING_WP_PATH}}|$STAGING_WP_PATH|g" \
    -e "s|{{GENERATED_AT}}|$GENERATED_AT|g" \
    -e "s|{{CLI_STATUS}}|$CLI_STATUS|g" \
    -e "s|{{LOCAL_REPO_STATUS}}|$LOCAL_REPO_STATUS|g" \
    -e "s|{{GITHUB_STATUS}}|$GITHUB_STATUS|g" \
    -e "s|{{SSH_STATUS}}|$SSH_STATUS|g" \
    -e "s|{{WPCLI_STATUS}}|$WPCLI_STATUS|g" \
    -e "s|{{STAGING_STATUS}}|$STAGING_STATUS|g" \
    -e "s|{{BLOCKERS}}|$BLOCKERS|g" \
    -e "s|{{ARCHITECTURE_SUMMARY}}|$ARCHITECTURE_SUMMARY|g" \
    -e "s|{{TODAY}}|$(date '+%Y-%m-%d')|g" \
    "$tpl" > "$out"
  echo "  wrote $out"
}

# CLAUDE.md
if [[ ! -f .claude/CLAUDE.md ]]; then
  render_template "$TEMPLATES_DIR/claude-md-template.md" ".claude/CLAUDE.md"
else
  echo "  (.claude/CLAUDE.md already exists — leaving alone)"
fi

# ci-cd.md
if [[ ! -f .claude/ci-cd.md ]]; then
  render_template "$TEMPLATES_DIR/ci-cd-template.md" ".claude/ci-cd.md"
else
  echo "  (.claude/ci-cd.md already exists — leaving alone)"
fi

# Generated capability + architecture entry points. The first scan overwrites
# these pending-state files with verified evidence.
if [[ ! -f .claude/capabilities.md ]]; then
  render_template "$TEMPLATES_DIR/capabilities-template.md" ".claude/capabilities.md"
else
  echo "  (.claude/capabilities.md already exists — leaving alone)"
fi
if [[ ! -f .claude/architecture.md ]]; then
  render_template "$TEMPLATES_DIR/architecture-template.md" ".claude/architecture.md"
else
  echo "  (.claude/architecture.md already exists — leaving alone)"
fi
if [[ ! -f .claude/docs/README.md ]]; then
  render_template "$TEMPLATES_DIR/docs-readme-template.md" ".claude/docs/README.md"
else
  echo "  (.claude/docs/README.md already exists — leaving alone)"
fi

# changelog/README.md
if [[ ! -f .claude/changelog/README.md ]]; then
  render_template "$TEMPLATES_DIR/changelog-readme-template.md" ".claude/changelog/README.md"
else
  echo "  (.claude/changelog/README.md already exists — leaving alone)"
fi

# changelog/daily.md
if [[ ! -f .claude/changelog/daily.md ]]; then
  TODAY=$(date '+%Y-%m-%d')
  cat > .claude/changelog/daily.md <<EOF
# Daily Changelog — $THEME_NAME

> Newest entries on top. Compresses to weekly.md weekly per the protocol
> in this folder's README.md.

## $TODAY

- $(date '+%H:%M') — [CHORE] Project initialized via norml-wp-developer.
  Mode: $MODE. CI/CD pattern: $PATTERN. Backup strategy: $BACKUP.
EOF
  echo "  wrote .claude/changelog/daily.md"
fi

# changelog/weekly.md + changelog/changelog.md — empty placeholders
[[ -f .claude/changelog/weekly.md    ]] || { echo "# Weekly Changelog — $THEME_NAME" > .claude/changelog/weekly.md;       echo "  wrote .claude/changelog/weekly.md"; }
[[ -f .claude/changelog/changelog.md ]] || { echo "# Long-term Changelog — $THEME_NAME" > .claude/changelog/changelog.md; echo "  wrote .claude/changelog/changelog.md"; }

# .claude/skills/README.md
if [[ ! -f .claude/skills/README.md ]]; then
  cat > .claude/skills/README.md <<'EOF'
# Project-specific skills

Drop any project-specific Claude skills here. The norml-wp-developer
skill auto-loads them at session start (if you've installed the
norml-wp-developer skill on your machine — `~/.claude/skills/`).
EOF
  echo "  wrote .claude/skills/README.md"
fi

# GitHub workflows (if pattern is full-pipeline or prod-direct-with-git)
case "$PATTERN" in
  full-pipeline)
    mkdir -p .github/workflows
    if [[ ! -f .github/workflows/staging.yml ]]; then
      render_template "$TEMPLATES_DIR/github-workflow-staging.template.yml" ".github/workflows/staging.yml"
    fi
    if [[ ! -f .github/workflows/production.yml ]]; then
      render_template "$TEMPLATES_DIR/github-workflow-prod.template.yml" ".github/workflows/production.yml"
    fi
    ;;
  prod-direct-with-git)
    mkdir -p .github/workflows
    if [[ ! -f .github/workflows/production.yml ]]; then
      render_template "$TEMPLATES_DIR/github-workflow-prod.template.yml" ".github/workflows/production.yml"
    fi
    ;;
  prod-direct-no-ci)
    echo "  (no CI/CD workflows scaffolded — pattern is prod-direct-no-ci)"
    ;;
esac

echo
echo "Scaffolded .claude/ inside $THEME_ROOT."
echo "Review the files, then commit them to git:"
echo "  git add .claude .github .gitignore"
echo "  git commit -m 'chore: scaffold .claude via norml-wp-developer'"
