# Module: Chrome bookmarks - puts an "Easyfin" bookmark folder in Chrome (and Edge) for everyone on the PC,
# using the browsers' company bookmark setting. Staff can't delete these; running again replaces the list.
# Check it worked: open chrome://policy and look for ManagedBookmarks.

# ============================ EDIT HERE ============================
# The repo is public - only links that are fine for anyone to see. Never a link with a password or key in it.
# A bookmark:  @{ Name = 'Shown name'; Url = 'https://...' }
# A folder:    @{ Folder = 'Folder name'; Items = @( bookmarks... ) }
$TopFolder = 'Easyfin'
# Portal links from the portal's own dashboard (Portal_New, 1 Oct 2026). Role-only pages just show
# "access denied" to staff without that role - harmless, so everyone gets the same list.
$Bookmarks = @(
    @{ Folder = 'Portal'; Items = @(
        @{ Name = 'Portal - Dashboard';  Url = 'https://portaleasfin.co.za/dashboard' }
        @{ Name = 'My documents';        Url = 'https://portaleasfin.co.za/documents/inbox' }
        @{ Name = 'Leave';               Url = 'https://portaleasfin.co.za/leave' }
        @{ Name = 'Daily Returns';       Url = 'https://portaleasfin.co.za/reports' }
        @{ Name = 'Weekly Returns';      Url = 'https://portaleasfin.co.za/weekly-returns' }
        @{ Name = 'Petty Cash';          Url = 'https://portaleasfin.co.za/petty-cash' }
        @{ Name = 'Attendance';          Url = 'https://portaleasfin.co.za/attendance' }
        @{ Name = 'Warnings';            Url = 'https://portaleasfin.co.za/documents/warnings' }
    ) }
    @{ Folder = 'Other systems'; Items = @(
        @{ Name = 'Webfin';              Url = 'https://easfin.webfin.co.za/Login.aspx' }
        @{ Name = 'Allps (debit orders)'; Url = 'https://iserv.amplifin.co.za/allps-i/AllpsiLogon.aspx' }
        @{ Name = 'ARP (Amplifin reports)'; Url = 'https://iserv.amplifin.co.za/arp/rdCenaccLogon.aspx' }
        @{ Name = 'SimplePay (payroll)'; Url = 'https://payroll.simplepay.cloud/login' }
        @{ Name = 'MaxMoney';            Url = 'https://online.maxmoney.co.za/MaxMoney/login/' }
    ) }
)
$AlsoEdge       = $true    # same folder in Microsoft Edge, in case staff open that
$ShowBookmarkBar = $true   # keep the bookmark bar visible so staff see the folder
# ===================================================================

if (-not $global:EasyfinSetupLoaded) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    . ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/lib/common.ps1' -UseBasicParsing)))
    Initialize-SetupLog
}

function ConvertTo-PolicyItem {
    param($Item)
    if ($Item.Folder) {
        $children = @()
        foreach ($c in $Item.Items) { $children += ConvertTo-PolicyItem $c }
        return [ordered]@{ name = $Item.Folder; children = $children }
    }
    if ($Item.Url -notmatch '^https?://') { throw "Bookmark '$($Item.Name)' has no proper web address: $($Item.Url)" }
    return [ordered]@{ name = $Item.Name; url = $Item.Url }
}

Write-Step 'Building the bookmark list'
$policy = @([ordered]@{ toplevel_name = $TopFolder })
foreach ($b in $Bookmarks) { $policy += ConvertTo-PolicyItem $b }
# -Compress keeps it on one line; -Depth must cover folder nesting or PS 5.1 silently flattens it.
$json = ConvertTo-Json -InputObject $policy -Depth 10 -Compress
$count = ([regex]::Matches($json, '"url"')).Count
Write-Info "$count bookmarks in the '$TopFolder' folder."

$targets = @(@{ Browser = 'Chrome'; Key = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Value = 'ManagedBookmarks' })
if ($AlsoEdge) { $targets += @{ Browser = 'Edge'; Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Value = 'ManagedFavorites' } }

foreach ($t in $targets) {
    Write-Step "$($t.Browser)"
    New-Item -Path $t.Key -Force | Out-Null
    $current = (Get-ItemProperty -Path $t.Key -Name $t.Value -ErrorAction SilentlyContinue).($t.Value)
    if ($current -eq $json) {
        Write-Skip "$($t.Browser) already has this bookmark list."
    } else {
        New-ItemProperty -Path $t.Key -Name $t.Value -Value $json -PropertyType String -Force | Out-Null
        Write-Ok "$($t.Browser) bookmarks set."
    }
    if ($ShowBookmarkBar) {
        $bar = 'BookmarkBarEnabled'; if ($t.Browser -eq 'Edge') { $bar = 'FavoritesBarEnabled' }
        New-ItemProperty -Path $t.Key -Name $bar -Value 1 -PropertyType DWord -Force | Out-Null
    }
}

Write-Info 'Chrome/Edge pick this up when they are next opened (or within a few minutes if already open).'
Write-Ok 'Bookmarks done.'
