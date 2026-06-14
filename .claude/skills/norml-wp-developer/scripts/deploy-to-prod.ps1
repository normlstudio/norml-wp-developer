#requires -Version 5.1
<#
.SYNOPSIS
  Deploy theme to production via rsync over SSH. Gated by backup
  acknowledgement.

.NOTES
  Requires `rsync` on PATH. Install via WSL (Ubuntu) or Git for
  Windows. From WSL, you'll typically just run the .sh script.
#>

param([Parameter(Mandatory=$true, Position=0)][string]$Slug)

$ErrorActionPreference = "Stop"
$ConfigFile = Join-Path $env:USERPROFILE ".config\norml-wp-developer\projects\${Slug}.json"
if (-not (Test-Path $ConfigFile)) { Write-Error "$ConfigFile missing."; exit 1 }

if (-not (Get-Command rsync -ErrorAction SilentlyContinue)) {
  Write-Host "rsync not on PATH." -ForegroundColor Red
  Write-Host "Recommend running deploy-to-prod.sh from WSL instead:" -ForegroundColor Yellow
  Write-Host "  wsl -- bash ~/.claude/skills/norml-wp-developer/scripts/deploy-to-prod.sh $Slug"
  exit 1
}

$cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$ThemeRoot  = $cfg.theme_root
$Alias      = $cfg.production.ssh_alias
$ThemePath  = $cfg.production.theme_path
$WpPath     = $cfg.production.wp_path
$ProdUrl    = $cfg.production.url
$Backup     = $cfg.ci_cd.backup_strategy

Set-Location $ThemeRoot

# Build + composer
if (Test-Path "package.json") {
  Write-Host "Building..." -ForegroundColor White
  npm run build
  if ($LASTEXITCODE -ne 0) { Write-Host "Build failed -- aborting." -ForegroundColor Red; exit 1 }
}
if (Test-Path "composer.json") {
  Write-Host "Composer install (no-dev)..." -ForegroundColor White
  composer install --no-dev --optimize-autoloader --no-interaction
}

# Backup gate
Write-Host ""
Write-Host "==================================================="
Write-Host " PRODUCTION DEPLOY -- BACKUP ACKNOWLEDGEMENT REQUIRED" -ForegroundColor White
Write-Host "==================================================="
Write-Host ""
Write-Host "  FROM: $ThemeRoot"
Write-Host "  TO:   ${Alias}:${ThemePath}"
Write-Host "  URL:  $ProdUrl"
Write-Host ""
Write-Host "Backup strategy: $Backup"
Write-Host ""
Write-Host "Type one of:"
Write-Host "  - I have a backup from {date}"
Write-Host "  - host backups verified"
Write-Host "  - abort"
Write-Host ""
$ack = (Read-Host "Your answer").ToLower().TrimEnd()
$proceed = ($ack -like "i have a backup from*") -or ($ack -eq "host backups verified")
if (-not $proceed) { Write-Host "Aborted." -ForegroundColor Yellow; exit 1 }

# Deploy
$excludes = @(
  '--exclude=.git','--exclude=.github','--exclude=.claude',
  '--exclude=node_modules','--exclude=.env','--exclude=.env.*',
  '--exclude=.DS_Store','--exclude=Thumbs.db','--exclude=*.log'
)
& rsync -avz --delete @excludes "$ThemeRoot/" "${Alias}:${ThemePath}/"

# Post-deploy
ssh $Alias "cd '$WpPath' && wp cache flush 2>&1 || true"
if ((Test-Path "composer.json") -and (Select-String -Path "composer.json" -Pattern 'roots/acorn' -Quiet)) {
  ssh $Alias "cd '$WpPath' && wp acorn view:cache 2>&1 || true"
}

# Smoke test
$code = (Invoke-WebRequest -Uri $ProdUrl -Method Head -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode
Write-Host "Smoke test: $ProdUrl -> HTTP $code"

# Log
$cl = Join-Path $ThemeRoot ".claude\changelog\daily.md"
if (Test-Path $cl) {
  $today = Get-Date -Format "yyyy-MM-dd"
  $time  = Get-Date -Format "HH:mm"
  $line  = "- $time -- [DEPLOY-PROD] Production deploy via rsync. Backup ack: `"$ack`"."
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
