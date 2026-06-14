#requires -Version 5.1
<#
.SYNOPSIS
  norml-wp-developer -- pop a native Windows credential dialog to capture
  a secret (SSH passphrase or GitHub PAT) and store it in Credential
  Manager.

.PARAMETER Kind
  Either 'ssh-passphrase' or 'github-pat'.

.PARAMETER Slug
  Project slug (kebab-case).

.EXAMPLE
  & "scripts\prompt-secret-windows.ps1" "ssh-passphrase" "acme-marketing"
#>

param(
  [Parameter(Mandatory=$true, Position=0)]
  [ValidateSet('ssh-passphrase', 'github-pat')]
  [string]$Kind,

  [Parameter(Mandatory=$true, Position=1)][string]$Slug
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib\credman.ps1")

switch ($Kind) {
  'ssh-passphrase' {
    $Target = "norml-wp-dev-${Slug}-ssh-passphrase"
    $Title  = "norml-wp-developer -- SSH passphrase for ${Slug}"
    $Body   = "Paste the passphrase for your SSH key.`n`nIt will be stored in Windows Credential Manager so ssh-agent can use it silently."
  }
  'github-pat' {
    $Target = "norml-wp-dev-${Slug}-github-pat"
    $Title  = "norml-wp-developer -- GitHub PAT for ${Slug}"
    $Body   = "Paste your GitHub Personal Access Token.`n`nIt will be stored in Windows Credential Manager. Make sure the token has 'repo' scope (and 'workflow' if you'll use Actions)."
  }
}

# Native Windows credential dialog. Password is masked; result is a
# PSCredential whose Password is a SecureString.
$cred = $null
try {
  $cred = $Host.UI.PromptForCredential($Title, $Body, "norml-wp-developer", "")
} catch {
  Write-Host "Cancelled." -ForegroundColor Yellow
  exit 1
}

if (-not $cred) {
  Write-Host "Cancelled." -ForegroundColor Yellow
  exit 1
}

# Convert SecureString -> plain briefly to strip trailing whitespace,
# then re-wrap.
$secure = $cred.Password
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $plain    = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
  $stripped = $plain.TrimEnd()
  if ([string]::IsNullOrWhiteSpace($stripped)) {
    Write-Host "Empty secret. Aborting." -ForegroundColor Red
    exit 1
  }
  $secure = New-Object System.Security.SecureString
  foreach ($c in $stripped.ToCharArray()) { $secure.AppendChar($c) }
  $secure.MakeReadOnly()
} finally {
  [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  $plain    = $null
  $stripped = $null
  [System.GC]::Collect()
}

try { Remove-StoredCredential -Target $Target | Out-Null } catch { }
Write-StoredCredential -Target $Target -Username "norml-wp-developer" -SecurePassword $secure

Write-Host "Stored ${Kind} under Credential Manager target '${Target}'."
