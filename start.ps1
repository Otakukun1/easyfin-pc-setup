# Easyfin PC Setup - menu.
# Run on a new PC in PowerShell (as administrator):
#   irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/start.ps1 | iex
# Windows PowerShell 5.1 compatible. Keep this file ASCII-only.
# Runs via iex, so never use 'exit' here - it would close the admin window. Use 'return'.

# ============================ EDIT HERE ============================
$SetupVersion = '0.2 (test)'
$RepoBase     = 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main'
# Test copies: $env:EASYFIN_BRANCH='test'; in front of the line takes every file from that GitHub branch.
if ($env:EASYFIN_BRANCH -match '^[A-Za-z0-9._-]+$') { $RepoBase = 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/' + $env:EASYFIN_BRANCH }

# To add a module: put the file in modules\ and add one line here.
# Ready   = $false shows it greyed out as "coming soon".
# RunAll  = $false leaves it out of "Run everything".
$Modules = @(
    @{ Key = '1'; Name = 'PC settings';      File = 'modules/pc-settings.ps1';      Ready = $true ; RunAll = $true;  Info = 'restore point, PC name, time and region' }
    @{ Key = '2'; Name = 'Clean-up';         File = 'modules/cleanup.ps1';          Ready = $true ; RunAll = $true;  Info = 'bloatware, trial antivirus, startup junk' }
    @{ Key = '3'; Name = 'Apps';             File = 'modules/apps.ps1';             Ready = $true;  RunAll = $true;  Info = 'Chrome, AnyDesk, Teams, TeamViewer, AweSun, Acrobat Reader' }
    @{ Key = '4'; Name = 'Chrome bookmarks'; File = 'modules/chrome-bookmarks.ps1'; Ready = $true ; RunAll = $true;  Info = 'Easyfin bookmarks and folders' }
    @{ Key = '5'; Name = 'Office 2013';      File = 'modules/office.ps1';           Ready = $true;  RunAll = $true;  Info = 'from your own installer (needs setup password)' }
    @{ Key = '6'; Name = 'Windows updates';  File = 'modules/windows-update.ps1';   Ready = $true ; RunAll = $true;  Info = 'install everything available' }
    @{ Key = '7'; Name = 'Email account';    File = 'modules/email-account.ps1';    Ready = $true ; RunAll = $false; Info = "add a staff member's email to Outlook" }
    @{ Key = '8'; Name = 'Register this PC'; File = 'modules/register-pc.ps1';     Ready = $true ; RunAll = $false; Info = 'PC already in use: record its details and who uses it, optional rename' }
    @{ Key = '9'; Name = 'Speed-up';         File = 'modules/speedup.ps1';          Ready = $true ; RunAll = $true;  Info = 'only Outlook and Teams start with Windows, file endings, no sleep' }
    @{ Key = '10'; Name = 'Defaults, taskbar'; File = 'modules/defaults.ps1';       Ready = $true ; RunAll = $true;  Info = 'Chrome and Acrobat as default apps, Chrome and Outlook on the taskbar' }
    @{ Key = '11'; Name = 'Final check';     File = 'modules/handover.ps1';         Ready = $true ; RunAll = $true;  Info = 'checklist, activation, read-me on the Desktop, tidy up' }
    @{ Key = '12'; Name = 'Teams account';   File = 'modules/teams-account.ps1';    Ready = $true ; RunAll = $false; Info = 'sign the staff member in to Teams (work or school)' }
)
# ===================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'Continue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

# Run from a local copy of the project (for testing) if start.ps1 was started as a file next to lib\.
$LocalRoot = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'lib\common.ps1'))) { $LocalRoot = $PSScriptRoot }

function Get-SetupFile {
    param([string]$RelativePath)
    if ($LocalRoot) { return Get-Content -Path (Join-Path $LocalRoot $RelativePath) -Raw }
    # The query string gets past GitHub's 5-minute cache so a fresh push is picked up straight away.
    return Invoke-RestMethod -Uri ('{0}/{1}?t={2}' -f $RepoBase, $RelativePath, [DateTime]::UtcNow.Ticks) -UseBasicParsing
}

# The window is the main way in. Put $env:EASYFIN_MENU=1; in front of the line for this text menu
# instead. Also the fallback when the window cannot open.
if (-not $env:EASYFIN_MENU) {
    try {
        Write-Host '  Opening the setup window...' -ForegroundColor Cyan
        if ($LocalRoot) { & (Join-Path $LocalRoot 'gui\start-gui.ps1') }
        else { . ([scriptblock]::Create((Get-SetupFile 'gui/start-gui.ps1'))) }
        return
    } catch {
        Write-Host "  The setup window could not open ($($_.Exception.Message)) - using the text menu." -ForegroundColor Yellow
    }
}

# --- admin check (before anything touches the PC)
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ''
    Write-Host '  This must run as ADMINISTRATOR.' -ForegroundColor Red
    Write-Host '  Close this window, right-click PowerShell, choose "Run as administrator", and paste the line again.' -ForegroundColor Red
    Write-Host ''
    return
}

# --- load shared helpers
try {
    . ([scriptblock]::Create((Get-SetupFile 'lib/common.ps1')))
} catch {
    Write-Host "  Could not download the setup helpers: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '  Check the internet connection and try again.' -ForegroundColor Red
    return
}
$global:EasyfinSetupLoaded = $true
Initialize-SetupLog
$global:EasyfinResults = New-Object System.Collections.ArrayList
$global:EasyfinRestartNeeded = $false

function Show-Menu {
    Clear-Host
    Write-Host ''
    Write-Host '  ==========================================================' -ForegroundColor DarkCyan
    Write-Host ('    EASYFIN PC SETUP                       v{0}' -f $SetupVersion) -ForegroundColor Cyan
    Write-Host ('    PC: {0}   |   Admin: yes' -f $env:COMPUTERNAME) -ForegroundColor Gray
    if ($LocalRoot) { Write-Host '    Running from local copy (test mode)' -ForegroundColor Yellow }
    Write-Host '  ==========================================================' -ForegroundColor DarkCyan
    Write-Host ''
    foreach ($m in $Modules) {
        if ($m.Ready) {
            Write-Host ('    {0}  ' -f $m.Key) -ForegroundColor White -NoNewline
            Write-Host ('{0,-18}' -f $m.Name) -ForegroundColor Cyan -NoNewline
            Write-Host $m.Info -ForegroundColor Gray
        } else {
            Write-Host ('    {0}  {1,-18}(coming soon)' -f $m.Key, $m.Name) -ForegroundColor DarkGray
        }
    }
    Write-Host ''
    Write-Host '    A  ' -ForegroundColor White -NoNewline; Write-Host 'Run everything that is ready, in order' -ForegroundColor Cyan
    Write-Host '    Q  ' -ForegroundColor White -NoNewline; Write-Host 'Quit' -ForegroundColor Cyan
    Write-Host ''
}

function Invoke-SetupModule {
    param($Module, [int]$Index = 1, [int]$Count = 1)
    Write-Title ('{0} / {1}  -  {2}' -f $Index, $Count, $Module.Name)
    Write-Progress -Id 0 -Activity 'Easyfin PC Setup' -Status ('Module {0} of {1}: {2}' -f $Index, $Count, $Module.Name) -PercentComplete ([int]((($Index - 1) / $Count) * 100))
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $result = 'OK'; $detail = ''
    try {
        $code = Get-SetupFile $Module.File
        & ([scriptblock]::Create($code)) | Out-Host
    } catch {
        $result = 'Failed'
        $detail = $_.Exception.Message
        Write-Fail "$($Module.Name) failed: $detail"
        Write-Log ($_ | Out-String)
    }
    $sw.Stop()
    [void]$global:EasyfinResults.Add([pscustomobject]@{ Module = $Module.Name; Result = $result; Time = (Format-Duration $sw.Elapsed); Detail = $detail })
    Write-Log "RESULT $($Module.Name): $result $detail"
}

function Show-Summary {
    if ($global:EasyfinResults.Count -eq 0) { return }
    Write-Title 'Summary'
    foreach ($r in $global:EasyfinResults) {
        $colour = 'Green'; if ($r.Result -ne 'OK') { $colour = 'Red' }
        Write-Host ('   {0,-18} {1,-8} {2,8}   {3}' -f $r.Module, $r.Result, $r.Time, $r.Detail) -ForegroundColor $colour
        Write-Log ('SUMMARY {0} {1} {2} {3}' -f $r.Module, $r.Result, $r.Time, $r.Detail)
    }
    Write-Host ''
    Write-Host "   Log file: $global:EasyfinLog" -ForegroundColor Gray
}

function Confirm-Restart {
    if (-not $global:EasyfinRestartNeeded) { return }
    Write-Host ''
    $ans = Read-Host '   Some changes need a restart. Restart now? (Y/N)'
    if ($ans -match '^[Yy]') { Write-Log 'Restarting PC.'; Restart-Computer -Force }
    else { Write-Warn 'Remember to restart this PC before handing it over.' }
}

# --- main loop
$ready = @($Modules | Where-Object { $_.Ready })
while ($true) {
    Show-Menu
    $choice = (Read-Host '  Choose (several at once is fine, e.g. 3,5)').Trim().ToUpper()
    if ($choice -eq 'Q') { break }

    $picked = @()
    if ($choice -eq 'A') {
        $picked = @($ready | Where-Object { $_.RunAll })
    } else {
        foreach ($k in ($choice -split '[,\s]+' | Where-Object { $_ })) {
            $m = $Modules | Where-Object { $_.Key -eq $k }
            if (-not $m) { Write-Host "  '$k' is not on the menu." -ForegroundColor Red; continue }
            if (-not $m.Ready) { Write-Host "  '$($m.Name)' is not built yet." -ForegroundColor Yellow; continue }
            $picked += $m
        }
    }
    if ($picked.Count -eq 0) { Start-Sleep -Seconds 2; continue }

    $i = 0
    foreach ($m in $picked) { $i++; Invoke-SetupModule -Module $m -Index $i -Count $picked.Count }
    Write-Progress -Id 0 -Activity 'Easyfin PC Setup' -Completed

    Show-Summary
    Write-Host ''
    Read-Host '   Press Enter to go back to the menu' | Out-Null
}

Show-Summary
Confirm-Restart
Write-Log 'Setup closed.'
Write-Host ''
Write-Host '  Done. You can close this window.' -ForegroundColor Cyan
