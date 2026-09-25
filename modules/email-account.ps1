# Module: Email account - adds a staff member's POP email account to Outlook 2013.
# Run it while signed in to Windows as THAT staff member: Outlook accounts belong to one Windows login.
# Safe to run again: skips if the account is already in Outlook. The password is never asked here -
# Outlook asks once when it first checks mail ("Remember password" ticked).

# ============================ EDIT HERE ============================
$MailDomain      = 'bloans.co.za'
$IncomingServer  = 'mail.bloans.co.za'
$IncomingPort    = 110
$IncomingSSL     = 0        # 0 = off, 1 = on (then port 995)
$OutgoingServer  = 'smtp.bloans.co.za'
$OutgoingPort    = 587
$OutgoingSecure  = 0        # 0 = none, 1 = SSL, 2 = TLS, 3 = auto
$ProfileName     = 'Outlook'
# Settings as Easyfin has used them for years (Nico, 26 Sep 2026). The server also supports
# encryption (995 / 587 TLS) - see PLAN.md, module 7, before switching it on.
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

# Outlook keeps account names as UTF-16 bytes under the profile key.
function Test-AccountExists {
    param([string]$Email)
    $root = 'HKCU:\Software\Microsoft\Office\15.0\Outlook\Profiles'
    if (-not (Test-Path $root)) { return $false }
    foreach ($key in Get-ChildItem $root -Recurse -ErrorAction SilentlyContinue) {
        foreach ($prop in 'Account Name', 'Email') {
            $v = $key.GetValue($prop)
            if ($v -is [byte[]]) { $v = [Text.Encoding]::Unicode.GetString($v).TrimEnd([char]0) }
            if ($v -and "$v" -ieq $Email) { return $true }
        }
    }
    return $false
}

# --- 1. checks
Write-Step 'Checking Outlook 2013'
$outlook = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE' -ErrorAction SilentlyContinue).'(default)'
if (-not $outlook -or -not (Test-Path $outlook)) { throw 'Outlook is not installed - run Office 2013 (option 5) first.' }
Write-Info "Found $outlook"

Write-Warn "This sets up Outlook for the Windows login '$env:USERNAME'."
Write-Warn 'It must be the staff member''s own Windows login, or they will not see the account.'
$ans = Read-Host '   Is this the right Windows login? (Y/N)'
if ($ans -notmatch '^[Yy]') { throw "Stopped: sign in to Windows as the staff member and run option 7 there." }

# --- 2. who
Write-Step 'Staff member details'
$name = ''
while (-not $name) { $name = (Read-Host '   Full name (as people should see it, e.g. Jane Smith)').Trim() }
$email = ''
while ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    $email = (Read-Host "   Email address (or just the part before @$MailDomain)").Trim()
    if ($email -and $email -notmatch '@') { $email = "$email@$MailDomain" }
    if ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { Write-Fail 'That is not a valid email address.' }
}
if ($email -notlike "*@$MailDomain") { Write-Warn "That is not an @$MailDomain address - the server settings may not fit it." }
Write-Info "Name: $name   Email: $email"

if (Test-AccountExists $email) {
    Write-Skip "$email is already in Outlook - moving on."
    return
}

# --- 3. build the Outlook setup file and hand it to Outlook
Write-Step "Adding $email to Outlook"
if (Get-Process OUTLOOK -ErrorAction SilentlyContinue) {
    Write-Warn 'Outlook is open. Close it, then press Enter.'
    Read-Host '   Press Enter when Outlook is closed' | Out-Null
    if (Get-Process OUTLOOK -ErrorAction SilentlyContinue) { throw 'Outlook is still open - close it and run option 7 again.' }
}

$pstDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Outlook Files'
New-Item -ItemType Directory -Path $pstDir -Force | Out-Null
$pst = Join-Path $pstDir "$email.pst"

# Standard Outlook profile file (PRF). The sections at the bottom map each setting to Outlook's
# internal property numbers - they are Microsoft's fixed values, don't "tidy" them.
$prf = @"
[General]
Custom=1
ProfileName=$ProfileName
DefaultProfile=Yes
OverwriteProfile=Append
ModifyDefaultProfileIfPresent=TRUE

[Service List]
Service1=Unicode Personal Folders

[Service1]
UniqueService=No
Name=$email
PathToPersonalFolders=$pst
EncryptionType=0x40000000

[Internet Account List]
Account1=I_Mail

[Account1]
UniqueService=No
AccountName=$email
DisplayName=$name
EmailAddress=$email
POP3Server=$IncomingServer
POP3UserName=$email
POP3UseSPA=0
POP3Port=$IncomingPort
POP3UseSSL=$IncomingSSL
SMTPServer=$OutgoingServer
SMTPUseAuth=1
SMTPAuthMethod=0
SMTPUseSPA=0
SMTPPort=$OutgoingPort
SMTPSecureConnection=$OutgoingSecure
ConnectionType=0
DeliverToStore=Service1

[Unicode Personal Folders]
ServiceName=MSUPST MS
Name=PT_UNICODE,0x3001
PathToPersonalFolders=PT_STRING8,0x6700
RememberPassword=PT_BOOLEAN,0x6701
EncryptionType=PT_LONG,0x6702
Password=PT_STRING8,0x6703

[I_Mail]
AccountType=POP3
AccountName=PT_UNICODE,0x0002
DisplayName=PT_UNICODE,0x000B
EmailAddress=PT_UNICODE,0x000C
POP3Server=PT_UNICODE,0x0100
POP3UserName=PT_UNICODE,0x0101
POP3UseSPA=PT_LONG,0x0108
Organization=PT_UNICODE,0x0107
ReplyEmailAddress=PT_UNICODE,0x0103
POP3Port=PT_LONG,0x0104
POP3UseSSL=PT_LONG,0x0105
SMTPServer=PT_UNICODE,0x0200
SMTPUseAuth=PT_LONG,0x0203
SMTPAuthMethod=PT_LONG,0x0208
SMTPUserName=PT_UNICODE,0x0204
SMTPUseSPA=PT_LONG,0x0207
ConnectionType=PT_LONG,0x000F
ConnectionOID=PT_UNICODE,0x0010
SMTPPort=PT_LONG,0x0201
SMTPSecureConnection=PT_LONG,0x020A
ServerTimeOut=PT_LONG,0x0209
LeaveOnServer=PT_LONG,0x1000
"@

$prfFile = Join-Path $global:EasyfinRoot 'outlook-account.prf'
Set-Content -Path $prfFile -Value $prf -Encoding Default
Write-Log "Outlook profile file written for $email (no password in it)."

Write-Info 'Opening Outlook with the new account...'
Start-Process -FilePath $outlook -ArgumentList "/importprf `"$prfFile`""

$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not (Test-AccountExists $email) -and $sw.Elapsed.TotalMinutes -lt 3) {
    Write-Progress -Id 1 -ParentId 0 -Activity 'Email account' -Status ('Waiting for Outlook to add the account  |  {0}' -f (Format-Duration $sw.Elapsed))
    Start-Sleep -Seconds 2
}
Write-Progress -Id 1 -Activity 'Email account' -Completed
Remove-Item $prfFile -Force -ErrorAction SilentlyContinue

if (-not (Test-AccountExists $email)) {
    throw 'Outlook opened but the account did not appear. Check Outlook for a message, then run option 7 again.'
}
Write-Ok "$email added to Outlook."
Write-Warn 'In Outlook now: when it asks for the password, type it, tick "Remember password", click OK.'
Write-Info 'Then send a test email to yourself to check sending and receiving.'
