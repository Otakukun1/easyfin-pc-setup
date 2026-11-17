# Module: Final check - shows what is in place on this PC and leaves a short "read me" for the staff member.
# Run it last. Windows PowerShell 5.1, ASCII only.

# ============================ EDIT HERE ============================
# The one sentence at the bottom of the note that says who to talk to.
$SupportLine = 'Tell your branch manager - they will pass it on to IT.'
# What the note says is installed, and how the check decides it is. Name = the line in the note.
$Checks = @(
    @{ Name = 'Google Chrome';          Test = { [bool](Get-InstalledProgram 'Google Chrome*') } }
    @{ Name = 'Adobe Acrobat Reader';   Test = { [bool](Get-InstalledProgram '*Acrobat*') } }
    @{ Name = 'Microsoft Teams';        Test = { [bool](Get-InstalledProgram '*Teams*') -or [bool](Get-AppxPackage -AllUsers -Name 'MSTeams' -ErrorAction SilentlyContinue) } }
    @{ Name = 'AnyDesk';                Test = { [bool](Get-InstalledProgram 'AnyDesk*') } }
    @{ Name = 'TeamViewer';             Test = { [bool](Get-InstalledProgram 'TeamViewer*') } }
    @{ Name = 'AweSun';                 Test = { [bool](Get-InstalledProgram '*AweSun*') -or [bool](Get-InstalledProgram '*Sunlogin*') } }
    @{ Name = 'Outlook (Office 2013)';  Test = { [bool](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE' -ErrorAction SilentlyContinue) -or [bool](Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE' -ErrorAction SilentlyContinue) } }
    @{ Name = 'Easyfin bookmarks in Chrome'; Test = { [bool](Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Google\Chrome' -Name ManagedBookmarks -ErrorAction SilentlyContinue) } }
)
$NotePath = 'C:\Users\Public\Desktop\READ ME - your new PC.txt'
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

Write-Step 'Checking this PC'
$present = @()
$missing = @()
foreach ($c in $Checks) {
    $ok = $false
    try { $ok = [bool](& $c.Test) } catch { $ok = $false }
    if ($ok) { $present += $c.Name; Write-Ok $c.Name } else { $missing += $c.Name; Write-Fail "$($c.Name) - not found" }
}

$pcName = Get-PendingName
if (-not $pcName) { $pcName = $env:COMPUTERNAME }
if ($pcName -match '^[A-Z]{2,4}-[A-Z]{4}-[LD]\d{2}$') { Write-Ok "PC name $pcName follows the naming rule." }
else { $missing += 'PC name'; Write-Fail "PC name $pcName does not follow the naming rule (e.g. MIL-WORC-L01)." }
if ($pcName -ne $env:COMPUTERNAME) { Write-Warn "The new name $pcName only applies after a restart." }

# Virus protection, and whether Windows and Office are paid for (activated).
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    if ($mp.RealTimeProtectionEnabled) { Write-Ok 'Virus protection (Defender) is on.' }
    else {
        $other = @()
        try { $other = @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop | Where-Object { $_.displayName -notlike '*Defender*' } | Select-Object -ExpandProperty displayName) } catch { }
        if ($other.Count -gt 0) { Write-Ok ('Virus protection: ' + ($other -join ', ')) }
        else { $missing += 'Virus protection'; Write-Fail 'Virus protection is OFF - restart, then run Clean-up again.' }
    }
} catch { Write-Warn "Could not check virus protection: $($_.Exception.Message)" }
try {
    $win = @(Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -ErrorAction Stop)
    if ($win | Where-Object { $_.LicenseStatus -eq 1 }) { Write-Ok 'Windows is activated.' }
    else { $missing += 'Windows activation'; Write-Fail 'Windows is NOT activated. Settings > System > Activation shows why.' }
} catch { Write-Warn "Could not check Windows activation: $($_.Exception.Message)" }
$ospp = @("$env:ProgramFiles\Microsoft Office\Office15\OSPP.VBS", "${env:ProgramFiles(x86)}\Microsoft Office\Office15\OSPP.VBS") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($ospp) {
    try {
        $out = (& cscript.exe //Nologo $ospp /dstatus) -join "`n"
        if ($out -match '---LICENSED---') { Write-Ok 'Office 2013 is activated.' }
        else { $missing += 'Office activation'; Write-Fail 'Office 2013 is NOT activated. Open Word > File > Account to activate it.' }
    } catch { Write-Warn "Could not check Office activation: $($_.Exception.Message)" }
}

$failedSteps = @($global:EasyfinResults | Where-Object { $_.Result -ne 'OK' })
foreach ($f in $failedSteps) { $missing += "step: $($f.Module)"; Write-Fail "Setup step '$($f.Module)' failed earlier in this run." }

Write-Host ''
if ($missing.Count -eq 0) { Write-Ok 'All good - this PC is ready to hand over.' }
else { Write-Warn ('{0} thing(s) need a look: {1}' -f $missing.Count, ($missing -join ', ')) }

# --- the note
Write-Step 'Leaving a read-me for the staff member'
try {
    $n = @()
    $n += 'WELCOME TO YOUR NEW PC'
    $n += ('PC name: {0}' -f $pcName)
    $n += ('Set up on: {0}' -f (Get-Date -Format 'd MMMM yyyy'))
    $n += ''
    if ($present.Count -gt 0) {
        $n += 'WHAT IS ON THIS PC'
        foreach ($p in $present) { $n += ('  - {0}' -f $p) }
        $n += ''
    }
    $n += 'WHERE TO FIND THINGS'
    $n += '  - Outlook and Chrome should sit on the bar at the bottom of the screen after you next sign in.'
    $n += '    If they are not there, click Start and type their name.'
    $n += '  - Outlook and Teams open by themselves when the PC starts. Everything else is switched off'
    $n += '    on purpose so the PC starts quickly. Open other programs from the Start menu when you need them.'
    $n += '  - Chrome has the Easyfin bookmarks on the bar at the top.'
    $n += '  - PDF files open in Acrobat Reader, and web links open in Chrome.'
    $n += '  - The screen locks by itself after 10 minutes. Press Windows key + L to lock it when you walk away.'
    $n += ''
    $staffEmail = [string]$global:EasyfinStaffEmail
    if ($staffEmail) {
        $n += 'YOUR ACCOUNTS'
        $n += ('  - Email (Outlook): {0}' -f $staffEmail)
        $n += ('  - Teams: open Teams and sign in with {0} (choose "Work or school").' -f $staffEmail)
        $n += '    If Microsoft asks for a code, it emails one to you - look in Outlook.'
        $n += ''
    }
    $n += 'IF SOMETHING IS NOT RIGHT'
    $n += '  1. Restart the PC first. Many small problems go away by themselves.'
    $n += '  2. If a program is missing, click Start and type its name before asking for help.'
    $n += ('  3. Still stuck? {0}' -f $SupportLine)
    $n += ''
    $n += 'You can delete this file once you have read it.'
    $text = ($n -join "`r`n") + "`r`n"
    New-Item -ItemType Directory -Path (Split-Path $NotePath) -Force | Out-Null
    Set-Content -Path $NotePath -Value $text -Encoding ASCII
    Write-Ok "Left the read-me on the Desktop: $NotePath"
} catch { Write-Warn "Could not leave the read-me: $($_.Exception.Message)" }

# --- tidy up: setup downloads (the Office installer alone is several GB).
# Logs, pc-info.json and pending-portal.json in C:\Temp\Setup stay - they are the record of this setup.
Write-Step 'Removing leftover setup files'
try {
    $freed = 0
    # Only a folder this setup made: none of C:\Temp, C:\Temp\Setup, downloads may be a link elsewhere,
    # and downloads must belong to administrators (a normal login could have made it first).
    $safe = Test-Path $global:EasyfinDownloads
    foreach ($p in @((Split-Path $global:EasyfinRoot), $global:EasyfinRoot, $global:EasyfinDownloads)) { if (Test-IsLink $p) { $safe = $false } }
    if ($safe -and -not (Test-AdminOwned $global:EasyfinDownloads)) { $safe = $false }
    if ((Test-Path $global:EasyfinDownloads) -and -not $safe) { Write-Warn 'Setup downloads left alone: that folder was not made by this setup. Delete C:\Temp\Setup\downloads by hand.' }
    if ($safe) {
        # Keep the Office installer until Office 2013 is really in, so a re-run after a restart needn't download it again.
        $officeIn = [bool](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE' -ErrorAction SilentlyContinue) -or
                    [bool](Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE' -ErrorAction SilentlyContinue)
        # This runs as administrator in a folder other logins can write to, so never follow a link or
        # junction out of it: walk it by hand, skip anything that is one, delete only plain files inside.
        $root = (Resolve-Path $global:EasyfinDownloads).Path.TrimEnd('\') + '\'
        $files = @(); $dirs = New-Object System.Collections.Queue; $dirs.Enqueue($root)
        while ($dirs.Count -gt 0) {
            foreach ($i in @(Get-ChildItem -LiteralPath $dirs.Dequeue() -Force -ErrorAction SilentlyContinue)) {
                if ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                if (-not $i.FullName.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { continue }
                if ($i.PSIsContainer) { $dirs.Enqueue($i.FullName) } else { $files += $i }
            }
        }
        foreach ($f in $files) {
            if ($f.Extension -eq '.iso') {
                if (-not $officeIn) { Write-Info 'Office installer kept - Office 2013 is not in yet.'; continue }
                try { Dismount-DiskImage -ImagePath $f.FullName -ErrorAction SilentlyContinue | Out-Null } catch { }
            }
            try { $len = $f.Length; Remove-Item $f.FullName -Force -ErrorAction Stop; $freed += $len } catch { }
        }
    }
    # Windows' own temp folders are left to Windows (Storage Sense): sweeping them as administrator
    # can be tricked by a planted link into deleting files elsewhere.
    Write-Ok ('Freed {0:N1} GB.' -f ($freed / 1GB))
} catch { Write-Warn "Could not remove all leftover files: $($_.Exception.Message)" }
