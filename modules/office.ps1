# Module: Office 2013 - downloads Nico's Office installer (ISO) from OneDrive and runs its setup.
# Safe to run again: skips if Office 2013 is already installed, and reuses an already-downloaded ISO.

# ============================ EDIT HERE ============================
# The OneDrive link, locked with the setup password. To change it: put the new link in .env
# as OFFICE_ISO_LINK and run tools\lock-value.ps1, then paste the result here.
$LockedIsoLink = 'v1:7R7PNrkFzkMskLNitMBpLW8kV7gG5+QLBqD296vS6hiuCjkYVzlMmxafGmKl7WJisFfnSEJ83BwJMcTFTDCrGT1u2VJg8lvb8AY4SSK9ZID0wHu/r4C70asNZQpAxEucM7MlqgGuDtZA2RpIlLv0FmIhbOjg1JgCipAYC49enroZp4lK6qBEoMX+l3uRelavAFjkA9nc6yBl3ot2lS2Cqg=='
$IsoFileName   = 'OfficeInstaller.iso'
$MinIsoSizeMB  = 500    # smaller than this = OneDrive sent a sign-in page, not the ISO
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

function Test-Office2013 {
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Office\15.0\Common\InstallRoot', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\15.0\Common\InstallRoot') {
        $path = (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).Path
        if ($path -and (Test-Path (Join-Path $path 'WINWORD.EXE'))) { return $true }
    }
    return [bool](Get-InstalledProgram 'Microsoft Office*2013*')
}

$total = 4
function Set-OfficeProgress { param([int]$Step, [string]$Text)
    Write-Progress -Id 1 -ParentId 0 -Activity 'Office 2013' -Status ('Step {0} of {1}: {2}' -f $Step, $total, $Text) -PercentComplete ([int]((($Step - 1) / $total) * 100))
}

# --- 1. already installed?
Set-OfficeProgress 1 'Checking'
Write-Step 'Checking if Office 2013 is already installed'
if (Test-Office2013) {
    Write-Skip 'Office 2013 is already installed - moving on.'
    Write-Progress -Id 1 -Activity 'Office 2013' -Completed
    return
}
Write-Info 'Not installed.'

$newer = Get-InstalledProgram 'Microsoft 365*'
if (-not $newer) { $newer = Get-InstalledProgram 'Microsoft Office*20[12][0-9]*' | Where-Object { $_.DisplayName -notlike '*2013*' } }
if ($newer) {
    Write-Warn ('A different Office is already on this PC: ' + (($newer | Select-Object -ExpandProperty DisplayName -Unique) -join ', '))
    Write-Warn 'Office 2013 setup usually fails next to it. Run Clean-up (option 2) first, or remove it in Settings > Apps.'
    $ans = Read-Host '   Carry on anyway? (Y/N)'
    if ($ans -notmatch '^[Yy]') { throw 'Stopped: another Office version is installed.' }
}

# --- 2. download
Set-OfficeProgress 2 'Downloading'
Write-Step 'Getting the Office installer'
$iso = Join-Path $global:EasyfinDownloads $IsoFileName
$existing = Get-Item $iso -ErrorAction SilentlyContinue
if ($existing -and ($existing.Length / 1MB) -ge $MinIsoSizeMB) {
    Write-Skip ('Already downloaded ({0:N0} MB) - reusing it.' -f ($existing.Length / 1MB))
} else {
    $link = Unlock-SetupSecret -Locked $LockedIsoLink -Check { param($v) $v -like 'https://*' }
    if ($link -match '\?') { $link = "$link&download=1" } else { $link = "${link}?download=1" }
    Save-Download -Url $link -OutFile $iso -Label 'Downloading Office 2013'
    $sizeMB = (Get-Item $iso).Length / 1MB
    if ($sizeMB -lt $MinIsoSizeMB) {
        Remove-Item $iso -Force
        throw ('Downloaded file is only {0:N1} MB - the OneDrive link needs sign-in or has expired. Set it to "Anyone with the link".' -f $sizeMB)
    }
    Write-Ok 'Office installer downloaded.'
}

# --- 3. open the ISO and run setup
Set-OfficeProgress 3 'Running Office setup'
Write-Step 'Opening the installer and starting Office setup'
$disk = Get-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue
$mountedHere = $false
if (-not ($disk -and $disk.Attached)) {
    $disk = Mount-DiskImage -ImagePath $iso -PassThru
    $mountedHere = $true
}
try {
    $letter = $null
    for ($i = 0; $i -lt 20 -and -not $letter; $i++) {
        $letter = (Get-DiskImage -ImagePath $iso | Get-Volume -ErrorAction SilentlyContinue).DriveLetter
        if (-not $letter) { Start-Sleep -Milliseconds 500 }
    }
    if (-not $letter) { throw 'The installer opened but Windows gave it no drive letter.' }

    $setup = "$($letter):\setup.exe"
    if (-not (Test-Path $setup)) {
        $found = Get-ChildItem "$($letter):\" -Filter setup.exe -Recurse -Depth 1 -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $found) { throw "setup.exe not found on the installer ($($letter):\)." }
        $setup = $found.FullName
    }
    Write-Info "Found $setup"
    Write-Warn 'The Office setup window is opening - click through it (no product key needed for now).'
    $code = Invoke-WithProgress -FilePath $setup -Label 'Office 2013 setup' -Hint 'finish the steps in the Office window' -TimeoutMinutes 90
    Write-Log "Office setup exit code: $code"
} finally {
    if ($mountedHere) { Dismount-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue | Out-Null }
}

# --- 4. check
Set-OfficeProgress 4 'Checking'
Write-Step 'Checking Office 2013 is installed'
Write-Progress -Id 1 -Activity 'Office 2013' -Completed
if (-not (Test-Office2013)) { throw "Office setup closed (code $code) but Office 2013 is not installed - was setup cancelled?" }
Write-Ok 'Office 2013 is installed.'
Write-Info "The installer is kept at $iso so a re-run doesn't download it again. Delete it to free 800 MB."
