# Module: Windows updates - finds and installs all available updates (including drivers) using
# Windows' own update service. Safe to run again: after a restart it picks up the next round.

# ============================ EDIT HERE ============================
$IncludeDrivers      = $true    # driver updates from Windows Update - helps with mixed laptop brands
$SkipFeatureUpgrades = $true    # skip big "new Windows version" upgrades (e.g. 24H2 -> 25H2), they take an hour+
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

function Format-Size { param([decimal]$Bytes)
    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    return '{0:N0} MB' -f [math]::Max(1, $Bytes / 1MB)
}

Write-Step 'Checking for updates (can take a few minutes)'
Write-Progress -Id 1 -ParentId 0 -Activity 'Windows updates' -Status 'Asking Microsoft which updates this PC needs - can take a few minutes'
Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

$session  = New-Object -ComObject Microsoft.Update.Session
$session.ClientApplicationID = 'Easyfin PC Setup'
$searcher = $session.CreateUpdateSearcher()
$criteria = "IsInstalled=0 and IsHidden=0 and Type='Software'"
if ($IncludeDrivers) { $criteria = "IsInstalled=0 and IsHidden=0" }
$sw = [Diagnostics.Stopwatch]::StartNew()
$found = $searcher.Search($criteria)
Write-Info ('Search took {0}' -f (Format-Duration $sw.Elapsed))

$todo = @()
foreach ($u in $found.Updates) {
    $isUpgrade = $false
    foreach ($c in $u.Categories) { if ($c.Name -eq 'Upgrades') { $isUpgrade = $true } }
    if ($isUpgrade -and $SkipFeatureUpgrades) { Write-Skip "Skipping Windows version upgrade: $($u.Title)"; continue }
    $todo += $u
}

if ($todo.Count -eq 0) {
    Write-Progress -Id 1 -Activity 'Windows updates' -Completed
    Write-Skip 'Windows is up to date - nothing to install.'
    return
}

$total = 0
foreach ($u in $todo) { $total += $u.MaxDownloadSize }
Write-Info ('{0} updates to install, about {1} to download:' -f $todo.Count, (Format-Size $total))
foreach ($u in $todo) { Write-Info ('   - {0}  ({1})' -f $u.Title, (Format-Size $u.MaxDownloadSize)) }

# One update at a time, so the progress bar can say exactly which one is busy.
$failed = @()
$i = 0
foreach ($u in $todo) {
    $i++
    $short = $u.Title
    if ($short.Length -gt 70) { $short = $short.Substring(0, 67) + '...' }
    $pct = [int]((($i - 1) / $todo.Count) * 100)
    Write-Step ('[{0}/{1}] {2}' -f $i, $todo.Count, $u.Title)
    try {
        if (-not $u.EulaAccepted) { $u.AcceptEula() }
        $one = New-Object -ComObject Microsoft.Update.UpdateColl
        [void]$one.Add($u)

        if (-not $u.IsDownloaded) {
            Write-Progress -Id 1 -ParentId 0 -Activity 'Windows updates' -Status ('{0} of {1}: downloading {2} ({3})' -f $i, $todo.Count, $short, (Format-Size $u.MaxDownloadSize)) -PercentComplete $pct
            $dl = $session.CreateUpdateDownloader()
            $dl.Updates = $one
            $dlResult = $dl.Download()
            if ($dlResult.ResultCode -ne 2 -and $dlResult.ResultCode -ne 3) { throw "download failed (code $($dlResult.ResultCode))" }
        }

        Write-Progress -Id 1 -ParentId 0 -Activity 'Windows updates' -Status ('{0} of {1}: installing {2}' -f $i, $todo.Count, $short) -PercentComplete $pct
        $inst = $session.CreateUpdateInstaller()
        $inst.Updates = $one
        $r = $inst.Install()
        # Result codes: 2 = done, 3 = done with warnings, 4 = failed, 5 = cancelled
        if ($r.ResultCode -eq 2 -or $r.ResultCode -eq 3) {
            Write-Ok 'Installed.'
            if ($r.RebootRequired) { $global:EasyfinRestartNeeded = $true }
        } else {
            throw ('install failed (code {0}, error 0x{1:X8})' -f $r.ResultCode, $r.HResult)
        }
    } catch {
        Write-Fail $_.Exception.Message
        $failed += $u.Title
    }
}
Write-Progress -Id 1 -Activity 'Windows updates' -Completed

if ($global:EasyfinRestartNeeded) { Write-Warn 'Restart needed. After restarting, run Windows updates again - there is often a second round.' }
if ($failed.Count -gt 0) { throw ('{0} update(s) failed: {1}' -f $failed.Count, ($failed -join '; ')) }
Write-Ok 'All updates installed.'
