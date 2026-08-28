#requires -Version 5.1
<#
.SYNOPSIS
  Generate the theme-local Advanced Copilot capability contract and architecture
  snapshot from local Git/theme evidence plus fixed read-only WP-CLI commands over
  SSH.
#>

param([Parameter(Mandatory=$true, Position=0)][string]$Slug)

$ErrorActionPreference = 'Stop'
if ($Slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw 'Project slug must be kebab-case.' }
foreach ($name in @('ssh','git')) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { throw "Required command missing: $name" }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatesDir = Join-Path (Split-Path -Parent $ScriptDir) 'templates'
$ConfigFile = Join-Path $env:USERPROFILE ".config\norml-wp-developer\projects\${Slug}.json"
if (-not (Test-Path $ConfigFile)) { throw "Project config missing: $ConfigFile" }
$cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$ThemeRoot = [string]$cfg.theme_root
$ThemeName = [string]$cfg.theme_name
$Mode = [string]$cfg.mode
$LocalTool = [string]$cfg.local.tool
$LocalUrl = [string]$cfg.local.url
$ProdUrl = [string]$cfg.production.url
$ProdAlias = [string]$cfg.production.ssh_alias
$ProdWpPath = [string]$cfg.production.wp_path
$ProdThemePath = [string]$cfg.production.theme_path
$StagingUrl = if ($cfg.staging) { [string]$cfg.staging.url } else { '' }
$StagingAlias = if ($cfg.staging) { [string]$cfg.staging.ssh_alias } else { '' }
$RemoteUrl = [string]$cfg.git.remote_url
$Pattern = [string]$cfg.ci_cd.pattern
$Backup = [string]$cfg.ci_cd.backup_strategy
$GeneratedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

if (-not (Test-Path $ThemeRoot)) { throw "theme_root not found: $ThemeRoot" }
if ($ProdAlias -notmatch '^[A-Za-z0-9._-]+$') { throw 'Unsafe production SSH alias in config.' }
if ($ProdWpPath -notmatch '^/[A-Za-z0-9._/-]+$') { throw 'production.wp_path contains unsupported characters.' }

$ClaudeDir = Join-Path $ThemeRoot '.claude'
$DocsDir = Join-Path $ClaudeDir 'docs'
New-Item -ItemType Directory -Force -Path $DocsDir | Out-Null
$Blockers = New-Object System.Collections.Generic.List[string]
$Critical = $false

$CliStatus = 'Verified: terminal, filesystem, ssh, git, and PowerShell available'
$GitDir = Join-Path $ThemeRoot '.git'
if (Test-Path $GitDir) {
  $branch = (& git -C $ThemeRoot branch --show-current 2>$null | Out-String).Trim()
  if (-not $branch) { $branch = 'detached or no commits' }
  $dirty = @(& git -C $ThemeRoot status --porcelain 2>$null).Count
  $LocalRepoStatus = "Verified Git repo on $branch; $dirty uncommitted path(s)"
  $origin = (& git -C $ThemeRoot remote get-url origin 2>$null | Out-String).Trim()
  if ($origin) { $RemoteUrl = $origin }
} else {
  $LocalRepoStatus = 'BLOCKED — local theme is not a Git repository'
  $Blockers.Add('Local theme is not a Git repository. Initialize Git before development.')
  $Critical = $true
}

if ($RemoteUrl -notmatch 'github\.com') {
  $GithubStatus = 'BLOCKED — origin is missing or is not GitHub'
  $Blockers.Add('A GitHub origin is required. Configure origin to a github.com repository.')
  $Critical = $true
} else {
  & git -C $ThemeRoot ls-remote origin 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    $GithubStatus = "Verified read-only access to $RemoteUrl"
  } else {
    $GithubStatus = 'BLOCKED — GitHub remote could not be read'
    $Blockers.Add('GitHub authentication failed for origin. Run the runtime-supported GitHub login flow, then rescan.')
    $Critical = $true
  }
}

function Invoke-SshText([string]$alias, [string]$command, [int]$timeout = 15) {
  $out = & ssh -o BatchMode=yes -o "ConnectTimeout=$timeout" $alias $command 2>&1
  return @{ Code = $LASTEXITCODE; Text = (($out | Out-String).Trim()) }
}
function Invoke-Wp([string]$command) {
  return (Invoke-SshText $ProdAlias "cd '$ProdWpPath' && $command" 25)
}

$Sections = @{}
$sshTest = Invoke-SshText $ProdAlias "printf ok" 12
if ($sshTest.Code -eq 0) {
  $SshStatus = "Verified through SSH alias $ProdAlias"
  $wpInfo = Invoke-Wp 'wp --info'
  if ($wpInfo.Code -eq 0) {
    $wpCli = Invoke-Wp 'wp cli version'
    $wpCliLabel = if ($wpCli.Text) { $wpCli.Text } else { 'WP-CLI available' }
    $WpCliStatus = "Verified: $wpCliLabel at $ProdWpPath"
    $fixed = [ordered]@{
      core_version = 'wp core version'
      php_version = "wp eval 'echo PHP_VERSION;'"
      site_name = 'wp option get blogname'
      home_url = 'wp option get home'
      site_url = 'wp option get siteurl'
      active_template = 'wp option get template'
      active_stylesheet = 'wp option get stylesheet'
      theme_list = 'wp theme list --fields=name,status,version,update,auto_update --format=table'
      plugin_list = 'wp plugin list --fields=name,status,version,update,auto_update --format=table'
      core_updates = 'wp core check-update --format=table'
      post_types = 'wp post-type list --fields=name,label,public,show_in_rest,hierarchical --format=table'
      taxonomies = 'wp taxonomy list --fields=name,label,public,show_in_rest,hierarchical --format=table'
      menus = 'wp menu list --fields=term_id,name,slug,locations,count --format=table'
    }
    foreach ($entry in $fixed.GetEnumerator()) {
      $result = Invoke-Wp $entry.Value
      $Sections[$entry.Key] = if ($result.Text) { $result.Text } else { '[no output]' }
      if ($result.Code -ne 0) { $Sections[$entry.Key] += "`n[command failed: exit $($result.Code)]" }
    }
    $types = Invoke-Wp 'wp post-type list --field=name'
    $countLines = New-Object System.Collections.Generic.List[string]
    if ($types.Code -eq 0) {
      foreach ($type in ($types.Text -split "`r?`n")) {
        if ($type -notmatch '^[A-Za-z0-9_-]+$') { continue }
        $count = Invoke-Wp "wp post list --post_type=$type --post_status=any --format=count"
        $countLines.Add("$type`t$($count.Text)")
      }
    }
    $Sections['post_counts'] = ($countLines -join "`n")
  } else {
    $WpCliStatus = "BLOCKED — WP-CLI cannot run from $ProdWpPath"
    $Blockers.Add("SSH works, but WP-CLI is unavailable or cannot run from $ProdWpPath.")
    $Critical = $true
  }
} else {
  $SshStatus = "BLOCKED — production SSH failed for alias $ProdAlias"
  $WpCliStatus = 'BLOCKED — remote WP-CLI not verified'
  $Blockers.Add("Production SSH failed for alias $ProdAlias.")
  $Critical = $true
}

if ($StagingUrl) {
  if ($StagingAlias -match '^[A-Za-z0-9._-]+$') {
    $stage = Invoke-SshText $StagingAlias "printf ok" 12
  } else { $stage = @{ Code = 1; Text = '' } }
  if ($stage.Code -eq 0) {
    $StagingStatus = "Configured and SSH verified at $StagingUrl"
  } else {
    $StagingStatus = "Configured at $StagingUrl, but SSH did not verify"
    $Blockers.Add('Staging is configured, but its SSH alias did not verify.')
  }
} else {
  $StagingStatus = "Not configured; deploy pattern is $Pattern"
}
if ($Blockers.Count -eq 0) { $Blockers.Add('None detected by the onboarding scan. Normal confirmation and backup gates still apply.') }
$BlockersText = ($Blockers | ForEach-Object { "- $_" }) -join "`n"

$inventory = Get-ChildItem -Path $ThemeRoot -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object {
    $relative = $_.FullName.Substring($ThemeRoot.Length).TrimStart('\','/')
    $relative -notmatch '(^|[\\/])(\.git|node_modules|vendor|public|dist|build)([\\/]|$)' -and
    (($relative -split '[\\/]').Count -le 4)
  } |
  ForEach-Object { $_.FullName.Substring($ThemeRoot.Length).TrimStart('\','/').Replace('\','/') } |
  Sort-Object | Select-Object -First 400
$InventoryText = if ($inventory) { $inventory -join "`n" } else { '(no files captured)' }

$signals = New-Object System.Collections.Generic.List[string]
if ((Test-Path (Join-Path $ThemeRoot 'composer.json')) -and (Test-Path (Join-Path $ThemeRoot 'app'))) { $signals.Add('Roots Sage / Acorn') }
if (Test-Path (Join-Path $ThemeRoot 'package.json')) { $signals.Add('Node build') }
if ((Test-Path (Join-Path $ThemeRoot 'vite.config.js')) -or (Test-Path (Join-Path $ThemeRoot 'vite.config.ts'))) { $signals.Add('Vite') }
if ((Test-Path (Join-Path $ThemeRoot 'tailwind.config.js')) -or (Test-Path (Join-Path $ThemeRoot 'tailwind.config.ts'))) { $signals.Add('Tailwind') }
if (Test-Path (Join-Path $ThemeRoot 'acf-json')) { $signals.Add('ACF JSON') }
if ((Test-Path (Join-Path $ThemeRoot 'style.css')) -and (Test-Path (Join-Path $ThemeRoot 'functions.php'))) { $signals.Add('WordPress theme headers') }
$StackText = if ($signals.Count) { $signals -join ', ' } else { 'No known stack signals detected beyond the theme folder.' }

function Sec([string]$name, [string]$fallback = 'Not captured') {
  if ($Sections.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace([string]$Sections[$name])) { return [string]$Sections[$name] }
  return $fallback
}
function Fence([string]$text) { return "``````text`n$text`n``````" }
function Write-Utf8([string]$path, [string]$content) {
  [IO.File]::WriteAllText($path, ($content.TrimEnd() + "`n"), (New-Object Text.UTF8Encoding($false)))
}

$Core = Sec 'core_version'
$Php = Sec 'php_version'
$Active = Sec 'active_stylesheet'
$SiteName = Sec 'site_name' $ThemeName
$Summary = "Production reports WordPress **$Core** on PHP **$Php**, active stylesheet ``$Active``, and site name **$SiteName**. Local mode is ``$Mode`` using ``$LocalTool``. Detected local signals: $StackText"

$tokens = @{
  '{{SLUG}}'=$Slug; '{{THEME_NAME}}'=$ThemeName; '{{MODE}}'=$Mode;
  '{{LOCAL_URL}}'=$LocalUrl; '{{LOCAL_TOOL}}'=$LocalTool; '{{PROD_URL}}'=$ProdUrl;
  '{{PROD_SSH_ALIAS}}'=$ProdAlias; '{{PROD_WP_PATH}}'=$ProdWpPath;
  '{{PROD_THEME_PATH}}'=$ProdThemePath; '{{STAGING_URL}}'=$(if($StagingUrl){$StagingUrl}else{'Not configured'});
  '{{REMOTE_URL}}'=$RemoteUrl; '{{PATTERN}}'=$Pattern; '{{BACKUP}}'=$Backup;
  '{{GENERATED_AT}}'=$GeneratedAt; '{{THEME_ROOT}}'=$ThemeRoot;
  '{{CLI_STATUS}}'=$CliStatus; '{{LOCAL_REPO_STATUS}}'=$LocalRepoStatus;
  '{{GITHUB_STATUS}}'=$GithubStatus; '{{SSH_STATUS}}'=$SshStatus;
  '{{WPCLI_STATUS}}'=$WpCliStatus; '{{STAGING_STATUS}}'=$StagingStatus;
  '{{BLOCKERS}}'=$BlockersText; '{{ARCHITECTURE_SUMMARY}}'=$Summary
}
function Render([string]$templateName) {
  $text = Get-Content (Join-Path $TemplatesDir $templateName) -Raw
  foreach ($key in $tokens.Keys) { $text = $text.Replace($key, [string]$tokens[$key]) }
  return $text
}
Write-Utf8 (Join-Path $ClaudeDir 'capabilities.md') (Render 'capabilities-template.md')
Write-Utf8 (Join-Path $ClaudeDir 'architecture.md') (Render 'architecture-template.md')
Write-Utf8 (Join-Path $DocsDir 'README.md') (Render 'docs-readme-template.md')

Write-Utf8 (Join-Path $DocsDir '01-infrastructure.md') @"
<!-- GENERATED — rescan overwrites this file. -->
# Infrastructure — $ThemeName

- Generated: $GeneratedAt
- Production URL: $ProdUrl
- Local URL: $LocalUrl
- Local tool: ``$LocalTool``
- Project mode: ``$Mode``
- GitHub remote: ``$RemoteUrl``
- Production SSH alias: ``$ProdAlias``
- Production WordPress path: ``$ProdWpPath``
- Production theme path: ``$ProdThemePath``
- CI/CD pattern: ``$Pattern``
- Backup strategy declaration: ``$Backup``

## Runtime versions

| Runtime | Reported value |
|---|---|
| WordPress | $Core |
| PHP | $Php |
| WP-CLI | $WpCliStatus |

## Connection results

- GitHub: $GithubStatus
- SSH: $SshStatus
- Staging: $StagingStatus
"@
Write-Utf8 (Join-Path $DocsDir '02-application.md') @"
<!-- GENERATED — rescan overwrites this file. -->
# WordPress application — $ThemeName

Generated: $GeneratedAt

## Site

- Name: $SiteName
- Home URL: $(Sec 'home_url')
- Site URL: $(Sec 'site_url')
- Active template: ``$(Sec 'active_template')``
- Active stylesheet: ``$Active``

## Themes

$(Fence (Sec 'theme_list'))

## Plugins

$(Fence (Sec 'plugin_list'))

## Core update signal

$(Fence (Sec 'core_updates' 'No update output returned.'))
"@
Write-Utf8 (Join-Path $DocsDir '03-theme-architecture.md') @"
<!-- GENERATED — rescan overwrites this file. -->
# Theme architecture — $ThemeName

Generated: $GeneratedAt

## Detected stack signals

$StackText

## Local source inventory

At most 400 files, four levels deep, excluding dependencies, build output, and Git internals.

$(Fence $InventoryText)
"@
Write-Utf8 (Join-Path $DocsDir '04-content-structure.md') @"
<!-- GENERATED — rescan overwrites this file. -->
# Content structure — $ThemeName

Generated: $GeneratedAt

## Post types

$(Fence (Sec 'post_types'))

## Taxonomies

$(Fence (Sec 'taxonomies'))

## Content counts

$(Fence (Sec 'post_counts'))

## Menus

$(Fence (Sec 'menus' 'No menu output returned.'))
"@
Write-Utf8 (Join-Path $DocsDir '05-issues.md') @"
<!-- GENERATED — rescan overwrites this file. -->
# Issues and follow-ups — $ThemeName

Generated: $GeneratedAt

## Connection and setup blockers

$BlockersText

## Update signals

### Core

$(Fence (Sec 'core_updates' 'No update output returned.'))

### Themes

$(Fence (Sec 'theme_list'))

### Plugins

$(Fence (Sec 'plugin_list'))

These are read-only signals, not authorization to update production. Updates follow
the project CI/CD, QA, confirmation, and backup contracts.
"@

Write-Host 'Generated Advanced Copilot documentation:'
Write-Host "  $(Join-Path $ClaudeDir 'capabilities.md')"
Write-Host "  $(Join-Path $ClaudeDir 'architecture.md')"
Write-Host "  $DocsDir"
if ($Critical) {
  Write-Error 'Onboarding scan completed with critical blockers. Read .claude/capabilities.md.'
  exit 1
}
