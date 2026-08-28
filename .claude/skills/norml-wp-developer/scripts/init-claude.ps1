#requires -Version 5.1
<#
.SYNOPSIS
  Scaffold .claude/ inside the theme repo for the configured project.
#>

param([Parameter(Mandatory=$true, Position=0)][string]$Slug)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatesDir = Join-Path (Split-Path -Parent $ScriptDir) "templates"
$ConfigFile = Join-Path $env:USERPROFILE ".config\norml-wp-developer\projects\${Slug}.json"

if (-not (Test-Path $ConfigFile)) {
  Write-Error "$ConfigFile missing."
  exit 1
}

$cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$ThemeRoot = $cfg.theme_root
if (-not (Test-Path $ThemeRoot)) {
  Write-Error "theme_root '$ThemeRoot' not on disk."
  exit 1
}

Set-Location $ThemeRoot

New-Item -ItemType Directory -Force -Path ".claude\changelog" | Out-Null
New-Item -ItemType Directory -Force -Path ".claude\docs"      | Out-Null
New-Item -ItemType Directory -Force -Path ".claude\skills"    | Out-Null

function Render-Template($tplName, $outPath) {
  $tplFile = Join-Path $TemplatesDir $tplName
  if (-not (Test-Path $tplFile)) {
    Write-Warning "Template missing: $tplFile"
    return
  }
  $today = Get-Date -Format "yyyy-MM-dd"
  $content = Get-Content $tplFile -Raw
  $repl = @{
    '{{SLUG}}'                = $cfg.slug
    '{{THEME_NAME}}'          = $cfg.theme_name
    '{{MODE}}'                = $cfg.mode
    '{{PROD_URL}}'            = $cfg.production.url
    '{{STAGING_URL}}'         = (if ($cfg.staging) { $cfg.staging.url } else { "" })
    '{{LOCAL_URL}}'           = $cfg.local.url
    '{{PATTERN}}'             = $cfg.ci_cd.pattern
    '{{BACKUP}}'              = $cfg.ci_cd.backup_strategy
    '{{REMOTE_URL}}'          = $cfg.git.remote_url
    '{{PROD_SSH_ALIAS}}'      = $cfg.production.ssh_alias
    '{{PROD_THEME_PATH}}'     = $cfg.production.theme_path
    '{{PROD_WP_PATH}}'        = $cfg.production.wp_path
    '{{STAGING_SSH_ALIAS}}'   = (if ($cfg.staging) { $cfg.staging.ssh_alias } else { "" })
    '{{STAGING_THEME_PATH}}'  = (if ($cfg.staging) { $cfg.staging.theme_path } else { "" })
    '{{STAGING_WP_PATH}}'     = (if ($cfg.staging) { $cfg.staging.wp_path } else { "" })
    '{{TODAY}}'               = $today
    '{{GENERATED_AT}}'        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    '{{CLI_STATUS}}'          = 'Terminal filesystem + shell available'
    '{{LOCAL_REPO_STATUS}}'   = (if (Test-Path (Join-Path $ThemeRoot '.git')) { 'Git repository detected' } else { 'BLOCKED — Git repository missing' })
    '{{GITHUB_STATUS}}'       = 'Pending first architecture scan'
    '{{SSH_STATUS}}'          = 'Pending first architecture scan'
    '{{WPCLI_STATUS}}'        = 'Pending first architecture scan'
    '{{STAGING_STATUS}}'      = (if ($cfg.staging) { "Configured at $($cfg.staging.url)" } else { 'Not configured' })
    '{{BLOCKERS}}'            = '- First architecture scan pending. GitHub, SSH, and remote WP-CLI have not been verified yet.'
    '{{ARCHITECTURE_SUMMARY}}'= 'First architecture scan pending. Run the bundled scraper after GitHub and SSH are connected.'
  }
  foreach ($k in $repl.Keys) {
    $content = $content.Replace($k, [string]$repl[$k])
  }
  Set-Content -Path $outPath -Value $content -Encoding UTF8
  Write-Host "  wrote $outPath"
}

if (-not (Test-Path ".claude\CLAUDE.md")) {
  Render-Template "claude-md-template.md" ".claude\CLAUDE.md"
}
if (-not (Test-Path ".claude\ci-cd.md")) {
  Render-Template "ci-cd-template.md" ".claude\ci-cd.md"
}
if (-not (Test-Path ".claude\capabilities.md")) {
  Render-Template "capabilities-template.md" ".claude\capabilities.md"
}
if (-not (Test-Path ".claude\architecture.md")) {
  Render-Template "architecture-template.md" ".claude\architecture.md"
}
if (-not (Test-Path ".claude\docs\README.md")) {
  Render-Template "docs-readme-template.md" ".claude\docs\README.md"
}
if (-not (Test-Path ".claude\changelog\README.md")) {
  Render-Template "changelog-readme-template.md" ".claude\changelog\README.md"
}

# Scaffold the rolling changelog files
$today = Get-Date -Format "yyyy-MM-dd"
$time  = Get-Date -Format "HH:mm"
if (-not (Test-Path ".claude\changelog\daily.md")) {
  @"
# Daily Changelog -- $($cfg.theme_name)

> Newest entries on top. Compresses to weekly.md weekly per the protocol
> in this folder's README.md.

## $today

- $time -- [CHORE] Project initialized via norml-wp-developer.
  Mode: $($cfg.mode). CI/CD pattern: $($cfg.ci_cd.pattern). Backup strategy: $($cfg.ci_cd.backup_strategy).
"@ | Set-Content -Path ".claude\changelog\daily.md" -Encoding UTF8
  Write-Host "  wrote .claude\changelog\daily.md"
}
if (-not (Test-Path ".claude\changelog\weekly.md"))    { "# Weekly Changelog -- $($cfg.theme_name)"    | Set-Content -Path ".claude\changelog\weekly.md"    -Encoding UTF8; Write-Host "  wrote .claude\changelog\weekly.md" }
if (-not (Test-Path ".claude\changelog\changelog.md")) { "# Long-term Changelog -- $($cfg.theme_name)" | Set-Content -Path ".claude\changelog\changelog.md" -Encoding UTF8; Write-Host "  wrote .claude\changelog\changelog.md" }
if (-not (Test-Path ".claude\skills\README.md")) {
  "# Project-specific skills`n`nDrop any project-specific Claude skills here." | Set-Content -Path ".claude\skills\README.md" -Encoding UTF8
}

# GitHub workflows
$pattern = $cfg.ci_cd.pattern
if ($pattern -in @('full-pipeline','prod-direct-with-git')) {
  New-Item -ItemType Directory -Force -Path ".github\workflows" | Out-Null
  if ($pattern -eq 'full-pipeline' -and -not (Test-Path ".github\workflows\staging.yml")) {
    Render-Template "github-workflow-staging.template.yml" ".github\workflows\staging.yml"
  }
  if (-not (Test-Path ".github\workflows\production.yml")) {
    Render-Template "github-workflow-prod.template.yml" ".github\workflows\production.yml"
  }
}

Write-Host ""
Write-Host "Scaffolded .claude/ inside $ThemeRoot."
Write-Host "Review the files, then commit:"
Write-Host "  git add .claude .github .gitignore"
Write-Host "  git commit -m 'chore: scaffold .claude via norml-wp-developer'"
