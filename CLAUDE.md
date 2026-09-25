# Easyfin PC Setup

A PowerShell toolkit, hosted in a public GitHub repo, that sets up new
Windows 10/11 work PCs for Easyfin. On a new PC: open PowerShell as admin,
paste `irm https://raw.githubusercontent.com/<account>/easyfin-pc-setup/main/start.ps1 | iex`,
pick from a menu. Each menu item downloads one module script from the repo and
runs it. Design and build order: [PLAN.md](PLAN.md). History: [LOG.md](LOG.md).

## Tech stack

- Windows PowerShell **5.1** (the one built into Windows). Must also run on 7, but 5.1 is the target.
- winget for app installs, with vendor-installer fallback.
- Office 2013 from Nico's own ISO on OneDrive (link locked, see below). Not Microsoft 365 — his decision.
- No dependencies, no modules from the PowerShell Gallery.

## Project structure

```
start.ps1        — the menu; $Modules list at the top is the only place modules are registered
lib/common.ps1   — shared helpers (Write-Step/Ok/Skip/Fail, logging, installed-app checks)
modules/*.ps1    — one script per menu item
tools/           — run on Nico's PC only (lock-value.ps1)
.env             — LOCAL ONLY, gitignored: SETUP_PASSWORD and the plain private values
```

## Locked (private) values

The repo is public. Private values (the Office 2013 ISO OneDrive link) are stored in modules
AES-locked with the setup password (`Protect-/Unprotect-/Unlock-SetupSecret` in common.ps1).
The password lives only in Nico's `.env` and password manager; the script prompts for it at run time.
To change a value: edit `.env`, run `tools\lock-value.ps1 -Name <NAME>`, paste output into the module.
Never log the password or an unlocked value.

## How modules run

- `start.ps1` is executed via `irm | iex`, so it has no `$PSScriptRoot` and no files on disk.
  It downloads `lib/common.ps1` and each module from the raw GitHub URL at run time.
- Modules must also work when downloaded on their own — if the helpers aren't loaded,
  a module loads `lib/common.ps1` itself.
- Each module runs inside its own try/catch in `start.ps1`; a throw marks it Failed
  in the summary and the next module still runs.
- Log: `C:\Temp\Setup\logs\setup-<yyyyMMdd-HHmm>.log`, one per run.

## Code style

- PS 5.1 only: no `??`, `?.`, ternary, `&&`/`||`, `-Parallel`, `ConvertFrom-Json -AsHashtable`.
- Force TLS 1.2 before any web request: `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12`.
- `Invoke-WebRequest` needs `-UseBasicParsing` on 5.1 (no IE engine on new PCs). Set
  `$ProgressPreference = 'SilentlyContinue'` around downloads — the progress bar makes 5.1 downloads 10x slower.
- Every step checks "already done?" first. Idempotence is a requirement, not a nice-to-have.
- Editable lists (apps, bookmarks) live in one clearly marked block at the top of their script.
- Save `.ps1` files as UTF-8 **with BOM** — 5.1 misreads non-ASCII in BOM-less files.
  (Content fetched via `irm` is a string, so this matters only for local runs; keep the files ASCII anyway.)

## Git workflow

- Push straight to `main` — the one-liner always pulls `main`, so `main` must always work.
- Test a change on a real PC (or VM) before pushing it to `main`.
- Commit with `git commit -F <file>`.

## Boundaries

### Always
- Keep every module safe to run twice.
- Test in Windows PowerShell 5.1 syntax, not 7.
- Add new modules by: file in `modules/` + one line in `$Modules` + a README section.
- Download installers only from the vendor's official domain or Microsoft.

### Ask first
- Before adding a new module or app to the install list.
- Before anything that restarts the PC, removes software, or changes security settings (Defender, firewall, UAC).
- Before changing the one-liner URL or repo name — it's written on Nico's notes and in the README.

### Never
- Never put a password, licence key, API key, Wi-Fi key or internal-only URL in the repo. It is public.
- Never restart the PC mid-run without asking.
- Never download anything from a third-party mirror.
- Never build the next module before Nico has tested the current one on a real PC.

## Notes

- `Checkpoint-Computer` silently skips if a restore point was made in the last 24h — set
  `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore\SystemRestorePointCreationFrequency` to 0 first.
  System Protection is often off on new PCs: `Enable-ComputerRestore -Drive 'C:\'`.
- winget may be missing or unregistered on a fresh PC until App Installer updates; when run elevated
  it sometimes isn't on PATH — resolve it from `C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*`.
- Rename-Computer needs a restart to take effect.
- OneDrive share links set a FedAuth cookie on the first response and 403 the redirect without it —
  downloads must keep cookies (Save-Download uses a CookieContainer). Plain curl.exe -L fails.
- AweSun is not in winget and has no fixed download link; the module asks
  `client-api-global.aweray.com/softwares/SUNLOGIN_X_WINDOWS?lang=en&x64=1` for `downloadurl`.
  No known silent switch, so its installer runs visibly.
- winget is run via `Start-Process -NoNewWindow` so its progress bar draws; `& winget` inside a
  function pipes its output into the return value.
- Chrome ManagedBookmarks is a JSON string at `HKLM:\SOFTWARE\Policies\Google\Chrome\ManagedBookmarks`;
  folder name via `toplevel_name`. Verify at `chrome://policy`.
