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
        Where-Object { $_.DisplayName -and $_.DisplayName -like $Pattern } |
        Select-Object DisplayName, DisplayVersion
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
        [int]$TimeoutMinutes = 30
    )
    $startArgs = @{ FilePath = $FilePath; PassThru = $true }
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
