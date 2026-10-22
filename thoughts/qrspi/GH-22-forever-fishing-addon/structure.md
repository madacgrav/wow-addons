# Structure Outline

## Approach
New addon `TackleBox/` (namespace `TB`, `/tb`). It copies WUK's skeleton: `On()` dispatcher, inits/refreshers, nil-safe SavedVariables, a pure `Logic.lua` tested under lua5.1, and a per-addon CI workflow.

Phase 1 ships the shell, which includes the probe. A probe run gates all data. Each later phase adds one panel section, end to end: `Data.lua` entries, then Logic, then Core reads, then the panel rows.

## Phase 1: Shell, skill line, probe, CI
**Delivers.**
- The addon loads and the panel opens.
- The panel is movable, has a minimap button, and responds to `/tb`.
- The panel shows Fishing skill.
- `/tb probe` writes the fishing facts to SavedVariables.
- CI tests the addon and releases `tb-v0.1.0`.

**Gate.** Run the probe in game and record `probe-results.md` before Phase 2.

**Files.**
- `TackleBox/TackleBox.toc`, `Data.lua`, `Logic.lua`, `Core.lua`, `Panel.lua`
- `TackleBox/tests/run.lua`, `README.md`, `CHANGELOG.md`
- `.github/workflows/package-tb.yml`

**Key changes.**
- `TackleBox.toc`
  - `## Interface: 16001`, `## Version: 0.1.0`
  - `SavedVariables: TackleBoxDB`, `SavedVariablesPerCharacter: TackleBoxCharDB`
  - File order: Data, Logic, Core, Panel
- `TB.DATA = { campBuffs={}, waterWalk={items={},auras={}}, questFish={}, fish={} }` (in `Data.lua`). Empty until the probe runs.
- `TB.MergeDefaults(sv, defaults) -> table`. Copied from `WUK/Logic.lua:16`.
- `TB.FormatTime(sec) -> string`. Copied from WUK Logic.
- `TB.On(event, fn)`, `TB.inits`, `TB.refreshers`, `TB.Refresh()`, `TB.Print`, `TB.Secret(v)`. Copied from `WUK/Core.lua:3-17,137-141`.
- `TB.Refresh` is debounced: a `pending` flag plus `C_Timer.After(0.1)`, as in `PP/Panel.lua:136-137`.
- `TB.ReadSkill() -> {level, max, modifier} | nil`, via `GetProfessions()` then `GetProfessionInfo(fishing)`.
  - `TB.active` = character has Fishing.
- Defaults
  - account `{frames={}, minimapAngle=200, shown=true, locked=false, collapsed={}, lastProbe=nil}`
  - character `{catches={}}`
- `TB.Probe()` dumps the following to `TackleBoxDB.lastProbe`:
  - player auras: spellId, name, expiration, secret flags
  - bag items: id, name, quality, class/subclass
  - `GetProfessionInfo(fishing)`
  - `C_Spell.GetSpellInfo(7620 / 131474)`
  - `type(IsFishingLoot)`
  - `GetSubZoneText()`
  - the last-loot snapshot
  - the last channel snapshot: `UnitChannelInfo("player")` start/end, secret flags, and the CHANNEL_START→STOP order relative to `LOOT_READY`
- Loot snapshot (probe-only in this phase): on `LOOT_READY`, store slots `{link, name, quality, qty}` plus `IsFishingLoot()` plus the last channel spellID in `TB.lastLoot`.
- Panel (`Panel.lua`)
  - `BasicFrameTemplateWithInset`, pre-built rows, `TB.RenderPanel(view)`
  - `view = {sections={ {key, title, rows={ {icon, text, sub} }} }}`
  - Collapsible section headers.
  - `MakeMovable` copied from `WUK/UI.lua:13-26`.
  - Minimap button copied from `WUK/Settings.lua:73-110`.
- `/tb show|hide|lock|reset|probe`
- `package-tb.yml`: copy of `package-wuk.yml` with paths filter `TackleBox/**`, tag `tb-v`, zip excluding `tests/*`.

**Verify.**
- `lua5.1 TackleBox/tests/run.lua` passes. It covers MergeDefaults, FormatTime and the section collapse view.
- In game:
  - The panel shows "Fishing 123/150".
  - Drag position persists across `/reload`.
  - Minimap button toggles the panel.
  - `/tb probe` succeeds at each probe site: standing at a Rack, at a Hut, after catching a fish, with the Draught and Surfer Shoes in bags, and with quest fish in bags.
- Outcome is recorded in `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md`.

---

## Phase 2: Quest fish
**Delivers.** The Quest fish section shows each Artisan fish as `have/need` (bags + bank), with a zone hint.

**Files.** `Data.lua`, `Logic.lua`, `Core.lua`, `Panel.lua`, `tests/run.lua`

**Key changes.**
- `TB.DATA.questFish = { {id=number, need=number, zone=string}, ... }`. IDs come from the probe.
- `TB.QuestRows(list, counts:{[id]=n}) -> rows`. Rows are sorted incomplete first, with `done` true when have ≥ need.
- `TB.CountItems(ids) -> {[id]=n}`, using `C_Item.GetItemCount(id, true)`.
- Refresh on `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED`.

**Verify.** Tests cover `QuestRows` (partial, complete, zero). In game, counts change when a fish is looted or banked.

---

## Phase 2b: Where to fish
**Delivers.** The "Where to fish" section is driven by skill. It shows:
- the recommended zones for the player's band
- the no-loss skill per zone
- whether a lure is needed
- an "outgrown" or "too low" flag for the current zone

**Files.** `Data.lua`, `Logic.lua`, `Core.lua`, `Panel.lua`, `tests/run.lua`

**Key changes.**
- `TB.DATA.zones = { {name=string, min=number, noLoss=number, max=number, lure=number?} }` (bands from the prior survey).
- `TB.DATA.lures = { {id=number, bonus=number} }`.
- `TB.WhereRows(zones, lures, skill, effective, currentZone) -> rows`
  - `effective` = level + modifier.
  - Each row is `{text=zone, sub="no loss at N" | "needs +X lure (Bright Baubles)", flag="here"|"outgrown"|"too low"}`.
- Refresh on `SKILL_LINES_CHANGED`, `ZONE_CHANGED_NEW_AREA` and `UNIT_INVENTORY_CHANGED` for the player, so modifier changes from pole or gear are picked up.

**Verify.**
- Tests cover `WhereRows` at these skill levels:
  - skill 1 (starting zones)
  - skill 60 (Redridge appears)
  - skill 210 effective 285 (lure note)
  - current zone outgrown
- In game, rows change after a skill-up and after equipping a pole.

---

## Phase 3: Fish collection
**Delivers.** Fish catches are recorded per character. The Collection section groups known fish into Uncommon, Rare and Unique, shows caught versus not caught, and gives the Chef's Knife product for Unique fish. Unknown catches appear as "Other".

**Files.** `Data.lua`, `Logic.lua`, `Core.lua`, `Panel.lua`, `tests/run.lua`

**Key changes.**
- `TB.DATA.fish = { [itemID]={tier="uncommon"|"rare"|"unique", knife=itemID?} }`
- `TB.IsFishingCatch(isFishingLoot:bool|nil, lastChannel:{spellID, t}|nil, now, fishingSpells) -> bool`
  - Uses `IsFishingLoot` when it is available.
  - Otherwise uses "the fishing channel ended within 30s".
- `TB.RecordCatch(catches, itemID, qty, now, zone) -> catches`. Each entry becomes `catches[id] = {n, first, last, zones={[zone]=n}}`. The zone is `GetRealZoneText()` plus `" - "..GetSubZoneText()` when the subzone is set.
- `TB.CollectionView(fishData, catches, qualityOf) -> rows`
  - Groups rows by tier.
  - Fish not listed in Data take their tier from quality (2 → uncommon, 3 → rare); anything else goes to "other".
- `UNIT_SPELLCAST_CHANNEL_START` with the player as unit stores `TB.lastChannel`. `LOOT_READY` then runs `IsFishingCatch`, reads the item ID from `GetLootSlotLink`, and calls `RecordCatch`.

**Verify.** Tests cover:
- `IsFishingCatch`: both paths, plus a stale channel.
- `RecordCatch`: accumulation.
- `CollectionView`: grouping and the "other" bucket.

In game, catching a fish increments its row, and it survives `/reload`.

---

## Phase 3b: Cast timer bar + got-away flash
**Delivers.**
- A movable bar counts down each fishing cast.
- A cast that ends with no fishing loot flashes the screen edge.
- The panel header shows a "got away: N" count for the session.
- `/tb flash` toggles the flash.

**Depends on.** Phase 3's channel and loot tracking (`TB.lastChannel`, the fishing-loot check).

**Files.** `Logic.lua`, `Core.lua`, `CastBar.lua` (new; added to the TOC after Panel), `tests/run.lua`

**Key changes.**
- `TB.CastProgress(startMs, endMs, nowMs) -> fraction 0..1, remainingSec`
  - Clamped to that range.
  - Returns nil if any input is secret or missing.
- `TB.IsMiss(stopT, lastLootT) -> bool`. True when there is no fishing loot at or after `stopT`, within the 1s window.
- Channel events:
  - `UNIT_SPELLCAST_CHANNEL_START` (player, fishing spell): show the bar and read `UnitChannelInfo`.
  - `UNIT_SPELLCAST_CHANNEL_STOP`: hide the bar, then `C_Timer.After(1)` runs `IsMiss`. On a miss, run `TB.Flash()` and increment `TB.session.misses`.
- `TB.lastLootT` is set in the Phase 3 `LOOT_READY` handler when the loot is a fishing catch.
- `CastBar.lua` frames:
  - `TBCastBar`: a `StatusBar` using `MakeMovable` key `"castbar"`, with an `OnUpdate` that is removed when hidden.
  - `TBFlash`: a full-screen edge texture with a fade-in/out animation group.
- Defaults: account `flash=true`; `frames.castbar` comes from `MakeMovable`.

**Verify.**
- Tests:
  - `CastProgress` covers start, mid, past end, and secret/nil input.
  - `IsMiss` covers loot before stop, loot after stop, and no loot.
- In game:
  - The bar counts down on a cast.
  - Clicking the bobber with a catch produces no flash.
  - Letting the cast expire produces a flash and the counter increments.
  - Jumping mid-cast produces a flash.
  - `/tb flash` disables the flash.
  - There are no errors in combat.

---

## Phase 4: Camp buffs
**Delivers.** The Camp section has one row per camp buff, showing the remaining time, "active" when the time is secret, or "needs skill N" when the player is below the unlock skill.

**Files.** `Data.lua`, `Logic.lua`, `Core.lua`, `Panel.lua`, `tests/run.lua`

**Key changes.**
- `TB.DATA.campBuffs = { {spellID=number, name=string, unlock=number} }`
- `TB.ReadAura(spellID) -> {active=bool, remaining=number|nil}`
  - Uses `C_UnitAuras.GetPlayerAuraBySpellID`.
  - Skipped when `InCombatLockdown()`.
  - Returns `remaining=nil` when the expiration is secret.
- `TB.CampRows(buffs, auraState:{[spellID]=state}, skill) -> rows`
- Refresh on `UNIT_AURA` for the player only (debounced).

**Fallback.** The Open Risk applies if the probe shows Rack/Hut are not player auras. In that case this phase switches to `GetSubZoneText` or skill-only rows. The decision is noted in `probe-results.md`, with no design rerun unless both fail.

**Verify.** Tests cover `CampRows`: active with time, active-secret, inactive-eligible, below-unlock. In game, standing at a Rack shows a countdown, and nothing errors in combat.

---

## Phase 5: Water-walk button
**Delivers.** The Water section shows a secure button for the first water-walk item in the bags. It is visible only when that item is present, no water-walk aura is active, and the player is out of combat. Clicking the button uses the item.

**Files.** `Data.lua`, `Logic.lua`, `Core.lua`, `Panel.lua`, `tests/run.lua`

**Key changes.**
- `TB.DATA.waterWalk = { items={itemID,...}, auras={spellID,...} }`
- `TB.WaterWalkPick(items, counts, auraActive:bool) -> itemID|nil`
- A `SecureActionButtonTemplate` button `TBWaterButton` with `type=item` and `item=item:<id>`.
  - Attributes and show/hide happen only out of combat.
  - `PLAYER_REGEN_ENABLED` triggers `TB.Refresh`.
  - `PLAYER_REGEN_DISABLED` leaves the button as is.

**Verify.** Tests cover `WaterWalkPick`: none, first present, aura active. In game, the click drinks the Draught, the button hides while the buff is up, and entering combat causes no taint error.

---

## Phase 6: Release
**Delivers.**
- Version `1.0.0` in the TOC and CHANGELOG.
- A README with all four sections plus a slash command list.
- Root `README.md` lists the three addons (optional one-liner).
- The CI release is published.

**Verify.**
- CI is green.
- The `tb-v1.0.0` release has a zip that contains no `tests/` folder.
- The zip installs into `_classic_beta_\Interface\AddOns` and loads cleanly.

## Testing Checkpoints
| After | True |
|---|---|
| 1 | `tests/run.lua` passes. The panel shows Fishing skill. The probe file is recorded, and every Data ID to come has a probe line. CI zip is built. |
| 2 | Quest fish counts are live, including the bank. |
| 2b | Where-to-fish rows track skill (with modifiers) and current zone. |
| 3 | Catches persist, with zones logged, per character and are grouped by tier. The `IsFishingLoot` vs channel path is chosen by the probe. |
| 3b | Cast bar counts down; a no-loot cast ends with a flash and a counter increment; the flash toggles off. |
| 4 | Camp buff rows are correct, or the fallback is documented. No combat errors. |
| 5 | The water-walk button works out of combat and is inert in combat. |
| 6 | `tb-v1.0.0` is released. |

Phases 2 to 5 depend only on Phase 1 and the probe, not on each other, with one exception: 3b needs 3. Any one of them can slip without blocking the rest.
