# Module: Defaults and taskbar - Chrome as the web browser, Acrobat Reader for PDFs, Chrome and Outlook on the taskbar.
# Best effort: Windows protects these choices, so each step can be ignored by Windows without failing the run.
# Windows PowerShell 5.1, ASCII only.

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

# Kept in ProgramData, not C:\Temp\Setup: the Windows policy below points at these files for every sign-in.
$dir = Join-Path $env:ProgramData 'Easyfin'
New-Item -ItemType Directory -Path $dir -Force | Out-Null

function Save-IfChanged {
    param([string]$Path, [string]$Text)
    if ((Test-Path $Path) -and ((Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue) -eq $Text)) { return $false }
    Set-Content -Path $Path -Value $Text -Encoding ASCII
    return $true
}
function Set-PolicyValue {
    param([string]$Key, [string]$Name, $Value, [string]$Type)
    New-Item -Path $Key -Force | Out-Null
    New-ItemProperty -Path $Key -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

# --- 1. default apps
Write-Step 'Default apps (Chrome for the web, Acrobat Reader for PDFs)'
try {
    $lines = @()
    if (Test-Path 'Registry::HKEY_CLASSES_ROOT\ChromeHTML') {
        foreach ($id in 'http', 'https', '.htm', '.html') { $lines += ('  <Association Identifier="{0}" ProgId="ChromeHTML" ApplicationName="Google Chrome" />' -f $id) }
    } else { Write-Skip 'Chrome is not installed - web browser default not set.' }
    $pdfId = $null
    foreach ($id in 'AcroExch.Document.DC', 'AcroExch.Document') { if (Test-Path "Registry::HKEY_CLASSES_ROOT\$id") { $pdfId = $id; break } }
    if ($pdfId) { $lines += ('  <Association Identifier=".pdf" ProgId="{0}" ApplicationName="Adobe Acrobat Reader" />' -f $pdfId) }
    else { Write-Skip 'Acrobat Reader is not installed - PDF default not set.' }

    if ($lines.Count -gt 0) {
        $xml = ('<?xml version="1.0" encoding="UTF-8"?>' + "`r`n" + '<DefaultAssociations>' + "`r`n" + ($lines -join "`r`n") + "`r`n" + '</DefaultAssociations>' + "`r`n")
        $xmlPath = Join-Path $dir 'DefaultApps.xml'
        $policyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        $set = (Get-ItemProperty -Path $policyKey -Name DefaultAssociationsConfiguration -ErrorAction SilentlyContinue).DefaultAssociationsConfiguration
        $changed = Save-IfChanged $xmlPath $xml
        if (-not $changed -and $set -eq $xmlPath) { Write-Skip 'Default apps already set.' }
        else {
            # Import covers staff logins created later; the policy covers the login that already exists (applied at each sign-in).
            & dism.exe /Online /Import-DefaultAppAssociations:"$xmlPath" | Out-Null
            if ($LASTEXITCODE -ne 0) { Write-Warn "Windows would not take the default apps for new logins (code $LASTEXITCODE)." }
            Set-PolicyValue $policyKey 'DefaultAssociationsConfiguration' $xmlPath 'String'
            Write-Ok 'Default apps set. They show from the next time the staff member signs in; Windows may still ask them to confirm.'
        }
    }
} catch { Write-Warn "Could not set the default apps: $($_.Exception.Message)" }

# --- 2. taskbar
Write-Step 'Taskbar (File Explorer, Chrome, Outlook)'
try {
    $programs = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
    $pins = @('        <taskbar:DesktopApp DesktopApplicationID="Microsoft.Windows.Explorer" />')
    $chrome = Join-Path $programs 'Google Chrome.lnk'
    if (Test-Path $chrome) { $pins += ('        <taskbar:DesktopApp DesktopApplicationLinkPath="{0}" />' -f $chrome) }
    else { Write-Skip 'Chrome shortcut not found - Chrome not pinned.' }
    $outlook = Get-ChildItem -Path $programs -Filter 'Outlook*.lnk' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($outlook) { $pins += ('        <taskbar:DesktopApp DesktopApplicationLinkPath="{0}" />' -f $outlook.FullName) }
    else { Write-Skip 'Outlook shortcut not found - Outlook not pinned.' }

    if ($pins.Count -gt 1) {
        $xml = (@(
            '<?xml version="1.0" encoding="utf-8"?>'
            '<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1">'
            '  <CustomTaskbarLayoutCollection PinListPlacement="Replace">'
            '    <defaultlayout:TaskbarLayout>'
            '      <taskbar:TaskbarPinList>'
        ) + $pins + @(
            '      </taskbar:TaskbarPinList>'
            '    </defaultlayout:TaskbarLayout>'
            '  </CustomTaskbarLayoutCollection>'
            '</LayoutModificationTemplate>'
        )) -join "`r`n"
        $xml += "`r`n"
        $xmlPath = Join-Path $dir 'TaskbarLayout.xml'
        $policyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
        $set = (Get-ItemProperty -Path $policyKey -Name StartLayoutFile -ErrorAction SilentlyContinue).StartLayoutFile
        $changed = Save-IfChanged $xmlPath $xml
        if (-not $changed -and $set -eq $xmlPath) { Write-Skip 'Taskbar already set.' }
        else {
            # Unlocked on purpose: staff can still unpin or add their own after the first sign-in.
            Set-PolicyValue $policyKey 'StartLayoutFile' $xmlPath 'String'
            Set-PolicyValue $policyKey 'LockedStartLayout' 0 'DWord'
            # New staff logins get the same layout from the Default profile.
            $shell = "$env:SystemDrive\Users\Default\AppData\Local\Microsoft\Windows\Shell"
            New-Item -ItemType Directory -Path $shell -Force | Out-Null
            Copy-Item -Path $xmlPath -Destination (Join-Path $shell 'LayoutModification.xml') -Force
            Write-Ok 'Taskbar set. The pins appear the next time the staff member signs in (Windows may ignore it - check then).'
        }
    }
} catch { Write-Warn "Could not set the taskbar: $($_.Exception.Message)" }

Write-Ok 'Defaults and taskbar finished.'
