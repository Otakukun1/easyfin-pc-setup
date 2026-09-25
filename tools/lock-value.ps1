# Locks a private value (e.g. a download link) with the setup password, so it can sit in the public repo.
# Run on Nico's own PC, from the project folder:
#   powershell -ExecutionPolicy Bypass -File .\tools\lock-value.ps1 -Name OFFICE_ISO_LINK
# Reads SETUP_PASSWORD and the named value from .env (never uploaded). Prints the locked text to paste into a module.

param([string]$Name)

$root = Split-Path $PSScriptRoot
. (Join-Path $root 'lib\common.ps1')

$envFile = Join-Path $root '.env'
$vals = @{}
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)$') { $vals[$Matches[1]] = $Matches[2].Trim() }
    }
}

$password = $vals['SETUP_PASSWORD']
if (-not $password) { $password = ConvertTo-PlainText (Read-Host 'Setup password' -AsSecureString) }

$value = $null
if ($Name) { $value = $vals[$Name] }
if (-not $value) { $value = Read-Host 'Value to lock' }

$locked = Protect-SetupSecret -PlainText $value -Password $password
if ((Unprotect-SetupSecret -Locked $locked -Password $password) -ne $value) { throw 'Self-check failed - do not use this output.' }
Write-Host ''
Write-Host 'Paste this into the module:' -ForegroundColor Cyan
Write-Host $locked
