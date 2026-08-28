#!/usr/bin/env bash
# Generate the theme-local Advanced Copilot capability contract and architecture
# snapshot from local Git/theme evidence plus fixed read-only WP-CLI commands over
# SSH. No config values or user input are executed as shell code.

set -euo pipefail
set +x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../templates" && pwd)"
CONFIG_DIR="$HOME/.config/norml-wp-developer/projects"
SLUG="${1:-}"

if [[ -z "$SLUG" || ! "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "ERROR: usage: $0 <project-slug>" >&2
  exit 2
fi
for cmd in python3 ssh git; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: required command missing: $cmd" >&2; exit 1; }
done

CONFIG_FILE="$CONFIG_DIR/${SLUG}.json"
[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: project config missing: $CONFIG_FILE" >&2; exit 1; }

parse() {
  python3 - "$CONFIG_FILE" "$1" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
value = data
for key in sys.argv[2].split('.'):
    if not key:
        continue
    value = value.get(key, '') if isinstance(value, dict) else ''
print('' if value is None else value)
PY
}

THEME_ROOT="$(parse theme_root)"
THEME_NAME="$(parse theme_name)"
MODE="$(parse mode)"
LOCAL_TOOL="$(parse local.tool)"
LOCAL_URL="$(parse local.url)"
PROD_URL="$(parse production.url)"
PROD_SSH_ALIAS="$(parse production.ssh_alias)"
PROD_WP_PATH="$(parse production.wp_path)"
PROD_THEME_PATH="$(parse production.theme_path)"
STAGING_URL="$(parse staging.url)"
STAGING_SSH_ALIAS="$(parse staging.ssh_alias)"
REMOTE_URL="$(parse git.remote_url)"
PATTERN="$(parse ci_cd.pattern)"
BACKUP="$(parse ci_cd.backup_strategy)"
GENERATED_AT="$(date -u +%FT%TZ)"

[[ -d "$THEME_ROOT" ]] || { echo "ERROR: theme_root not found: $THEME_ROOT" >&2; exit 1; }
[[ "$PROD_SSH_ALIAS" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ERROR: unsafe production SSH alias in config." >&2; exit 1; }
[[ "$PROD_WP_PATH" =~ ^/[A-Za-z0-9._/-]+$ ]] || { echo "ERROR: production.wp_path must be an absolute path containing only letters, digits, dot, underscore, slash, or hyphen." >&2; exit 1; }

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/norml-wp-advanced-scan.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
REMOTE_SNAPSHOT="$TMP_DIR/remote.txt"
LOCAL_INVENTORY="$TMP_DIR/local-files.txt"
BLOCKERS_FILE="$TMP_DIR/blockers.md"
: > "$REMOTE_SNAPSHOT"
: > "$BLOCKERS_FILE"

CRITICAL=0
add_blocker() {
  printf -- '- %s\n' "$1" >> "$BLOCKERS_FILE"
}

CLI_STATUS="Verified: terminal, filesystem, ssh, git, and python3 available"

if [[ -d "$THEME_ROOT/.git" ]]; then
  BRANCH="$(git -C "$THEME_ROOT" branch --show-current 2>/dev/null || true)"
  [[ -z "$BRANCH" ]] && BRANCH="detached or no commits"
  DIRTY_COUNT="$(git -C "$THEME_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  LOCAL_REPO_STATUS="Verified Git repo on ${BRANCH}; ${DIRTY_COUNT} uncommitted path(s)"
else
  LOCAL_REPO_STATUS="BLOCKED — local theme is not a Git repository"
  add_blocker "Local theme is not a Git repository. Initialize Git before development."
  CRITICAL=1
fi

ORIGIN_URL=""
if [[ -d "$THEME_ROOT/.git" ]]; then
  ORIGIN_URL="$(git -C "$THEME_ROOT" remote get-url origin 2>/dev/null || true)"
fi
[[ -n "$ORIGIN_URL" ]] && REMOTE_URL="$ORIGIN_URL"
if [[ "$REMOTE_URL" != *github.com* ]]; then
  GITHUB_STATUS="BLOCKED — origin is missing or is not GitHub"
  add_blocker "A GitHub origin is required. Configure `origin` to a github.com repository."
  CRITICAL=1
elif git -C "$THEME_ROOT" ls-remote origin >/dev/null 2>"$TMP_DIR/github-error.txt"; then
  GITHUB_STATUS="Verified read-only access to ${REMOTE_URL}"
else
  GITHUB_STATUS="BLOCKED — GitHub remote could not be read"
  add_blocker "GitHub authentication failed for origin. Run the runtime's supported GitHub login flow, then rescan."
  CRITICAL=1
fi

SSH_STATUS="BLOCKED — production SSH not verified"
WPCLI_STATUS="BLOCKED — remote WP-CLI not verified"
if ssh -o BatchMode=yes -o ConnectTimeout=12 "$PROD_SSH_ALIAS" "printf 'ok'" >/dev/null 2>"$TMP_DIR/ssh-error.txt"; then
  SSH_STATUS="Verified through SSH alias ${PROD_SSH_ALIAS}"
  if ssh -o BatchMode=yes -o ConnectTimeout=15 "$PROD_SSH_ALIAS" "cd '$PROD_WP_PATH' && wp --info" >"$TMP_DIR/wp-info.txt" 2>"$TMP_DIR/wp-info-error.txt"; then
    WPCLI_VERSION="$(ssh -o BatchMode=yes -o ConnectTimeout=15 "$PROD_SSH_ALIAS" "cd '$PROD_WP_PATH' && wp cli version" 2>/dev/null | sed -n '1p' || true)"
    [[ -z "$WPCLI_VERSION" ]] && WPCLI_VERSION="WP-CLI available"
    WPCLI_STATUS="Verified: ${WPCLI_VERSION} at ${PROD_WP_PATH}"

    if ! ssh -o BatchMode=yes -o ConnectTimeout=25 "$PROD_SSH_ALIAS" "bash -s -- '$PROD_WP_PATH'" >"$REMOTE_SNAPSHOT" 2>"$TMP_DIR/remote-error.txt" <<'REMOTE'
set +e
wp_path="$1"
cd "$wp_path" || exit 20
section() { printf '\n@@NORML_SECTION:%s@@\n' "$1"; }
run() { section "$1"; shift; "$@" 2>&1 || printf '[command failed: exit %s]\n' "$?"; }

run core_version wp core version
run php_version wp eval 'echo PHP_VERSION;'
run site_name wp option get blogname
run home_url wp option get home
run site_url wp option get siteurl
run active_template wp option get template
run active_stylesheet wp option get stylesheet
run theme_list wp theme list --fields=name,status,version,update,auto_update --format=table
run plugin_list wp plugin list --fields=name,status,version,update,auto_update --format=table
run core_updates wp core check-update --format=table
run post_types wp post-type list --fields=name,label,public,show_in_rest,hierarchical --format=table
run taxonomies wp taxonomy list --fields=name,label,public,show_in_rest,hierarchical --format=table
section post_counts
for type in $(wp post-type list --field=name 2>/dev/null); do
  count=$(wp post list --post_type="$type" --post_status=any --format=count 2>/dev/null)
  printf '%s\t%s\n' "$type" "${count:-?}"
done
run menus wp menu list --fields=term_id,name,slug,locations,count --format=table
REMOTE
    then
      add_blocker "The combined read-only WP-CLI architecture scan failed. See `.claude/docs/05-issues.md`."
      CRITICAL=1
    fi
  else
    add_blocker "SSH works, but WP-CLI is unavailable or cannot run from ${PROD_WP_PATH}."
    CRITICAL=1
  fi
else
  add_blocker "Production SSH failed for alias ${PROD_SSH_ALIAS}."
  CRITICAL=1
fi

if [[ -n "$STAGING_URL" && "$STAGING_URL" != "null" ]]; then
  if [[ "$STAGING_SSH_ALIAS" =~ ^[A-Za-z0-9._-]+$ ]] && ssh -o BatchMode=yes -o ConnectTimeout=12 "$STAGING_SSH_ALIAS" "printf 'ok'" >/dev/null 2>"$TMP_DIR/staging-error.txt"; then
    STAGING_STATUS="Configured and SSH verified at ${STAGING_URL}"
  else
    STAGING_STATUS="Configured at ${STAGING_URL}, but SSH did not verify"
    add_blocker "Staging is configured, but its SSH alias did not verify."
  fi
else
  STAGING_STATUS="Not configured; deploy pattern is ${PATTERN}"
fi

if [[ ! -s "$BLOCKERS_FILE" ]]; then
  printf -- '- None detected by the onboarding scan. Normal confirmation and backup gates still apply.\n' > "$BLOCKERS_FILE"
fi

find "$THEME_ROOT" -maxdepth 4 -type f \
  ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/vendor/*' \
  ! -path '*/public/*' ! -path '*/dist/*' ! -path '*/build/*' \
  | sed "s|^$THEME_ROOT/||" | LC_ALL=C sort | sed -n '1,400p' > "$LOCAL_INVENTORY"

python3 - \
  "$TEMPLATES_DIR" "$THEME_ROOT" "$REMOTE_SNAPSHOT" "$LOCAL_INVENTORY" "$BLOCKERS_FILE" \
  "$SLUG" "$THEME_NAME" "$MODE" "$LOCAL_TOOL" "$LOCAL_URL" "$PROD_URL" \
  "$PROD_SSH_ALIAS" "$PROD_WP_PATH" "$PROD_THEME_PATH" "$STAGING_URL" "$REMOTE_URL" \
  "$PATTERN" "$BACKUP" "$GENERATED_AT" "$CLI_STATUS" "$LOCAL_REPO_STATUS" \
  "$GITHUB_STATUS" "$SSH_STATUS" "$WPCLI_STATUS" "$STAGING_STATUS" <<'PY'
from pathlib import Path
import re, sys

(templates, theme_root, remote_file, inventory_file, blockers_file, slug,
 theme_name, mode, local_tool, local_url, prod_url, prod_alias, prod_wp_path,
 prod_theme_path, staging_url, remote_url, pattern, backup, generated_at,
 cli_status, local_repo_status, github_status, ssh_status, wpcli_status,
 staging_status) = sys.argv[1:]

root = Path(theme_root)
claude = root / '.claude'
docs = claude / 'docs'
docs.mkdir(parents=True, exist_ok=True)
raw = Path(remote_file).read_text(encoding='utf-8', errors='replace') if Path(remote_file).exists() else ''
inventory = Path(inventory_file).read_text(encoding='utf-8', errors='replace').strip() or '(no files captured)'
blockers = Path(blockers_file).read_text(encoding='utf-8', errors='replace').strip()

sections = {}
parts = re.split(r'^@@NORML_SECTION:([^@]+)@@\s*$', raw, flags=re.M)
for i in range(1, len(parts), 2):
    sections[parts[i].strip()] = parts[i + 1].strip()
def sec(name, fallback='Not captured'):
    return sections.get(name, '').strip() or fallback
def fenced(value):
    return f"```text\n{value}\n```"

stack = []
checks = {
    'Roots Sage / Acorn': [root / 'composer.json', root / 'app'],
    'Node build': [root / 'package.json'],
    'Vite': [root / 'vite.config.js', root / 'vite.config.ts'],
    'Tailwind': [root / 'tailwind.config.js', root / 'tailwind.config.ts'],
    'ACF JSON': [root / 'acf-json'],
    'WordPress theme headers': [root / 'style.css', root / 'functions.php'],
}
for label, paths in checks.items():
    if all(p.exists() for p in paths):
        stack.append(label)
stack_text = ', '.join(stack) if stack else 'No known stack signals detected beyond the theme folder.'

active = sec('active_stylesheet')
core = sec('core_version')
php = sec('php_version')
site_name = sec('site_name', theme_name)
summary = (
    f"Production reports WordPress **{core}** on PHP **{php}**, active stylesheet "
    f"`{active}`, and site name **{site_name}**. Local mode is `{mode}` using "
    f"`{local_tool}`. Detected local signals: {stack_text}"
)

tokens = {
    '{{SLUG}}': slug, '{{THEME_NAME}}': theme_name, '{{MODE}}': mode,
    '{{LOCAL_URL}}': local_url, '{{LOCAL_TOOL}}': local_tool,
    '{{PROD_URL}}': prod_url, '{{PROD_SSH_ALIAS}}': prod_alias,
    '{{PROD_WP_PATH}}': prod_wp_path, '{{PROD_THEME_PATH}}': prod_theme_path,
    '{{STAGING_URL}}': staging_url or 'Not configured', '{{REMOTE_URL}}': remote_url,
    '{{PATTERN}}': pattern, '{{BACKUP}}': backup, '{{GENERATED_AT}}': generated_at,
    '{{THEME_ROOT}}': theme_root, '{{CLI_STATUS}}': cli_status,
    '{{LOCAL_REPO_STATUS}}': local_repo_status, '{{GITHUB_STATUS}}': github_status,
    '{{SSH_STATUS}}': ssh_status, '{{WPCLI_STATUS}}': wpcli_status,
    '{{STAGING_STATUS}}': staging_status, '{{BLOCKERS}}': blockers,
    '{{ARCHITECTURE_SUMMARY}}': summary,
}
def render(name):
    text = (Path(templates) / name).read_text(encoding='utf-8')
    for key, value in tokens.items():
        text = text.replace(key, str(value))
    return text.rstrip() + '\n'

(claude / 'capabilities.md').write_text(render('capabilities-template.md'), encoding='utf-8')
(claude / 'architecture.md').write_text(render('architecture-template.md'), encoding='utf-8')
(docs / 'README.md').write_text(render('docs-readme-template.md'), encoding='utf-8')

(docs / '01-infrastructure.md').write_text(f"""<!-- GENERATED — rescan overwrites this file. -->
# Infrastructure — {theme_name}

- Generated: {generated_at}
- Production URL: {prod_url}
- Local URL: {local_url}
- Local tool: `{local_tool}`
- Project mode: `{mode}`
- GitHub remote: `{remote_url}`
- Production SSH alias: `{prod_alias}`
- Production WordPress path: `{prod_wp_path}`
- Production theme path: `{prod_theme_path}`
- CI/CD pattern: `{pattern}`
- Backup strategy declaration: `{backup}`

## Runtime versions

| Runtime | Reported value |
|---|---|
| WordPress | {core} |
| PHP | {php} |
| WP-CLI | {wpcli_status} |

## Connection results

- GitHub: {github_status}
- SSH: {ssh_status}
- Staging: {staging_status}
""", encoding='utf-8')

(docs / '02-application.md').write_text(f"""<!-- GENERATED — rescan overwrites this file. -->
# WordPress application — {theme_name}

Generated: {generated_at}

## Site

- Name: {site_name}
- Home URL: {sec('home_url')}
- Site URL: {sec('site_url')}
- Active template: `{sec('active_template')}`
- Active stylesheet: `{active}`

## Themes

{fenced(sec('theme_list'))}

## Plugins

{fenced(sec('plugin_list'))}

## Core update signal

{fenced(sec('core_updates', 'No update output returned.'))}
""", encoding='utf-8')

(docs / '03-theme-architecture.md').write_text(f"""<!-- GENERATED — rescan overwrites this file. -->
# Theme architecture — {theme_name}

Generated: {generated_at}

## Detected stack signals

{stack_text}

## Local source inventory

The scanner records at most 400 files, four levels deep, excluding dependencies,
build output, and Git internals.

{fenced(inventory)}
""", encoding='utf-8')

(docs / '04-content-structure.md').write_text(f"""<!-- GENERATED — rescan overwrites this file. -->
# Content structure — {theme_name}

Generated: {generated_at}

## Post types

{fenced(sec('post_types'))}

## Taxonomies

{fenced(sec('taxonomies'))}

## Content counts

{fenced(sec('post_counts'))}

## Menus

{fenced(sec('menus', 'No menu output returned.'))}
""", encoding='utf-8')

remote_errors = []
for name, value in sections.items():
    if '[command failed:' in value:
        remote_errors.append(f"- `{name}` returned a non-zero exit status; inspect its section in the generated docs.")
issue_lines = blockers
if remote_errors:
    issue_lines += '\n' + '\n'.join(remote_errors)
(docs / '05-issues.md').write_text(f"""<!-- GENERATED — rescan overwrites this file. -->
# Issues and follow-ups — {theme_name}

Generated: {generated_at}

## Connection and setup blockers

{issue_lines}

## Update signals

### Core

{fenced(sec('core_updates', 'No update output returned.'))}

### Themes

{fenced(sec('theme_list'))}

### Plugins

{fenced(sec('plugin_list'))}

These are read-only signals, not authorization to update production. Updates follow
the project CI/CD, QA, confirmation, and backup contracts.
""", encoding='utf-8')
PY

echo "Generated Advanced Copilot documentation:"
echo "  $THEME_ROOT/.claude/capabilities.md"
echo "  $THEME_ROOT/.claude/architecture.md"
echo "  $THEME_ROOT/.claude/docs/"

if [[ "$CRITICAL" -ne 0 ]]; then
  echo "ERROR: onboarding scan completed with critical blockers. Read .claude/capabilities.md." >&2
  exit 1
fi
