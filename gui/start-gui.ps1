# Easyfin PC Setup - WINDOW VERSION. Separate from start.ps1 on purpose: deleting the gui\ folder
# removes it and leaves the normal menu untouched. It runs the SAME modules\*.ps1.
#   Started from the portal (Assets > Set up a new PC): the page prints a line that also sets
#   EASYFIN_PORTAL and EASYFIN_CODE - then branches and staff come from the portal and the PC is
#   logged in the asset register at the end. API: PORTAL-API.md.
#   Without those it works on its own (no logging):
#     irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/gui/start-gui.ps1 | iex
#   Demo (changes nothing on the PC, no administrator needed):
#     $env:EASYFIN_DEMO=1; irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/gui/start-gui.ps1 | iex
# Windows PowerShell 5.1, ASCII only. Runs via iex: never 'exit', use 'return'.
#
# How it works: the window runs on this thread. The modules run in a second PowerShell (a runspace).
# A timer on the window reads that runspace's output/progress streams and answers its questions:
# the worker replaces Read-Host with a function that hands the question to the window.

# ============================ EDIT HERE ============================
$GuiVersion = '0.3'
$RepoBase   = 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main'
# Test copies: $env:EASYFIN_BRANCH='test'; in front of the line takes every file from that GitHub branch.
if ($env:EASYFIN_BRANCH -match '^[A-Za-z0-9._-]+$') { $RepoBase = 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/' + $env:EASYFIN_BRANCH }
# Order here is the order they run in. On = ticked by default. PortalName = what the asset page shows.
$Steps = @(
    @{ Key = 'pc';        Name = 'Name this PC, set time and region'; PortalName = 'PC settings';      Info = 'Restore point, new PC name, SA time and formats, screen lock after 10 min'; File = 'modules/pc-settings.ps1';      On = $true;  Mode = 'new' }
    @{ Key = 'clean';     Name = 'Remove junk';                       PortalName = 'Clean-up';         Info = 'McAfee, every other Office, games, personal Teams; Defender on'; File = 'modules/cleanup.ps1';          On = $true;  Mode = 'new' }
    @{ Key = 'apps';      Name = 'Install apps';                      PortalName = 'Apps';             Info = 'Chrome, AnyDesk, Teams, TeamViewer, AweSun, Acrobat Reader'; File = 'modules/apps.ps1';             On = $true;  Mode = 'new' }
    @{ Key = 'bookmarks'; Name = 'Add Easyfin bookmarks';             PortalName = 'Chrome bookmarks'; Info = 'Portal and other systems, in Chrome and Edge';              File = 'modules/chrome-bookmarks.ps1'; On = $true;  Mode = 'new' }
    @{ Key = 'office';    Name = 'Install Office 2013';               PortalName = 'Office 2013';      Info = 'Needs the setup password';                                  File = 'modules/office.ps1';           On = $true;  Mode = 'new' }
    @{ Key = 'speedup';   Name = 'Speed up and quieten Windows';      PortalName = 'Speed-up';         Info = 'Fast start-up and power, no animations, ads, news, Copilot'; File = 'modules/speedup.ps1';        On = $true;  Mode = 'new' }
    @{ Key = 'defaults';  Name = 'Default apps and taskbar';          PortalName = 'Defaults, taskbar'; Info = 'Chrome and Acrobat as defaults, Chrome and Outlook on the taskbar'; File = 'modules/defaults.ps1';   On = $true;  Mode = 'new' }
    @{ Key = 'updates';   Name = 'Install Windows updates';           PortalName = 'Windows updates';  Info = 'Slowest step - can take an hour';                           File = 'modules/windows-update.ps1';   On = $true;  Mode = 'new' }
    @{ Key = 'email';     Name = 'Add staff email to Outlook';        PortalName = 'Email account';    Info = 'Only when signed in to Windows as the staff member';        File = 'modules/email-account.ps1';    On = $false; Mode = 'new' }
    @{ Key = 'teams';     Name = 'Sign in to Teams (work or school)'; PortalName = 'Teams account';    Info = 'Only when signed in to Windows as the staff member';        File = 'modules/teams-account.ps1';    On = $false; Mode = 'new' }
    @{ Key = 'final';     Name = 'Final check and read-me';           PortalName = 'Final check';      Info = 'Checklist, activation, read-me on the Desktop, tidy up';     File = 'modules/handover.ps1';         On = $true;  Mode = 'new' }
    @{ Key = 'register';  Name = 'Record this PC';                    PortalName = 'Record this PC';   Info = 'Saves its details and who uses it. Installs and removes nothing'; File = 'modules/register-pc.ps1'; On = $true;  Mode = 'register' }
)
# Steps that are about the staff member's own Windows login (ticked by "this login is theirs").
$StaffLoginSteps = @('email', 'teams')
# After a restart the window opens by itself and carries on (see Save-Resume). Never more rounds than this.
$MaxRounds = 3
# ===================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, Microsoft.VisualBasic

$Demo = [bool]$env:EASYFIN_DEMO
$LocalRoot = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot '..\lib\common.ps1'))) { $LocalRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }

function Get-GuiFile {
    param([string]$RelativePath)
    if ($LocalRoot) { return Get-Content -Path (Join-Path $LocalRoot $RelativePath) -Raw }
    return Invoke-RestMethod -Uri ('{0}/{1}?t={2}' -f $RepoBase, $RelativePath, [DateTime]::UtcNow.Ticks) -UseBasicParsing
}

$isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $Demo) {
    [void][Windows.MessageBox]::Show("This must run as ADMINISTRATOR.`n`nClose this, right-click Start, choose 'Terminal (Admin)', and paste the line again.", 'Easyfin PC Setup', 'OK', 'Warning')
    return
}

# Shared helpers, the branch list and the portal link all come from lib/common.ps1.
try {
    . ([scriptblock]::Create((Get-GuiFile 'lib/common.ps1')))
} catch {
    [void][Windows.MessageBox]::Show("Could not download the setup files:`n$($_.Exception.Message)`n`nCheck the internet connection and try again.", 'Easyfin PC Setup', 'OK', 'Error')
    return
}

# --- carrying on after a restart: a logon task (Save-Resume) starts this with EASYFIN_RESUME=1.
# The file holds the portal code (valid 2 hours) - admin-only, and deleted as soon as it is read.
$ResumeFile = Join-Path $env:ProgramData 'Easyfin\resume.json'
$ResumeTask = 'Easyfin PC Setup - carry on'
$resume = $null
if ($env:EASYFIN_RESUME -and (Test-Path $ResumeFile)) {
    # Trusted only if an administrator run wrote it into the locked folder (see Initialize-LockedFolder).
    $resumeDir = Split-Path $ResumeFile
    if (-not (Test-IsLink $resumeDir) -and -not (Test-IsLink $ResumeFile) -and (Test-LockedFolder $resumeDir) -and (Test-AdminOwned $ResumeFile)) {
        try { $resume = Get-Content -Path $ResumeFile -Raw | ConvertFrom-Json } catch { $resume = $null }
    }
    Remove-Item -LiteralPath $ResumeFile -Force -ErrorAction SilentlyContinue
    if ($resume -and ([string]$resume.PcName -notmatch '^[A-Za-z0-9-]{0,15}$')) { $resume = $null }
}
if ($env:EASYFIN_RESUME) {
    try { Unregister-ScheduledTask -TaskName $ResumeTask -Confirm:$false -ErrorAction Stop } catch { }
    $env:EASYFIN_RESUME = $null
}
if ($resume) {
    $global:EasyfinPortal = $null; $global:EasyfinCode = $null
    if ($resume.Portal -and $resume.Code -and (Test-PortalAddressAllowed ([string]$resume.Portal))) {
        $global:EasyfinPortal = [string]$resume.Portal
        $global:EasyfinCode = [string]$resume.Code
    }
}

# Everything the event handlers share lives in this one object, so PowerShell scoping can't bite.
$state = @{ Mode = 'new'; Running = $false; Finished = $false; InfoIdx = 0; ErrIdx = 0; ProgIdx = 0; Progress = @{}; StepUi = @{}
            Ps = $null; Sync = $null; Picked = @(); Linked = $false; Loading = $false; Session = $null; Existing = $null
            ExistingNote = ''; UseExistingTag = $null; CodeByPrefix = @{}; StaffFor = $null; EmailById = @{}; Round = 1 }

# --- portal link: check the code before showing anything, so a bad code is caught up front
function Stop-PortalLink { $global:EasyfinCode = $null; $state.Linked = $false }
if ($resume) {
    # Every choice was made before the restart; the code is not checked again (if it ran out, the
    # record waits on the PC in pending-portal.json and is sent on the next linked run).
    $state.Linked = Test-PortalLinked
    $state.Round = [int]$resume.Round
} elseif (Test-PortalLinked) {
    $state.Linked = $true
    $why = $null
    if (-not (Test-PortalAddressAllowed $global:EasyfinPortal)) {
        $why = "The portal address $global:EasyfinPortal is not a secure (https) address, so the setup code is not sent to it."
    } else {
        try { $state.Session = Invoke-Portal -Path '/session' } catch { $why = $_.Exception.Message }
    }
    if ($why) {
        $r = [Windows.MessageBox]::Show("$why`n`nCarry on WITHOUT logging this PC in the portal?", 'Easyfin PC Setup', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
        Stop-PortalLink
    }
}
$portalBranches = @()
if ($state.Linked -and -not $resume) {
    try {
        $portalBranches = @(Invoke-Portal -Path '/branches')
        $id = Get-PcIdentity
        $q = @()
        if ($id.SerialNumber) { $q += 'serial=' + [uri]::EscapeDataString($id.SerialNumber) }
        if ($id.HardwareUuid) { $q += 'uuid=' + [uri]::EscapeDataString($id.HardwareUuid) }
        if ($q.Count -gt 0) {
            try { $state.Existing = Invoke-Portal -Path ('/assets/lookup?' + ($q -join '&')) }
            catch {
                $st = $_.Exception.Data['Status']
                if ($st -eq 403) { $state.ExistingNote = $_.Exception.Message }
                elseif ($st -ne 404) { throw }
            }
        }
    } catch {
        $r = [Windows.MessageBox]::Show("The portal did not answer properly: $($_.Exception.Message)`n`nCarry on WITHOUT logging this PC in the portal?", 'Easyfin PC Setup', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
        Stop-PortalLink
    }
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Easyfin PC Setup" Width="1020" Height="760" MinWidth="920" MinHeight="640"
        WindowStartupLocation="CenterScreen" Background="#F4F6F8" FontFamily="Segoe UI" FontSize="14">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#0F4C5C" Padding="24,14">
      <StackPanel>
        <TextBlock x:Name="TitleText" Text="Easyfin PC Setup" Foreground="White" FontSize="24" FontWeight="SemiBold"/>
        <TextBlock x:Name="PcLine" Foreground="#CFE3E8" Margin="0,4,0,0"/>
        <TextBlock x:Name="PortalLine" Foreground="#9FE0B5" Margin="0,2,0,0"/>
      </StackPanel>
    </Border>

    <Grid Grid.Row="1" Margin="20,16,20,16">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="390"/><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto">
        <StackPanel x:Name="LeftPanel" Margin="0,0,6,0">
          <Border Background="White" BorderBrush="#DDE3E7" BorderThickness="1" CornerRadius="6" Padding="14,10" Margin="0,0,0,16">
            <StackPanel>
              <RadioButton x:Name="ModeNew" GroupName="mode" IsChecked="True" Margin="0,2,0,2">
                <StackPanel>
                  <TextBlock Text="New PC - full setup" FontWeight="SemiBold"/>
                  <TextBlock Text="Cleans it, installs everything, names it" Foreground="#5A6B75" FontSize="12"/>
                </StackPanel>
              </RadioButton>
              <RadioButton x:Name="ModeReg" GroupName="mode" Margin="0,8,0,2">
                <StackPanel>
                  <TextBlock Text="PC already in use - just record it" FontWeight="SemiBold"/>
                  <TextBlock Text="Takes a minute. Installs and removes nothing" Foreground="#5A6B75" FontSize="12"/>
                </StackPanel>
              </RadioButton>
            </StackPanel>
          </Border>

          <TextBlock Text="1. Which PC is this?" FontWeight="SemiBold" FontSize="16"/>
          <Border Background="White" BorderBrush="#DDE3E7" BorderThickness="1" CornerRadius="6" Padding="14" Margin="0,8,0,16">
            <StackPanel>
              <TextBlock x:Name="ExistingText" Foreground="#0F4C5C" TextWrapping="Wrap" Margin="0,0,0,10" Visibility="Collapsed"/>
              <TextBlock Text="Group" Foreground="#5A6B75"/>
              <ComboBox x:Name="GroupBox" Margin="0,4,0,10" Padding="6,4"/>
              <TextBlock Text="Branch" Foreground="#5A6B75"/>
              <ComboBox x:Name="BranchBox" Margin="0,4,0,12" Padding="6,4"/>
              <StackPanel Orientation="Horizontal">
                <RadioButton x:Name="KindL" Content="Laptop" GroupName="kind" Margin="0,0,18,0" VerticalAlignment="Center"/>
                <RadioButton x:Name="KindD" Content="Desktop" GroupName="kind" VerticalAlignment="Center"/>
                <TextBlock Text="PC number" Margin="28,0,8,0" VerticalAlignment="Center" Foreground="#5A6B75"/>
                <TextBox x:Name="NumBox" Width="46" Text="1" Padding="4,2" VerticalAlignment="Center"/>
              </StackPanel>
              <TextBlock x:Name="NamePreview" Margin="0,12,0,8" FontSize="16" FontWeight="SemiBold" Foreground="#0F4C5C" TextWrapping="Wrap"/>
              <CheckBox x:Name="KeepName" Content="Keep the name it has now"/>
              <CheckBox x:Name="RenameBox" Content="Rename the PC to this now (after a restart)" IsChecked="True" Visibility="Collapsed"/>
              <TextBlock Text="Who uses this PC?" Foreground="#5A6B75" Margin="0,14,0,0"/>
              <TextBox x:Name="UsedByBox" Margin="0,4,0,2" Padding="4,2"/>
              <ComboBox x:Name="UsedByCombo" Margin="0,4,0,2" Padding="6,4" Visibility="Collapsed"/>
              <TextBlock x:Name="UsedByHint" Text="Leave empty if it is shared or nobody has it yet." Foreground="#8A979E" FontSize="12" TextWrapping="Wrap"/>
              <TextBlock Text="Their work email (for Outlook and Teams)" Foreground="#5A6B75" Margin="0,12,0,0"/>
              <TextBox x:Name="StaffEmailBox" Margin="0,4,0,2" Padding="4,2"/>
              <CheckBox x:Name="StaffLoginBox" Margin="0,10,0,0">
                <TextBlock TextWrapping="Wrap" Text="I am signed in to Windows as this staff member (also sets up their email and Teams)"/>
              </CheckBox>
            </StackPanel>
          </Border>

          <TextBlock Text="2. What should be done?" FontWeight="SemiBold" FontSize="16"/>
          <Border Background="White" BorderBrush="#DDE3E7" BorderThickness="1" CornerRadius="6" Padding="14,8" Margin="0,8,0,16">
            <StackPanel x:Name="StepsPanel"/>
          </Border>

          <StackPanel x:Name="PwPanel">
            <TextBlock Text="3. Setup password" FontWeight="SemiBold" FontSize="16"/>
            <TextBlock Text="Only needed for Office." Foreground="#5A6B75" Margin="0,2,0,6"/>
            <PasswordBox x:Name="PwBox" Padding="6,4"/>
          </StackPanel>
        </StackPanel>
      </ScrollViewer>

      <Grid Grid.Column="2">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="Activity" Grid.Row="0" FontSize="20" FontWeight="SemiBold" TextWrapping="Wrap" Text="Ready when you are"/>
        <TextBlock x:Name="SubStatus" Grid.Row="1" Foreground="#5A6B75" TextWrapping="Wrap" Margin="0,4,0,0"
                   Text="Choose on the left, then press Start."/>
        <ProgressBar x:Name="Bar" Grid.Row="2" Height="14" Margin="0,12,0,12" Minimum="0" Maximum="100"/>
        <Border Grid.Row="3" Background="#12181C" CornerRadius="6" Padding="6">
          <RichTextBox x:Name="LogBox" IsReadOnly="True" Background="Transparent" BorderThickness="0"
                       Foreground="#D7DEE2" FontFamily="Consolas" FontSize="12.5" VerticalScrollBarVisibility="Auto"/>
        </Border>
      </Grid>
    </Grid>

    <Border Grid.Row="2" Background="White" BorderBrush="#DDE3E7" BorderThickness="0,1,0,0" Padding="20,12">
      <DockPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
          <Button x:Name="RestartBtn" Content="Restart PC now" Padding="18,8" Margin="0,0,10,0" Visibility="Collapsed"/>
          <Button x:Name="StartBtn" Content="Start setup" Padding="26,8" FontWeight="SemiBold" Background="#0F4C5C" Foreground="White" BorderThickness="0"/>
        </StackPanel>
        <TextBlock x:Name="Hint" VerticalAlignment="Center" Foreground="#5A6B75" TextWrapping="Wrap" Margin="0,0,16,0"
                   Text="After you press Start you can walk away. It only stops when it needs a click from you."/>
      </DockPanel>
    </Border>
  </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Parse($xaml)
$ui = @{}
foreach ($n in 'TitleText', 'PcLine', 'PortalLine', 'ExistingText', 'GroupBox', 'BranchBox', 'KindL', 'KindD', 'NumBox', 'NamePreview', 'KeepName',
               'StepsPanel', 'PwBox', 'ModeNew', 'ModeReg', 'RenameBox', 'UsedByBox', 'UsedByCombo', 'UsedByHint', 'PwPanel', 'StaffEmailBox', 'StaffLoginBox',
               'Activity', 'SubStatus', 'Bar', 'LogBox', 'RestartBtn', 'StartBtn', 'Hint', 'LeftPanel') { $ui[$n] = $window.FindName($n) }

# --- header
$cs = Get-CimInstance Win32_ComputerSystem
$idHead = Get-PcIdentity
$serialText = $idHead.SerialNumber; if (-not $serialText) { $serialText = '(none - uses hardware number)' }
$ui.PcLine.Text = ('This PC: {0}   |   {1} {2}   |   Serial {3}   |   v{4}' -f $env:COMPUTERNAME, "$($cs.Manufacturer)".Trim(), "$($cs.Model)".Trim(), $serialText, $GuiVersion)
if ($Demo) { $ui.TitleText.Text = 'Easyfin PC Setup  -  DEMO (nothing on this PC is changed)' }
if ($resume) {
    $ui.PortalLine.Text = ('Carrying on after the restart (round {0} of {1}) - {2}' -f $state.Round, $MaxRounds, $resume.PcName)
} elseif ($state.Linked) {
    $until = ''
    try { $until = ([datetime]$state.Session.expires_at).ToString('HH:mm') } catch { }
    $ui.PortalLine.Text = ('Linked to the portal - code made by {0}, valid until {1}. This PC will be logged in the asset list.' -f $state.Session.made_by, $until)
} else {
    $ui.PortalLine.Text = 'Not linked to the portal - this PC will NOT be logged in the asset list. (Start from the portal: Assets > Set up a new PC.)'
    $ui.PortalLine.Foreground = '#F2C94C'
}

# --- section 1: group, branch, laptop/desktop, number
# Group names come from the portal when it sends them, otherwise from the PC name start (MIL-... = Miloans).
# Offline fallback only - matches the portal's Setup > Branches groups (Quickloans CW sits under Budget). Linked runs use the portal's own group.
$GroupByHead = @{ MIL = 'Miloans'; QUA = 'Qualiloans'; BUD = 'Budget'; QCK = 'Budget'; TLG = 'The Loan Guy'; HO = 'Head Office'; WBDC = 'Debt Collection' }
function Get-GroupName {
    param([string]$Prefix, [string]$FromPortal)
    if ($FromPortal) { return $FromPortal }
    if ($Prefix) { $head = $Prefix.Split('-')[0]; if ($GroupByHead[$head]) { return $GroupByHead[$head] } }
    return 'Other'
}
$state.BranchList = @()
if ($state.Linked) {
    foreach ($b in $portalBranches) {
        $prefix = [string]$b.pc_name_prefix
        $group = ''
        if ($b.PSObject.Properties['group']) { $group = [string]$b.group }
        $state.BranchList += @{ Name = [string]$b.name; Prefix = $prefix; Group = (Get-GroupName $prefix $group) }
        if ($prefix) { $state.CodeByPrefix[$prefix] = [string]$b.code }
    }
} else {
    foreach ($code in $Branches.Keys) { $state.BranchList += @{ Name = $Branches[$code]; Prefix = $code; Group = (Get-GroupName $code '') } }
}
foreach ($g in @($state.BranchList | ForEach-Object { $_.Group } | Select-Object -Unique)) { [void]$ui.GroupBox.Items.Add($g) }

function Update-BranchList {
    $state.Loading = $true
    try {
        $ui.BranchBox.Items.Clear()
        foreach ($b in $state.BranchList) {
            if ($b.Group -ne $ui.GroupBox.SelectedItem) { continue }
            $item = New-Object Windows.Controls.ComboBoxItem
            if ($b.Prefix) { $item.Content = $b.Name; $item.Tag = $b.Prefix }
            else { $item.Content = "$($b.Name)  (no PC name set in the portal yet)"; $item.IsEnabled = $false }
            [void]$ui.BranchBox.Items.Add($item)
        }
    } finally { $state.Loading = $false }
    Update-NamePreview
}
$ui.GroupBox.Add_SelectionChanged({ Update-BranchList })
# Picks group + branch for a PC name start (used when the PC is already in the portal).
function Select-BranchByPrefix {
    param([string]$Prefix)
    $b = $state.BranchList | Where-Object { $_.Prefix -eq $Prefix } | Select-Object -First 1
    if (-not $b) { return }
    $ui.GroupBox.SelectedItem = $b.Group
    foreach ($it in $ui.BranchBox.Items) { if ($it.Tag -eq $Prefix) { $ui.BranchBox.SelectedItem = $it } }
}
$isLaptop = $false
foreach ($c in @((Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes)) {
    if (@(8, 9, 10, 11, 14, 30, 31, 32) -contains [int]$c) { $isLaptop = $true }
}
$ui.KindL.IsChecked = $isLaptop
$ui.KindD.IsChecked = -not $isLaptop

function Get-Kind { if ($ui.KindL.IsChecked) { return 'laptop' } else { return 'desktop' } }
function Get-SelectedCode {
    $sel = $ui.BranchBox.SelectedItem
    if (-not $sel -or -not $sel.Tag) { return $null }
    return $state.CodeByPrefix[[string]$sel.Tag]
}

function Get-NewPcName {
    if ($ui.KeepName.IsChecked) { return $env:COMPUTERNAME }
    if ($state.UseExistingTag) { return $state.UseExistingTag }
    $sel = $ui.BranchBox.SelectedItem
    $num = 0
    if (-not $sel -or -not $sel.Tag -or -not [int]::TryParse($ui.NumBox.Text.Trim(), [ref]$num) -or $num -lt 1 -or $num -gt 99) { return '' }
    $kind = 'D'; if ($ui.KindL.IsChecked) { $kind = 'L' }
    return ('{0}-{1}{2:00}' -f $sel.Tag, $kind, $num)
}
function Update-NamePreview {
    $name = Get-NewPcName
    if ($ui.KeepName.IsChecked) { $ui.NamePreview.Text = "Name stays: $name" }
    elseif ($state.UseExistingTag) { $ui.NamePreview.Text = "Keeps its portal name: $name" }
    elseif ($name -and $state.Mode -eq 'register') { $ui.NamePreview.Text = "Recorded as: $name" }
    elseif ($name) { $ui.NamePreview.Text = "New name: $name" }
    else { $ui.NamePreview.Text = 'Pick a branch and a number (1-99)' }
    $on = -not $ui.KeepName.IsChecked
    $ui.GroupBox.IsEnabled = $on; $ui.BranchBox.IsEnabled = $on; $ui.KindL.IsEnabled = $on; $ui.KindD.IsEnabled = $on; $ui.NumBox.IsEnabled = $on
}

# Shows a portal refusal as the portal worded it.
function Show-PortalProblem { param([string]$Text) [void][Windows.MessageBox]::Show($window, $Text, 'Easyfin PC Setup', 'OK', 'Warning') }

# "Who uses this PC?" from the branch's staff list. Keep / nobody / a person.
function Update-StaffList {
    param([string]$Code)
    if ($state.StaffFor -eq $Code) { return }
    $state.StaffFor = $Code
    $ui.UsedByCombo.Items.Clear()
    $ex = $state.Existing
    $add = {
        param($Text, $Mode, $Id, $Email)
        $it = New-Object Windows.Controls.ComboBoxItem
        $it.Content = $Text; $it.Tag = @{ Mode = $Mode; Id = $Id; Name = $Text; Email = $Email }
        [void]$ui.UsedByCombo.Items.Add($it)
        return $it
    }
    $select = $null
    if ($ex -and $ex.branch_code -eq $Code) {
        $keepText = 'No change - nobody has it'
        if ($ex.assigned_to) { $keepText = "No change - $($ex.assigned_to.name)" }
        $select = & $add $keepText 'keep' $null
    }
    $nobody = & $add 'Nobody yet / shared PC' 'none' $null
    if (-not $select) { $select = $nobody }
    try {
        foreach ($p in @(Invoke-Portal -Path "/branches/$Code/staff")) {
            # email arrives once the portal sends it (PORTAL-PLAN.md, phase 2); until then it is typed.
            $mail = ''; if ($p.PSObject.Properties['email']) { $mail = [string]$p.email }
            if ($mail) { $state.EmailById[[int]$p.id] = $mail }
            [void](& $add ([string]$p.name) 'id' ([int]$p.id) $mail)
        }
    } catch {
        Show-PortalProblem $_.Exception.Message
    }
    $ui.UsedByCombo.SelectedItem = $select
}

# When linked: reuse the PC's portal name if branch and kind still match, else ask the portal for the next free number.
function Update-Suggestion {
    if (-not $state.Linked -or $state.Loading) { Update-NamePreview; return }
    $code = Get-SelectedCode
    if (-not $code) { Update-NamePreview; return }
    $kind = Get-Kind
    $state.Loading = $true
    try {
        Update-StaffList $code
        $ex = $state.Existing
        if ($ex -and $ex.branch_code -eq $code -and $ex.kind -eq $kind) {
            $state.UseExistingTag = [string]$ex.asset_tag
            if ($ex.asset_tag -match '-[LD](\d{2})$') { $ui.NumBox.Text = [string][int]$Matches[1] }
        } else {
            $state.UseExistingTag = $null
            try {
                $r = Invoke-Portal -Path "/branches/$code/next-tag?kind=$kind"
                if ($r.asset_tag -match '-[LD](\d{2})$') { $ui.NumBox.Text = [string][int]$Matches[1] }
            } catch { Show-PortalProblem $_.Exception.Message }
        }
    } finally { $state.Loading = $false }
    Update-NamePreview
}

$ui.BranchBox.Add_SelectionChanged({ Update-Suggestion })
$ui.UsedByCombo.Add_SelectionChanged({
    $who = $ui.UsedByCombo.SelectedItem
    if (-not $who) { return }
    $mail = $who.Tag.Email
    if (-not $mail -and $who.Tag.Mode -eq 'keep' -and $state.Existing -and $state.Existing.assigned_to) { $mail = $state.EmailById[[int]$state.Existing.assigned_to.id] }
    if ($mail) { $ui.StaffEmailBox.Text = $mail }
    elseif ($who.Tag.Mode -eq 'none') { $ui.StaffEmailBox.Text = '' }
})
$ui.KindL.Add_Checked({ Update-Suggestion })
$ui.KindD.Add_Checked({ Update-Suggestion })
$ui.NumBox.Add_TextChanged({ if (-not $state.Loading) { $state.UseExistingTag = $null }; Update-NamePreview })
$ui.KeepName.Add_Click({ Update-NamePreview })

if ($state.Linked) {
    # Names must follow the rule to be logged, so "keep the current Windows name" is not offered.
    $ui.KeepName.Visibility = 'Collapsed'
    $ui.UsedByBox.Visibility = 'Collapsed'; $ui.UsedByCombo.Visibility = 'Visible'
    $ui.UsedByHint.Text = 'Pick from the branch''s staff. The portal keeps a history of who had it.'
    if ($global:EasyfinPortal -like 'https://*') { $ui.PwPanel.Visibility = 'Collapsed' }
    $ex = $state.Existing
    if ($ex) {
        $who = 'nobody'; if ($ex.assigned_to) { $who = $ex.assigned_to.name }
        $ui.ExistingText.Text = "Already in the portal as $($ex.asset_tag) (used by $who). Change below only if that is wrong."
        $ui.ExistingText.Visibility = 'Visible'
        $ui.ModeReg.IsChecked = $true
        $ui.KindL.IsChecked = ($ex.kind -eq 'laptop'); $ui.KindD.IsChecked = ($ex.kind -ne 'laptop')
        $exPrefix = $null
        foreach ($k in $state.CodeByPrefix.Keys) { if ($state.CodeByPrefix[$k] -eq $ex.branch_code) { $exPrefix = $k } }
        if ($exPrefix) { Select-BranchByPrefix $exPrefix }
    } elseif ($state.ExistingNote) {
        $ui.ExistingText.Text = $state.ExistingNote
        $ui.ExistingText.Foreground = '#C0392B'
        $ui.ExistingText.Visibility = 'Visible'
    }
}
Update-NamePreview

# --- section 2: one row per step = tick box + status word
foreach ($s in $Steps) {
    $row = New-Object Windows.Controls.Grid
    $row.Margin = '0,6,0,6'
    $c1 = New-Object Windows.Controls.ColumnDefinition
    $c2 = New-Object Windows.Controls.ColumnDefinition; $c2.Width = 'Auto'
    [void]$row.ColumnDefinitions.Add($c1); [void]$row.ColumnDefinitions.Add($c2)

    $info = $s.Info
    if ($s.Key -eq 'office' -and $state.Linked -and $global:EasyfinPortal -like 'https://*') { $info = 'Download link comes from the portal' }
    $text = New-Object Windows.Controls.StackPanel
    $t1 = New-Object Windows.Controls.TextBlock; $t1.Text = $s.Name; $t1.FontWeight = 'SemiBold'
    $t2 = New-Object Windows.Controls.TextBlock; $t2.Text = $info; $t2.Foreground = '#5A6B75'; $t2.FontSize = 12; $t2.TextWrapping = 'Wrap'
    [void]$text.Children.Add($t1); [void]$text.Children.Add($t2)
    $cb = New-Object Windows.Controls.CheckBox; $cb.Content = $text; $cb.IsChecked = $s.On
    [Windows.Controls.Grid]::SetColumn($cb, 0)

    $status = New-Object Windows.Controls.TextBlock; $status.Text = ''; $status.VerticalAlignment = 'Center'; $status.FontWeight = 'SemiBold'; $status.Margin = '8,0,0,0'
    [Windows.Controls.Grid]::SetColumn($status, 1)

    [void]$row.Children.Add($cb); [void]$row.Children.Add($status)
    [void]$ui.StepsPanel.Children.Add($row)
    $state.StepUi[$s.Key] = @{ Check = $cb; Status = $status; Row = $row }
}

$ui.StaffLoginBox.Add_Click({
    foreach ($k in $StaffLoginSteps) { $state.StepUi[$k].Check.IsChecked = [bool]$ui.StaffLoginBox.IsChecked }
})

# --- the two modes: full setup of a new PC, or just recording a PC that is already in use
function Update-Mode {
    $mode = 'new'; if ($ui.ModeReg.IsChecked) { $mode = 'register' }
    $state.Mode = $mode
    foreach ($s in $Steps) {
        $vis = 'Collapsed'; if ($s.Mode -eq $mode) { $vis = 'Visible' }
        $state.StepUi[$s.Key].Row.Visibility = $vis
    }
    if ($mode -eq 'register') {
        $ui.KeepName.IsChecked = $false
        $ui.KeepName.Visibility = 'Collapsed'; $ui.RenameBox.Visibility = 'Visible'; $ui.PwPanel.Visibility = 'Collapsed'
        $ui.StaffLoginBox.Visibility = 'Collapsed'
        $ui.StartBtn.Content = 'Record this PC'
        $ui.Hint.Text = 'Renaming a PC that is in use can break shared printers or folders that other PCs reach by its old name. Untick "Rename" if unsure.'
    } else {
        $ui.RenameBox.Visibility = 'Collapsed'
        $ui.StaffLoginBox.Visibility = 'Visible'
        if (-not $state.Linked) { $ui.KeepName.Visibility = 'Visible' }
        if (-not ($state.Linked -and $global:EasyfinPortal -like 'https://*')) { $ui.PwPanel.Visibility = 'Visible' }
        $ui.StartBtn.Content = 'Start setup'
        $ui.Hint.Text = 'After you press Start you can walk away. It only stops when it needs a click from you.'
    }
    Update-NamePreview
}
$ui.ModeNew.Add_Checked({ Update-Mode })
$ui.ModeReg.Add_Checked({ Update-Mode })
Update-Mode
if ($state.Linked -and $ui.BranchBox.SelectedItem) { Update-Suggestion }

# --- log box
$doc = New-Object Windows.Documents.FlowDocument
$para = New-Object Windows.Documents.Paragraph
$para.Margin = '0'
[void]$doc.Blocks.Add($para)
$ui.LogBox.Document = $doc
$logColours = @{ Green = '#6FCF97'; Yellow = '#F2C94C'; Red = '#FF7B72'; Cyan = '#56CCF2'; DarkCyan = '#3A9CB8'; Gray = '#AEB8BE'; DarkGray = '#7C8A92'; White = '#FFFFFF' }
function Add-LogLine {
    param([string]$Text, [string]$Colour = 'Gray')
    $run = New-Object Windows.Documents.Run($Text)
    $hex = $logColours[$Colour]; if (-not $hex) { $hex = '#D7DEE2' }
    $run.Foreground = (New-Object Windows.Media.BrushConverter).ConvertFromString($hex)
    [void]$para.Inlines.Add($run)
    [void]$para.Inlines.Add((New-Object Windows.Documents.LineBreak))
    $ui.LogBox.ScrollToEnd()
}

# Shows a question from a module and returns the answer as text.
function Show-ModuleQuestion {
    param([string]$Prompt)
    $p = $Prompt.Trim()
    if ($env:EASYFIN_GUI_SHOT) { return 'Y' }
    if ($p -match '\(Y/N\)') {
        $r = [Windows.MessageBox]::Show($window, ($p -replace '\s*\(Y/N\)\s*:?\s*$', ''), 'Easyfin PC Setup', 'YesNo', 'Question')
        if ($r -eq 'Yes') { return 'Y' } else { return 'N' }
    }
    if ($p -match '^Press Enter') {
        [void][Windows.MessageBox]::Show($window, ($p -replace '^Press Enter\s*', 'Click OK '), 'Easyfin PC Setup', 'OK', 'Information')
        return ''
    }
    return [Microsoft.VisualBasic.Interaction]::InputBox($p, 'Easyfin PC Setup', '')
}

# The worker: runs in its own PowerShell. Kept as text so nothing leaks in from this scope by accident.
$workerScript = @'
$global:sync = $sync
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Modules ask questions with Read-Host. A function beats a cmdlet of the same name, so this one
# takes over: it passes the question to the window and waits for the answer.
function global:Read-Host {
    param([Parameter(Position = 0)]$Prompt, [switch]$AsSecureString)
    $global:sync.Answered = $false
    $global:sync.Prompt = "$Prompt"
    while (-not $global:sync.Answered) { Start-Sleep -Milliseconds 150 }
    $a = [string]$global:sync.Answer
    if ($AsSecureString) {
        $sec = New-Object Security.SecureString
        foreach ($ch in $a.ToCharArray()) { $sec.AppendChar($ch) }
        return $sec
    }
    return $a
}

function Get-WorkerFile {
    param([string]$RelativePath)
    if ($sync.LocalRoot) { return Get-Content -Path (Join-Path $sync.LocalRoot $RelativePath) -Raw }
    return Invoke-RestMethod -Uri ('{0}/{1}?t={2}' -f $sync.RepoBase, $RelativePath, [DateTime]::UtcNow.Ticks) -UseBasicParsing
}

try {
    . ([scriptblock]::Create((Get-WorkerFile 'lib/common.ps1')))
    # The window decides whether this run is linked (the person may have chosen to carry on without).
    $global:EasyfinPortal = $sync.Portal
    $global:EasyfinCode = $sync.Code
    $global:EasyfinSetupLoaded = $true
    $global:EasyfinRestartNeeded = $false
    Initialize-SetupLog
    $sync.LogFile = $global:EasyfinLog

    # Answers given in the window up front, so the modules don't have to ask.
    if ($sync.PcName) { $global:EasyfinPcName = $sync.PcName }
    $global:EasyfinUsedBy = [string]$sync.UsedBy
    $global:EasyfinStaffName = [string]$sync.StaffName
    $global:EasyfinStaffEmail = [string]$sync.StaffEmail
    if ($sync.StaffId) { $global:EasyfinEmployeeId = [int]$sync.StaffId }
    $global:EasyfinLoginConfirmed = [bool]$sync.LoginConfirmed
    if ($sync.Mode -eq 'register') { $global:EasyfinRename = [bool]$sync.Rename }
    if ($sync.Password) {
        $sec = New-Object Security.SecureString
        foreach ($ch in ([string]$sync.Password).ToCharArray()) { $sec.AppendChar($ch) }
        $global:EasyfinSetupPassword = $sec
    }

    $n = 0
    foreach ($step in $sync.Picked) {
        $n++
        $sync.CurrentKey = $step.Key
        $sync.CurrentText = ('Step {0} of {1}: {2}' -f $n, $sync.Picked.Count, $step.Name)
        $sync.Status[$step.Key] = 'Working'
        Write-Title $sync.CurrentText
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            if ($sync.Demo) {
                Write-Step "Demo: pretending to do '$($step.Name)'"
                foreach ($i in 1..20) {
                    Write-Progress -Id 1 -Activity $step.Name -Status "Working ($i of 20)" -PercentComplete ($i * 5)
                    Start-Sleep -Milliseconds 120
                }
                Write-Progress -Id 1 -Activity $step.Name -Completed
                if ($step.Key -eq 'office') { $a = Read-Host '   Demo question: this is how a question looks. Carry on? (Y/N)'; Write-Info "You answered $a" }
                if ($step.Key -eq 'updates') { throw 'Demo: this step fails on purpose so you can see what a failure looks like.' }
                Write-Ok 'Done (demo).'
            } else {
                & ([scriptblock]::Create((Get-WorkerFile $step.File))) | Out-Null
            }
            $sync.Status[$step.Key] = 'Done'
        } catch {
            $sync.Status[$step.Key] = 'Failed'
            $sync.Detail[$step.Key] = $_.Exception.Message
            Write-Fail "$($step.Name) failed: $($_.Exception.Message)"
            Write-Log ($_ | Out-String)
        }
        Write-Log ('RESULT {0}: {1} in {2}' -f $step.Name, $sync.Status[$step.Key], (Format-Duration $sw.Elapsed))
    }

    # Log the PC in the portal's asset list, with what was done and how it went.
    if ($sync.Portal -and $sync.Code -and $sync.PcName) {
        $sync.CurrentText = 'Logging this PC in the portal'
        Write-Title 'Logging this PC in the portal'
        # The portal replaces the whole list each time, so steps done before a restart are sent again.
        $stepList = @()
        $nowKeys = @($sync.Picked | ForEach-Object { $_.Key })
        foreach ($p in @($sync.PrevSteps)) {
            if (-not $p -or $nowKeys -contains $p.Key) { continue }
            $o = [ordered]@{ name = [string]$p.name; ok = [bool]$p.ok }
            if ($p.note) { $o.note = [string]$p.note }
            $stepList += $o
        }
        foreach ($p in $sync.Picked) {
            $o = [ordered]@{ name = $p.PortalName; ok = ($sync.Status[$p.Key] -eq 'Done') }
            $d = [string]$sync.Detail[$p.Key]
            if ($d) { if ($d.Length -gt 300) { $d = $d.Substring(0, 300) }; $o.note = $d }
            $stepList += $o
        }
        $pick = @{ BranchCode = $sync.BranchCode; Kind = $sync.Kind; Tag = $sync.PcName; EmployeeMode = $sync.EmployeeMode; EmployeeId = $sync.EmployeeId }
        $info = Get-PcInfo -AssetTag $sync.PcName -UsedBy $sync.UsedBy
        $body = New-PortalAssetBody -Info $info -Pick $pick -Steps $stepList -ScriptVersion ('window ' + $sync.GuiVersion)
        if ($sync.Demo -and -not $sync.DemoPost) {
            Write-Info ("Demo: would log this PC as {0} at branch {1}." -f $sync.PcName, $sync.BranchCode)
            $sync.PortalResult = 'Demo: not logged in the portal.'
        } else {
            try {
                $r = Send-PcToPortal -Body $body
                if ($r) { $sync.PortalResult = "Logged in the portal as $($r.asset_tag)." }
                else { $sync.PortalResult = 'Not logged in the portal yet - saved on this PC and sent the next time setup runs here.'; $sync.PortalFailed = $true }
            } catch {
                Write-Fail "Could not log this PC in the portal: $($_.Exception.Message)"
                $sync.PortalResult = "Not logged in the portal: $($_.Exception.Message)"
                $sync.PortalFailed = $true
            }
        }
    }
    $sync.RestartNeeded = [bool]$global:EasyfinRestartNeeded
} catch {
    $sync.Fatal = $_.Exception.Message
} finally {
    $sync.Done = $true
}
'@

function Set-StepStatus {
    param([string]$Key, [string]$Word)
    $t = $state.StepUi[$Key].Status
    $t.Text = $Word
    switch ($Word) {
        'Waiting' { $t.Foreground = '#8A979E' }
        'Working' { $t.Foreground = '#0F4C5C' }
        'Done'    { $t.Foreground = '#1E8E4E' }
        'Failed'  { $t.Foreground = '#C0392B' }
        default   { $t.Foreground = '#8A979E' }
    }
}

function Complete-Run {
    $state.Running = $false
    $state.Finished = $true
    $sync = $state.Sync
    $done = @($state.Picked | Where-Object { $sync.Status[$_.Key] -eq 'Done' }).Count
    $failed = @($state.Picked | Where-Object { $sync.Status[$_.Key] -eq 'Failed' })
    $ui.Bar.IsIndeterminate = $false
    $ui.Bar.Value = 100
    if ($sync.Fatal) {
        $ui.Activity.Text = 'Setup could not start'
        $ui.SubStatus.Text = $sync.Fatal
    } elseif ($failed.Count -eq 0) {
        $ui.Activity.Text = "Finished - all $done steps done"; if ($done -eq 1) { $ui.Activity.Text = 'Finished - done' }
        $ui.SubStatus.Text = 'Everything worked.'
    } else {
        $ui.Activity.Text = "Finished - $done done, $($failed.Count) failed"
        $ui.SubStatus.Text = 'Failed: ' + (($failed | ForEach-Object { $_.Name }) -join ', ') + '. The reason is in red in the box below.'
    }
    if ($sync.PortalResult) {
        $ui.SubStatus.Text += "  " + $sync.PortalResult
        if ($sync.PortalFailed) { $ui.SubStatus.Foreground = '#C0392B' }
    }
    $todo = @()
    $again = @(Get-FollowUpSteps)
    if ($sync.RestartNeeded -and $again.Count -gt 0) { $todo += 'press "Restart and carry on" - it finishes by itself after you sign in again' }
    elseif ($sync.RestartNeeded) { $todo += 'restart this PC' }
    $staffDone = @(@($state.Picked) + @($state.Choice.PrevSteps) | Where-Object { $_ -and $StaffLoginSteps -contains $_.Key })
    if ($state.Mode -eq 'new' -and $staffDone.Count -eq 0) { $todo += "sign in as the staff member and run email and Teams" }
    if ($todo.Count -gt 0) { $ui.Hint.Text = 'Still to do: ' + ($todo -join '; ') + '.' } else { $ui.Hint.Text = 'Nothing else to do on this PC.' }
    if ($sync.LogFile) { Add-LogLine ''; Add-LogLine "Full log: $($sync.LogFile)" 'DarkGray' }
    $ui.StartBtn.Content = 'Close'
    $ui.StartBtn.IsEnabled = $true
    if ($sync.RestartNeeded -and -not $Demo) {
        if ($again.Count -gt 0) { $ui.RestartBtn.Content = 'Restart and carry on' } else { $ui.RestartBtn.Content = 'Restart PC now' }
        $ui.RestartBtn.Visibility = 'Visible'
    }
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
    $ps = $state.Ps; $sync = $state.Sync
    if (-not $ps) { return }

    # 1. new text lines
    $info = $ps.Streams.Information
    while ($state.InfoIdx -lt $info.Count) {
        $rec = $info[$state.InfoIdx]; $state.InfoIdx++
        $msg = $rec.MessageData
        $colour = 'Gray'
        if ($msg -and $msg.PSObject.Properties['ForegroundColor'] -and $msg.ForegroundColor -ne $null) { $colour = "$($msg.ForegroundColor)" }
        $text = "$msg"; if ($msg -and $msg.PSObject.Properties['Message']) { $text = "$($msg.Message)" }
        Add-LogLine $text $colour
    }
    $errs = $ps.Streams.Error
    while ($state.ErrIdx -lt $errs.Count) { Add-LogLine ("   [ERROR] " + $errs[$state.ErrIdx]) 'Red'; $state.ErrIdx++ }

    # 2. progress bars from the modules (Write-Progress)
    $prog = $ps.Streams.Progress
    while ($state.ProgIdx -lt $prog.Count) {
        $r = $prog[$state.ProgIdx]; $state.ProgIdx++
        if ("$($r.RecordType)" -eq 'Completed') { $state.Progress.Remove($r.ActivityId) } else { $state.Progress[$r.ActivityId] = $r }
    }
    if ($state.Running) {
        if ($sync.CurrentText) { $ui.Activity.Text = $sync.CurrentText }
        if ($state.Progress.Count -gt 0) {
            $top = $state.Progress[($state.Progress.Keys | Sort-Object | Select-Object -Last 1)]
            $ui.SubStatus.Text = ('{0} - {1}' -f $top.Activity, $top.StatusDescription)
            if ($top.PercentComplete -ge 0) { $ui.Bar.IsIndeterminate = $false; $ui.Bar.Value = $top.PercentComplete }
            else { $ui.Bar.IsIndeterminate = $true }
        } else {
            $ui.SubStatus.Text = 'Working...'
            $ui.Bar.IsIndeterminate = $true
        }
        foreach ($p in $state.Picked) { if ($sync.Status[$p.Key]) { Set-StepStatus $p.Key $sync.Status[$p.Key] } }
    }

    # 3. a module is asking something
    if ($sync.Prompt) {
        $q = $sync.Prompt; $sync.Prompt = $null
        $ui.SubStatus.Text = 'Waiting for your answer...'
        $sync.Answer = Show-ModuleQuestion $q
        $sync.Answered = $true
    }

    # 4. finished
    if ($sync.Done -and $state.Running -and $state.InfoIdx -ge $info.Count) {
        foreach ($p in $state.Picked) { if ($sync.Status[$p.Key]) { Set-StepStatus $p.Key $sync.Status[$p.Key] } }
        $timer.Stop()
        Complete-Run
    }
})

$ui.StartBtn.Add_Click({
    if ($state.Finished) { $window.Close(); return }
    if ($state.Running) { return }

    $picked = @($Steps | Where-Object { $_.Mode -eq $state.Mode -and $state.StepUi[$_.Key].Check.IsChecked })
    if ($picked.Count -eq 0) { [void][Windows.MessageBox]::Show($window, 'Tick at least one thing to do.', 'Easyfin PC Setup', 'OK', 'Information'); return }
    $pcName = ''
    # Linked runs always need a name: it is how the PC is listed in the portal.
    if ($state.Linked -or ($picked | Where-Object { $_.Key -eq 'pc' -or $_.Key -eq 'register' })) {
        $pcName = Get-NewPcName
        if (-not $pcName) { [void][Windows.MessageBox]::Show($window, 'Pick a branch and a PC number (1-99).', 'Easyfin PC Setup', 'OK', 'Information'); return }
    }
    if (($picked | Where-Object { $_.Key -eq 'office' }) -and -not ($state.Linked -and $global:EasyfinPortal -like 'https://*') -and -not $ui.PwBox.Password -and -not $Demo) {
        [void][Windows.MessageBox]::Show($window, 'Type the setup password - Office needs it.', 'Easyfin PC Setup', 'OK', 'Information'); return
    }

    $usedBy = $ui.UsedByBox.Text.Trim()
    $empMode = 'keep'; $empId = $null; $staffId = $null
    if ($state.Linked) {
        $who = $ui.UsedByCombo.SelectedItem
        if ($who) {
            $empMode = $who.Tag.Mode; $empId = $who.Tag.Id; $staffId = $who.Tag.Id
            $usedBy = ''
            if ($empMode -eq 'id') { $usedBy = $who.Tag.Name }
            elseif ($empMode -eq 'keep' -and $state.Existing -and $state.Existing.assigned_to) {
                $usedBy = [string]$state.Existing.assigned_to.name; $staffId = [int]$state.Existing.assigned_to.id
            }
        }
    }
    $staffEmail = $ui.StaffEmailBox.Text.Trim()
    if ($staffEmail -and $staffEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        [void][Windows.MessageBox]::Show($window, 'The work email does not look right. Fix it or leave it empty.', 'Easyfin PC Setup', 'OK', 'Information'); return
    }
    $loginIsStaff = [bool]$ui.StaffLoginBox.IsChecked
    if (($picked | Where-Object { $StaffLoginSteps -contains $_.Key }) -and -not $loginIsStaff) {
        $r = [Windows.MessageBox]::Show($window, "Email and Teams only work when you are signed in to Windows as the staff member (this login is '$env:USERNAME').`n`nIs this their login?", 'Easyfin PC Setup', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
        $loginIsStaff = $true
    }

    Start-Run -Picked $picked -Choice @{
        PcName = $pcName; Password = $ui.PwBox.Password; UsedBy = $usedBy; Rename = [bool]$ui.RenameBox.IsChecked
        BranchCode = (Get-SelectedCode); Kind = (Get-Kind); EmployeeMode = $empMode; EmployeeId = $empId
        StaffName = $usedBy; StaffEmail = $staffEmail; StaffId = $staffId; LoginConfirmed = $loginIsStaff; PrevSteps = @()
    }
})

# Starts the worker. $Choice holds every answer, so a run after a restart can start without the form.
function Start-Run {
    param([array]$Picked, [hashtable]$Choice)
    $sync = [hashtable]::Synchronized(@{
        Picked = $Picked; PcName = $Choice.PcName; Password = $Choice.Password; Demo = $Demo; DemoPost = [bool]$env:EASYFIN_DEMO_POST
        Mode = $state.Mode; UsedBy = $Choice.UsedBy; Rename = [bool]$Choice.Rename
        Portal = $null; Code = $null; BranchCode = $Choice.BranchCode; Kind = $Choice.Kind; EmployeeMode = $Choice.EmployeeMode; EmployeeId = $Choice.EmployeeId
        StaffName = $Choice.StaffName; StaffEmail = $Choice.StaffEmail; StaffId = $Choice.StaffId; LoginConfirmed = [bool]$Choice.LoginConfirmed
        PrevSteps = @($Choice.PrevSteps)
        GuiVersion = $GuiVersion; PortalResult = $null; PortalFailed = $false
        LocalRoot = $LocalRoot; RepoBase = $RepoBase
        Status = [hashtable]::Synchronized(@{}); Detail = [hashtable]::Synchronized(@{})
        Prompt = $null; Answer = $null; Answered = $false; Done = $false; Fatal = $null
        CurrentKey = ''; CurrentText = ''; RestartNeeded = $false; LogFile = $null
    })
    if ($state.Linked) { $sync.Portal = $global:EasyfinPortal; $sync.Code = $global:EasyfinCode }
    $state.Choice = $Choice
    foreach ($s in $Steps) { $state.StepUi[$s.Key].Check.IsEnabled = $false; $state.StepUi[$s.Key].Status.Text = '' }
    foreach ($p in $Picked) { $state.StepUi[$p.Key].Check.IsChecked = $true; Set-StepStatus $p.Key 'Waiting' }
    foreach ($c in 'GroupBox', 'BranchBox', 'KindL', 'KindD', 'NumBox', 'KeepName', 'PwBox', 'ModeNew', 'ModeReg', 'RenameBox', 'UsedByBox', 'UsedByCombo', 'StaffEmailBox', 'StaffLoginBox') { $ui[$c].IsEnabled = $false }
    $ui.StartBtn.IsEnabled = $false
    $ui.StartBtn.Content = 'Working...'
    $ui.Hint.Text = 'You can walk away. It only stops when it needs a click from you. Do not close this window.'
    $ui.Bar.IsIndeterminate = $true

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $sync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($workerScript)

    $state.Sync = $sync; $state.Ps = $ps; $state.Picked = $Picked
    $state.InfoIdx = 0; $state.ErrIdx = 0; $state.ProgIdx = 0; $state.Progress = @{}
    $state.Running = $true
    $state.Handle = $ps.BeginInvoke()
    $timer.Start()
}

# Steps worth running again after a restart: Windows updates (there are always more after the first
# round), anything that failed (often only because a restart was due), and the final check.
# The staff member's own email/Teams steps are not repeated - they need that person at the PC.
function Get-FollowUpSteps {
    $sync = $state.Sync
    if (-not $sync -or $Demo -or -not $sync.RestartNeeded -or $state.Round -ge $MaxRounds) { return @() }
    $again = @($state.Picked | Where-Object {
        $StaffLoginSteps -notcontains $_.Key -and $_.Key -ne 'final' -and
        ($_.Key -eq 'updates' -or $sync.Status[$_.Key] -eq 'Failed') })
    if ($again.Count -eq 0) { return @() }
    $again += @($state.Picked | Where-Object { $_.Key -eq 'final' })
    return $again
}

# Saves what is left to do and makes Windows open this window again at the next sign-in, as administrator.
function Save-Resume {
    param([array]$Again)
    $sync = $state.Sync
    $prev = @()
    $againKeys = @($Again | ForEach-Object { $_.Key })
    foreach ($p in @($state.Choice.PrevSteps)) { if ($p -and $againKeys -notcontains $p.Key) { $prev += $p } }
    foreach ($p in $state.Picked) {
        if ($againKeys -contains $p.Key) { continue }
        $o = [ordered]@{ Key = $p.Key; name = $p.PortalName; ok = ($sync.Status[$p.Key] -eq 'Done') }
        $d = [string]$sync.Detail[$p.Key]; if ($d) { if ($d.Length -gt 300) { $d = $d.Substring(0, 300) }; $o.note = $d }
        $prev += $o
    }
    $data = [ordered]@{
        Round = $state.Round + 1; Steps = $againKeys; Mode = $state.Mode
        PcName = $sync.PcName; UsedBy = $sync.UsedBy; BranchCode = $sync.BranchCode; Kind = $sync.Kind
        EmployeeMode = $sync.EmployeeMode; EmployeeId = $sync.EmployeeId
        StaffName = $sync.StaffName; StaffEmail = $sync.StaffEmail; StaffId = $sync.StaffId
        Portal = $sync.Portal; Code = $sync.Code; PrevSteps = $prev; SavedAt = (Get-Date -Format 's')
    }
    Initialize-LockedFolder (Split-Path $ResumeFile)
    if (Test-Path -LiteralPath $ResumeFile) { [IO.File]::Delete($ResumeFile) }
    ConvertTo-Json -InputObject $data -Depth 6 | Set-Content -Path $ResumeFile -Encoding UTF8
    & icacls.exe $ResumeFile /inheritance:r /grant:r '*S-1-5-32-544:F' '*S-1-5-18:F' | Out-Null

    # The paste line's one-liner, but waiting up to 5 minutes for the internet after sign-in.
    if ($LocalRoot) {
        $run = "& '" + (Join-Path $LocalRoot 'gui\start-gui.ps1') + "'"
    } else {
        $run = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `$t = `$null; " +
               "for (`$i = 0; `$i -lt 60 -and -not `$t; `$i++) { try { `$t = Invoke-RestMethod -Uri '$RepoBase/gui/start-gui.ps1' -UseBasicParsing } catch { Start-Sleep -Seconds 5 } }; " +
               "if (`$t) { Invoke-Expression `$t }"
    }
    $branch = ''
    if ($env:EASYFIN_BRANCH -match '^[A-Za-z0-9._-]+$') { $branch = "`$env:EASYFIN_BRANCH='$env:EASYFIN_BRANCH'; " }
    $arg = "-NoProfile -ExecutionPolicy Bypass -Command `"`$env:EASYFIN_RESUME='1'; $branch$run`""
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
    $trigger.Delay = 'PT20S'
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 12)
    Register-ScheduledTask -TaskName $ResumeTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
}

$ui.RestartBtn.Add_Click({
    $again = @(Get-FollowUpSteps)
    if ($again.Count -gt 0) {
        $names = ($again | ForEach-Object { $_.Name }) -join ', '
        $r = [Windows.MessageBox]::Show($window, "Restart now and carry on by itself?`n`nAfter the restart, sign in as '$env:USERNAME' again. This window opens by itself and does: $names.", 'Easyfin PC Setup', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
        try { Save-Resume -Again $again }
        catch {
            [void][Windows.MessageBox]::Show($window, "Could not set up carrying on after the restart: $($_.Exception.Message)`n`nRestart by hand and paste the line again.", 'Easyfin PC Setup', 'OK', 'Warning')
            return
        }
    } else {
        $r = [Windows.MessageBox]::Show($window, 'Restart this PC now?', 'Easyfin PC Setup', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
    }
    Restart-Computer -Force
})

$window.Add_Closing({
    param($sender, $e)
    if ($state.Running) {
        $r = [Windows.MessageBox]::Show($window, "Setup is still busy. Closing now can leave something half installed.`n`nClose anyway?", 'Easyfin PC Setup', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $e.Cancel = $true; return }
        $timer.Stop()
        try { [void]$state.Ps.BeginStop($null, $null) } catch { }
    }
})

if ($resume) {
    $keys = @($resume.Steps)
    $state.ResumePicked = @($Steps | Where-Object { $_.Mode -eq 'new' -and $keys -contains $_.Key })
    $state.ResumeChoice = @{
        PcName = [string]$resume.PcName; Password = ''; UsedBy = [string]$resume.UsedBy; Rename = $false
        BranchCode = [string]$resume.BranchCode; Kind = [string]$resume.Kind; EmployeeMode = [string]$resume.EmployeeMode; EmployeeId = $resume.EmployeeId
        StaffName = [string]$resume.StaffName; StaffEmail = [string]$resume.StaffEmail; StaffId = $resume.StaffId; LoginConfirmed = $false
        PrevSteps = @($resume.PrevSteps)
    }
    foreach ($s in $Steps) { $state.StepUi[$s.Key].Check.IsChecked = ($keys -contains $s.Key) }
    $ui.Activity.Text = 'Carrying on after the restart'
    $ui.SubStatus.Text = 'Starts by itself in a few seconds: ' + (($state.ResumePicked | ForEach-Object { $_.Name }) -join ', ')
    $state.ResumeTimer = New-Object Windows.Threading.DispatcherTimer
    $state.ResumeTimer.Interval = [TimeSpan]::FromSeconds(5)
    $state.ResumeTimer.Add_Tick({
        $state.ResumeTimer.Stop()
        if ($state.ResumePicked.Count -gt 0 -and -not $state.Running -and -not $state.Finished) { Start-Run -Picked $state.ResumePicked -Choice $state.ResumeChoice }
    })
    $window.Add_ContentRendered({ $state.ResumeTimer.Start() })
}

# Test hook used while building this: saves pictures of the window, presses Start by itself, then closes.
if ($env:EASYFIN_GUI_SHOT) {
    $shot = {
        param([string]$Name)
        $window.UpdateLayout()
        $bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth, [int]$window.ActualHeight, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
        $bmp.Render($window.Content)
        $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
        [void]$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
        $fs = [IO.File]::Create((Join-Path $env:EASYFIN_GUI_SHOT $Name)); $enc.Save($fs); $fs.Dispose()
    }
    $state.ShotTick = 0
    $auto = New-Object Windows.Threading.DispatcherTimer
    $auto.Interval = [TimeSpan]::FromMilliseconds(500)
    $auto.Add_Tick({
        $state.ShotTick++
        if ($state.ShotTick -eq 2) {
            if ($env:EASYFIN_GUI_MODE -eq 'register') { $ui.ModeReg.IsChecked = $true; $ui.UsedByBox.Text = 'Jane Smith' }
            if (-not $ui.GroupBox.SelectedItem) { $ui.GroupBox.SelectedIndex = 0 }
            if (-not $ui.BranchBox.SelectedItem) {
                $i = 0; foreach ($it in $ui.BranchBox.Items) { if ($it.IsEnabled -and -not $ui.BranchBox.SelectedItem) { $ui.BranchBox.SelectedIndex = $i }; $i++ }
                if (-not $state.Linked) { $ui.GroupBox.SelectedItem = 'Miloans'; $ui.BranchBox.SelectedIndex = 7; $ui.NumBox.Text = '2' }
            }
            if ($state.Linked -and $ui.UsedByCombo.Items.Count -gt 2) { $ui.UsedByCombo.SelectedIndex = $ui.UsedByCombo.Items.Count - 1 }
            & $shot '1-start.png'
            if (-not $resume) { $ui.StartBtn.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent))) }
        }
        if ($state.ShotTick -eq 14) { & $shot '2-working.png' }
        if ($state.Finished -and -not $state.ShotDone) { $state.ShotDone = $true; & $shot '3-finished.png'; $auto.Stop(); $window.Close() }
        if ($state.ShotTick -gt 120) { $auto.Stop(); $window.Close() }
    })
    $auto.Start()
}

Write-Host ''
Write-Host '  The Easyfin PC Setup window is open. Leave this black window open behind it.' -ForegroundColor Cyan
[void]$window.ShowDialog()
