# Module: Teams (work or school) - gets the staff member into Easyfin's Teams with their work email.
# Run it signed in to Windows as THAT staff member: a Teams sign-in belongs to one Windows login.
# Linked to the portal: the portal makes sure the person has an Easyfin (guest) Microsoft account and
# is in their branch's teams. The Azure key that can do that lives ONLY on the portal's server - never
# put one in this script, the repo is public. The sign-in itself the person does once (password or
# the code Microsoft emails them); no script can finish that for them.
# Windows PowerShell 5.1, ASCII only.

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

# --- 1. Teams installed?
Write-Step 'Checking Teams'
$pkg = Get-AppxPackage -Name 'MSTeams' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $pkg) { $pkg = Get-AppxPackage -AllUsers -Name 'MSTeams' -ErrorAction SilentlyContinue | Select-Object -First 1 }
if (-not $pkg) { throw 'Teams (work or school) is not installed - run Install apps first.' }
Write-Ok "Teams $($pkg.Version) is installed."

if (-not $global:EasyfinLoginConfirmed) {
    Write-Warn "This signs in Teams for the Windows login '$env:USERNAME'."
    $ans = Read-Host '   Is this the staff member''s own Windows login? (Y/N)'
    if ($ans -notmatch '^[Yy]') { throw 'Stopped: sign in to Windows as the staff member and run this step there.' }
    $global:EasyfinLoginConfirmed = $true
}

# --- 2. which email
Write-Step 'Work email'
$email = ([string]$global:EasyfinStaffEmail).Trim()
while ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    $email = (Read-Host '   Staff member''s work email (e.g. jane@bloans.co.za)').Trim()
    if ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { Write-Fail 'That is not a valid email address.' }
}
$global:EasyfinStaffEmail = $email
Write-Info "Email: $email"

# --- 3. the Easyfin Microsoft account (made by the portal - see PORTAL-PLAN.md, phase 2)
Write-Step 'Easyfin Microsoft account'
$invited = $false
if ((Test-PortalLinked) -and $global:EasyfinEmployeeId) {
    try {
        $r = Invoke-Portal -Method POST -Path ('/staff/{0}/teams-access' -f [int]$global:EasyfinEmployeeId) -Body @{ email = $email } -TimeoutSeconds 90
        if ($r.message) { Write-Ok ([string]$r.message) } else { Write-Ok "Account ready ($($r.result))." }
        if ($r.result -eq 'invited') { $invited = $true }
        foreach ($t in @($r.teams)) { if ($t) { Write-Info "In the team: $t" } }
    } catch {
        $st = $_.Exception.Data['Status']
        if ($st -eq 404 -or $st -eq 405) { Write-Skip 'The portal cannot make Teams accounts yet - the person must already have one (ask Nico).' }
        else { Write-Warn "The portal could not make the Teams account: $($_.Exception.Message)" }
    }
} else {
    Write-Skip 'No staff member picked from the portal - the Teams account must already exist.'
}

# --- 4. the person signs in
Write-Step 'Signing in to Teams'
try { Start-Process -FilePath 'explorer.exe' -ArgumentList 'shell:AppsFolder\MSTeams_8wekyb3d8bbwe!MSTeams' } catch { Write-Warn 'Could not open Teams - open it from the Start menu.' }
if ($invited) { Write-Warn "Microsoft has emailed an invitation to $email. Open it in Outlook and click Accept first." }
Write-Warn "In Teams: choose 'Work or school', type $email, then what Microsoft asks for (password, or a code it emails to you)."
Write-Info 'If it shows the personal Teams instead, sign out there and choose Work or school.'
$ok = Read-Host '   Is Teams signed in and showing the Easyfin teams? (Y/N)'
if ($ok -notmatch '^[Yy]') { throw "Teams is not signed in yet. The staff member can finish later: open Teams and sign in with $email." }
Write-Ok "Teams is signed in as $email."
