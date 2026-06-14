#requires -Version 5.1
<#
.SYNOPSIS
  norml-wp-developer -- per-project setup on Windows.

.DESCRIPTION
  Mirror of setup-macos.sh for Windows / PowerShell. Walks through the
  per-project onboarding flow described in onboarding.md.

  Note: deploy/sync flows on Windows work best from WSL (Ubuntu) where
  rsync is native. The PowerShell scripts in this skill call rsync if
  available on PATH and tell you to use WSL if not.
#>

$ErrorActionPreference = "Stop"

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatesDir = Join-Path (Split-Path -Parent $ScriptDir) "templates"
$ConfigDir    = Join-Path $env:USERPROFILE ".config\norml-wp-developer"
$ProjectsDir  = Join-Path $ConfigDir "projects"

. (Join-Path $ScriptDir "lib\credman.ps1")

function Write-Bold($t) { Write-Host $t -ForegroundColor White }
function Write-Info($t) { Write-Host "  $t" }
function Write-Warn($t) { Write-Host "  $t" -ForegroundColor Yellow }
function Write-Err($t)  { Write-Host "  $t" -ForegroundColor Red }

function Ask($prompt, $default = $null) {
  if ($default) {
    $v = Read-Host "$prompt [$default]"
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return $v
  }
  return Read-Host $prompt
}

function Confirm($prompt) {
  $v = Read-Host "$prompt (y/N)"
  return ($v -match '^[Yy]')
}

Write-Bold "norml-wp-developer -- per-project setup (Windows)"
Write-Host ""
Write-Host "This walks through the one-time per-project setup."
Write-Host "Run me from inside the theme folder (folder with style.css)."
Write-Host ""
Write-Host "NOTE: For best results, run this from WSL (Ubuntu) -- the"
Write-Host "deploy + sync flows need rsync, which is native on WSL."
Write-Host ""
Read-Host "Press Enter to continue, Ctrl-C to cancel"

# ---- Verify we're in a theme folder --------------------------------------

$ThemeRoot = (Get-Location).Path
if (-not (Test-Path (Join-Path $ThemeRoot "style.css"))) {
  Write-Err "Not in a theme folder. Expected style.css in $ThemeRoot."
  exit 1
}

$ThemeNameLine = (Get-Content (Join-Path $ThemeRoot "style.css") -ErrorAction SilentlyContinue) | Where-Object { $_ -match '^\s*Theme Name:' } | Select-Object -First 1
$ThemeName = if ($ThemeNameLine) { ($ThemeNameLine -replace '^[^:]*:\s*', '').Trim() } else { "(unnamed)" }
Write-Info "Detected theme: $ThemeName"
Write-Info "Theme root:     $ThemeRoot"

if (-not (Test-Path $ProjectsDir)) {
  New-Item -ItemType Directory -Force -Path $ProjectsDir | Out-Null
}

# ---- Project basics ------------------------------------------------------

Write-Host ""
Write-Bold "Project basics"

$DefaultSlug = (Split-Path -Leaf $ThemeRoot).ToLower() -replace '[^a-z0-9-]', '-'
$Slug = Ask "Project slug (kebab-case)" $DefaultSlug
if ($Slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
  Write-Err "Slug must be kebab-case."
  exit 1
}

$ConfigFile = Join-Path $ProjectsDir "${Slug}.json"
if (Test-Path $ConfigFile) {
  Write-Warn "$ConfigFile already exists -- will overwrite."
  if (-not (Confirm "Continue?")) { exit 1 }
}

$ProdUrl = (Ask "Production URL").TrimEnd('/')
if ($ProdUrl -notmatch '^https?://') { Write-Err "URL must start with http:// or https://"; exit 1 }

$Mode = Ask "Project mode (sage / inherited)" "inherited"
if ($Mode -notin @('sage','inherited')) { Write-Err "Mode must be 'sage' or 'inherited'."; exit 1 }

# ---- Local env detection -------------------------------------------------

Write-Host ""
Write-Bold "Local environment"

$LocalTool = "manual"
$LocalUrl = ""

if ($ThemeRoot -match 'Local Sites') {
  $LocalTool = "wp-local"
  Write-Info "Detected WP Local."
  $LocalUrl = Ask "Local URL" "https://${Slug}.local"
} elseif (Test-Path (Join-Path $ThemeRoot ".ddev\config.yaml")) {
  $LocalTool = "ddev"
  $LocalUrl = Ask "Local URL (from ddev describe)"
} else {
  Write-Warn "No known local-WP tool detected."
  $LocalTool = Ask "Local tool (wp-local/ddev/lando/valet/manual)" "manual"
  $LocalUrl = Ask "Local URL"
}

# ---- Git setup -----------------------------------------------------------

Write-Host ""
Write-Bold "Git"

if (Test-Path (Join-Path $ThemeRoot ".git")) {
  Write-Info "Already a git repo."
} else {
  if (Confirm "Initialize git here?") {
    git -C $ThemeRoot init -b main | Out-Null
    Write-Info "Initialized git repo."
    @"
public/
dist/
build/
node_modules/
vendor/
.env
.env.local
.env.*.local
.DS_Store
Thumbs.db
.idea/
.vscode/
*.log
"@ | Set-Content -Path (Join-Path $ThemeRoot ".gitignore") -Encoding UTF8
    Write-Info "Wrote .gitignore"
  }
}

$GitProvider = "github"
$GitRemoteUrl = ""
if (Test-Path (Join-Path $ThemeRoot ".git")) {
  $existing = git -C $ThemeRoot remote get-url origin 2>$null
  if ($existing) {
    $GitRemoteUrl = $existing
    Write-Info "Existing remote: $GitRemoteUrl"
    if ($GitRemoteUrl -match 'bitbucket') { $GitProvider = 'bitbucket' }
    elseif ($GitRemoteUrl -match 'gitlab') { $GitProvider = 'gitlab' }
  } else {
    $GitProvider = Ask "Git provider (github/bitbucket/gitlab)" "github"
    $GitRemoteUrl = Ask "Remote URL (leave blank to set later)"
    if ($GitRemoteUrl) {
      git -C $ThemeRoot remote add origin $GitRemoteUrl 2>$null
      if ($LASTEXITCODE -ne 0) { git -C $ThemeRoot remote set-url origin $GitRemoteUrl | Out-Null }
      Write-Info "Configured origin -> $GitRemoteUrl"
    }
  }
}

# ---- SSH details ---------------------------------------------------------

Write-Host ""
Write-Bold "SSH to production"

$ProdHost = Ask "Production SSH host"
$ProdPort = [int](Ask "Production SSH port" "22")
$ProdUser = Ask "Production SSH username"

$DefaultKey = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
if (-not (Test-Path $DefaultKey)) {
  $DefaultKey = Join-Path $env:USERPROFILE ".ssh\norml-wp-dev-$Slug"
}
$ProdKey = Ask "Production SSH key path" $DefaultKey
if ($ProdKey.StartsWith('~')) { $ProdKey = $ProdKey -replace '^~', $env:USERPROFILE }

if (-not (Test-Path $ProdKey)) {
  Write-Warn "$ProdKey does not exist."
  if (Confirm "Generate a new ed25519 key at $ProdKey?") {
    $sshDir = Split-Path -Parent $ProdKey
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Force -Path $sshDir | Out-Null }
    & ssh-keygen -t ed25519 -f $ProdKey -C "norml-wp-dev-$Slug"
    Write-Host ""
    Write-Bold "Add this public key to your production server:"
    Write-Host "---------- BEGIN PUBLIC KEY ----------"
    Get-Content "${ProdKey}.pub"
    Write-Host "----------  END PUBLIC KEY  ----------"
    Write-Host ""
    Read-Host "Press Enter once the key is added"
  } else {
    Write-Err "Need an SSH key. Aborting."; exit 1
  }
}

$ProdWp = Ask "WordPress path on the production server"
$ProdThemePathDefault = "$ProdWp/wp-content/themes/" + (Split-Path -Leaf $ThemeRoot)
$ProdThemePath = Ask "Theme path on the production server" $ProdThemePathDefault

$SshAlias = "norml-wp-dev-$Slug"
$SshConfig = Join-Path $env:USERPROFILE ".ssh\config"
if (-not (Test-Path $SshConfig)) { New-Item -ItemType File -Force -Path $SshConfig | Out-Null }

$existing = Get-Content $SshConfig -ErrorAction SilentlyContinue | Where-Object { $_ -match "^Host $SshAlias`$" }
if ($existing) {
  Write-Warn "SSH alias '$SshAlias' already in config. Skipping."
} else {
  Add-Content -Path $SshConfig -Value @"

# Added by norml-wp-developer setup for project: $Slug
Host $SshAlias
  HostName $ProdHost
  Port $ProdPort
  User $ProdUser
  IdentityFile $ProdKey
"@
  Write-Info "Wrote SSH alias '$SshAlias' to $SshConfig"
}

# Optional passphrase via dialog
if (Confirm "Does your SSH key have a passphrase?") {
  & "$ScriptDir\prompt-secret-windows.ps1" ssh-passphrase $Slug
}

# ---- Staging (optional) --------------------------------------------------

$StagingConfigured = $false
$StagingUrl = $null; $StagingAlias = $null
if (Confirm "Does this project have staging?") {
  $StagingConfigured = $true
  $StagingUrl = (Ask "Staging URL").TrimEnd('/')
  $StagingHost = Ask "Staging SSH host" $ProdHost
  $StagingPort = [int](Ask "Staging SSH port" "$ProdPort")
  $StagingUser = Ask "Staging SSH username" $ProdUser
  $StagingKey  = Ask "Staging SSH key path" $ProdKey
  $StagingWp   = Ask "WordPress path on staging" $ProdWp
  $StagingThemePathDefault = "$StagingWp/wp-content/themes/" + (Split-Path -Leaf $ThemeRoot)
  $StagingThemePath = Ask "Theme path on staging" $StagingThemePathDefault

  $StagingAlias = "norml-wp-dev-$Slug-staging"
  if (-not (Get-Content $SshConfig | Where-Object { $_ -match "^Host $StagingAlias`$" })) {
    Add-Content -Path $SshConfig -Value @"

# Added by norml-wp-developer setup for project: $Slug (staging)
Host $StagingAlias
  HostName $StagingHost
  Port $StagingPort
  User $StagingUser
  IdentityFile $StagingKey
"@
    Write-Info "Wrote SSH alias '$StagingAlias'."
  }
}

# ---- CI/CD pattern + backup ---------------------------------------------

Write-Host ""
Write-Bold "CI/CD pattern"
Write-Host "  full-pipeline         -- staging gates prod"
Write-Host "  prod-direct-with-git  -- single env with git safety net"
Write-Host "  prod-direct-no-ci     -- rsync from local, no CI"
$default = if ($StagingConfigured) { "full-pipeline" } else { "prod-direct-with-git" }
$Pattern = Ask "Pattern" $default

$Backup = Ask "Backup strategy (host-automatic / manual-before-deploy / none-warned)" "host-automatic"

# ---- Write per-project config -------------------------------------------

$ThemeRootJson = $ThemeRoot -replace '\\', '\\'
$ProdKeyJson   = $ProdKey   -replace '\\', '\\'
$StagingKeyJson = if ($StagingConfigured) { $StagingKey -replace '\\','\\' } else { "" }

$stagingBlock = if ($StagingConfigured) { @"

  "staging": {
    "url": "$StagingUrl",
    "ssh_alias": "$StagingAlias",
    "ssh_host": "$StagingHost",
    "ssh_port": $StagingPort,
    "ssh_user": "$StagingUser",
    "ssh_key": "$StagingKeyJson",
    "wp_path": "$StagingWp",
    "theme_path": "$StagingThemePath"
  },
"@
} else { "" }

$createdAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$json = @"
{
  "slug": "$Slug",
  "theme_name": "$ThemeName",
  "theme_root": "$ThemeRootJson",
  "mode": "$Mode",
  "local": {
    "tool": "$LocalTool",
    "url": "$LocalUrl"
  },
  "production": {
    "url": "$ProdUrl",
    "ssh_alias": "$SshAlias",
    "ssh_host": "$ProdHost",
    "ssh_port": $ProdPort,
    "ssh_user": "$ProdUser",
    "ssh_key": "$ProdKeyJson",
    "wp_path": "$ProdWp",
    "theme_path": "$ProdThemePath"
  },$stagingBlock
  "git": {
    "provider": "$GitProvider",
    "remote_url": "$GitRemoteUrl"
  },
  "ci_cd": {
    "pattern": "$Pattern",
    "backup_strategy": "$Backup"
  },
  "created_at": "$createdAt",
  "version": 1
}
"@
Set-Content -Path $ConfigFile -Value $json -Encoding UTF8
Write-Info "Wrote $ConfigFile"

# ---- Scaffold .claude/ --------------------------------------------------

Write-Host ""
Write-Bold "Scaffolding .claude/ inside the theme repo..."
& "$ScriptDir\init-claude.ps1" $Slug

# ---- Test SSH -----------------------------------------------------------

Write-Host ""
Write-Bold "Testing SSH..."
& "$ScriptDir\test-ssh.ps1" $Slug production

# ---- Done ---------------------------------------------------------------

Write-Host ""
Write-Bold "Setup complete."
Write-Info "Config:           $ConfigFile"
Write-Info "Theme root:       $ThemeRoot"
Write-Info "Mode:             $Mode"
Write-Info "Pattern:          $Pattern"
Write-Info "Backup strategy:  $Backup"
Write-Info "SSH alias:        $SshAlias"
Write-Host ""
Write-Host "Next steps:"
Write-Info "  - Review .claude/ and commit it: git add .claude .github .gitignore"
Write-Info "  - For deploys + sync, run from WSL (or install rsync)."
Write-Info "  - Start building: ask Claude 'add a hero block to this theme'."
