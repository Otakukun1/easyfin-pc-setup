# Module: Apps - installs the standard Easyfin apps. Safe to run again: installed apps are skipped.
# Order of attempts per app: already installed? -> winget -> vendor's own installer.

# ============================ EDIT HERE ============================
# Name      what is shown on screen
# Detect    name in "Programs and Features" (* = anything), or 'appx:<name>' for Store-style apps
# WingetId  winget package ID ('' = not in winget)
# Url       vendor download used when winget is missing/fails ('' = none).
#           'aweray:' means: ask AweRay's own site for the latest download link.
# Type      exe or msi
# Args      silent install switches for the vendor download
# Silent    $false = the installer window opens and you click through it
$Apps = @(
    @{ Name = 'Google Chrome';  Detect = 'Google Chrome';       WingetId = 'Google.Chrome';               Url = 'https://dl.google.com/chrome/install/googlechromestandaloneenterprise64.msi'; Type = 'msi'; Args = '/qn /norestart'; Silent = $true }
    @{ Name = 'AnyDesk';        Detect = 'AnyDesk*';            WingetId = 'AnyDesk.AnyDesk';             Url = 'https://download.anydesk.com/AnyDesk.exe'; Type = 'exe'; Args = '--install "C:\Program Files (x86)\AnyDesk" --start-with-win --silent --create-shortcuts --create-desktop-icon'; Silent = $true }
    @{ Name = 'Microsoft Teams'; Detect = 'appx:MSTeams';       WingetId = '';                            Url = 'https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409'; Type = 'exe'; Args = '-p'; Silent = $true }
    @{ Name = 'TeamViewer';     Detect = 'TeamViewer*';         WingetId = 'TeamViewer.TeamViewer';       Url = 'https://download.teamviewer.com/download/TeamViewer_Setup_x64.exe'; Type = 'exe'; Args = '/S'; Silent = $true }
    @{ Name = 'AweSun';         Detect = 'AweSun*';             WingetId = '';                            Url = 'aweray:'; Type = 'exe'; Args = ''; Silent = $false }
    @{ Name = 'Adobe Acrobat Reader'; Detect = 'Adobe Acrobat*'; WingetId = 'Adobe.Acrobat.Reader.64-bit'; Url = ''; Type = 'exe'; Args = ''; Silent = $true }
)
# Teams skips winget on purpose: winget installs it for the admin only. Microsoft's
# installer with -p installs it for every person who signs in to the PC.
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

function Test-AppInstalled {
    param($App)
    if ($App.Detect -like 'appx:*') {
        $name = $App.Detect.Substring(5)
        try {
            if (Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.DisplayName -eq $name }) { return $true }
            if (Get-AppxPackage -AllUsers -Name $name -ErrorAction Stop) { return $true }
        } catch { }
        return [bool](Get-AppxPackage -Name $name -ErrorAction SilentlyContinue)
    }
    return [bool](Get-InstalledProgram $App.Detect)
}

function Resolve-AppUrl {
    param($App)
    if ($App.Url -ne 'aweray:') { return $App.Url }
    # AweRay has no fixed download link; this is the same lookup their download page does.
    $info = Invoke-RestMethod 'https://client-api-global.aweray.com/softwares/SUNLOGIN_X_WINDOWS?lang=en&x64=1' -UseBasicParsing
    if (-not $info.downloadurl) { throw 'AweRay did not return a download link.' }
    return $info.downloadurl
}

function Install-WithWinget {
    param($App, [string]$Winget)
    Write-Info "Installing with winget ($($App.WingetId)) - winget shows its own progress below"
    # Start-Process -NoNewWindow gives winget the console directly so its live progress bar draws;
    # calling it with & would pipe its output and scramble the bar (and pollute this function's return).
    # The top progress bar shows running time, because big installers (Acrobat ~800 MB) sit on
    # "Starting package install..." for 5-15 minutes and look frozen.
    $wingetArgs = "install --id $($App.WingetId) --exact --source winget --silent --accept-package-agreements --accept-source-agreements"
    $code = Invoke-WithProgress -FilePath $Winget -Arguments $wingetArgs -NoNewWindow -TimeoutMinutes 45 `
        -Label "Installing $($App.Name)" -Hint 'still working - big apps can take 10+ minutes, do not close this window'
    Write-Log "winget exit code for $($App.Name): $code"
    return (Test-AppInstalled $App)
}

function Install-FromVendor {
    param($App)
    $url = Resolve-AppUrl $App
    $file = Join-Path $global:EasyfinDownloads (($App.Name -replace '[^A-Za-z0-9]', '') + '.' + $App.Type)
    Write-Info "Downloading from the vendor's site"
    Save-Download -Url $url -OutFile $file -Label "Downloading $($App.Name)"

    $hint = 'installing silently'
    if (-not $App.Silent) {
        $hint = 'the installer window is open - click Install and finish it'
        Write-Warn "$($App.Name) has no silent install. Its window is opening now - click through it."
    }
    if ($App.Type -eq 'msi') {
        $code = Invoke-WithProgress -FilePath 'msiexec.exe' -Arguments ('/i "{0}" {1}' -f $file, $App.Args) -Label "Installing $($App.Name)" -Hint $hint
    } else {
        $code = Invoke-WithProgress -FilePath $file -Arguments $App.Args -Label "Installing $($App.Name)" -Hint $hint
    }
    Write-Log "Installer exit code for $($App.Name): $code"
    if ($code -eq 3010 -or $code -eq 1641) { $global:EasyfinRestartNeeded = $true }
    Remove-Item $file -Force -ErrorAction SilentlyContinue

    # Some installers hand over to a background process and return before they finish.
    for ($i = 0; $i -lt 30 -and -not (Test-AppInstalled $App); $i++) {
        Write-Progress -Id 2 -ParentId 1 -Activity "Installing $($App.Name)" -Status 'Waiting for the install to finish...'
        Start-Sleep -Seconds 2
    }
    Write-Progress -Id 2 -Activity "Installing $($App.Name)" -Completed
    return (Test-AppInstalled $App)
}

$winget = Get-WingetPath
if ($winget) { Write-Info "winget found: $winget" }
else { Write-Warn "winget is not available on this PC - using the vendors' own installers." }

$failed = @()
$n = 0
foreach ($app in $Apps) {
    $n++
    Write-Progress -Id 1 -ParentId 0 -Activity 'Apps' -Status ('{0} of {1}: {2}' -f $n, $Apps.Count, $app.Name) -PercentComplete ([int]((($n - 1) / $Apps.Count) * 100))
    Write-Step ('[{0}/{1}] {2}' -f $n, $Apps.Count, $app.Name)

    if (Test-AppInstalled $app) {
        Write-Skip "$($app.Name) is already installed - moving on."
        continue
    }

    $ok = $false
    try {
        if ($winget -and $app.WingetId) {
            $ok = Install-WithWinget -App $app -Winget $winget
            if (-not $ok) { Write-Warn 'winget did not install it - trying the vendor download instead.' }
        }
        if (-not $ok -and $app.Url) {
            $ok = Install-FromVendor -App $app
        }
    } catch {
        Write-Warn $_.Exception.Message
        Write-Log ($_ | Out-String)
    }

    if ($ok) { Write-Ok "$($app.Name) installed." }
    else { Write-Fail "$($app.Name) could not be installed."; $failed += $app.Name }
}
Write-Progress -Id 1 -Activity 'Apps' -Completed

if ($failed.Count -gt 0) { throw ('Not installed: ' + ($failed -join ', ')) }
Write-Ok 'All apps are installed.'
