#requires -Version 5.1
<#
.SYNOPSIS
  Pull production database (+ optionally uploads) down to local.

.NOTES
  Requires rsync + a local WP-CLI install on the user's PATH. Run from
  WSL for the smoothest experience.
#>

param(
  [Parameter(Mandatory=$true, Position=0)][string]$Slug,
  [switch]$NoUploads
)

$ErrorActionPreference = "Stop"
$ConfigFile = Join-Path $env:USERPROFILE ".config\norml-wp-developer\projects\${Slug}.json"
if (-not (Test-Path $ConfigFile)) { Write-Error "$ConfigFile missing."; exit 1 }

if (-not (Get-Command rsync -ErrorAction SilentlyContinue)) {
  Write-Host "rsync not on PATH. Recommend WSL:" -ForegroundColor Yellow
  Write-Host "  wsl -- bash ~/.claude/skills/norml-wp-developer/scripts/sync-from-prod.sh $Slug $(if ($NoUploads) { '--no-uploads' })"
  exit 1
}

if (-not (Get-Command wp -ErrorAction SilentlyContinue)) {
  Write-Host "wp (WP-CLI) not on PATH locally. Install or run from WSL." -ForegroundColor Yellow
  exit 1
}

$cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$ThemeRoot = $cfg.theme_root
$ProdSsh   = $cfg.production.ssh_alias
$ProdWp    = $cfg.production.wp_path
$ProdUrl   = $cfg.production.url
$LocalUrl  = $cfg.local.url

# Infer local WP root from theme path: theme is at {WP}/wp-content/themes/{name}
$LocalWpRoot = (Resolve-Path (Join-Path $ThemeRoot "..\..\..")).Path
if (-not (Test-Path (Join-Path $LocalWpRoot "wp-config.php"))) {
  Write-Error "Could not find wp-config.php at expected local WP root: $LocalWpRoot"
  exit 1
}

Write-Host "Production: $ProdUrl  ($ProdSsh)"
Write-Host "Local:      $LocalUrl  ($LocalWpRoot)"
Write-Host ""
$go = Read-Host "This will REPLACE your local database with production. Proceed? (y/N)"
if ($go -notmatch '^[Yy]') { Write-Host "Aborted." -ForegroundColor Yellow; exit 1 }

$ts = [int][double]::Parse((Get-Date -UFormat %s))
$remoteDump = "/tmp/norml-wp-dev-${Slug}-${ts}.sql"
$localDump  = Join-Path $env:TEMP "norml-wp-dev-${Slug}-${ts}.sql"

Write-Host "Exporting production DB..." -ForegroundColor White
ssh $ProdSsh "cd '$ProdWp' && wp db export '$remoteDump'"
& rsync -avz "${ProdSsh}:${remoteDump}" $localDump
ssh $ProdSsh "rm -f '$remoteDump'"

Write-Host "Importing locally..." -ForegroundColor White
Set-Location $LocalWpRoot
wp db import $localDump
Remove-Item $localDump

Write-Host "Search-replace..." -ForegroundColor White
$prodNoProto  = $ProdUrl  -replace '^https?://',''
$localNoProto = $LocalUrl -replace '^https?://',''
wp search-replace $ProdUrl $LocalUrl --all-tables --skip-columns=guid --report-changed-only
wp search-replace $prodNoProto $localNoProto --all-tables --skip-columns=guid --report-changed-only

if (-not $NoUploads) {
  Write-Host "Pulling uploads..." -ForegroundColor White
  & rsync -avz --info=progress2 "${ProdSsh}:${ProdWp}/wp-content/uploads/" "$LocalWpRoot/wp-content/uploads/"
}

# Log
$cl = Join-Path $ThemeRoot ".claude\changelog\daily.md"
if (Test-Path $cl) {
  $today = Get-Date -Format "yyyy-MM-dd"
  $time  = Get-Date -Format "HH:mm"
  $uploads = if ($NoUploads) { "without uploads" } else { "including uploads" }
  $line  = "- $time -- [PULL-DB] Production DB pulled to local ($uploads). search-replace done."
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
