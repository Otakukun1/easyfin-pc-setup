# PC Setup <-> Portal: build plan

Written for: the Portal_New Claude session that will build the portal side.
From: the Easyfin PC Setup session. Date: 2 Oct 2026. Nico has approved the direction;
he still confirms the build in the portal session's own window.

## What Nico wants

When the PC setup script runs on a work PC, the portal's asset register ends up with **that PC,
its details, and the staff member who uses it, linked together** - without anyone typing it in.
Two things to build on the portal side:

1. **"Set up a new PC" page** - where an RM gets a one-time code and the line to paste.
2. **Asset integration** - a small private API the script talks to, plus showing what it logged
   on the asset's page.

Nico asked that the pages be built with the portal's **rebuild-page skill**.

## Decisions already made (don't re-open without a reason)

- **Who may make a code:** all Regional Managers. A code only works for branches its maker may see.
- **Auth:** one-time setup code from the page, not a long-lived key. Nothing secret in the public
  GitHub repo; the script's "setup password" goes away.
- **Main way to start:** paste line with a Copy button. Windows Smart App Control blocks downloaded
  `.cmd` files outright (tested 1 Oct), pasting is never blocked.
- **PC is identified by its serial number**, not its name. Names can change; serials don't.
- **PC naming is `<GROUP>-<TOWN>-<L|D><nn>`** (changed 2 Oct from EF-<code>-...), table below.
  The portal's `branches.code` values stay exactly as they are.
- **VPS first** is fine. The script takes the portal address from the paste line.

## PC naming table

Max 15 characters (Windows limit); longest here is 13. `L` laptop, `D` desktop, `nn` 01-99.

| branches.code | Branch | PC name prefix |
|---|---|---|
| CW | Miloans CW (Worcester) | MIL-WORC |
| MCT | Miloans CT | MIL-CAPE |
| HAM | Hamlet | MIL-HAML |
| WEL | Wellington | MIL-WELL |
| STR | Strand | MIL-STRA |
| SW | Somerset West | MIL-SWES |
| PRL | Paarl | MIL-PAAR |
| (Tulbagh - Nico added it, check its code) | Tulbagh | MIL-TULB |
| DD | De Doorns | QUA-DDOR |
| VIL | Villiersdorp | QUA-VILL |
| CER | Ceres | QUA-CERE |
| BRE | Bredasdorp | QUA-BRED |
| CAL | Caledon | QUA-CALE |
| BUD | Budget CW (Worcester) | BUD-WORC |
| GAN | Gansbaai | BUD-GANS |
| WOL | Wolseley | BUD-WOLS |
| ROB | Robertson | BUD-ROBE |
| ONL | Budget Online | BUD-ONLI |
| QCW | Quickloans CW (Worcester) | QCK-WORC |
| HEI | Heidelberg | TLG-HEID |
| SWE | Swellendam | TLG-SWEL |
| GEO | George | TLG-GEOR |
| KNY | Knysna | TLG-KNYS |
| KIL | Killarney | TLG-KILL |
| MAI | Maitland | TLG-MAIT |
| HO | Head Office Worcester | HO-WORC |
| WBDC | Worcester Budget Debt Collection | WBDC-WORC |

**Ask:** store this prefix on the branch (e.g. a `pc_name_prefix` column, unique, editable in
Setup > Branches) and return it from the API, so the list lives in one place. Until then the script
carries the same table (in `modules/pc-settings.ps1`).

## What "good" looks like (research, and what it means here)

Checked against how established asset tools work (Snipe-IT's check-out/check-in model, Intune's
"primary user", general IT asset practice) and API security guidance (OWASP API Security: broken
authentication, short-lived scoped tokens).

1. **One PC = one record, for ever.** Create-or-update by serial number. A rename, a Windows reset
   or a second setup run must update the same record.
2. **Serial numbers are sometimes junk.** No-name PCs report `Default string`, `To be filled by
   O.E.M.`, `System Serial Number`, `None`, blank, or all zeros - Nico's own PC reports make/model
   "Standard". Two PCs with the same junk value would collide on the unique column.
   -> The script sends both `serial_number` and `hardware_uuid` (the motherboard's UUID). It sends
   `serial_number: null` when the value is junk. The portal matches on serial when present,
   otherwise on `hardware_uuid`. Suggest storing `hardware_uuid` as an `asset_data` row or a new
   unique nullable column - your call.
3. **Assignment is an event with history, not just a field.** Every tool that does this well keeps
   who had the PC, from when to when, and who made the change. "Who had this laptop in March?" must
   be answerable after it is reassigned.
   -> When the assigned person changes, close the old assignment and open a new one; never just
   overwrite `assigned_to`. If the portal has no assignment-history table yet, this needs one.
4. **Link the PC to a real employee record, chosen from a list.** Windows login names (`user`,
   `admin`, `janic`) are not reliable. The person running setup picks the staff member from the
   branch's active staff, or "Nobody yet / shared PC".
   -> The Windows login name and the Outlook address are sent too, but only as extra details.
5. **The portal decides the next PC number.** Two setups at the same branch on the same day must
   not both get `L02`. The portal suggests the next free tag and refuses a tag that belongs to a
   different serial.
6. **Codes: random, short-lived, scoped, hashed, logged.**
   - Long random value (it is pasted, never typed) - 32+ characters.
   - Stored hashed, shown once, expires after ~2 hours, can be cancelled from the page.
   - Works only for the maker's branches. Every call logged: code id, maker, IP, route, result.
   - Rate limited. Feature flag to switch the whole API off.
   - HTTPS only. The script will refuse a portal address that is not `https://` with a valid
     certificate - **if the VPS is only reachable by IP today, tell me**, because that blocks testing.
7. **The code can only add knowledge, never remove or re-price anything.** Laptop/Desktop PC types
   only. It may set branch, tag, model, details, assigned person. It may not set price, supplier,
   condition, or retired/lost, and it never deletes. Refuse (409) if the serial belongs to a
   retired/lost asset - a person must un-retire it in the portal first.
8. **Collect only what is needed (POPIA).** Hardware details, PC name, branch, setup results, and
   the link to an employee. No files, no browsing data, no passwords. The staff list sent to the
   script is id + display name only.
9. **Offline must not lose the record.** If the POST fails, the script saves the details on the PC
   and says so plainly; the next run sends them. So the POST must be safe to repeat.
10. **Plain-sentence errors.** RMs will read them. Every 4xx returns `{"error": "one plain sentence"}`.

## API (all under `/api/pc-setup`, header `Authorization: Bearer <code>`)

Route names and field names are a proposal - change them to fit the portal, just tell me the final ones.

- `GET /session` -> `{ "made_by": "Jane Smith", "expires_at": "...", "portal_name": "Easyfin Portal" }`
  Lets the script check the code up front and greet the right person.
- `GET /branches` -> `[{ "code": "CW", "name": "Miloans CW", "pc_name_prefix": "MIL-WORC" }]`
  Only branches the code's maker may see.
- `GET /branches/{code}/staff` -> `[{ "id": 12, "name": "Jane Smith" }]` active employees of that branch.
- `GET /branches/{code}/next-tag?kind=laptop` -> `{ "asset_tag": "MIL-WORC-L02", "existing": ["MIL-WORC-L01"] }`
- `GET /assets/lookup?serial=...&uuid=...` -> the existing record for this PC if there is one
  (`asset_tag`, `branch_code`, `assigned_to {id,name}`, `status`), or 404. Lets the script say
  "this PC is already MIL-WORC-L01, used by Jane - keep that?" instead of asking again.
- `POST /assets` -> create-or-update. Body:
  ```json
  {
    "serial_number": "ABC123",            // null when junk
    "hardware_uuid": "4C4C4544-...",
    "asset_tag": "MIL-WORC-L02",
    "branch_code": "CW",
    "kind": "laptop",                      // laptop | desktop
    "assigned_employee_id": 12,            // null = nobody yet / shared
    "make": "Dell", "model": "Latitude 5440",
    "cpu": "...", "ram_gb": 16, "disk_gb": 512,
    "windows_version": "Windows 11 Pro 25H2", "windows_build": "26200",
    "mac_addresses": ["AA:BB:... (Wi-Fi)"],
    "windows_user": "janic",
    "outlook_email": "jane@bloans.co.za",  // only if the email step ran
    "setup_date": "2026-10-02T09:14:00+02:00",
    "steps": [ { "name": "apps", "ok": true }, { "name": "office", "ok": false, "note": "..." } ],
    "script_version": "..."
  }
  ```
  Replies: `201 {"result":"created","asset_tag":...,"asset_url":...}`, `200 {"result":"updated",...}`,
  `403` branch outside the code's reach, `409` tag belongs to another PC / asset is retired or lost,
  `422` validation, `401` code expired or unknown.
- `GET /office-link` -> `{ "url": "..." }` from the portal's `.env` (Nico adds it himself; it is in
  the script project's local `.env` as `OFFICE_ISO_LINK`). Never put it in chat or in git.

## Portal pages

1. **Set up a new PC** (RMs): one button "Make a setup code"; then the paste line with a Copy
   button, the expiry time, and three plain steps (right-click Start > Terminal (Admin) > paste >
   Enter). A list of the user's recent codes: made when, expires, used for which PCs, Cancel button.
   Paste line format:
   ```
   $env:EASYFIN_PORTAL='https://<portal>'; $env:EASYFIN_CODE='<code>'; irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/gui/start-gui.ps1 | iex
   ```
2. **Asset page** (existing): show what setup logged - hardware details, last setup date and by
   whom, step results (green/red), and the assignment history.

## Script side (mine, after you send the final routes)

- Read `EASYFIN_PORTAL` / `EASYFIN_CODE`; without them the script works as today (no logging).
- Branch list, staff list and next tag from the portal; look up the PC first.
- New "Who will use this PC?" choice in the window.
- POST at the end of every run; save-and-retry when offline.
- Office link from the portal; remove the locked link and the setup password.

## What I need back

Final routes, field names, example responses for each, the test address, how to get a test code,
and anything above you changed and why.
