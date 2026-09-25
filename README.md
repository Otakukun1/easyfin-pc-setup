# Easyfin PC Setup

Sets up a new Easyfin work PC (Windows 10/11) from one pasted line.

## Start

1. Right-click **Start** > **Terminal (Admin)** or **Windows PowerShell (Admin)**.
2. Paste this and press Enter:

```powershell
irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/start.ps1 | iex
```

3. Pick a number from the menu, or **A** for everything.

**Old Windows 10 PC and the line above fails?** Use this one instead. It switches on the modern security setting first:

```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/start.ps1 | iex
```

## What each option does

| # | Option | What it does | Status |
|---|---|---|---|
| 1 | PC settings | Restore point, PC name (`EF-ABC-L01` rule), time zone, region, PC info file | coming soon |
| 2 | Clean-up | Removes bloatware and trial antivirus, turns off junk startup items | coming soon |
| 3 | Apps | Chrome, AnyDesk, Teams, TeamViewer, AweSun, Acrobat Reader. Skips anything already installed. Uses winget, falls back to the vendor's own download | **ready** |
| 4 | Chrome bookmarks | Easyfin bookmark folders in Chrome | coming soon |
| 5 | Office 2013 | Downloads the Office installer from OneDrive and runs setup. Asks for the **setup password** | **ready** |
| 6 | Windows updates | Installs all available updates | coming soon |
| 7 | Email account | Adds a staff member's email to Outlook | coming soon |

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
