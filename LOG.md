# Log

Newest first.

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
