<#
.SYNOPSIS
  Inline Win32 wrapper for Windows Credential Manager.
  Lets PowerShell read, write, and delete generic credentials without
  requiring any external module (no CredentialManager from PSGallery,
  no SecretManagement). Works on Windows 10+ with stock PowerShell 5.1.

.USAGE
  . "$PSScriptRoot\lib\credman.ps1"
  Write-StoredCredential -Target "norml-wp-manager-acme" -Username "acme-admin" -SecurePassword $secure
  $plain = Read-StoredCredential -Target "norml-wp-manager-acme"
  Remove-StoredCredential -Target "norml-wp-manager-acme"
#>

if (-not ("WpManagerCredMan" -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WpManagerCredMan
{
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CREDENTIAL
    {
        public uint   Flags;
        public uint   Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint   CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint   Persist;
        public uint   AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("Advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="CredReadW")]
    public static extern bool CredRead(string target, uint type, uint flags, out IntPtr credentialPtr);

    [DllImport("Advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="CredWriteW")]
    public static extern bool CredWrite(ref CREDENTIAL credential, uint flags);

    [DllImport("Advapi32.dll", SetLastError=true)]
    public static extern void CredFree(IntPtr credential);

    [DllImport("Advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="CredDeleteW")]
    public static extern bool CredDelete(string target, uint type, uint flags);
}
"@
}

# Cred type constants
$script:CRED_TYPE_GENERIC        = 1
$script:CRED_PERSIST_LOCAL_MACH  = 2

function Write-StoredCredential {
  param(
    [Parameter(Mandatory=$true)][string]$Target,
    [Parameter(Mandatory=$true)][string]$Username,
    [Parameter(Mandatory=$true)][System.Security.SecureString]$SecurePassword
  )

  # SecureString -> Unicode byte array, via BSTR. Discard plaintext immediately
  # after writing into the Credential struct.
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
  try {
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
    $blob  = [System.Text.Encoding]::Unicode.GetBytes($plain)
    $cred  = New-Object WpManagerCredMan+CREDENTIAL
    $cred.Type               = $script:CRED_TYPE_GENERIC
    $cred.TargetName         = $Target
    $cred.UserName           = $Username
    $cred.Persist            = $script:CRED_PERSIST_LOCAL_MACH
    $cred.AttributeCount     = 0
    $cred.Attributes         = [IntPtr]::Zero
    $cred.CredentialBlobSize = [uint32]$blob.Length
    $cred.CredentialBlob     = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($blob.Length)
    [System.Runtime.InteropServices.Marshal]::Copy($blob, 0, $cred.CredentialBlob, $blob.Length)
    try {
      $ok = [WpManagerCredMan]::CredWrite([ref]$cred, 0)
      if (-not $ok) {
        $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "CredWrite failed for target '$Target' (Win32 error $err)"
      }
    } finally {
      [System.Runtime.InteropServices.Marshal]::FreeHGlobal($cred.CredentialBlob)
      # Zero the local byte array to reduce in-memory residue.
      for ($i = 0; $i -lt $blob.Length; $i++) { $blob[$i] = 0 }
    }
  } finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Read-StoredCredential {
  param([Parameter(Mandatory=$true)][string]$Target)

  $ptr = [IntPtr]::Zero
  $ok = [WpManagerCredMan]::CredRead($Target, $script:CRED_TYPE_GENERIC, 0, [ref]$ptr)
  if (-not $ok) {
    $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($err -eq 1168) {
      throw "Credential '$Target' not found in Windows Credential Manager. Re-run scripts\setup-windows.ps1."
    }
    throw "CredRead failed for '$Target' (Win32 error $err)"
  }
  try {
    $cred = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type][WpManagerCredMan+CREDENTIAL])
    $size = [int]$cred.CredentialBlobSize
    if ($size -le 0) { return "" }
    $buf  = New-Object byte[] $size
    [System.Runtime.InteropServices.Marshal]::Copy($cred.CredentialBlob, $buf, 0, $size)
    return [System.Text.Encoding]::Unicode.GetString($buf)
  } finally {
    [WpManagerCredMan]::CredFree($ptr)
  }
}

function Remove-StoredCredential {
  param([Parameter(Mandatory=$true)][string]$Target)
  $ok = [WpManagerCredMan]::CredDelete($Target, $script:CRED_TYPE_GENERIC, 0)
  if (-not $ok) {
    $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($err -eq 1168) { return $false }  # not found is fine
    throw "CredDelete failed for '$Target' (Win32 error $err)"
  }
  return $true
}
