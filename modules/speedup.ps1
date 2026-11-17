# Module: Speed-up - only Outlook and Teams start with Windows, fastest power and display settings,
# and no ads, tips, news panel, Copilot or Recall. Never touches virus protection, updates or security.
# Windows PowerShell 5.1, ASCII only.

# ============================ EDIT HERE ============================
# Start-up entries matching these are LEFT ON. Everything else that starts with Windows is switched off
# (still installed, and can be switched back on in Task Manager > Startup).
$KeepStartup = @(
    # what the staff member asked to have at start-up
    'Outlook*', 'Teams*', 'MSTeams*', 'com.squirrel.Teams.Teams',
    # files stay in step with the cloud
    'OneDrive*',
    # security and remote help - must never be switched off
    'SecurityHealth*', '*Defender*', 'AnyDesk*', 'TeamViewer*', 'Sunlogin*', 'AweSun*', '*Mesh*',
    # drivers and keys the PC needs to behave (sound, touchpad, Bluetooth, screen brightness keys, graphics)
    '*Realtek*', 'RtkAudio*', '*HD Audio*', '*Waves*', '*Synaptics*', '*Touchpad*', '*ELAN*', '*Bluetooth*', '*Wacom*',
    '*Hotkey*', '*Hot Key*', '*NVIDIA*', '*Radeon*', '*AMD*', 'igfx*', '*Intel*Graphics*'
)
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

function Test-KeepStartup {
    param([string[]]$Names)
    foreach ($n in $Names) { foreach ($p in $KeepStartup) { if ($n -like $p) { return $true } } }
    return $false
}

# Same "disabled" marker Task Manager writes (first byte 3). Deleting the entry would be permanent.
$disabledMark = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
function Disable-StartupEntry {
    param([string]$ApprovedKey, [string]$Name)
    $current = (Get-ItemProperty -Path $ApprovedKey -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($current -and $current[0] -eq 3) { Write-Skip "$Name already switched off."; return }
    New-Item -Path $ApprovedKey -Force | Out-Null
    New-ItemProperty -Path $ApprovedKey -Name $Name -Value $disabledMark -PropertyType Binary -Force | Out-Null
    Write-Ok "$Name will no longer start with Windows."
}

# --- 1. Outlook starts with Windows (Office 2013 does not do that by itself)
Write-Step 'Outlook at start-up'
try {
    $outlook = $null
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE') {
        $v = (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).'(default)'
        if ($v -and (Test-Path $v)) { $outlook = $v; break }
    }
    $startupDir = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp'
    $lnk = Join-Path $startupDir 'Outlook.lnk'
    if (-not $outlook) { Write-Skip 'Outlook is not installed yet - run this again after Office.' }
    elseif (Test-Path $lnk) { Write-Skip 'Outlook already starts with Windows.' }
    else {
        $sh = New-Object -ComObject WScript.Shell
        $s = $sh.CreateShortcut($lnk)
        $s.TargetPath = $outlook
        $s.WorkingDirectory = Split-Path $outlook
        $s.Save()
        Write-Ok 'Outlook will start with Windows.'
    }
} catch { Write-Warn "Could not set Outlook to start with Windows: $($_.Exception.Message)" }

# --- 2. switch off everything else that starts with Windows
Write-Step 'Switching off other start-up programs'
try {
    $runKeys = @(
        @{ Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
    )
    $kept = @()
    foreach ($rk in $runKeys) {
        $item = Get-Item -Path $rk.Key -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        foreach ($name in $item.GetValueNames()) {
            if (-not $name) { continue }
            if (Test-KeepStartup @($name)) { $kept += $name; continue }
            Disable-StartupEntry -ApprovedKey $rk.Approved -Name $name
        }
    }
    $folders = @(
        @{ Dir = (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp');   Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
        @{ Dir = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup');       Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
    )
    foreach ($f in $folders) {
        if (-not (Test-Path $f.Dir)) { continue }
        foreach ($file in (Get-ChildItem -Path $f.Dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })) {
            if (Test-KeepStartup @($file.BaseName, $file.Name)) { $kept += $file.BaseName; continue }
            Disable-StartupEntry -ApprovedKey $f.Approved -Name $file.Name
        }
    }
    if ($kept.Count -gt 0) { Write-Info ('Left on: ' + (($kept | Sort-Object -Unique) -join ', ')) }
} catch { Write-Warn "Could not switch off all start-up programs: $($_.Exception.Message)" }

# --- 3. comfort settings
Write-Step 'File endings and sleep settings'
function Invoke-ForCurrentAndNewUsers {
    param([scriptblock]$Do)
    & $Do 'HKCU:'
    $hive = "$env:SystemDrive\Users\Default\NTUSER.DAT"
    & reg.exe load 'HKU\EasyfinSpeed' $hive 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        try { & $Do 'Registry::HKEY_USERS\EasyfinSpeed' }
        finally {
            # reg unload fails while PowerShell still holds handles into the hive - collect first.
            [GC]::Collect(); [GC]::WaitForPendingFinalizers()
            & reg.exe unload 'HKU\EasyfinSpeed' 2>&1 | Out-Null
        }
    }
}
try {
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $already = ((Get-ItemProperty -Path $adv -Name HideFileExt -ErrorAction SilentlyContinue).HideFileExt -eq 0)
    Invoke-ForCurrentAndNewUsers {
        param($Root)
        $k = "$Root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        New-Item -Path $k -Force | Out-Null
        New-ItemProperty -Path $k -Name HideFileExt -Value 0 -PropertyType DWord -Force | Out-Null
    }
    if ($already) { Write-Skip 'File endings (.pdf, .docx) are already shown.' } else { Write-Ok 'File endings (.pdf, .docx) will be shown.' }
} catch { Write-Warn "Could not turn on file endings: $($_.Exception.Message)" }

try {
    $isLaptop = $false
    foreach ($c in @((Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes)) {
        if (@(8, 9, 10, 11, 14, 30, 31, 32) -contains [int]$c) { $isLaptop = $true }
    }
    if ($isLaptop) { Write-Skip 'Laptop - sleep settings left as they are (saves battery).' }
    else {
        & powercfg.exe /change standby-timeout-ac 0
        & powercfg.exe /change hibernate-timeout-ac 0
        Write-Ok 'Desktop will not go to sleep on its own.'
    }
} catch { Write-Warn "Could not change sleep settings: $($_.Exception.Message)" }

# --- 4. performance: fastest power setting when plugged in, no animations
Write-Step 'Fastest settings (power, animations)'
try {
    # Laptops keep the Balanced plan (Windows' own battery saving still works) but run at "Best performance"
    # when plugged in. Desktops also switch to the High performance plan where Windows offers it.
    $powerUser = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes'
    New-Item -Path $powerUser -Force | Out-Null
    New-ItemProperty -Path $powerUser -Name ActiveOverlayAcPowerScheme -Value 'ded574b5-45a0-4f42-8737-46345c09c238' -PropertyType String -Force | Out-Null
    Write-Ok 'Best performance when plugged in.'
    if (-not $isLaptop) {
        $high = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        if ((& powercfg.exe /list) -match $high) {
            & powercfg.exe /setactive $high
            Write-Ok 'Desktop uses the High performance power plan.'
        } else { Write-Skip 'This PC has no High performance plan - Balanced with best performance is used.' }
    }
} catch { Write-Warn "Could not change the power setting: $($_.Exception.Message)" }

try {
    Invoke-ForCurrentAndNewUsers {
        param($Root)
        # Same as "Adjust for best performance" in System > Advanced, but text stays smooth and
        # pictures still show as small previews. The mask bytes are Windows' own; don't "tidy" them.
        $vfx = "$Root\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        New-Item -Path $vfx -Force | Out-Null
        New-ItemProperty -Path $vfx -Name VisualFXSetting -Value 3 -PropertyType DWord -Force | Out-Null
        $desk = "$Root\Control Panel\Desktop"
        New-Item -Path $desk -Force | Out-Null
        New-ItemProperty -Path $desk -Name UserPreferencesMask -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) -PropertyType Binary -Force | Out-Null
        New-ItemProperty -Path $desk -Name FontSmoothing -Value '2' -PropertyType String -Force | Out-Null
        New-Item -Path "$desk\WindowMetrics" -Force | Out-Null
        New-ItemProperty -Path "$desk\WindowMetrics" -Name MinAnimate -Value '0' -PropertyType String -Force | Out-Null
        $adv = "$Root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        New-Item -Path $adv -Force | Out-Null
        New-ItemProperty -Path $adv -Name TaskbarAnimations -Value 0 -PropertyType DWord -Force | Out-Null
        $theme = "$Root\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        New-Item -Path $theme -Force | Out-Null
        New-ItemProperty -Path $theme -Name EnableTransparency -Value 0 -PropertyType DWord -Force | Out-Null
    }
    Write-Ok 'Animations and see-through effects off (shows from the next sign-in).'
} catch { Write-Warn "Could not switch off animations: $($_.Exception.Message)" }

# --- 5. no ads, tips, news panel, Copilot or Recall
Write-Step 'No ads, tips, news, Copilot or Recall'
try {
    $machine = @(
        @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh';                       Name = 'AllowNewsAndInterests';      Value = 0 }   # Windows 11 news panel
        @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds';     Name = 'EnableFeeds';                Value = 0 }   # Windows 10 news on the taskbar
        @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot';    Name = 'TurnOffWindowsCopilot';      Value = 1 }
        @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI';         Name = 'DisableAIDataAnalysis';      Value = 1 }   # Recall
        @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI';         Name = 'AllowRecallEnablement';      Value = 0 }
        @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search';    Name = 'EnableDynamicContentInWBS';  Value = 0 }   # search "highlights"
        @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent';      Name = 'DisableSoftLanding';         Value = 1 }
    )
    foreach ($m in $machine) {
        New-Item -Path $m.Key -Force | Out-Null
        New-ItemProperty -Path $m.Key -Name $m.Name -Value $m.Value -PropertyType DWord -Force | Out-Null
    }
    Invoke-ForCurrentAndNewUsers {
        param($Root)
        $cdm = "$Root\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        New-Item -Path $cdm -Force | Out-Null
        # Lock-screen ads and "fun facts", tips, Settings suggestions, welcome pages after updates.
        foreach ($n in 'RotatingLockScreenOverlayEnabled', 'SoftLandingEnabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338389Enabled',
                       'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled', 'SubscribedContent-310093Enabled') {
            New-ItemProperty -Path $cdm -Name $n -Value 0 -PropertyType DWord -Force | Out-Null
        }
        $adv = "$Root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        New-Item -Path $adv -Force | Out-Null
        New-ItemProperty -Path $adv -Name Start_IrisRecommendations -Value 0 -PropertyType DWord -Force | Out-Null   # ads in Start
        New-ItemProperty -Path $adv -Name ShowSyncProviderNotifications -Value 0 -PropertyType DWord -Force | Out-Null  # ads in File Explorer
        $eng = "$Root\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
        New-Item -Path $eng -Force | Out-Null
        New-ItemProperty -Path $eng -Name ScoobeSystemSettingEnabled -Value 0 -PropertyType DWord -Force | Out-Null   # "finish setting up your PC"
        $exp = "$Root\Software\Policies\Microsoft\Windows\Explorer"
        New-Item -Path $exp -Force | Out-Null
        New-ItemProperty -Path $exp -Name DisableSearchBoxSuggestions -Value 1 -PropertyType DWord -Force | Out-Null  # no web results in Start search
        $cop = "$Root\Software\Policies\Microsoft\Windows\WindowsCopilot"
        New-Item -Path $cop -Force | Out-Null
        New-ItemProperty -Path $cop -Name TurnOffWindowsCopilot -Value 1 -PropertyType DWord -Force | Out-Null
    }
    Write-Ok 'Ads, tips, news panel, web results in Start search, Copilot and Recall are off.'
} catch { Write-Warn "Could not switch off all ads and tips: $($_.Exception.Message)" }

Write-Ok 'Speed-up finished. Most of it shows after the next restart.'
