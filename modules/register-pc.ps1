# Module: Register this PC - for PCs already in use. Installs and removes nothing: it records the PC's
# details and who uses it, and (if wanted) gives it its new name. Safe to run again.
# Recording needs no administrator rights; renaming does.
# The details are saved on the PC now; sending them to the portal is added when the portal side is ready
# (see PORTAL-PLAN.md).

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

Write-Step 'Which PC is this?'
$pending = Get-PendingName
Write-Info "Current name: $env:COMPUTERNAME"
if ($pending -and $pending -ne $env:COMPUTERNAME) { Write-Info "Already renamed to $pending - waiting for a restart." }

# The window version fills these in up front; the menu version asks.
$tag = $global:EasyfinPcName
if (-not $tag) { $tag = Read-PcName }

$usedBy = $global:EasyfinUsedBy
if ($null -eq $usedBy) { $usedBy = (Read-Host '   Who uses this PC? (name - or just Enter if shared or nobody yet)').Trim() }

$rename = $global:EasyfinRename
if ($tag -and $null -eq $rename) {
    Write-Warn 'Renaming a PC that is in use can break shared printers or shared folders that other PCs reach by its old name.'
    $rename = (Read-Host "   Rename this PC to $tag now? It takes effect after a restart (Y/N)") -match '^[Yy]'
}

Write-Step 'PC name'
if (-not $tag) { Write-Skip 'No new name chosen - keeping the current name.' }
elseif ($rename) { Set-PcName $tag }
else { Write-Skip "Not renaming. It is recorded as $tag; Windows keeps calling it $env:COMPUTERNAME." }

Write-Step 'Recording this PC'
[void](Save-PcInfo -AssetTag $tag -UsedBy $usedBy)
Write-Info 'Not sent to the portal yet - that link is still being built.'
Write-Ok 'PC recorded.'
