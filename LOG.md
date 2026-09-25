# Log

Newest first.

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
