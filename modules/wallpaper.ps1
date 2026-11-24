# Module: Wallpaper - the group's own desktop picture, for every login on the PC. Only groups listed below
# get one; any other PC is skipped. Safe to run again.
# Windows PowerShell 5.1, ASCII only.

# ============================ EDIT HERE ============================
# Group name exactly as the portal shows it (Setup > Branches) => picture in the project's assets folder.
$Wallpapers = [ordered]@{
    'Miloans' = 'assets/wallpapers/miloans.jpg'
}
# Used only when the portal did not say which group the PC is in: PC name start => group.
$GroupByPcName = @{ MIL = 'Miloans'; QUA = 'Qualiloans'; BUD = 'Budget'; QCK = 'Budget'; TLG = 'The Loan Guy' }
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

# --- 1. which group
Write-Step 'Which group is this PC in?'
$pcName = [string]$global:EasyfinPcName
if (-not $pcName) { $pcName = Get-PendingName }
if (-not $pcName) { $pcName = $env:COMPUTERNAME }
$group = [string]$global:EasyfinGroup
if (-not $group) { $group = $GroupByPcName[$pcName.Split('-')[0].ToUpper()] }
if (-not $group -or -not $Wallpapers.Contains($group)) {
    Write-Skip ("{0} is not in a group with its own wallpaper (only: {1})." -f $pcName, (@($Wallpapers.Keys) -join ', '))
    return
}
Write-Info "$pcName is in $group."

# --- 2. get the picture
Write-Step "Getting the $group wallpaper"
$isAdmin = Test-IsAdmin
# Admin: kept where every login can read it but only administrators can change it.
if ($isAdmin) { $dir = Join-Path $env:ProgramData 'Easyfin'; Initialize-LockedFolder $dir }
else { $dir = Join-Path $env:APPDATA 'Easyfin'; New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$file = Join-Path $dir ('wallpaper-{0}.jpg' -f ($group -replace '[^A-Za-z0-9]', '').ToLower())
$base = 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main'
if ($env:EASYFIN_BRANCH -match '^[A-Za-z0-9._-]+$') { $base = 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/' + $env:EASYFIN_BRANCH }
$part = "$file.part"
$old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
try { Invoke-WebRequest -Uri ('{0}/{1}?t={2}' -f $base, $Wallpapers[$group], [DateTime]::UtcNow.Ticks) -OutFile $part -UseBasicParsing }
finally { $ProgressPreference = $old }
if ((Get-Item $part).Length -lt 20KB) { Remove-Item $part -Force; throw 'The wallpaper download came back empty.' }
Move-Item -Path $part -Destination $file -Force
Write-Ok "Saved to $file"

# --- 3. put it on every login's desktop: this one now, the others at their next sign-in, new logins too
Write-Step 'Setting the wallpaper'
function Set-WallpaperValues {
    param([string]$Root)
    $k = "$Root\Control Panel\Desktop"
    New-Item -Path $k -Force | Out-Null
    New-ItemProperty -Path $k -Name Wallpaper -Value $file -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $k -Name WallpaperStyle -Value '10' -PropertyType String -Force | Out-Null   # 10 = Fill the screen
    New-ItemProperty -Path $k -Name TileWallpaper -Value '0' -PropertyType String -Force | Out-Null
}

Set-WallpaperValues 'HKCU:'
Add-Type -Namespace EasyfinWall -Name Native -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SystemParametersInfo(int a, int b, string c, int d);' -ErrorAction SilentlyContinue
# 20 = set desktop wallpaper; 3 = save it and tell open windows.
[void][EasyfinWall.Native]::SystemParametersInfo(20, 0, $file, 3)
Write-Ok "Set for $env:USERNAME."

if ($isAdmin) {
    $done = 0
    $profiles = @(Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath -and (Test-Path $_.LocalPath) })
    $mySid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($p in $profiles) {
        if ($p.SID -eq $mySid) { continue }
        try {
            if (Test-Path "Registry::HKEY_USERS\$($p.SID)") { Set-WallpaperValues "Registry::HKEY_USERS\$($p.SID)"; $done++; continue }
            $hive = Join-Path $p.LocalPath 'NTUSER.DAT'
            if (-not (Test-Path $hive)) { continue }
            & reg.exe load 'HKU\EasyfinWall' $hive 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { continue }
            try { Set-WallpaperValues 'Registry::HKEY_USERS\EasyfinWall'; $done++ }
            finally {
                # reg unload fails while PowerShell still holds handles into the hive - collect first.
                [GC]::Collect(); [GC]::WaitForPendingFinalizers()
                & reg.exe unload 'HKU\EasyfinWall' 2>&1 | Out-Null
            }
        } catch { Write-Warn "Could not set it for $($p.LocalPath): $($_.Exception.Message)" }
    }
    if ($done -gt 0) { Write-Ok "Set for $done other login(s) - they see it at their next sign-in." }

    $hive = "$env:SystemDrive\Users\Default\NTUSER.DAT"
    & reg.exe load 'HKU\EasyfinWallDefault' $hive 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        try { Set-WallpaperValues 'Registry::HKEY_USERS\EasyfinWallDefault'; Write-Ok 'New logins on this PC get it too.' }
        finally {
            [GC]::Collect(); [GC]::WaitForPendingFinalizers()
            & reg.exe unload 'HKU\EasyfinWallDefault' 2>&1 | Out-Null
        }
    }
}
Write-Ok "$group wallpaper done."
