# Portal API for PC setup — as built

Written for: the Easyfin PC Setup session. From: Portal_New (portal-new-57), 2 Oct 2026.
Portal commit `6ad01224`. On the VPS since 2 Oct 2026. Source of truth:
`Portal_New/app/Http/Controllers/Api/PcSetupApiController.php` and
`Portal_New/tests/Feature/PcSetupApiTest.php`.

## Where and how to test

- **Base address today:** `http://41.222.36.148` — **plain http only.** The VPS has
  no https name or certificate until DNS cutover. Your "https with a valid
  certificate only" rule blocks testing against it. Options, Nico's call: a
  test-only switch in the script that allows this one http address, or wait for
  cutover. Do not weaken the rule for normal use.
- **Getting a test code:** Nico signs in on the VPS, opens Assets > Set up a new
  PC, presses "Make a setup code" and copies the line. The feature is at "visible
  to you only", so only his (developer) codes work for now. Never paste a code in chat.
- The paste line the page prints (portal address is whatever address the page was opened on):
  `$env:EASYFIN_PORTAL='<base>'; $env:EASYFIN_CODE='<code>'; irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/gui/start-gui.ps1 | iex`

## Rules for every call

- Prefix `/api/pc-setup`. Header `Authorization: Bearer <code>`. Send `Accept: application/json`.
- The code is 40 letters and digits, lasts 120 minutes, can be cancelled, and
  works for any number of PCs.
- Throttle: 90 calls a minute per IP (429 above that).
- **Every refusal is `{"error": "one plain sentence"}`** — show it as-is.
- A code answers as the person who made it. It only sees and writes that
  person's branches.

| Status | Meaning |
|---|---|
| 401 | Code unknown, expired, cancelled, its maker stopped, or the feature is switched off |
| 403 | Branch (or the PC's current branch) is outside the maker's reach |
| 404 | Lookup: PC not on the register. Office link: not set yet |
| 409 | Retired/lost asset, name already used, serial belongs to a non-PC, two-asset clash |
| 422 | Something in the request is missing or does not fit |

401 sentences: "This setup code is not recognised. Get a new one from the portal." ·
"This setup code was cancelled. Get a new one from the portal." ·
"This setup code has expired. Get a new one from the portal." ·
"The person who made this setup code may no longer set up PCs. Ask for a new code." ·
"Setting up PCs through the portal is switched off at the moment. Ask Nico."

## Routes

### GET /session
```json
{ "made_by": "Nico van der Sandt", "expires_at": "2026-10-02T11:14:46+02:00", "portal_name": "Easyfin Portal" }
```
No `preset` yet — that idea is parked with Nico.

### GET /branches
Active branches the maker may see, by name. `pc_name_prefix` can be null.
```json
[ { "code": "CW", "name": "Miloans CW", "pc_name_prefix": "MIL-WORC" } ]
```
An RM will not see Head Office (HO) or WBDC — they belong to no RM group.

### GET /branches/{code}/staff
Active staff of that branch. `{code}` is `branches.code` (e.g. `CW`).
```json
[ { "id": 12, "name": "Jane Smith" } ]
```
403 if the branch is not the maker's or is closed.

### GET /branches/{code}/next-tag?kind=laptop|desktop
```json
{ "asset_tag": "MIL-WORC-L02", "existing": ["MIL-WORC-L01"] }
```
Highest number plus one (a retired PC's number is never reused). 422 if `kind`
is wrong or the branch has no prefix; 409 past 99.

### GET /assets?branch=CW
Laptops and desktops registered at that branch.
```json
[ { "asset_tag": "MIL-WORC-L01", "serial_number": "7XK2R94", "type": "Laptop", "status": "available" } ]
```

### GET /assets/lookup?serial=...&uuid=...
Either or both. Matched on serial first, else uuid.
```json
{ "asset_tag": "MIL-WORC-L01", "branch_code": "CW", "kind": "laptop",
  "assigned_to": { "id": 12, "name": "Jane Smith" }, "status": "available" }
```
`assigned_to` is null when nobody has it. 404 = not registered. 403 = registered
somewhere the maker does not look after.

### POST /assets
Create-or-update, safe to repeat.

| Field | Rule |
|---|---|
| `serial_number` | string ≤100, or null when junk |
| `hardware_uuid` | string ≤64, or null. **At least one of the two is required** |
| `asset_tag` | **required**, ≤15. Stored upper-case |
| `branch_code` | **required**, `branches.code` |
| `kind` | **required**, `laptop` or `desktop` |
| `assigned_employee_id` | integer or null. **Leave the key out to not touch who has it.** `null` = nobody. Must be an id from that branch's staff list |
| `make`, `model` | strings ≤100. Asset name is "make model", set only when first created |
| `cpu` | string ≤150 |
| `ram_gb`, `disk_gb` | numbers |
| `windows_version`, `windows_build` | strings |
| `mac_addresses` | array of strings (≤12), e.g. `"A4:BB:6D:1C:90:2E (Wi-Fi)"` |
| `windows_user`, `outlook_email` | strings |
| `setup_date` | any date-time string; now if left out |
| `steps` | array of `{ "name": string ≤60, "ok": bool, "note": string ≤300 or absent }` |
| `script_version` | string ≤40 |

`setup_by` is NOT accepted — the portal records the code's maker. Any other
field is ignored. The whole `steps` list replaces the last run's list.

**Send step names as readable words** — "PC settings", "Clean-up", "Office 2013".
They are shown on the asset page as sent (a bare slug like `windows-update` is tidied).

**Naming:** a new or changed name must be `<branch prefix>-<L|D><2 digits>` and
match `kind`. A PC that is already registered may keep the name it has, whatever
it looks like — send back the `asset_tag` from lookup.

Replies:
```json
201 { "result": "created", "asset_tag": "MIL-WORC-L02", "asset_url": "http://.../assets/17" }
200 { "result": "updated", "asset_tag": "MIL-WORC-L02", "asset_url": "http://.../assets/17" }
```
`asset_url` only opens for someone signed in to the portal.

It never sets status, condition, price or supplier, and never deletes.

### GET /office-link
```json
{ "url": "https://..." }
```
404 with a sentence until Nico adds it to the server's settings.

## Things to know

- **Tulbagh** on the VPS is "Easyfin Tulbagh", code **`CCM`** (not TUL), and
  **switched off**, with no PC name prefix. It will not appear in `/branches`
  until Nico switches it on and sets "PC names start with" to `MIL-TULB` under
  Setup > Branches. The script never needs the code for names — use `pc_name_prefix`.
- The asset register on the VPS is empty, so the first PC at each branch is 01.
- Parked with Nico, not built: presets in `/session`, the per-branch roll-out
  view, "Register my PC" self codes.
