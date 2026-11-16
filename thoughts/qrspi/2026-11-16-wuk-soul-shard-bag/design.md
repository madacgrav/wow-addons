# Design Discussion

## Current State
- `WUK.ScanBags` (`WarlockUtilityKit/Core.lua:30-44`) loops bags `0..NUM_BAG_SLOTS or 4` and classifies each slot by **name**: `info.itemName or C_Item.GetItemInfo(info.itemID)` (35) fed to `WUK.ClassifyItem` (`Logic.lua:9-14`).
- If the name is nil (field absent on this client, or item not cached), `ClassifyItem` returns nil (`Logic.lua:10`) and the slot is silently dropped. No retry; only `BAG_UPDATE_DELAYED` and unrelated events trigger a rescan (`Core.lua:155-159`).
- Reported symptom (user): with shards in a soul bag, the shard core shows **0 / too few**.
- Readers of `counts.shard`: shard core count/desaturate (`UI.lua:154-165`), ring alert (`UI.lua:46`), summon "no shard" check (`Summon.lua:16`, `Logic.lua:74`). Fixing the count fixes all of them.
- Existing debug tool: `/wuk probe` -> `WUK.Probe` (`Core.lua:174+`, slash at `Core.lua:239`) with local `P`/`S` print helpers. No bag section.
- Tests load only `Logic.lua` with no WoW stubs (`tests/run.lua:1-3`); `ScanBags` untested.
- Root cause not confirmed in-game. Leading hypothesis: name lookup returns nil for shards in the soul bag (wiki says `ContainerItemInfo.itemName` is a 10.1.5 Mainline field whose Classic presence is unverified). Bag range already covers equipped soul bags (bags 1-4).

## Desired End State
- Shards are counted by **itemID 6265** regardless of item name/cache state, in any of bags 0-4 including soul bags.
- `/wuk probe` prints a bag section so the user can confirm in-game what the client returns per bag/slot.
- Per-slot classification is a pure function in `Logic.lua`, covered by `tests/run.lua`.

Verify:
1. `lua5.1 WarlockUtilityKit/tests/run.lua` prints `all tests passed`, including new cases (id 6265 with nil name -> shard; stone names unchanged; unknown id + nil name -> nil).
2. In-game on Forever with N shards in a soul bag: shard core shows N; creating/consuming a shard updates it; summon row has no "no shard" when N >= 1.
3. `/wuk probe` lists each bag id, slot count, bag family, and shard slots with itemID/itemName.

## Patterns to Follow
- **Pure logic in `Logic.lua`, WoW calls in `Core.lua`** — `ClassifyItem` (`Logic.lua:9-14`), `StoneMacro` (`Logic.lua:26-36`) are pure and tested; `ScanBags` keeps the API calls.
- **Classify by itemID** — `ProfessionPlanner/Core.lua:91-99` tallies by `info.itemID`; `TackleBox/Actions.lua:79-91` avoids cache via `GetItemInfoInstant`. ItemID is always in `ContainerItemInfo`.
- **Probe output** — extend `WUK.Probe` (`Core.lua:174-176`) using its `P`/`S` helpers; mirror TackleBox's bag probe loop (`TackleBox/Core.lua:207-215`).
- **Test style** — `eq(got, want, label)` in `tests/run.lua:5-7`, existing ClassifyItem cases at `tests/run.lua:10-16`.
- **ponytail: comments** for known ceilings (`Logic.lua:3`).

Do NOT follow:
- Name-only identification for shards (`Core.lua:35`) — depends on a field/cache that may be nil.
- Unguarded `C_Item.GetItemInfo(info.itemID)` when `itemID` is nil (`Core.lua:35`).

## Design Decisions
1. **Shard identification**: match `itemID == 6265` first; fall back to name match for everything else — itemID is always present and needs no cache; shard has a single item ID. Stones keep name matching (many ranked IDs, out of scope).
2. **Pure classifier**: add `WUK.ClassifySlot(itemID, name)` (or extend `ClassifyItem` with an id arg) in `Logic.lua`; `ScanBags` calls it — keeps the testable surface pure, no API stubs.
3. **Diagnostics**: add a bags section to existing `/wuk probe` rather than a new `/wuk bags` command — reuses `WUK.Probe` and its helpers, no new slash branch. Prints per bag: id, `GetContainerNumSlots`, `GetContainerNumFreeSlots` bagFamily; per shard-or-unclassified slot: itemID, itemName (or "nil"), stackCount.
4. **Bag range unchanged**: keep `0..NUM_BAG_SLOTS or 4` — soul bags equip in 1-4; probe will reveal if Forever differs.
5. **Tests**: new `eq` cases for the classifier in `tests/run.lua`; no `C_Container` stubs.

## What We're NOT Doing
- No itemID tables for Healthstone/Soulstone/Spellstone/Firestone ranks.
- No `GET_ITEM_INFO_RECEIVED` / `ITEM_DATA_LOAD_RESULT` retry wiring.
- No localization of name matching.
- No bank, keyring, or reagent-bag scanning.
- No UI changes to the shard core or summon rows.
- No changes to WarlockCombatKit, TackleBox, ProfessionPlanner.

## Open Risks
- Root cause may not be the name lookup (e.g. soul bag not returned in bags 1-4, or `BAG_UPDATE_DELAYED` not firing for soul-bag changes). Probe output will show this; if so, return to design.
- If stones in a soul bag (not allowed in Classic) or stones generally also miss due to nil names, they stay broken — out of scope; probe will expose it.
- Soul Shard ID 6265 assumed identical on Forever (already used in tests, `tests/run.lua:53`).
- `GetContainerNumFreeSlots` second return may differ on this client; probe prints raw value.
