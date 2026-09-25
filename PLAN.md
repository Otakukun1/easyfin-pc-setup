# Easyfin PC Setup — Plan

The design for the toolkit, agreed **before** any script is written.
Read this, answer the questions at the bottom, then we build one module at a time.

---

## What it does

On a brand-new work PC you open PowerShell **as administrator**, paste one line:

```powershell
irm https://raw.githubusercontent.com/<account>/easyfin-pc-setup/main/start.ps1 | iex
```

A menu appears. You pick what to run. Each choice downloads that one script
from GitHub and runs it. Nothing is installed on the PC first.

---

## Folder layout

```
easyfin-pc-setup/
├── start.ps1                     The menu. The module list sits at the very top.
├── lib/
│   └── common.ps1                Shared helpers: coloured output, logging, "is it installed?" checks
├── modules/
│   ├── pc-settings.ps1           1. Restore point, PC name, time zone
│   ├── apps.ps1                  2. Chrome, AnyDesk, Teams, Acrobat Reader
│   ├── chrome-bookmarks.ps1      3. "Easyfin" bookmark folder in Chrome
│   └── office.ps1                4. Microsoft 365 Apps
├── config/
│   └── office-configuration.xml  What Office installs (edit this, not the script)
├── README.md                     The one-liner, what each module does, how to add one
├── CLAUDE.md                     Rules for Claude when working on this project
├── PLAN.md                       This file
└── LOG.md                        What changed, newest first
```

Why `lib/common.ps1`: every module needs the same coloured output and logging.
Writing it once means a fix in one place fixes every module.

---

## The menu

```
  ==========================================
    EASYFIN PC SETUP                v1.0
    PC: DESKTOP-7F3K2  |  Admin: yes
  ==========================================

    1  Basic PC settings   restore point, PC name, time zone
    2  Apps                Chrome, AnyDesk, Teams, Acrobat Reader
    3  Chrome bookmarks    Easyfin bookmark folder
    4  Microsoft Office    Word, Excel, PowerPoint, Outlook

    A  Run everything (1 to 4, in order)
    Q  Quit

  Choose (you can also type several, e.g. 2,3):
```

Design decisions:

- **PC settings is number 1** because the restore point must be made before
  anything else changes the PC. "Run everything" runs in menu order.
- **"Run everything" asks all its questions first** (only the PC name, for now),
  then runs without stopping, so you can walk away.
- **Several at once:** typing `2,3` runs just those two.
- After a module finishes you go back to the menu. The summary shows when you quit
  or when "Run everything" ends.

### The module list at the top of start.ps1

Adding a module later = drop the file in `modules/` and add one line here:

```powershell
$Modules = @(
    @{ Key = '1'; Name = 'Basic PC settings'; File = 'modules/pc-settings.ps1';      Info = 'restore point, PC name, time zone' }
    @{ Key = '2'; Name = 'Apps';              File = 'modules/apps.ps1';             Info = 'Chrome, AnyDesk, Teams, Acrobat Reader' }
    @{ Key = '3'; Name = 'Chrome bookmarks';  File = 'modules/chrome-bookmarks.ps1'; Info = 'Easyfin bookmark folder' }
    @{ Key = '4'; Name = 'Microsoft Office';  File = 'modules/office.ps1';           Info = 'Word, Excel, PowerPoint, Outlook' }
)
```

---

## How every module behaves

| Rule | How |
|---|---|
| Works on the PowerShell built into Windows (5.1) | No PowerShell 7-only features anywhere |
| Stops if not run as admin | `start.ps1` checks first and says so in red |
| Safe to run twice | Every step checks "already done?" and skips with a grey "already done" line |
| Coloured output | Green = done, Yellow = skipped/warning, Red = failed, Cyan = step heading |
| Log file | `C:\Temp\Setup\logs\setup-<date>-<time>.log` — one per run |
| One failure doesn't stop the rest | Each module runs inside its own error trap; the next one still runs |
| Summary at the end | Table: module, result (OK / Failed / Skipped), how long it took |
| No secrets | Nothing in the repo needs a password or key. The repo is public. |

---

## The four modules

### 1. Basic PC settings
1. Turn on System Protection for C: if it's off (it often is on new PCs), then make a restore point.
2. Ask for the new PC name, check it's a valid Windows name (max 15 characters, letters/numbers/dash).
   Skip if the PC already has that name.
3. Set time zone to South Africa Standard Time. Skip if already set.
4. Say clearly that the new name only takes effect after a restart. Offer to restart at the very end, not mid-run.

### 2. Apps
For each of Chrome, AnyDesk, Teams (new), Acrobat Reader:
1. Already installed? → skip.
2. Try winget (Windows' built-in app installer).
3. If winget is missing or fails → download the vendor's official installer and run it silently.
4. Check again that it's now installed.

Each app is one entry in a list at the top of the script (winget ID, direct download link, silent switches, how to detect it).

### 3. Chrome bookmarks
Writes Chrome's `ManagedBookmarks` policy to the registry, in a folder called "Easyfin".
The bookmark list is at the top of the script (placeholders to start). Running it again
simply overwrites with the current list. Staff can't delete these bookmarks — that's how
Chrome policies work.

### 4. Microsoft Office
1. Already installed (Microsoft 365 Apps found)? → skip.
2. Download Microsoft's Office Deployment Tool straight from Microsoft.
3. Download `config/office-configuration.xml` from the repo.
4. Run the install silently: 64-bit, English, Word, Excel, PowerPoint, Outlook. No Teams, OneNote, Access, Publisher, etc.

---

## Things you should know up front

- **Whoever controls the GitHub account controls every PC this runs on.** The one-liner runs
  whatever is in the repo at that moment. Turn on two-factor login on the GitHub account.
- **Bookmarks will be public.** The repo is public, so anyone can see the bookmark links.
  Fine for public sites (the portal login page is public anyway). Don't put anything private in them.
- **Restore points:** Windows only allows one every 24 hours by default. The script works around that.
- **winget on a fresh PC** is sometimes not ready until Windows has updated the Store once.
  That's exactly why the fallback download exists.
- **Old Windows 10 PCs** can fail to download from GitHub because of an old security setting.
  `start.ps1` switches on the modern one (TLS 1.2) first, but the one-liner itself runs before
  that — if it fails on an old PC, the README will give a slightly longer one-liner that fixes it.

---

## Build order (one at a time, you test each on a real PC)

| Step | What | You test |
|---|---|---|
| 1 | `start.ps1` + `lib/common.ps1` + README skeleton, push to GitHub | One-liner shows menu, admin check, log file appears |
| 2 | Module 1 — PC settings | Rename, time zone, restore point; run twice |
| 3 | Module 2 — Apps | All four install; run twice; test with winget broken |
| 4 | Module 3 — Chrome bookmarks | Folder shows in Chrome (`chrome://policy` to confirm) |
| 5 | Module 4 — Office | Office installs and activates when you sign in |
| 6 | "Run everything" end to end on a clean PC | Summary is correct |

---

## Questions for you

1. **GitHub account and repo name.** You're logged in as `Otakukun1`. Use that, with the repo
   called `easyfin-pc-setup`? Or a company GitHub account?
2. **PC naming rule.** Do Easyfin PCs follow a pattern (e.g. `EF-BRANCHNAME-01`)? If yes the
   script can check the name matches it.
3. **Office update channel.** Default is "Current Channel" (updates monthly, newest features).
   The other common choice is "Monthly Enterprise" (updates once a month on a fixed day, fewer surprises).
4. **Restart at the end.** Offer a restart (Y/N) at the end of "Run everything"? Recommended yes.
5. **Anything already on new PCs?** E.g. do they come with a manufacturer's Office trial or
   McAfee that should be removed? That would be a good future module.
