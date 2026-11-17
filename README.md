# Easyfin PC Setup

Sets up a new Easyfin work PC (Windows 10/11) from one pasted line.

## Start

1. Right-click **Start** > **Terminal (Admin)** or **Windows PowerShell (Admin)**.
2. Paste this and press Enter:

```powershell
irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/start.ps1 | iex
```

3. The setup window opens. Pick the branch and the person, press **Start setup**, walk away.
   If a restart is needed at the end, press **Restart and carry on**: after you sign in again the
   window opens by itself and finishes (Windows updates round two, final check).

Want the old numbered text menu instead? Put `$env:EASYFIN_MENU=1;` in front of the line.

**Old Windows 10 PC and the line above fails?** Use this one instead. It switches on the modern security setting first:

```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/start.ps1 | iex
```

## What each option does

| # | Option | What it does | Status |
|---|---|---|---|
| 1 | PC settings | Restore point, PC name (`MIL-WORC-L01` rule: group, town, laptop or desktop, number), time zone + clock sync, region (en-ZA), screen locks after 10 minutes of no use, PC details file `C:\Temp\Setup\pc-info.json` | **ready** (screen lock untested) |
| 2 | Clean-up | Restore point, then removes McAfee and other trial antivirus, preinstalled Office trials, checks no Office other than 2013 is left, junk apps (games, Xbox, Copilot, personal Teams, new Outlook), stops sponsored apps and Game Bar coming back, turns off junk startup items, makes sure Defender is on | **ready** (Office check, games list, Defender untested) |
| 3 | Apps | Chrome, AnyDesk, Teams, TeamViewer, AweSun, Acrobat Reader. Skips anything already installed. Uses winget, falls back to the vendor's own download | **ready** |
| 4 | Chrome bookmarks | "Easyfin" bookmark folder (with sub-folders) in Chrome and Edge for everyone on the PC. Edit the list at the top of `modules/chrome-bookmarks.ps1` | **ready** |
| 5 | Office 2013 | Downloads the Office installer from OneDrive and runs setup. Asks for the **setup password** | **ready** |
| 6 | Windows updates | Installs all available updates and drivers one by one (skips big Windows version upgrades). Run again after the restart | **ready** |
| 7 | Email account | Adds a staff member's POP email (@bloans.co.za) to Outlook 2013. Run it signed in to Windows as that staff member. Outlook asks the password once | **ready** |
| 8 | Register this PC | For PCs already in use: records the details and who uses it, optional rename. Installs and removes nothing | **ready** |
| 9 | Speed-up | Only Outlook and Teams start with Windows (the rest is switched off, not removed; OneDrive, security, remote-help tools and drivers are kept). Best performance when plugged in, no animations or see-through effects, no ads, tips, news panel, web results in Start, Copilot or Recall. Shows file endings; desktops do not sleep. Never touches virus protection, updates or security | **built, untested** |
| 10 | Defaults, taskbar | Chrome as web browser, Acrobat Reader for PDFs, Chrome and Outlook on the taskbar. Best effort - Windows can ignore it. Shows from the staff member's next sign-in | **built, untested** |
| 11 | Final check | Checklist of what is on the PC, virus protection on, Windows and Office activated, a read-me on the Public Desktop for the staff member (edit the support sentence at the top of `modules/handover.ps1`), then deletes the setup downloads | **built, untested** |
| 12 | Teams account | Run signed in to Windows as the staff member. Asks the portal to make their Easyfin guest account and add them to their teams (once the portal has it - see PORTAL-PLAN.md phase 2), then opens Teams for them to sign in with their work email | **built, untested** |

Everything is safe to run twice: anything already done is skipped.

## Logs

Every run writes a log to `C:\Temp\Setup\logs\`. Downloads go to `C:\Temp\Setup\downloads\`.

## The setup password

This project is public, so private things (like the Office download link) are stored
**locked**. The script asks for the setup password when it needs one, and nothing
works without it. The password is never stored in this project.

To lock a new value: put it in your local `.env` file, then run
`tools\lock-value.ps1 -Name <NAME>` and paste the result into the module.

## Adding a new option

1. Copy an existing file in `modules\` as a starting point. Keep the "EDIT HERE" block at the top.
2. Make every step check "already done?" first, so it's safe to run twice.
3. If something fails, `throw` a clear message; the menu records it as Failed and carries on.
4. Add one line to the `$Modules` list at the top of `start.ps1`.
5. Add a row to the table above.

## Testing a change before uploading

From the project folder, in an admin PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

This runs your local files instead of the ones on GitHub (the menu says "test mode").

## Window version (the main way in since 17 Nov 2026)

A guided window instead of the numbered menu. It runs the same scripts. `start.ps1` opens it;
if it cannot open, the numbered menu shows instead.

- Pick the person from the portal's staff list and their work email fills itself (once the portal
  sends it); otherwise type it.
- Tick "I am signed in to Windows as this staff member" to also set up their Outlook email and Teams.
- After a restart it carries on by itself: a one-off sign-in task called "Easyfin PC Setup - carry on"
  reopens the window as administrator (at most 3 rounds), then removes itself.

See it without changing anything on the PC (no administrator needed):

```powershell
$env:EASYFIN_DEMO=1; irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/gui/start-gui.ps1 | iex
```

Real run (PowerShell as administrator):

```powershell
irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/gui/start-gui.ps1 | iex
```
