# Shared helpers for Easyfin PC Setup. Loaded by start.ps1 (and by a module run on its own).
# Must stay Windows PowerShell 5.1 compatible and ASCII-only.

$global:EasyfinRoot      = 'C:\Temp\Setup'
$global:EasyfinDownloads = Join-Path $global:EasyfinRoot 'downloads'
$global:EasyfinLogDir    = Join-Path $global:EasyfinRoot 'logs'

# ---------------------------------------------------------------- logging + output

function Initialize-SetupLog {
    if ($global:EasyfinLog) { return }
    New-Item -ItemType Directory -Path $global:EasyfinLogDir -Force | Out-Null
    $global:EasyfinLog = Join-Path $global:EasyfinLogDir ('setup-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Write-Log "Log started on $env:COMPUTERNAME by $env:USERNAME, PowerShell $($PSVersionTable.PSVersion)"
}

function Write-Log {
    param([string]$Message)
    if (-not $global:EasyfinLog) { return }
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $global:EasyfinLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Write-Title { param([string]$Text)
    Write-Host ''
    Write-Host ('=' * 60) -ForegroundColor DarkCyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor DarkCyan
    Write-Log "===== $Text ====="
}
function Write-Step { param([string]$Text) Write-Host ''; Write-Host ">> $Text" -ForegroundColor Cyan;      Write-Log "STEP  $Text" }
function Write-Ok   { param([string]$Text) Write-Host "   [OK]    $Text" -ForegroundColor Green;          Write-Log "OK    $Text" }
function Write-Skip { param([string]$Text) Write-Host "   [SKIP]  $Text" -ForegroundColor Yellow;         Write-Log "SKIP  $Text" }
function Write-Warn { param([string]$Text) Write-Host "   [WARN]  $Text" -ForegroundColor Yellow;         Write-Log "WARN  $Text" }
function Write-Fail { param([string]$Text) Write-Host "   [FAIL]  $Text" -ForegroundColor Red;            Write-Log "FAIL  $Text" }
function Write-Info { param([string]$Text) Write-Host "           $Text" -ForegroundColor Gray;           Write-Log "INFO  $Text" }

function Format-Duration {
    param([TimeSpan]$Span)
    if ($Span.TotalHours -ge 1) { return '{0}h {1:00}m' -f [int][math]::Floor($Span.TotalHours), $Span.Minutes }
    if ($Span.TotalMinutes -ge 1) { return '{0}m {1:00}s' -f [int][math]::Floor($Span.TotalMinutes), $Span.Seconds }
    return '{0}s' -f [int]$Span.TotalSeconds
}

# ---------------------------------------------------------------- checks

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Looks in every "Programs and Features" location (64-bit, 32-bit, per-user). $Pattern uses -like wildcards.
function Get-InstalledProgram {
    param([string]$Pattern)
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.DisplayName -like $Pattern -and -not $_.SystemComponent } |
        Select-Object DisplayName, DisplayVersion, UninstallString, QuietUninstallString, PSChildName
}

# Makes one restore point per run. Turns System Protection on first (often off on new PCs) and
# lifts Windows' "one per 24 hours" limit, which otherwise makes Checkpoint-Computer silently do nothing.
function New-SetupRestorePoint {
    param([string]$Description = 'Easyfin PC Setup')
    if ($global:EasyfinRestorePointMade) { Write-Skip 'Restore point already made this run.'; return }
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name SystemRestorePointCreationFrequency -Value 0 -Type DWord
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        $global:EasyfinRestorePointMade = $true
        Write-Ok 'Restore point made - you can roll back to this moment if anything goes wrong.'
    } catch {
        Write-Warn "Could not make a restore point: $($_.Exception.Message)"
    }
}

# Elevated sessions often can't find winget on PATH even when it's installed; look in WindowsApps too.
function Get-WingetPath {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $found = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

# ---------------------------------------------------------------- downloads

# Streams a download with a live progress bar (MB, %, speed, time left).
# Uses a cookie container on purpose: OneDrive share links set a cookie on the first
# response and return 403 on the redirect without it.
function Save-Download {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$OutFile,
        [string]$Label = 'Downloading'
    )
    New-Item -ItemType Directory -Path (Split-Path $OutFile) -Force | Out-Null
    $part = "$OutFile.part"

    $req = [Net.HttpWebRequest]::Create($Url)
    $req.CookieContainer   = New-Object Net.CookieContainer
    $req.AllowAutoRedirect = $true
    $req.UserAgent         = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) EasyfinSetup'
    $req.Timeout           = 60000
    $req.ReadWriteTimeout  = 60000

    $resp = $req.GetResponse()
    $done = [long]0
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $total = $resp.ContentLength
        $in  = $resp.GetResponseStream()
        $out = [IO.File]::Create($part)
        try {
            $buf = New-Object byte[] 1048576
            $lastDraw = -1000
            while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                $out.Write($buf, 0, $n)
                $done += $n
                if ($sw.ElapsedMilliseconds - $lastDraw -ge 250) {
                    $lastDraw = $sw.ElapsedMilliseconds
                    $secs  = [math]::Max($sw.Elapsed.TotalSeconds, 0.1)
                    $speed = $done / $secs
                    $status = '{0:N1} MB' -f ($done / 1MB)
                    if ($total -gt 0) {
                        $pct  = [int](($done / $total) * 100)
                        $left = [int](($total - $done) / [math]::Max($speed, 1))
                        $status = '{0:N1} MB of {1:N1} MB  |  {2:N1} MB/s  |  {3} left' -f ($done / 1MB), ($total / 1MB), ($speed / 1MB), (Format-Duration ([TimeSpan]::FromSeconds($left)))
                        Write-Progress -Id 2 -ParentId 1 -Activity $Label -Status $status -PercentComplete $pct
                    } else {
                        $status = '{0}  |  {1:N1} MB/s' -f $status, ($speed / 1MB)
                        Write-Progress -Id 2 -ParentId 1 -Activity $Label -Status $status
                    }
                }
            }
        } finally {
            $out.Dispose()
            $in.Dispose()
        }
    } finally {
        $resp.Dispose()
        Write-Progress -Id 2 -Activity $Label -Completed
    }

    if ($total -gt 0 -and $done -ne $total) {
        Remove-Item $part -Force -ErrorAction SilentlyContinue
        throw "Download stopped early ($('{0:N1}' -f ($done/1MB)) MB of $('{0:N1}' -f ($total/1MB)) MB)."
    }
    Move-Item -Path $part -Destination $OutFile -Force
    Write-Info ('Downloaded {0:N1} MB in {1}' -f ($done / 1MB), (Format-Duration $sw.Elapsed))
}

# ---------------------------------------------------------------- running installers

# Starts a program and shows elapsed time in the progress bar until it exits.
# Returns the exit code. Treats a timeout as failure.
function Invoke-WithProgress {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$Arguments,
        [string]$Label = 'Installing',
        [string]$Hint = 'please wait',
        [int]$TimeoutMinutes = 30,
        [switch]$NoNewWindow
    )
    $startArgs = @{ FilePath = $FilePath; PassThru = $true; NoNewWindow = [bool]$NoNewWindow }
    if ($Arguments) { $startArgs.ArgumentList = $Arguments }
    $p = Start-Process @startArgs
    # Touching .Handle straight away is required: without it PS 5.1 often reports ExitCode as empty.
    $null = $p.Handle
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $p.HasExited) {
        if ($sw.Elapsed.TotalMinutes -ge $TimeoutMinutes) {
            Write-Progress -Id 2 -Activity $Label -Completed
            throw "$Label did not finish within $TimeoutMinutes minutes."
        }
        Write-Progress -Id 2 -ParentId 1 -Activity $Label -Status ('{0}  |  running for {1}' -f $Hint, (Format-Duration $sw.Elapsed))
        Start-Sleep -Milliseconds 500
    }
    Write-Progress -Id 2 -Activity $Label -Completed
    return $p.ExitCode
}

# ---------------------------------------------------------------- locked (private) values

# Private values (e.g. the Office download link) are stored in the public repo scrambled
# with AES-256. Only the setup password unscrambles them. Format: 'v1:' + base64(salt16 + iv16 + cipher).
# Changing the iteration count or format breaks every existing locked value - bump to 'v2:' instead.

function ConvertTo-PlainText {
    param([Security.SecureString]$Secure)
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

function Get-SecretKey {
    param([string]$Password, [byte[]]$Salt)
    $kdf = New-Object Security.Cryptography.Rfc2898DeriveBytes($Password, $Salt, 200000)
    try { , $kdf.GetBytes(32) } finally { $kdf.Dispose() }
}

function Protect-SetupSecret {
    param([Parameter(Mandatory)][string]$PlainText, [Parameter(Mandatory)][string]$Password)
    $salt = New-Object byte[] 16
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($salt); $rng.Dispose()
    $aes = [Security.Cryptography.Aes]::Create()
    try {
        $aes.Key = Get-SecretKey $Password $salt
        $aes.GenerateIV()
        $data = [Text.Encoding]::UTF8.GetBytes($PlainText)
        $cipher = $aes.CreateEncryptor().TransformFinalBlock($data, 0, $data.Length)
        return 'v1:' + [Convert]::ToBase64String([byte[]]($salt + $aes.IV + $cipher))
    } finally { $aes.Dispose() }
}

# Returns the plain text, or $null if the password is wrong.
function Unprotect-SetupSecret {
    param([Parameter(Mandatory)][string]$Locked, [Parameter(Mandatory)][string]$Password)
    if (-not $Locked.StartsWith('v1:')) { throw 'Unknown locked value format.' }
    $all = [Convert]::FromBase64String($Locked.Substring(3))
    $salt = [byte[]]$all[0..15]
    $iv = [byte[]]$all[16..31]
    $cipher = [byte[]]$all[32..($all.Length - 1)]
    $aes = [Security.Cryptography.Aes]::Create()
    try {
        $aes.Key = Get-SecretKey $Password $salt
        $aes.IV = $iv
        $plain = $aes.CreateDecryptor().TransformFinalBlock($cipher, 0, $cipher.Length)
        return [Text.Encoding]::UTF8.GetString($plain)
    } catch [Security.Cryptography.CryptographicException] {
        return $null
    } finally { $aes.Dispose() }
}

# Asks for the setup password (once per run, 3 tries) and returns the unlocked value.
# $Check guards against the rare wrong password that decrypts to garbage without an error.
function Unlock-SetupSecret {
    param([Parameter(Mandatory)][string]$Locked, [scriptblock]$Check = { $true })
    for ($try = 1; $try -le 3; $try++) {
        if (-not $global:EasyfinSetupPassword) {
            $global:EasyfinSetupPassword = Read-Host '   Setup password' -AsSecureString
        }
        $plain = Unprotect-SetupSecret -Locked $Locked -Password (ConvertTo-PlainText $global:EasyfinSetupPassword)
        if ($plain -and (& $Check $plain)) {
            Write-Log 'Setup password accepted.'
            return $plain
        }
        $global:EasyfinSetupPassword = $null
        Write-Fail "Wrong setup password (try $try of 3)."
    }
    throw 'Setup password was wrong 3 times.'
}

# ---------------------------------------------------------------- PC identity

# The portal recognises a PC by serial number, falling back to the motherboard UUID.
# No-name PCs report placeholder serials ("Default string", "To be filled by O.E.M." ...) that
# are identical across machines - those are returned as $null so two PCs never look like one.
function Get-PcIdentity {
    $junk = '^(|0+|none|n/?a|null|unknown|default string|system serial number|serial number|not specified|not applicable|chassis serial number|to be filled by o\.?e\.?m\.?|123456789|xxxxxxx+)$'
    $serial = "$((Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue).SerialNumber)".Trim()
    if ($serial -match $junk) {
        $serial = "$((Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).IdentifyingNumber)".Trim()
    }
    if ($serial -match $junk) { $serial = $null }
    $uuid = "$((Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".Trim().ToUpper()
    if ($uuid -match '^(|0{8}-0{4}-0{4}-0{4}-0{12}|F{8}-F{4}-F{4}-F{4}-F{12})$') { $uuid = $null }
    [pscustomobject]@{ SerialNumber = $serial; HardwareUuid = $uuid }
}

# ---------------------------------------------------------------- PC naming + PC details

# ============================ EDIT HERE: branches ============================
# PC name rule: <GROUP>-<TOWN>-<L|D><nn>, e.g. MIL-WORC-L01, BUD-WORC-D02 (Nico, 2 Oct 2026).
# Key = the name prefix, value = what is shown in the list. Keep in step with PORTAL-PLAN.md -
# the portal's own branch codes (CW, BUD ...) are different and are NOT used in PC names.
$Branches = [ordered]@{
    'MIL-WORC' = 'Miloans Worcester';     'MIL-CAPE' = 'Miloans Cape Town';   'MIL-HAML' = 'Miloans Hamlet'
    'MIL-WELL' = 'Miloans Wellington';    'MIL-STRA' = 'Miloans Strand';      'MIL-SWES' = 'Miloans Somerset West'
    'MIL-PAAR' = 'Miloans Paarl';         'MIL-TULB' = 'Miloans Tulbagh'
    'QUA-DDOR' = 'Qualiloans De Doorns';  'QUA-VILL' = 'Qualiloans Villiersdorp'; 'QUA-CERE' = 'Qualiloans Ceres'
    'QUA-BRED' = 'Qualiloans Bredasdorp'; 'QUA-CALE' = 'Qualiloans Caledon'
    'BUD-WORC' = 'Budget Worcester';      'BUD-GANS' = 'Budget Gansbaai';     'BUD-WOLS' = 'Budget Wolseley'
    'BUD-ROBE' = 'Budget Robertson';      'BUD-ONLI' = 'Budget Online';       'QCK-WORC' = 'Quickloans Worcester'
    'TLG-HEID' = 'The Loan Guy Heidelberg'; 'TLG-SWEL' = 'The Loan Guy Swellendam'; 'TLG-GEOR' = 'The Loan Guy George'
    'TLG-KNYS' = 'The Loan Guy Knysna';   'TLG-KILL' = 'The Loan Guy Killarney'; 'TLG-MAIT' = 'The Loan Guy Maitland'
    'HO-WORC'  = 'Head Office Worcester'; 'WBDC-WORC' = 'Worcester Budget Debt Collection'
}
# =============================================================================

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
        $left = '{0,2}. {1,-10} {2,-26}' -f ($i + 1), $codes[$i], $Branches[$codes[$i]]
        $right = ''
        if ($i + 1 -lt $codes.Count) { $right = '{0,2}. {1,-10} {2}' -f ($i + 2), $codes[$i + 1], $Branches[$codes[$i + 1]] }
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

    $name = '{0}-{1}{2:00}' -f $code, $kind, $num
    $ok = (Read-Host "   New name will be $name - OK? (Y/N)").Trim()
    if ($ok -match '^[Yy]') { return $name }
    Write-Info 'OK, let''s try again.'
    return (Read-PcName)
}

# Renames the PC unless it already has (or is already waiting for) that name.
function Set-PcName {
    param([Parameter(Mandatory)][string]$NewName)
    $pending = Get-PendingName
    if ($NewName -eq $env:COMPUTERNAME -or $NewName -eq $pending) {
        Write-Skip "PC is already named $NewName."
        return
    }
    Rename-Computer -NewName $NewName -Force -ErrorAction Stop -WarningAction SilentlyContinue
    $global:EasyfinRestartNeeded = $true
    Write-Ok "PC will be called $NewName after the restart."
}

# Get-PcInfo collects this PC's details; Save-PcInfo also writes them to C:\Temp\Setup\pc-info.json.
# AssetTag is the name the PC has in the asset list; it can differ from the Windows name until a rename.
# Needs no administrator rights - staff can run it on their own PC.
function Get-PcInfo {
    param([string]$AssetTag, [string]$UsedBy)
    $cs   = Get-CimInstance Win32_ComputerSystem
    $identity = Get-PcIdentity
    $os   = Get-CimInstance Win32_OperatingSystem
    $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $ver  = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
    # Chassis type, not "has a battery": desktops on a UPS report a battery too.
    $type = 'Desktop'
    foreach ($c in @((Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes)) {
        if (@(8, 9, 10, 11, 14, 30, 31, 32) -contains [int]$c) { $type = 'Laptop' }
    }
    $ramBytes = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
    if (-not $ramBytes) { $ramBytes = $cs.TotalPhysicalMemory }
    $macs = @(Get-CimInstance Win32_NetworkAdapter -Filter 'PhysicalAdapter=True' -ErrorAction SilentlyContinue |
        Where-Object { $_.MACAddress } | ForEach-Object { '{0} ({1})' -f $_.MACAddress, $_.NetConnectionID })
    $name = Get-PendingName
    if (-not $name) { $name = $env:COMPUTERNAME }
    if (-not $AssetTag) { $AssetTag = $name }

    $info = [ordered]@{
        AssetTag     = $AssetTag
        PcName       = $name
        UsedBy       = $UsedBy
        Type         = $type
        Make         = "$($cs.Manufacturer)".Trim()
        Model        = "$($cs.Model)".Trim()
        SerialNumber = $identity.SerialNumber      # $null when the maker left a placeholder
        HardwareUuid = $identity.HardwareUuid
        Processor    = "$($cpu.Name)".Trim()
        RamGB        = [math]::Round($ramBytes / 1GB)
        DiskGB       = [math]::Round($disk.Size / 1GB)
        Windows      = ("$($os.Caption) $ver").Trim()
        WindowsBuild = $os.BuildNumber
        MacAddresses = $macs
        WindowsUser  = $env:USERNAME
        RecordedOn   = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    }
    return $info
}

function Save-PcInfo {
    param([string]$AssetTag, [string]$UsedBy, [string]$Path = 'C:\Temp\Setup\pc-info.json')
    $info = Get-PcInfo -AssetTag $AssetTag -UsedBy $UsedBy
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    $info | ConvertTo-Json | Set-Content -Path $Path -Encoding UTF8
    foreach ($k in 'AssetTag', 'PcName', 'UsedBy', 'Type', 'Make', 'Model', 'SerialNumber', 'RamGB', 'Windows') { Write-Info ('{0,-13} {1}' -f $k, $info[$k]) }
    Write-Ok "Saved to $Path"
    return $info
}

# ---------------------------------------------------------------- portal link (asset register)

# The portal's "Set up a new PC" page prints a line that sets EASYFIN_PORTAL and EASYFIN_CODE.
# With both set, the script reads branches/staff from the portal and logs each PC in the asset
# register. Without them everything works as before, just without logging. API: PORTAL-API.md.
if ($env:EASYFIN_PORTAL -and -not $global:EasyfinPortal) { $global:EasyfinPortal = $env:EASYFIN_PORTAL.Trim().TrimEnd('/') }
if ($env:EASYFIN_CODE -and -not $global:EasyfinCode) { $global:EasyfinCode = $env:EASYFIN_CODE.Trim() }
$global:EasyfinPendingFile = 'C:\Temp\Setup\pending-portal.json'

function Test-PortalLinked { return [bool]($global:EasyfinPortal -and $global:EasyfinCode) }

# The setup code travels with every call, so the address must be https. Two exceptions, both for
# testing only: this PC itself (127.0.0.1), and the VPS's bare address before DNS cutover.
function Test-PortalAddressAllowed {
    param([string]$Address)
    if ($Address -match '^https://') { return $true }
    if ($Address -match '^http://127\.0\.0\.1(:\d+)?$') { return $true }
    # Nico's call 2 Oct 2026: allow the VPS's bare address until DNS cutover. REMOVE after cutover.
    if ($Address -eq 'http://41.222.36.148') { return $true }
    return $false
}

# Calls the portal. Returns the parsed reply. On a refusal it throws the portal's own plain
# sentence; the exception's Data['Status'] holds the HTTP status (0 = could not reach it at all).
function Invoke-Portal {
    param([string]$Method = 'GET', [Parameter(Mandatory)][string]$Path, $Body, [int]$TimeoutSeconds = 30)
    if (-not (Test-PortalLinked)) { throw 'Not linked to the portal.' }
    if (-not (Test-PortalAddressAllowed $global:EasyfinPortal)) {
        $ex = New-Object Exception("The portal address '$global:EasyfinPortal' is not a secure (https) address, so the setup code will not be sent to it.")
        $ex.Data['Status'] = -1
        throw $ex
    }
    $req = [Net.HttpWebRequest]::Create($global:EasyfinPortal + '/api/pc-setup' + $Path)
    $req.Method = $Method
    $req.Accept = 'application/json'
    $req.UserAgent = 'EasyfinSetup'
    $req.Timeout = $TimeoutSeconds * 1000
    $req.Headers['Authorization'] = "Bearer $global:EasyfinCode"
    if ($null -ne $Body) {
        $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Depth 6 -Compress))
        $req.ContentType = 'application/json'
        $req.ContentLength = $bytes.Length
        $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Dispose()
    }
    $resp = $null
    try { $resp = $req.GetResponse() }
    catch {
        # PS 5.1 wraps the WebException in a MethodInvocationException - dig it out.
        $web = $_.Exception
        while ($web -and $web -isnot [Net.WebException]) { $web = $web.InnerException }
        if ($web -and $web.Response) { $resp = $web.Response }
        else {
            $ex = New-Object Exception("Could not reach the portal ($($_.Exception.Message)).")
            $ex.Data['Status'] = 0
            throw $ex
        }
    }
    $status = [int]$resp.StatusCode
    $reader = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $text = $reader.ReadToEnd(); $reader.Dispose(); $resp.Dispose()
    $data = $null
    if ($text) { try { $data = $text | ConvertFrom-Json } catch { } }
    if ($status -ge 400) {
        $msg = "The portal answered with error $status."
        if ($data -and $data.error) { $msg = [string]$data.error }
        $ex = New-Object Exception($msg)
        $ex.Data['Status'] = $status
        throw $ex
    }
    return $data
}

# Builds the body for POST /assets from the PC's details (Get-PcInfo) and the choices made.
# $Pick: BranchCode, Kind ('laptop'|'desktop'), Tag, EmployeeMode ('keep'|'none'|'id'), EmployeeId.
function New-PortalAssetBody {
    param($Info, $Pick, [array]$Steps, [string]$ScriptVersion)
    $body = [ordered]@{
        serial_number   = $Info.SerialNumber
        hardware_uuid   = $Info.HardwareUuid
        asset_tag       = $Pick.Tag
        branch_code     = $Pick.BranchCode
        kind            = $Pick.Kind
        make            = $Info.Make
        model           = $Info.Model
        cpu             = $Info.Processor
        ram_gb          = $Info.RamGB
        disk_gb         = $Info.DiskGB
        windows_version = $Info.Windows
        windows_build   = "$($Info.WindowsBuild)"
        mac_addresses   = @($Info.MacAddresses | Select-Object -First 12)
        windows_user    = $Info.WindowsUser
        setup_date      = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
        steps           = @($Steps)
        script_version  = $ScriptVersion
    }
    # Leaving the key out means "do not touch who has it"; null means "nobody".
    if ($Pick.EmployeeMode -eq 'none') { $body.assigned_employee_id = $null }
    elseif ($Pick.EmployeeMode -eq 'id') { $body.assigned_employee_id = [int]$Pick.EmployeeId }
    if ($global:EasyfinOutlookEmail) { $body.outlook_email = $global:EasyfinOutlookEmail }
    return $body
}

# Sends the PC to the portal. If the portal cannot be reached (or the code ran out), the record is
# kept on the PC and sent on the next run. Real refusals (wrong branch, name taken) are not kept -
# repeating them would only fail again. Returns the portal's reply, or $null when it was kept for later.
function Send-PcToPortal {
    param([Parameter(Mandatory)]$Body)
    try {
        $r = Invoke-Portal -Method POST -Path '/assets' -Body $Body
        Remove-Item $global:EasyfinPendingFile -Force -ErrorAction SilentlyContinue
        Write-Ok ("Logged in the portal as {0} ({1})." -f $r.asset_tag, $r.result)
        return $r
    } catch {
        $status = $_.Exception.Data['Status']
        if ($status -eq 0 -or $status -eq 401 -or $status -eq 429 -or $status -ge 500) {
            New-Item -ItemType Directory -Path (Split-Path $global:EasyfinPendingFile) -Force | Out-Null
            ConvertTo-Json -InputObject $Body -Depth 6 | Set-Content -Path $global:EasyfinPendingFile -Encoding UTF8
            Write-Warn "Not logged in the portal yet: $($_.Exception.Message)"
            Write-Warn 'The details are saved on this PC and will be sent the next time setup runs here.'
            return $null
        }
        throw
    }
}

# Sends a record that could not be sent last time. Quiet when there is nothing waiting.
function Send-PendingToPortal {
    if (-not (Test-PortalLinked) -or -not (Test-Path $global:EasyfinPendingFile)) { return }
    try {
        $body = Get-Content $global:EasyfinPendingFile -Raw | ConvertFrom-Json
        Write-Info 'A record from last time was not sent - sending it now.'
        $r = Invoke-Portal -Method POST -Path '/assets' -Body $body
        Remove-Item $global:EasyfinPendingFile -Force -ErrorAction SilentlyContinue
        Write-Ok ("Logged in the portal as {0} ({1})." -f $r.asset_tag, $r.result)
    } catch {
        Write-Warn "Last time's record still could not be sent: $($_.Exception.Message)"
    }
}
