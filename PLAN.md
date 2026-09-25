# Easyfin PC Setup — Plan

The design for the toolkit, agreed **before** any script is written.
We build one module at a time; Nico tests each on a real PC before the next.

---

## What it does

On a brand-new work PC you open PowerShell **as administrator**, paste one line:

```powershell
irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/start.ps1 | iex
```

A menu appears. You pick what to run. Each choice downloads that one script
from GitHub and runs it. Nothing is installed on the PC first.

The GitHub project is **public**. Nothing private is ever saved in it — anything
private (the Office download link, passwords) is typed in when the script runs.

---

## Folder layout

```
easyfin-pc-setup/
├── start.ps1                     The menu. The module list sits at the very top.
├── lib/
│   └── common.ps1                Shared helpers: coloured output, logging, "is it installed?" checks
├── modules/
│   ├── pc-settings.ps1           1. Restore point, PC name, time zone, region, PC info file
│   ├── cleanup.ps1               2. Remove bloatware, trial antivirus, junk startup items
│   ├── apps.ps1                  3. Chrome, AnyDesk, Teams, TeamViewer, AweSun, Acrobat Reader
│   ├── chrome-bookmarks.ps1      4. Easyfin bookmarks and folders in Chrome
│   ├── office.ps1                5. Office 2013 from Nico's own installer
│   ├── windows-update.ps1        6. Install all Windows updates
│   └── email-account.ps1         7. Add a staff email account to Outlook (later)
├── README.md                     The one-liner, what each module does, how to add one
├── CLAUDE.md                     Rules for Claude when working on this project
├── PLAN.md                       This file
└── LOG.md                        What changed, newest first
```

More modules get added over time — each one is a new file plus one line in the menu list.

---

## The menu

```
  ==========================================
    EASYFIN PC SETUP                v1.0
    PC: DESKTOP-7F3K2  |  Admin: yes
  ==========================================

    1  PC settings        restore point, PC name, time and region
    2  Clean-up           bloatware, trial antivirus, startup junk
    3  Apps               Chrome, AnyDesk, Teams, TeamViewer, AweSun, Acrobat Reader
    4  Chrome bookmarks   Easyfin bookmarks and folders
    5  Office 2013        from your own installer
    6  Windows updates    install everything available

    7  Email account      add a staff member's email to Outlook

    A  Run everything (1 to 6, in order)
    Q  Quit

  Choose (you can also type several, e.g. 3,4):
```

Why this order:

- **PC settings first** — the restore point must exist before anything changes.
- **Clean-up before Apps** — so the clean-up can never touch something we just installed.
- **Windows updates last** — it's the slowest and the one most likely to want a restart.
- **Email account is not in "Run everything"** — it's per staff member, done after the PC is set up.
- **"Run everything" asks all its questions first** (PC name, Office link), then runs without stopping.
- Restart is offered once, at the very end.

### The module list at the top of start.ps1

```powershell
$Modules = @(
    @{ Key = '1'; Name = 'PC settings';      File = 'modules/pc-settings.ps1';      RunAll = $true;  Info = 'restore point, PC name, time and region' }
    @{ Key = '2'; Name = 'Clean-up';         File = 'modules/cleanup.ps1';          RunAll = $true;  Info = 'bloatware, trial antivirus, startup junk' }
    @{ Key = '3'; Name = 'Apps';             File = 'modules/apps.ps1';             RunAll = $true;  Info = 'Chrome, AnyDesk, Teams, TeamViewer, AweSun, Acrobat Reader' }
    @{ Key = '4'; Name = 'Chrome bookmarks'; File = 'modules/chrome-bookmarks.ps1'; RunAll = $true;  Info = 'Easyfin bookmarks and folders' }
    @{ Key = '5'; Name = 'Office 2013';      File = 'modules/office.ps1';           RunAll = $true;  Info = 'from your own installer' }
    @{ Key = '6'; Name = 'Windows updates';  File = 'modules/windows-update.ps1';   RunAll = $true;  Info = 'install everything available' }
    @{ Key = '7'; Name = 'Email account';    File = 'modules/email-account.ps1';    RunAll = $false; Info = "add a staff member's email to Outlook" }
)
```

---

## How every module behaves

| Rule | How |
|---|---|
| Works on the PowerShell built into Windows (5.1) | No PowerShell 7-only features anywhere |
| Stops if not run as admin | `start.ps1` checks first and says so in red |
| Safe to run twice | Every step checks "already done?" and skips it |
| Coloured output | Green = done, Yellow = skipped/warning, Red = failed, Cyan = step heading |
| Log file | `C:\Temp\Setup\logs\setup-<date>-<time>.log` — one per run |
| One failure doesn't stop the rest | Each module runs inside its own error trap; the next one still runs |
| Summary at the end | Table: module, result (OK / Failed / Skipped), how long it took |
| No secrets in the project | Anything private is typed in at run time and never written to the log |

---

## The modules

### 1. PC settings
1. Turn on System Protection for C: if it's off, then make a restore point.
2. Ask for the PC name and check it follows the naming rule (below). Skip if already named that.
3. Time zone: South Africa Standard Time. Sync the clock with the internet time server.
4. Region: South Africa (English) — date format, currency (R), number format.
5. Save a PC info file (name, serial number, make, model, RAM, Windows version) to
   `C:\Temp\Setup\pc-info.json` — ready for the portal's asset manager later.

**Naming rule:** `EF-ABC-L01`
- `EF` = Easyfin
- `ABC` = 3-letter branch code (list at the top of the script)
- `L` = laptop, `D` = desktop
- `01` = number

### 2. Clean-up
PCs are mixed brands, so the remove list covers the common ones.
- Remove: games (Candy Crush etc.), Xbox apps, trial antivirus (McAfee, Norton, etc.),
  manufacturer extras (Dell, HP, Lenovo, Acer, Asus), other preinstalled junk.
- Turn off startup items on a known-junk list. Anything not on the list is **shown, not touched** —
  so drivers and needed tools (AnyDesk etc.) keep working.
- Remove the **personal** Teams (Windows 11 "Microsoft Teams (free)", package `MicrosoftTeams`) so staff
  don't open the wrong one. The work or school Teams (`MSTeams`) installed by Apps stays.
- Remove the **preinstalled Office**: the "Microsoft 365 (Office)" / "Microsoft 365 Copilot" app
  (`Microsoft.MicrosoftOfficeHub`), and any manufacturer-loaded Microsoft 365 / OneNote trial
  (Click-to-Run, often several languages). Removed with Microsoft's Office Deployment Tool
  (`<Remove All="TRUE"/>`), downloaded from Microsoft. This only removes Click-to-Run Office,
  never Office 2013. Clean-up runs before the Office module, so Office 2013 installs cleanly.
- Never removes: Store, Calculator, Photos, Snipping Tool, Windows Security.
- The remove list sits at the top of the script so it's easy to add to.

### 3. Apps
Chrome, AnyDesk, Microsoft Teams (new), AweSun, Adobe Acrobat Reader. No setup after install.
For each: already installed → skip. Otherwise winget (Windows' built-in app installer);
if that fails, download the vendor's official installer and run it silently.
Each app is one entry in a list at the top of the script.

### 4. Chrome bookmarks
Writes Chrome's `ManagedBookmarks` policy: a top folder "Easyfin", with sub-folders.
The bookmark list sits at the top of the script (placeholders to start). Running again
overwrites with the current list. Staff can't delete these. Check at `chrome://policy`.

### 5. Office 2013
Nico's own Office 2013 installer file on OneDrive. **Decision pending** — see questions.
No product key for now.

### 6. Windows updates
Uses Windows' own update service (no extra downloads). Installs all available updates,
shows progress, says if a restart is needed. Safe to run again after the restart to pick up
the next round.

### 7. Email account (later)
All staff accounts use the same settings; only the email address and password change.
Script asks for name + email and creates the Outlook 2013 account; Outlook asks the password once
on first open ("remember password"). The password is never saved in the project or the log.

Mail settings (from Nico, 26 Sep 2026; checked from outside the same day):
- Username = full email address (`name@bloans.co.za`)
- Incoming `mail.bloans.co.za`, outgoing `smtp.bloans.co.za` (same server, cPanel/Dovecot, 197.189.230.11)
- Outgoing port 587, "my outgoing server requires authentication - same as incoming" ON
- Currently encryption OFF. Server supports encryption on 993 (IMAP), 995 (POP), 465 and 587.
  Its certificate covers `mail.bloans.co.za`, but only for programs that ask for the name
  (SNI); others get the host's own name `alma3.ds03-dcsrv.com` -> "name doesn't match" warning.
  Likely why encryption was switched off. **Open:** IMAP or POP; encryption on or off.

---

## Things you should know up front

- **Whoever controls the GitHub account controls every PC this runs on.** Turn on two-step login.
- **Bookmarks will be public** (the project is public). Don't put anything private in them.
- **Office 2013 has had no security updates since April 2023.** Nico's decision to keep it; only module 5 changes when he moves off it.
- **Restore points:** Windows only allows one every 24 hours by default. The script works around that.
- **winget on a fresh PC** is sometimes not ready until Windows has updated the Store once — that's why the fallback exists.
- **Old Windows 10 PCs** can fail to download from GitHub because of an old security setting. The README will have a slightly longer paste line for those.

---

## Build order (one at a time, Nico tests each on a real PC)

| Step | What | You test |
|---|---|---|
| 1 | Menu + shared helpers + README, push to GitHub | Paste line shows menu, admin check, log file appears |
| 2 | Module 1 — PC settings | Name rule, time, region, restore point, PC info file; run twice |
| 3 | Module 2 — Clean-up | Junk gone, nothing needed gone; run twice |
| 4 | Module 3 — Apps | All five install; run twice |
| 5 | Module 4 — Chrome bookmarks | Folders show in Chrome |
| 6 | Module 5 — Office 2013 | Downloads and installs |
| 7 | Module 6 — Windows updates | Updates install, restart message correct |
| 8 | "Run everything" on a clean PC | Summary correct |
| 9 | Module 7 — Email account | Account works in Outlook |

---

## Decisions log

- **25 Sep 2026** — GitHub `Otakukun1/easyfin-pc-setup`, public. Private things typed in at run time.
- **25 Sep 2026** — Naming rule `EF-ABC-L01` agreed; ties in with the portal asset manager later.
- **25 Sep 2026** — Office stays Office 2013 from Nico's own installer (not Microsoft 365). No product key for now.
- **25 Sep 2026** — Apps: Chrome, AnyDesk, Teams, TeamViewer, AweSun, Acrobat Reader. No setup after install.
- **25 Sep 2026** — Added modules: clean-up, Windows updates, email account.
- **25 Sep 2026** — Restart offered once, at the end.

## Still open

1. **Branch codes** — list of branches and a 3-letter code for each.
2. **Office download** — how the script gets the file (see chat, 25 Sep).
3. **Email account** — which email service Easyfin uses (for module 7, not needed yet).
