# Structure Outline

## Approach
Probe the unverified APIs first, then ship independently useful slices: panel polish, static Spots tab, pool learning + nearby list (with HereBeDragons embedded), map pins, detector, docs. Pure logic lives in `Logic.lua` with `tests/run.lua` coverage; WoW calls in `Core.lua`/`Map.lua`; UI in `Panel.lua`.

Every phase: `lint.sh TackleBox` (skill script) clean and `lua TackleBox/tests/run.lua` prints "all tests passed"; then deploy to `_forever_\Interface\AddOns\TackleBox`, `/reload` with no errors.

## Phase 1: Probe pools, position, map hooks
Extend `/tb probe` so one in-game run answers the design's open risks; record results in `probe-results.md`. Check HereBeDragons licence offline.

**Files**: `TackleBox/Core.lua`, `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md`
**Key changes**:
- `TB.Probe()` — adds: `UnitIsGameObject("softinteract")`, `UnitName("softinteract")`, `GameTooltipTextLeft1:GetText()` + secret check, `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(map,"player")`, `GetPlayerFacing()`, presence of `WorldMapFrame.AddDataProvider`, `MapCanvasDataProviderMixin`.
- `TB.trace` — logs `PLAYER_SOFT_INTERACT_CHANGED` payloads and softinteract name at `UNIT_SPELLCAST_CHANNEL_START`.

**Verify**: lint and tests green. In game: stand facing a pool, `/tb probe`, then cast at the pool and `/tb probe` again; paste output into probe-results.md. **Gate**: if neither softinteract nor tooltip gives the pool name, stop and revisit design decision 1.

---

## Phase 2: Panel polish
Same look, cleaner build, plus visual upgrades. Tab strip ready for 6 tabs.

**Files**: `TackleBox/Panel.lua`, `TackleBox/CastBar.lua` (theme refs only)
**Key changes**:
- `L = { PAD, PITCH, HEAD, TOP, ... }` layout table; header y offsets derived from it.
- `TB.THEME.muted`, `TB.THEME.hi` — replace literal greys and highlight alphas.
- `TB.TitleFont(fs)` — MORPHEUS with `GameFontNormalLarge` fallback.
- Header gradient band; 1px rope border on row icons; `RenderEmpty(section)` centred icon + text.
- `MakeTab` — icon-only label when `n >= 6`, full title in tooltip.

**Verify**: lint and tests green (no logic change). In game: collapsed and expanded panels look aligned, `/fstack` shows no overlaps, empty tab shows the new empty state, close button and hover match.

---

## Phase 3: Spots tab (static data) + Forever zone bands
New 6th tab listing zones for the player's skill with notable loot and pool types.

**Files**: `TackleBox/Data.lua`, `TackleBox/Logic.lua`, `TackleBox/Panel.lua`, `TackleBox/tests/run.lua`
**Key changes**:
- `DATA.zones` — rewritten to published Forever tiers (third-party note).
- `DATA.pools = { {key, name, loot, water, icon} }` — enUS names.
- `DATA.spots = { [zone] = { notable = {names}, pools = {keys} } }`.
- `TB.SpotsRows(spots, zones, pools, skill, zone) -> rows` — current zone first, header rows by section.
- `TB.sections` entry `{key="spots", ...}`.

**Verify**: tests for `SpotsRows` (in band, current zone first, unknown zone) and updated `WhereRows`. In game: Spots tab shows rows for current skill; Where tab bands changed.

---

## Phase 4: Learn pools + nearby list + waypoint
Embed libs, record pools when fishing them, show nearest learned pools in the Spots tab.

**Files**: `TackleBox/Libs/` (LibStub, CallbackHandler-1.0, HereBeDragons-2.0, HereBeDragons-Pins-2.0), `TackleBox/TackleBox.toc`, `TackleBox/.luacheckrc`, `TackleBox/Core.lua`, `TackleBox/Logic.lua`, `TackleBox/Panel.lua`, `TackleBox/tests/run.lua`, `.github/workflows/package-tb.yml` (if it filters files)
**Key changes**:
- SV: `TackleBoxDB.version = 2`, `pools[uiMapID] = { {x, y, t, n, last} }`, `pins = {map, minimap}`, `detect = true`.
- `TB.PoolKey(name, pools) -> key|nil` — pure.
- `TB.OffsetPos(x, y, facing, yards, zoneW, zoneH) -> x, y` — pure.
- `TB.MergePool(list, x, y, t, now, radiusYd, zoneW, zoneH) -> list, isNew` — pure.
- `TB.NearestPools(list, px, py, zoneW, zoneH, max) -> rows` — pure.
- `TB.ReadPoolTarget() -> name|nil` (softinteract then tooltip; secret-safe) — Core.
- Learning: name captured at `UNIT_SPELLCAST_CHANNEL_START`, saved on `LOOT_READY` when `IsFishingLoot()`.
- Spots tab "Nearby" section; row click sets `C_Map.SetUserWaypoint` + super-track; 2 s ticker only while Spots visible.

**Verify**: tests for `PoolKey`, `OffsetPos`, `MergePool` (merge, new, other type), `NearestPools`. In game: fish a pool, it appears under Nearby with distance; fish it again, count bumps; click sets waypoint; `/reload` keeps it; indoors shows "no position here".

---

## Phase 5: Map pins
Learned pools on world map and minimap.

**Files**: `TackleBox/Map.lua` (new), `TackleBox/TackleBox.toc`, `TackleBox/Core.lua` (slash toggles)
**Key changes**:
- `TB.Pins.Refresh()` — remove all, add per learned pool on current map (minimap) and all maps (world map) via HBD-Pins.
- Pin frame pool; tooltip "Firefin Snapper School · seen 7×".
- Triggers: `PlayerZoneChanged` callback, pool learned, toggle change.
- `/tb pins map|minimap`.

**Verify**: lint/tests green. In game: pins show on world map and minimap, rotate-minimap on/off correct, toggles hide them, open world map in combat — no `ADDON_ACTION_BLOCKED`.

---

## Phase 6: Pool detector
Alert when a pool is targeted or hovered.

**Files**: `TackleBox/Core.lua`, `TackleBox/Logic.lua`, `TackleBox/tests/run.lua`
**Key changes**:
- `TB.ShouldAlert(lastAlerts, key, now, cooldown) -> bool` — pure.
- `PLAYER_SOFT_INTERACT_CHANGED` handler + `GameTooltip` OnShow hook → `TB.ReadPoolTarget()` → chat line + `TBFlash`; skipped in combat or when `db.detect` false.
- `/tb detect` toggle.

**Verify**: tests for `ShouldAlert` cooldown. In game: face a pool, alert once; again within 60 s, silent; in combat, silent; `/tb detect` off silences.

---

## Phase 7: Docs and release 1.2.0
**Files**: `TackleBox/README.md`, `TackleBox/CHANGELOG.md`, `TackleBox/TackleBox.toc` (Version), root `README.md`, `docs/index.html` (TackleBox blurb)
**Verify**: lint/tests green; README commands match `/tb` help output; packaging zip contains `Libs/`.

## Testing Checkpoints
- **After 1**: probe-results.md has pool-name, position, map-hook facts; go/no-go recorded; HBD licence noted.
- **After 2**: panel polished, all 5 tabs behave as before.
- **After 3**: Spots tab live with static data; Where uses new bands.
- **After 4**: libs load; pools learned, saved (v2), listed by distance, waypoint works.
- **After 5**: pins on both maps, toggles, no taint.
- **After 6**: detector alerts with cooldown.
- **After 7**: docs and version bumped, ready to tag.
