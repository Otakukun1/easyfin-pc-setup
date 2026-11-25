# Old PC boost - NOT part of the work setup (nothing in start.ps1 or the window uses it).
# For an old home PC on Windows 10/11: Ultimate Performance power plan, no animations, no background
# apps, no search indexing, no ads/tips, tidy + defrag, then optionally Office 2013.
#   irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/extras/old-pc-boost.ps1 | iex
# Never touches virus protection, Windows Update or the firewall. Safe to run twice.
# Windows PowerShell 5.1, ASCII only. Runs via iex: never 'exit', use 'return'.

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Repo = 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main'

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host '  Run this as ADMINISTRATOR: right-click Start > Terminal (Admin) / Windows PowerShell (Admin).' -ForegroundColor Red
    return
}
. ([scriptblock]::Create((Invoke-RestMethod "$Repo/lib/common.ps1" -UseBasicParsing)))
$global:EasyfinSetupLoaded = $true
Initialize-SetupLog
Write-Title 'Old PC boost'

Write-Step 'Restore point (a way back if anything feels wrong)'
New-SetupRestorePoint 'Before old PC boost'

# --- power: Ultimate Performance (Windows' own hidden plan), never slow the processor down
Write-Step 'Ultimate Performance power plan'
try {
    $ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    $list = (& powercfg.exe /list) -join "`n"
    $guid = $null
    foreach ($line in ($list -split "`n")) { if ($line -match 'Ultimate Performance' -and $line -match '([0-9a-f-]{36})') { $guid = $Matches[1] } }
    if (-not $guid) {
        $out = (& powercfg.exe -duplicatescheme $ultimate) -join ' '
        if ($out -match '([0-9a-f-]{36})') { $guid = $Matches[1] }
    }
    if ($guid) {
        & powercfg.exe /setactive $guid
        # Processor never below 100% when plugged in.
        & powercfg.exe /setacvalueindex $guid SUB_PROCESSOR PROCTHROTTLEMIN 100
        & powercfg.exe /setactive $guid
        Write-Ok 'Ultimate Performance is on. (On battery it drains faster - normal.)'
    } else { Write-Warn 'This Windows would not add Ultimate Performance - left the plan as it was.' }
} catch { Write-Warn "Power plan: $($_.Exception.Message)" }

# --- look and feel: speed over looks (text stays smooth)
Write-Step 'No animations or see-through effects'
try {
    $vfx = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    New-Item -Path $vfx -Force | Out-Null
    New-ItemProperty -Path $vfx -Name VisualFXSetting -Value 3 -PropertyType DWord -Force | Out-Null
    $desk = 'HKCU:\Control Panel\Desktop'
    # Windows' own "best performance" bytes; don't tidy them.
    New-ItemProperty -Path $desk -Name UserPreferencesMask -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) -PropertyType Binary -Force | Out-Null
    New-ItemProperty -Path $desk -Name FontSmoothing -Value '2' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $desk -Name MenuShowDelay -Value '0' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path "$desk\WindowMetrics" -Name MinAnimate -Value '0' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name TaskbarAnimations -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name EnableTransparency -Value 0 -PropertyType DWord -Force | Out-Null
    Write-Ok 'Done (shows after signing out and in).'
} catch { Write-Warn "Effects: $($_.Exception.Message)" }

# --- background work the PC does for nothing
Write-Step 'Background apps, ads, tips, Game Bar off'
try {
    $bg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
    New-Item -Path $bg -Force | Out-Null
    New-ItemProperty -Path $bg -Name GlobalUserDisabled -Value 1 -PropertyType DWord -Force | Out-Null
    $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
    New-Item -Path $pol -Force | Out-Null
    New-ItemProperty -Path $pol -Name LetAppsRunInBackground -Value 2 -PropertyType DWord -Force | Out-Null
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    New-Item -Path $cdm -Force | Out-Null
    foreach ($n in 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled', 'RotatingLockScreenOverlayEnabled',
                   'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-353694Enabled') {
        New-ItemProperty -Path $cdm -Name $n -Value 0 -PropertyType DWord -Force | Out-Null
    }
    $feeds = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'
    New-Item -Path $feeds -Force | Out-Null
    New-ItemProperty -Path $feeds -Name EnableFeeds -Value 0 -PropertyType DWord -Force | Out-Null
    $dvr = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
    New-Item -Path $dvr -Force | Out-Null
    New-ItemProperty -Path $dvr -Name AllowGameDVR -Value 0 -PropertyType DWord -Force | Out-Null
    Write-Ok 'Done.'
} catch { Write-Warn "Background: $($_.Exception.Message)" }

# --- search indexing keeps an old hard drive busy all day; searching still works, just a bit slower
Write-Step 'Search indexing off'
try {
    $svc = Get-Service WSearch -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -ne 'Stopped') { Stop-Service WSearch -Force -ErrorAction SilentlyContinue }
        Set-Service WSearch -StartupType Disabled
        Write-Ok 'Indexing off. (Turn back on: Services > Windows Search > Automatic.)'
    } else { Write-Skip 'Not on this PC.' }
} catch { Write-Warn "Indexing: $($_.Exception.Message)" }

# --- programs that start with Windows: list them, switch off the usual junk
Write-Step 'Programs that start with Windows'
$junk = @('Spotify*', 'Discord*', 'Steam*', 'EpicGamesLauncher*', 'CCleaner*', 'Skype*', 'MicrosoftEdgeAutoLaunch*', 'iTunesHelper',
          'Adobe*Updater*', 'AdobeAAMUpdater*', 'Opera*', 'uTorrent*', 'BitTorrent*', 'GoogleDriveSync*', 'Dropbox*', 'OneDrive*', 'McAfee*', 'Norton*', 'Avast*')
$mark = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)   # Task Manager's own "disabled" marker
foreach ($rk in @(@{ K = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; A = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
                  @{ K = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; A = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
                  @{ K = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; A = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' })) {
    $item = Get-Item -Path $rk.K -ErrorAction SilentlyContinue
    if (-not $item) { continue }
    foreach ($n in $item.GetValueNames()) {
        if (-not $n) { continue }
        $hit = $false; foreach ($j in $junk) { if ($n -like $j) { $hit = $true } }
        if (-not $hit) { Write-Info "Left on: $n"; continue }
        New-Item -Path $rk.A -Force | Out-Null
        New-ItemProperty -Path $rk.A -Name $n -Value $mark -PropertyType Binary -Force | Out-Null
        Write-Ok "$n no longer starts with Windows."
    }
}

# --- tidy and defrag
Write-Step 'Clearing temporary files'
$freed = 0
foreach ($t in @($env:TEMP)) {
    foreach ($f in @(Get-ChildItem $t -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) })) {
        try { $len = $f.Length; Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $freed += $len } catch { }
    }
}
Write-Ok ('Freed {0:N0} MB.' -f ($freed / 1MB))
Write-Step 'Old Windows update leftovers (can take 10-20 minutes on an old PC)'
& dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet /NoRestart
Write-Ok 'Done.'
Write-Step 'Optimising the drive (defrag on a hard drive, trim on an SSD - can take a while)'
try { Optimize-Volume -DriveLetter ($env:SystemDrive.TrimEnd(':')) -Verbose:$false -ErrorAction Stop; Write-Ok 'Done.' }
catch { Write-Warn "Drive optimise: $($_.Exception.Message)" }

# --- Office 2013 (same installer as the work setup; asks for the setup password)
Write-Host ''
$ans = Read-Host '   Install Office 2013 now? (Y/N)'
if ($ans -match '^[Yy]') {
    try { & ([scriptblock]::Create((Invoke-RestMethod "$Repo/modules/office.ps1" -UseBasicParsing))) | Out-Host }
    catch { Write-Fail "Office: $($_.Exception.Message)" }
}

Write-Host ''
Write-Ok 'All done. Restart the PC to feel the full difference.'
$r = Read-Host '   Restart now? (Y/N)'
if ($r -match '^[Yy]') { Restart-Computer -Force }
