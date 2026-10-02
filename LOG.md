# Log

Newest first.

## 2026-10-02 — Script linked to the portal's asset list

- Portal phase 1 is on the VPS (PORTAL-API.md, written by the portal session). The window version now:
  checks the setup code, takes branches (+ PC name prefix) and staff from the portal, recognises a PC
  that is already registered (keeps its name), asks the portal for the next free number, and logs the
  PC + person + step results at the end. Office link comes from the portal when it has one.
- Only https portal addresses get the code. Test exception: http://41.222.36.148 when the line starts
  with `$env:EASYFIN_ALLOW_HTTP_TEST=1;` (remove after DNS cutover), and 127.0.0.1.
- If the portal cannot be reached the record is saved in C:\Temp\Setup\pending-portal.json.
- Tested against a fake portal on Nico's PC (new PC + already-registered PC, POST bodies checked).
  NOT yet tested against the real VPS - needs a code Nico makes himself.
- Nico renamed his own PC with Register this PC: HO-WORC-L01 after restart (worked).

## 2026-10-02 — Register-this-PC mode

- New module `modules/register-pc.ps1` (menu option 8) and a second mode in the window version:
  "PC already in use - just record it" - details + who uses it + optional rename, no installs.
- Branch list, Read-PcName, Set-PcName, Save-PcInfo, Get-PcIdentity now live in `lib/common.ps1`.
  pc-info.json gained AssetTag, UsedBy, HardwareUuid.
- Tested on Nico's PC: record without rename (normal user), both window modes in demo. Rename path
  and real admin run not yet tested. Nothing is sent to the portal yet.
- Nico wants the bulk roll-out to be staff self-service (he cannot log in to every PC) - proposal sent
  to the portal session: staff make a personal code in the portal, no admin needed, rename done later.

## 2026-10-02 — New PC naming rule, portal build plan sent

- PC names are now `<GROUP>-<TOWN>-<L|D><nn>` (MIL-WORC-L01, BUD-WORC-D02), Nico's decision; replaces
  EF-<portal code>-... . Portal branch codes are no longer used in names. Menu and window version updated.
- `PORTAL-PLAN.md` written and sent to the Portal_New session: "Set up a new PC" page, one-time codes
  (all RMs, scoped to their branches), asset API that links PC + staff member, serial/UUID identity,
  assignment history. Script side waits for the portal's final routes.
- Starter file `starter/Easyfin-PC-Setup.cmd` (GitHub release) - blocked by Smart App Control when
  downloaded; works from a USB stick or after Properties > Unblock. Paste line stays the main way.

## 2026-10-01 — Window version (trial) + portal link-up plan

- `gui/start-gui.ps1`: guided window (branch drop-down, tick boxes, live Done/Failed per step, progress
  bar, log box, finish summary). Runs the same modules in a second PowerShell; module questions pop up
  as dialogs. Separate folder so it can be scrapped. Demo mode tested on Nico's PC (pictures checked);
  REAL run as administrator not tested yet.
- PC settings: branch picked by number, laptop/desktop, PC number; Tulbagh (TUL) added.
- Portal link-up design written into PLAN.md; on hold until the portal's documents rebuild is done.

## 2026-10-01 — Chrome bookmarks

- Option 4: "Easyfin" folder in Chrome + Edge via ManagedBookmarks/ManagedFavorites policy.
  Portal sub-folder (8 dashboard pages, from Portal_New via the portal session) and Other systems
  (Webfin, Allps, ARP, SimplePay, MaxMoney). All 7 menu options now built.

## 2026-10-01 — PC settings + Windows updates

- Nico confirmed Office 2013 (option 5) and Email account (option 7) work on a real laptop.
- Option 1 PC settings: restore point, rename EF-<code>-<L|D><nn> using the portal's own branch codes
  (2-4 letters, from Portal_New BranchSeeder.php via the portal session), time zone + clock sync,
  en-ZA region (also copied to sign-in screen / new logins), pc-info.json for the asset manager.
- Option 6 Windows updates: Windows' own update service, drivers included, feature upgrades skipped,
  one update at a time with progress. Search tested on Nico's PC; install not yet tested.

## 2026-09-26 — Email account module, new setup password

- Option 7: adds a POP account to Outlook 2013 via a profile file (outlook /importprf). Settings as
  Easyfin has always used: mail.bloans.co.za:110, smtp.bloans.co.za:587, no encryption (Nico's call,
  raised that the server supports encryption). Password typed in Outlook on first open. Not yet tested.
- Setup password changed at Nico's request; Office link re-locked.
- Clean-up: fallback removal for Office trials the ODT leaves behind.

## 2026-09-26 — Clean-up module + install timer

- Clean-up (option 2): restore point, McAfee via McAfee's own removal tool (MCPR, interactive),
  other trial/OEM programs, preinstalled Office (ODT Remove All), junk Store apps incl. personal Teams
  and new Outlook, sponsored-app suggestions off (this user + Default profile), junk startup items off.
- Apps: top progress bar now counts running time during winget installs.
- First real test on a laptop: Apps worked (AnyDesk, TeamViewer, AweSun installed; Acrobat ok, needed restart).
  Office stopped correctly because 7 Microsoft 365 language trials were preinstalled.

## 2026-09-25 — Test build: menu, Apps, Office 2013

- Menu (`start.ps1`), shared helpers (`lib/common.ps1`), Apps and Office 2013 modules, README.
- Apps: Chrome, AnyDesk, Teams, TeamViewer, AweSun, Acrobat Reader. AweSun installer is not silent.
- Office link locked with a setup password (in `.env`, never uploaded).
- Checked on Nico's PC: syntax in PowerShell 5.1, app detection, AweSun link lookup, a real
  download, unlocking the link, and the first 20 MB of the Office download. Not yet run end to end as admin.

## 2026-09-25 — Project created

PowerShell toolkit to set up new Easyfin work PCs from one pasted line. Folder
layout, CLAUDE.md and PLAN.md written; no scripts yet. Waiting on Nico's answers
to the questions in PLAN.md before building step 1 (menu + shared helpers).
