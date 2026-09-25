# Module: Clean-up - removes bloatware, trial antivirus, preinstalled Office and junk startup items,
# and stops Windows re-installing sponsored apps. Safe to run again: anything already gone is skipped.

# ============================ EDIT HERE ============================
# Normal programs (Settings > Apps) to remove. * = anything.
# McAfee and preinstalled Office have their own special removal below - don't add them here.
$RemovePrograms = @(
    'Norton*', 'Avast*', 'AVG *', 'WildTangent*', 'ExpressVPN*', 'Dropbox*Promotion*', 'Booking.com*',
    'HP Wolf Security*', 'HP Security Update Service', 'HP Sure Click*', 'HP Documentation',
    'HP Connection Optimizer', 'HP JumpStart*', 'Acer Jumpstart*', 'Acer Collection*', 'Acer Product Registration*',
    'ASUS GiftBox*', 'Lenovo Welcome*', 'Amazon Music*', 'Spotify*', 'Candy Crush*'
)

# Store-style apps to remove, for everyone on the PC and for new staff profiles. * = anything.
$RemoveApps = @(
    # games and entertainment
    '*CandyCrush*', '*BubbleWitch*', '*MarchofEmpires*', 'king.com.*', '*Disney*', '*Netflix*', '*Hulu*',
    '*Spotify*', '*TikTok*', '*Instagram*', '*Facebook*', '*Twitter*', '*AmazonVideo*', '*PrimeVideo*',
    'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.GamingApp', 'Microsoft.XboxApp', 'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxGameOverlay', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI', 'Microsoft.ZuneVideo',
    # Microsoft extras staff don't need
    'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.Getstarted',
    'Microsoft.WindowsFeedbackHub', 'Microsoft.People', 'Microsoft.WindowsMaps', 'Microsoft.MixedReality.Portal',
    'Microsoft.Microsoft3DViewer', 'Microsoft.MSPaint', 'Microsoft.SkypeApp', 'Microsoft.YourPhone',
    'Microsoft.PowerAutomateDesktop', 'Microsoft.Windows.DevHome', 'Microsoft.Todos', 'Clipchamp.Clipchamp',
    'Microsoft.549981C3F5F10', '7EE7776C.LinkedInforWindows', '*ExpressVPN*', '*Booking*',
    # things that clash with Office 2013 / confuse staff
    'MicrosoftTeams',                       # PERSONAL Teams. Work Teams is 'MSTeams' and stays.
    'Microsoft.MicrosoftOfficeHub',         # "Microsoft 365 (Office)" / "Microsoft 365 Copilot" app
    'Microsoft.Office.OneNote',
    'Microsoft.OutlookForWindows',          # "new Outlook" - staff use Outlook 2013
    'microsoft.windowscommunicationsapps'   # old Mail and Calendar
)

# Never removed, even if a pattern above matches.
$KeepApps = @(
    'Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp', 'Microsoft.WindowsCalculator', 'Microsoft.Windows.Photos',
    'Microsoft.ScreenSketch', 'Microsoft.SecHealthUI', 'Microsoft.DesktopAppInstaller', 'Microsoft.Paint',
    'Microsoft.WindowsNotepad', 'Microsoft.MicrosoftStickyNotes', 'Microsoft.WindowsTerminal',
    'MicrosoftCorporationII.QuickAssist', 'MSTeams', 'Microsoft.MicrosoftEdge*', 'Microsoft.VCLibs*',
    'Microsoft.UI.Xaml*', 'Microsoft.NET.*', 'Microsoft.WindowsAppRuntime*'
)

# Things that start with Windows to switch off (they stay installed). Anything not on this
# list is only shown, never touched - so drivers, AnyDesk etc. keep working.
$DisableStartup = @(
    'Spotify*', 'Discord*', 'Steam*', 'EpicGamesLauncher*', 'CCleaner*', '*Cortana*', 'Skype*',
    'MicrosoftEdgeAutoLaunch*', 'com.squirrel.Teams.Teams', 'iTunesHelper', 'Amazon Music*', 'WildTangent*'
)
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

$steps = 6
function Set-CleanupProgress { param([int]$Step, [string]$Text)
    Write-Progress -Id 1 -ParentId 0 -Activity 'Clean-up' -Status ('Step {0} of {1}: {2}' -f $Step, $steps, $Text) -PercentComplete ([int]((($Step - 1) / $steps) * 100))
}
$problems = @()

# Splits an uninstall command into program + arguments.
function Split-Command {
    param([string]$Command)
    if ($Command -match '^\s*"([^"]+)"\s*(.*)$') { return @($Matches[1], $Matches[2]) }
    if ($Command -match '^\s*(.+?\.exe)\s*(.*)$') { return @($Matches[1], $Matches[2]) }
    return @($Command, '')
}

# --- 1. restore point
Set-CleanupProgress 1 'Restore point'
Write-Step 'Making a restore point before removing anything'
New-SetupRestorePoint 'Easyfin PC Setup - before clean-up'

# --- 2. McAfee (needs McAfee's own removal tool - its normal uninstaller leaves parts behind)
Set-CleanupProgress 2 'McAfee'
Write-Step 'McAfee'
if (Get-InstalledProgram 'McAfee*') {
    Write-Info ('Found: ' + ((Get-InstalledProgram 'McAfee*' | Select-Object -ExpandProperty DisplayName -Unique) -join ', '))
    try {
        $mcpr = Join-Path $global:EasyfinDownloads 'MCPR.exe'
        Save-Download -Url 'https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe' -OutFile $mcpr -Label 'Downloading McAfee removal tool'
        Write-Warn "McAfee's removal tool is opening. Click Next, agree, type the letters it shows, and let it finish."
        Write-Warn 'When it asks to restart, choose LATER - this script restarts once at the end.'
        [void](Invoke-WithProgress -FilePath $mcpr -Label 'McAfee removal tool' -Hint 'finish the steps in the McAfee window' -TimeoutMinutes 30)
        Remove-Item $mcpr -Force -ErrorAction SilentlyContinue
        $global:EasyfinRestartNeeded = $true
        if (Get-InstalledProgram 'McAfee*') { Write-Warn 'McAfee still shows as installed - it usually disappears after the restart.' }
        else { Write-Ok 'McAfee removed.' }
    } catch {
        Write-Fail "McAfee removal failed: $($_.Exception.Message)"; $problems += 'McAfee'
    }
} else {
    Write-Skip 'McAfee is not on this PC.'
}

# --- 3. other unwanted programs
Set-CleanupProgress 3 'Unwanted programs'
Write-Step 'Unwanted programs (trial antivirus, manufacturer extras)'
$found = @()
foreach ($pattern in $RemovePrograms) { $found += @(Get-InstalledProgram $pattern) }
$found = @($found | Where-Object { $_ } | Sort-Object DisplayName -Unique)
if ($found.Count -eq 0) { Write-Skip 'None found.' }
foreach ($prog in $found) {
    $name = $prog.DisplayName
    try {
        if ($prog.UninstallString -match 'msiexec' -and $prog.PSChildName -match '^\{.+\}$') {
            $code = Invoke-WithProgress -FilePath 'msiexec.exe' -Arguments "/x $($prog.PSChildName) /qn /norestart" -Label "Removing $name" -Hint 'removing silently'
        } elseif ($prog.QuietUninstallString) {
            $cmd = Split-Command $prog.QuietUninstallString
            $code = Invoke-WithProgress -FilePath $cmd[0] -Arguments $cmd[1] -Label "Removing $name" -Hint 'removing silently'
        } elseif ($prog.UninstallString) {
            Write-Warn "$name has no silent removal - its uninstaller is opening, click through it."
            $cmd = Split-Command $prog.UninstallString
            $code = Invoke-WithProgress -FilePath $cmd[0] -Arguments $cmd[1] -Label "Removing $name" -Hint 'finish the steps in its window'
        } else {
            throw 'no uninstaller registered'
        }
        if ($code -eq 3010 -or $code -eq 1641) { $global:EasyfinRestartNeeded = $true }
        if (Get-InstalledProgram $name) { Write-Fail "$name is still installed (code $code)."; $problems += $name }
        else { Write-Ok "$name removed." }
    } catch {
        Write-Fail "$name could not be removed: $($_.Exception.Message)"; $problems += $name
    }
}

# --- 4. preinstalled Office (Microsoft 365 / OneNote trials). Click-to-Run only - never touches Office 2013.
Set-CleanupProgress 4 'Preinstalled Office'
Write-Step 'Preinstalled Office trial'
$c2r = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction SilentlyContinue
if ($c2r -and $c2r.ProductReleaseIds) {
    Write-Info "Found: $($c2r.ProductReleaseIds)"
    try {
        $odtDir = Join-Path $global:EasyfinDownloads 'ODT'
        New-Item -ItemType Directory -Path $odtDir -Force | Out-Null
        $odt = Join-Path $odtDir 'setup.exe'
        Save-Download -Url 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile $odt -Label "Downloading Microsoft's Office removal tool"
        $xml = Join-Path $odtDir 'remove.xml'
        Set-Content -Path $xml -Encoding ASCII -Value '<Configuration><Remove All="TRUE" /><Display Level="None" AcceptEULA="TRUE" /></Configuration>'
        $code = Invoke-WithProgress -FilePath $odt -Arguments "/configure `"$xml`"" -Label 'Removing preinstalled Office' -Hint 'removing silently - can take 5-10 minutes' -TimeoutMinutes 45
        Write-Log "Office removal exit code: $code"
        Remove-Item $odtDir -Recurse -Force -ErrorAction SilentlyContinue
        $left = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction SilentlyContinue).ProductReleaseIds
        if ($left) { Write-Fail "Preinstalled Office still there: $left"; $problems += 'Preinstalled Office' }
        else { Write-Ok 'Preinstalled Office removed.' }
    } catch {
        Write-Fail "Preinstalled Office removal failed: $($_.Exception.Message)"; $problems += 'Preinstalled Office'
    }
} else {
    Write-Skip 'No preinstalled Office found.'
}

# --- 5. Store-style apps
Set-CleanupProgress 5 'Junk apps'
Write-Step 'Junk apps (games, ads, personal Teams, new Outlook)'
function Test-Kept { param([string]$Name) foreach ($k in $KeepApps) { if ($Name -like $k) { return $true } }; return $false }
$installed   = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
$provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
$removed = 0
foreach ($pattern in $RemoveApps) {
    $inst = @($installed | Where-Object { $_.Name -like $pattern -and -not (Test-Kept $_.Name) })
    $prov = @($provisioned | Where-Object { $_.DisplayName -like $pattern -and -not (Test-Kept $_.DisplayName) })
    if ($inst.Count -eq 0 -and $prov.Count -eq 0) { continue }
    $label = @($inst | Select-Object -ExpandProperty Name) + @($prov | Select-Object -ExpandProperty DisplayName) | Select-Object -First 1
    Write-Progress -Id 2 -ParentId 1 -Activity 'Removing apps' -Status $label
    try {
        foreach ($p in $inst) { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop }
        foreach ($p in $prov) { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null }
        Write-Ok "$label removed."
        $removed++
    } catch {
        Write-Fail "$label could not be removed: $($_.Exception.Message)"; $problems += $label
    }
}
Write-Progress -Id 2 -Activity 'Removing apps' -Completed
if ($removed -eq 0) { Write-Skip 'No junk apps found.' }

# Stop Windows quietly installing sponsored apps again - for this account and every new staff profile.
Write-Info 'Turning off sponsored app installs and suggestions'
$cdm = @{
    'ContentDeliveryAllowed' = 0; 'OemPreInstalledAppsEnabled' = 0; 'PreInstalledAppsEnabled' = 0
    'PreInstalledAppsEverEnabled' = 0; 'SilentInstalledAppsEnabled' = 0; 'SystemPaneSuggestionsEnabled' = 0
    'SubscribedContent-338388Enabled' = 0; 'SubscribedContent-338389Enabled' = 0; 'SubscribedContent-310093Enabled' = 0
    'SubscribedContent-353694Enabled' = 0; 'SubscribedContent-353696Enabled' = 0
}
function Set-CdmValues { param([string]$Root)
    $k = "$Root\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    New-Item -Path $k -Force | Out-Null
    foreach ($n in $cdm.Keys) { New-ItemProperty -Path $k -Name $n -Value $cdm[$n] -PropertyType DWord -Force | Out-Null }
}
try {
    $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
    New-Item -Path $pol -Force | Out-Null
    New-ItemProperty -Path $pol -Name DisableWindowsConsumerFeatures -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $pol -Name DisableConsumerAccountStateContent -Value 1 -PropertyType DWord -Force | Out-Null
    Set-CdmValues 'HKCU:'
    # The Default profile is the template every new staff login is copied from.
    $hive = "$env:SystemDrive\Users\Default\NTUSER.DAT"
    & reg.exe load 'HKU\EasyfinDefault' $hive | Out-Null
    if ($LASTEXITCODE -eq 0) {
        try { Set-CdmValues 'Registry::HKEY_USERS\EasyfinDefault' }
        finally {
            # reg unload fails while PowerShell still holds handles into the hive - collect first.
            [GC]::Collect(); [GC]::WaitForPendingFinalizers()
            & reg.exe unload 'HKU\EasyfinDefault' | Out-Null
        }
    }
    Write-Ok 'Sponsored apps and suggestions turned off.'
} catch {
    Write-Warn "Could not turn off all suggestions: $($_.Exception.Message)"
}

# --- 6. startup items
Set-CleanupProgress 6 'Startup items'
Write-Step 'Programs that start with Windows'
$runKeys = @(
    @{ Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
    @{ Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
    @{ Key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
)
# Same "disabled" marker Task Manager writes (first byte 3). Deleting the entry instead would be permanent.
$disabledMark = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
$kept = @()
foreach ($rk in $runKeys) {
    $item = Get-Item -Path $rk.Key -ErrorAction SilentlyContinue
    if (-not $item) { continue }
    foreach ($name in $item.GetValueNames()) {
        if (-not $name) { continue }
        $match = $false
        foreach ($p in $DisableStartup) { if ($name -like $p) { $match = $true } }
        if (-not $match) { $kept += $name; continue }
        $current = (Get-ItemProperty -Path $rk.Approved -Name $name -ErrorAction SilentlyContinue).$name
        if ($current -and $current[0] -eq 3) { Write-Skip "$name already switched off."; continue }
        New-Item -Path $rk.Approved -Force | Out-Null
        New-ItemProperty -Path $rk.Approved -Name $name -Value $disabledMark -PropertyType Binary -Force | Out-Null
        Write-Ok "$name will no longer start with Windows."
    }
}
if ($kept.Count -gt 0) { Write-Info ('Left alone (not on the junk list): ' + (($kept | Sort-Object -Unique) -join ', ')) }

Write-Progress -Id 1 -Activity 'Clean-up' -Completed
if ($problems.Count -gt 0) { throw ('Could not remove: ' + ($problems -join ', ')) }
Write-Ok 'Clean-up finished.'
if ($global:EasyfinRestartNeeded) { Write-Warn 'A restart is needed to finish - you will be asked at the end.' }
