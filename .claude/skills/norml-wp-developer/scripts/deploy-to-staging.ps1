#requires -Version 5.1
<#
.SYNOPSIS
  Deploy theme to staging via rsync over SSH. No backup gate.
#>

param([Parameter(Mandatory=$true, Position=0)][string]$Slug)

$ErrorActionPreference = "Stop"
$ConfigFile = Join-Path $env:USERPROFILE ".config\norml-wp-developer\projects\${Slug}.json"
if (-not (Test-Path $ConfigFile)) { Write-Error "$ConfigFile missing."; exit 1 }

if (-not (Get-Command rsync -ErrorAction SilentlyContinue)) {
  Write-Host "rsync not on PATH. Run from WSL instead:" -ForegroundColor Yellow
  Write-Host "  wsl -- bash ~/.claude/skills/norml-wp-developer/scripts/deploy-to-staging.sh $Slug"
  exit 1
}

$cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
if (-not $cfg.staging) {
  Write-Error "No staging environment configured for $Slug."
  exit 1
}

$ThemeRoot  = $cfg.theme_root
$Alias      = $cfg.staging.ssh_alias
$ThemePath  = $cfg.staging.theme_path
$WpPath     = $cfg.staging.wp_path
$StagingUrl = $cfg.staging.url

Set-Location $ThemeRoot

if (Test-Path "package.json") { npm run build }
if (Test-Path "composer.json") { composer install --no-dev --optimize-autoloader --no-interaction }

$excludes = @(
  '--exclude=.git','--exclude=.github','--exclude=.claude',
  '--exclude=node_modules','--exclude=.env','--exclude=.env.*',
  '--exclude=.DS_Store','--exclude=Thumbs.db','--exclude=*.log'
)
& rsync -avz --delete @excludes "$ThemeRoot/" "${Alias}:${ThemePath}/"

ssh $Alias "cd '$WpPath' && wp cache flush 2>&1 || true"
if ((Test-Path "composer.json") -and (Select-String -Path "composer.json" -Pattern 'roots/acorn' -Quiet)) {
  ssh $Alias "cd '$WpPath' && wp acorn view:cache 2>&1 || true"
}

$code = (Invoke-WebRequest -Uri $StagingUrl -Method Head -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode
Write-Host "Smoke test: $StagingUrl -> HTTP $code"

$cl = Join-Path $ThemeRoot ".claude\changelog\daily.md"
if (Test-Path $cl) {
  $today = Get-Date -Format "yyyy-MM-dd"
  $time  = Get-Date -Format "HH:mm"
  $line  = "- $time -- [DEPLOY-STAGING] Theme rsync'd to staging."
  $body  = Get-Content $cl -Raw
  if ($body -match "(?m)^## $today.*$") {
    $body = $body -replace "(?m)^(## $today.*)`n", "`$1`n`n$line"
  } else {
    $first = [regex]::Match($body, "(?m)^## ")
    $new = "## $today`n`n$line`n`n"
    $body = if ($first.Success) { $body.Substring(0,$first.Index) + $new + $body.Substring($first.Index) } else { $body.TrimEnd() + "`n`n" + $new }
  }
  Set-Content -Path $cl -Value $body -Encoding UTF8
}

Write-Host "Done." -ForegroundColor White
