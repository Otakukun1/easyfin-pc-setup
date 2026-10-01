# Module: PC settings - restore point, PC name, time zone + clock, region, PC info file.
# Safe to run again: anything already set is skipped. A new PC name needs a restart to take effect.

# ============================ EDIT HERE ============================
# Branch codes for the PC name rule EF-<code>-<L|D><nn>, e.g. EF-PRL-L01, EF-WBDC-D01.
# Same codes as the portal's branch list (Portal_New BranchSeeder.php, 1 Oct 2026) so the
# asset manager can match PCs to branches. Codes are 2-4 letters. Empty list = any 2-4 letters.
$Branches = [ordered]@{
    'CW'  = 'Miloans CW';      'MCT' = 'Miloans CT';     'HAM' = 'Hamlet';        'WEL' = 'Wellington'
    'STR' = 'Strand';          'SW'  = 'Somerset West';  'PRL' = 'Paarl'
    'DD'  = 'De Doorns';       'VIL' = 'Villiersdorp';   'CER' = 'Ceres';         'BRE' = 'Bredasdorp'
    'CAL' = 'Caledon'
    'BUD' = 'Budget CW (Worcester)'; 'GAN' = 'Gansbaai'; 'WOL' = 'Wolseley';      'ROB' = 'Robertson'
    'QCW' = 'Quickloans CW (Worcester)'; 'ONL' = 'Budget Online'
    'HEI' = 'Heidelberg';      'SWE' = 'Swellendam';     'GEO' = 'George';        'KNY' = 'Knysna'
    'KIL' = 'Killarney';       'MAI' = 'Maitland'
    'TUL' = 'Tulbagh'   # not in the portal's branch list yet (1 Oct 2026)
    'HO'  = 'Head Office Worcester'; 'WBDC' = 'Worcester Budget Debt Collection'
}
$TimeZoneId  = 'South Africa Standard Time'
$Culture     = 'en-ZA'        # date format, currency (R), numbers
$GeoId       = 209            # Windows' number for South Africa (location)
$InfoFile    = 'C:\Temp\Setup\pc-info.json'
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

$steps = 5
function Set-PcProgress { param([int]$Step, [string]$Text)
    Write-Progress -Id 1 -ParentId 0 -Activity 'PC settings' -Status ('Step {0} of {1}: {2}' -f $Step, $steps, $Text) -PercentComplete ([int]((($Step - 1) / $steps) * 100))
}

# Name Windows will use after the next restart (differs from $env:COMPUTERNAME while a rename is pending).
function Get-PendingName {
    (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ErrorAction SilentlyContinue).ComputerName
}

# Builds the name step by step: pick the branch by number, laptop/desktop, then the PC number.
# Returns '' to keep the current name.
function Read-PcName {
    $codes = @($Branches.Keys)
    Write-Info 'Branches:'
    for ($i = 0; $i -lt $codes.Count; $i += 2) {
        $left = '{0,2}. {1,-5} {2,-26}' -f ($i + 1), $codes[$i], $Branches[$codes[$i]]
        $right = ''
        if ($i + 1 -lt $codes.Count) { $right = '{0,2}. {1,-5} {2}' -f ($i + 2), $codes[$i + 1], $Branches[$codes[$i + 1]] }
        Write-Host "           $left $right" -ForegroundColor Gray
    }
    while ($true) {
        $pick = (Read-Host '   Branch number (Enter = keep the current PC name)').Trim()
        if (-not $pick) { return '' }
        $num = 0
        if ([int]::TryParse($pick, [ref]$num) -and $num -ge 1 -and $num -le $codes.Count) { $code = $codes[$num - 1]; break }
        if ($Branches.Contains($pick.ToUpper())) { $code = $pick.ToUpper(); break }
        Write-Fail "Pick a number from 1 to $($codes.Count)."
    }
    Write-Info "Branch: $code - $($Branches[$code])"

    # This laptop/desktop guess comes from the PC itself (chassis type), so Enter is usually right.
    $guess = 'D'
    foreach ($c in @((Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes)) {
        if (@(8, 9, 10, 11, 14, 30, 31, 32) -contains [int]$c) { $guess = 'L' }
    }
    $guessWord = 'desktop'; if ($guess -eq 'L') { $guessWord = 'laptop' }
    while ($true) {
        $kind = (Read-Host "   L = laptop, D = desktop (Enter = $guess, this looks like a $guessWord)").Trim().ToUpper()
        if (-not $kind) { $kind = $guess }
        if ($kind -eq 'L' -or $kind -eq 'D') { break }
        Write-Fail 'Type L or D.'
    }

    while ($true) {
        $n = (Read-Host '   PC number at that branch, 1-99 (e.g. 2 for the second laptop)').Trim()
        $num = 0
        if ([int]::TryParse($n, [ref]$num) -and $num -ge 1 -and $num -le 99) { break }
        Write-Fail 'Type a number from 1 to 99.'
    }

    $name = 'EF-{0}-{1}{2:00}' -f $code, $kind, $num
    $ok = (Read-Host "   New name will be $name - OK? (Y/N)").Trim()
    if ($ok -match '^[Yy]') { return $name }
    Write-Info 'OK, let''s try again.'
    return (Read-PcName)
}
# --- 1. restore point
Set-PcProgress 1 'Restore point'
Write-Step 'Restore point'
New-SetupRestorePoint 'Easyfin PC Setup - before PC settings'

# --- 2. PC name
Set-PcProgress 2 'PC name'
Write-Step 'PC name'
$pending = Get-PendingName
Write-Info "Current name: $env:COMPUTERNAME"
if ($pending -and $pending -ne $env:COMPUTERNAME) { Write-Info "Already renamed to $pending - waiting for a restart." }

$newName = $global:EasyfinPcName      # filled in up front by "Run everything" (later)
if (-not $newName) { $newName = Read-PcName }
if (-not $newName) {
    Write-Skip 'Keeping the current name.'
} elseif ($newName -eq $env:COMPUTERNAME -or $newName -eq $pending) {
    Write-Skip "PC is already named $newName."
} else {
    Rename-Computer -NewName $newName -Force -ErrorAction Stop -WarningAction SilentlyContinue
    $global:EasyfinRestartNeeded = $true
    Write-Ok "PC will be called $newName after the restart."
}
$finalName = Get-PendingName
if (-not $finalName) { $finalName = $env:COMPUTERNAME }

# --- 3. time zone and clock
Set-PcProgress 3 'Time zone and clock'
Write-Step 'Time zone and clock'
if ((Get-TimeZone).Id -eq $TimeZoneId) {
    Write-Skip "Time zone is already $TimeZoneId."
} else {
    Set-TimeZone -Id $TimeZoneId
    Write-Ok "Time zone set to $TimeZoneId."
}
try {
    Set-Service -Name W32Time -StartupType Automatic
    Start-Service -Name W32Time -ErrorAction Stop
    $out = & w32tm.exe /resync /force 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Ok ('Clock synced with the internet: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')) }
    else { Write-Warn "Clock sync did not work ($out) - check the time by hand." }
} catch {
    Write-Warn "Clock sync did not work: $($_.Exception.Message)"
}

# --- 4. region
Set-PcProgress 4 'Region'
Write-Step 'Region (date format, currency, location)'
if ((Get-Culture).Name -eq $Culture) { Write-Skip "Format is already $Culture." }
else { Set-Culture -CultureInfo $Culture; Write-Ok "Format set to $Culture (takes full effect after signing out)." }
if ((Get-WinHomeLocation).GeoId -eq $GeoId) { Write-Skip 'Location is already South Africa.' }
else { Set-WinHomeLocation -GeoId $GeoId; Write-Ok 'Location set to South Africa.' }
# Also apply to the sign-in screen and to every new staff login (Windows 11 22H2 and later only).
if (Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
    try {
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
        Write-Ok 'Region also applied to the sign-in screen and new staff logins.'
    } catch { Write-Warn "Could not copy region to new logins: $($_.Exception.Message)" }
} else {
    Write-Info 'This Windows version cannot copy region to new logins - each login gets it when they run this.'
}

# --- 5. PC info file (for the portal's asset manager later)
Set-PcProgress 5 'PC info'
Write-Step 'Saving PC details'
$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os   = Get-CimInstance Win32_OperatingSystem
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
$ver  = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
# Chassis type, not "has a battery": desktops on a UPS report a battery too.
$type = 'Desktop'
$chassis = @((Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes)
foreach ($c in $chassis) { if (@(8, 9, 10, 11, 14, 30, 31, 32) -contains [int]$c) { $type = 'Laptop' } }
$ramBytes = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
if (-not $ramBytes) { $ramBytes = $cs.TotalPhysicalMemory }
$macs = @(Get-CimInstance Win32_NetworkAdapter -Filter 'PhysicalAdapter=True' -ErrorAction SilentlyContinue |
    Where-Object { $_.MACAddress } | ForEach-Object { '{0} ({1})' -f $_.MACAddress, $_.NetConnectionID })

$info = [ordered]@{
    PcName       = $finalName
    Type         = $type
    Make         = "$($cs.Manufacturer)".Trim()
    Model        = "$($cs.Model)".Trim()
    SerialNumber = "$($bios.SerialNumber)".Trim()
    Processor    = "$($cpu.Name)".Trim()
    RamGB        = [math]::Round($ramBytes / 1GB)
    DiskGB       = [math]::Round($disk.Size / 1GB)
    Windows      = ("$($os.Caption) $ver").Trim()
    WindowsBuild = $os.BuildNumber
    MacAddresses = $macs
    SetUpOn      = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    SetUpBy      = $env:USERNAME
}
New-Item -ItemType Directory -Path (Split-Path $InfoFile) -Force | Out-Null
$info | ConvertTo-Json | Set-Content -Path $InfoFile -Encoding UTF8
foreach ($k in 'PcName', 'Type', 'Make', 'Model', 'SerialNumber', 'RamGB', 'Windows') { Write-Info ('{0,-13} {1}' -f $k, $info[$k]) }
Write-Ok "Saved to $InfoFile"

Write-Progress -Id 1 -Activity 'PC settings' -Completed
if ($global:EasyfinRestartNeeded) { Write-Warn 'Restart needed for the new PC name - you will be asked at the end.' }
