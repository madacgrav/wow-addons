# Design Discussion

## Current State
- TackleBox 1.1.0, vanilla, no libs; load order Data, Logic, Core, Actions, Panel, CastBar (`TackleBox.toc:9-14`), Interface 16001 (`TackleBox.toc:1`).
- Panel: themed backdrop panel with portrait, skill bar, misses, zone line, custom top tab strip and pooled rows (`Panel.lua:56-255`). Five tabs registered as `TB.sections` entries `{key,title,tab,icon,empty,build}` (`Panel.lua:257-316`), active tab in `TB.db.tab` (`Core.lua:17`).
- Layout uses hand-placed y offsets (-58/-65/-86/-100/-138) beside constants TOP/HEAD (`Panel.lua:3-4,91-122,169`); grey .6 and highlight alphas live outside `TB.THEME` (`Panel.lua:8-11,195,233,327`); title is plain `GameFontNormalLarge` (`Panel.lua:82-84`).
- Data: zone bands per enUS zone name (`Data.lua:18-26`), sourced from older third-party guides; they disagree with published Forever tiers (research Q3) and miss Forever zones (Zephras Isle, Riverglades, Shen'Dralas, Hyjal). No pool types, no per-zone loot, no coordinates anywhere (research Q2).
- No map, position, soft-interact or tooltip-object code; none of these have been probed in Forever (research Q2, Q5).
- Saved variables: `TackleBoxDB` (account) and `TackleBoxCharDB` (char), defaults merged on `ADDON_LOADED` (`Core.lua:17-26`), no version field.
- Tests: `tests/run.lua` loads only Data + Logic, pure functions, no WoW stubs (`tests/run.lua:1-8`).

## Desired End State
1. **Polished panel**: same sea/rope/sand look, but layout derived from constants, one padding value, theme-owned greys/highlights, consistent hover strength, close button aligned, title in a display font with fallback, gradient header band, bordered row icons, readable empty state, tab strip that fits 6 tabs.
2. **Spots tab** (6th tab): for the player's skill, zones worth fishing with notable fish/loot and the pool types that spawn there; below that, **nearby learned pools** in the current zone sorted by distance, click a row to set a waypoint.
3. **Learned pools**: casting Fishing at a pool records `{map, x, y, type}` (player position offset along facing), merged with nearby records of the same type, saved per account.
4. **Map pins**: learned pools shown on the world map and minimap (HereBeDragons-Pins), icon per pool type, tooltip with name and times seen; toggles to hide each.
5. **Pool detector**: when a fishing pool becomes the soft-interact target (or under the mouse tooltip), show a throttled alert ("Firefin Snapper School nearby").

Verify: `lint.sh TackleBox && test.sh TackleBox` / `lua tests/run.lua` green with new pure-logic tests; in game `/reload` clean, fish a pool, see it appear in Spots, on world map and minimap; `/reload` keeps it; detector fires when facing a pool.

## Patterns to Follow
- **Sections registry**: new tab = one `TB.sections` entry with `build` returning rows `{icon,text,sub,progress,onClick?,onTooltip?}` (`Panel.lua:257-316`); row rendering stays in `GetRow`/`RenderPanel` (`Panel.lua:137-255`).
- **Pure logic in `Logic.lua`, WoW calls in `Core.lua`/`Actions.lua`** (research cross-cutting). Pool matching, merging, distance sort, spots rows are pure and tested in `tests/run.lua` with the `eq` helper (`tests/run.lua:6-8`).
- **Event wiring through `TB.On`** single frame (`Core.lua:9-12`); init via `TB.inits` on `PLAYER_LOGIN` (`Core.lua:52-56`); refresh via debounced `TB.Refresh` (`Core.lua:42-50`).
- **Defaults merge** via `TB.MergeDefaults` (`Logic.lua:3-10`); new keys go into `DEFAULTS` (`Core.lua:17`).
- **Data provenance**: IDs in `Data.lua` trace to probe-results or wago DB2; third-party guide numbers carry a source comment (`Data.lua:2,15-16`). Spots/pool data uses names, flagged "third-party: warcraft.wiki.gg Fishing_Pool, Gfinity 2026-10-22".
- **Probe-first for unverified APIs**: one `/tb probe` style run recorded in `probe-results.md` before relying on behaviour (GH-22 pattern, `Core.lua:167` `db.lastProbe`).
- **Title font fallback** pattern from `BusinessCard/Skin.lua:96-97`.
- **pcall around risky reads, cache in combat** like `TB.ReadAura` (`Core.lua:69-76`); treat secret values as missing.
- **Do NOT follow**: hand-placed y literals (`Panel.lua:91-122`); duplicated 26 pitch (`Panel.lua:140,248-253`); unthrottled `OnUpdate` for anything new (`CastBar.lua:47-53` stays as is); enUS-only matching is accepted with a `ponytail:` note as in `Data.lua:17`.

## Design Decisions
1. **Pool locations = learned as you fish** (Q1 A). No seed coordinates. On fishing cast (`UNIT_SPELLCAST_CHANNEL_START` for `DATA.fishingSpells`), read the target pool name from `UnitName("softinteract")` when `UnitIsGameObject("softinteract")`, else `GameTooltipTextLeft1` if the tooltip is showing a world object; match against `DATA.pools` names. Position = `HBD:GetPlayerZonePosition()` + 15 yd along `GetPlayerFacing()` (GatherMate2 method, research Q5). Confirm with `IsFishingLoot` on `LOOT_READY` before saving; unmatched casts are ignored.
2. **Merge rule**: same map + same pool type within 15 yd of an existing record → bump `n`, update `last`, average position; else append. ponytail: linear scan per map, fine for hundreds of nodes.
3. **Saved schema** (account-wide): `TackleBoxDB.version = 2`, `TackleBoxDB.pools[uiMapID] = { {x, y, t = poolKey, n, last} }`, `TackleBoxDB.pins = { map = true, minimap = true }`, `TackleBoxDB.detect = true`. Migration: absent version → 2, nothing to convert.
4. **Libraries embedded** (Q2 A): vendor `Libs/LibStub`, `Libs/CallbackHandler-1.0`, `Libs/HereBeDragons` (2.0 + Pins-2.0) into `TackleBox/Libs/`, listed first in the TOC. First libs in the repo; `.luacheckrc` excludes `Libs/`. Packaging keeps them in the zip.
5. **Pins**: one `TB.Pins` module (new file `Map.lua`) owns world map + minimap icons via HBD-Pins `AddWorldMapIconMap` / `AddMinimapIconMap`, pooled pin frames, rebuilt on `PlayerZoneChanged` callback and when a pool is learned. Minimap pins only for the current map. Icon per pool type from `DATA.pools[*].icon`.
6. **Nearby = Spots tab section + detector** (Q3 C).
   - Nearby list: learned pools on the current map sorted by `HBD:GetZoneDistance`, top 10, sub = "42 yd · seen 7×". Row click: `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`.
   - Refresh: 2 s `C_Timer` ticker only while panel shown, expanded and Spots active; cancelled otherwise. No `OnUpdate`.
   - Detector: `PLAYER_SOFT_INTERACT_CHANGED` → if game object and name matches a pool → chat line + existing `TBFlash` pulse, throttled once per pool per 60 s; also a `GameTooltip` OnShow hook for mouseover. Off via `TB.db.detect`.
7. **Spots tab content** (Q4 A): new `DATA.pools` (key, enUS name, loot, water, icon) and `DATA.spots` (zone, band, notable loot names, pool keys) from warcraft.wiki.gg + Gfinity. Rows: zone in band (current zone first), sub "Stonescale Eel, Firefin · Stonescale Eel Swarm". Sections inside one tab via a header row style.
8. **Zone bands replaced with published Forever tiers** (default taken, Q4 linked question not answered): rewrite `DATA.zones` to Gfinity tiers incl. Forever zones, flagged third-party. `WhereRows` tests updated.
9. **UI polish** (Q5 A+B):
   - Layout constants table (`PAD = 12`, header rows derived from `HEAD`/`TOP`), one row pitch constant.
   - `THEME.muted`, `THEME.hi` (alpha .10 for rows and tabs).
   - Close button aligned with BusinessCard's inset.
   - Tab label shortened, icon-first when 6 tabs, tooltip carries full title.
   - Title in `Fonts\MORPHEUS.ttf` with `GameFontNormalLarge` fallback; header gradient band using `Fade` with shallows.
   - Row icons get a 1px rope border; empty state = centred muted icon + text instead of a plain row.
   - Toggles for pins/detect live in the existing minimap-button right-click / slash, no options panel.
10. **No Ace3, no options UI**; vanilla frames per `references/ace3-vs-vanilla.md`. No secure frames touched; waypoint and pin calls are not protected. Detector suppresses alerts in combat.

### Constraints
- Interface `16001` (from skill `references/toc-format.md`).
- No never-emit names (`references/forever-api-notes.md`).
- Every API name verified in `references/forever-api-index.md` (all of `C_Map`, `C_SuperTrack`, `UnitIsGameObject`, `PLAYER_SOFT_INTERACT_CHANGED`, `GetPlayerFacing` present per research Q4/Q5); unverified items go through the probe first.

## What We're NOT Doing
- No live scan of objects (no API exists) and no reading of minimap tracking blips.
- No seed/pre-filled pool coordinates; no Wowhead scraping.
- No sharing pools between players (addon comms), no import/export.
- No localization beyond enUS pool/zone names.
- No Ace3, AceConfig options panel, or LibDBIcon; minimap button code stays as is and is not deduped across addons.
- No changes to Catch, Quest, Camp, Water tab logic, cast bar, or one-key cast actions.
- No hand-rolled MapCanvas data provider.
- No Find Fish integration.

## Open Risks
- **Soft-interact on fishing pools unverified**: fishing holes may not become `softinteract` targets; tooltip fallback needs the mouse over the pool. Probe phase decides; if both fail, learning falls back to recording "unknown pool" only when loot is a known pool fish (weak).
- **Secret values**: tooltip text / soft-interact name may be secret in some states (`PLAYER_SOFT_INTERACT_CHANGED` is SecretWhenUnitIdentityRestricted). Guard with pcall + `issecretvalue`-style checks per notes.
- **HBD license unconfirmed** in the lib files; check repo/CurseForge before vendoring. HBD Forever branch reported, not tested.
- **WorldMapFrame data provider taint** in Forever unverified; HBD-Pins is the mitigation; probe pins with world map open in and out of combat.
- **Position nil indoors/instances** (`GetPlayerMapPosition` restricted) — skip recording, hide nearby list with a "no position here" empty state.
- **15 yd offset accuracy**: cast distance varies; merge radius may split one pool into two records or merge neighbours. Tunable constant.
- **Published bands are fan-sourced**; may not match live Forever.
- **6 tabs at 296 px** ≈ 46 px each; labels may need icon-only.
