#requires -Version 5.1
<#
.SYNOPSIS
  Verify the configured SSH alias for a project works. Read-only.

.PARAMETER Slug
  Project slug.

.PARAMETER Environment
  'production' (default) or 'staging'.
#>

param(
  [Parameter(Mandatory=$true, Position=0)][string]$Slug,
  [Parameter(Position=1)][ValidateSet('production','staging')][string]$Environment = 'production'
)

$ErrorActionPreference = "Stop"

$ConfigFile = Join-Path $env:USERPROFILE ".config\norml-wp-developer\projects\${Slug}.json"
if (-not (Test-Path $ConfigFile)) {
  Write-Error "$ConfigFile missing. Run scripts\setup-windows.ps1 first."
  exit 1
}

$cfg     = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$envCfg  = $cfg.$Environment
if (-not $envCfg) {
  Write-Error "No '$Environment' configured for $Slug."
  exit 1
}

$Url     = $envCfg.url
$Alias   = $envCfg.ssh_alias
$WpPath  = $envCfg.wp_path

if ([string]::IsNullOrWhiteSpace($Alias)) {
  Write-Error "No ssh_alias configured for $Environment on $Slug."
  exit 1
}

Write-Host "Project:  $Slug"
Write-Host "Env:      $Environment"
Write-Host "URL:      $Url"
Write-Host "Alias:    $Alias"
Write-Host "WP path:  $WpPath"
Write-Host ""

Write-Host "1. SSH handshake..."
$out = & ssh -o BatchMode=yes -o ConnectTimeout=10 $Alias "echo ok" 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "   FAIL -- check ~/.ssh/config alias '$Alias'." -ForegroundColor Red
  exit 1
}
Write-Host "   OK"

Write-Host "2. WP-CLI on remote..."
$wp = & ssh $Alias "cd '$WpPath' && wp --info 2>&1" 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "   FAIL -- wp-cli unavailable or wrong path." -ForegroundColor Red
  Write-Host $wp -ForegroundColor Red
  exit 1
}
($wp -split "`n" | Select-Object -First 8) | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "OK -- SSH and WP-CLI both working."
