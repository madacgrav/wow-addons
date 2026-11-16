# Structure Outline

## Approach
First add a bag section to `/wuk probe` so the in-game cause can be confirmed. Then count shards by itemID 6265 through a pure `Logic.lua` classifier that `ScanBags` calls, covered by `tests/run.lua`.

Deploy after each phase: `robocopy "D:\Source\wow-addons\WarlockUtilityKit" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WarlockUtilityKit" /MIR /XD tests /NJH /NJS /NP /NDL` (exit 0-7 = ok), then `/reload` in game.

## Phase 1: Bag probe
`/wuk probe` prints what the client returns for each bag, so we can see whether shards in the soul bag have a nil name, a missing bag, or something else. This changes only diagnostics; counts work as before.

**Files**: `WarlockUtilityKit/Core.lua`
**Key changes**:
- `WUK.Probe()` — modified (`Core.lua:174+`). Appends a "bags" section using the existing local `P`/`S` helpers:
  - per bag `0..NUM_BAG_SLOTS or 4`: `bag <id>: slots=<GetContainerNumSlots> free=<n> family=<bagFamily>` from `C_Container.GetContainerNumFreeSlots`
  - per slot where `itemID == 6265` OR `info.itemName` is nil: `  <bag>/<slot> id=<itemID> name=<itemName|nil> getinfo=<C_Item.GetItemInfo name|nil> stack=<stackCount>`
  - summary line: `NUM_BAG_SLOTS=<v> counts.shard=<WUK.counts.shard>`
- Debug-only use of `C_Container.GetContainerNumFreeSlots`; nothing else calls it.

**Verify**:
- `lua5.1 WarlockUtilityKit/tests/run.lua` passes (unchanged).
- Deploy, `/reload`, then `/wuk probe` with shards in a soul bag. The user pastes the bags section. Check: the soul bag appears as bag 1-4 with family 4, and the shard slots show `id=6265` with name/getinfo values.
- If the soul bag is missing or the shard rows don't show `id=6265`, stop and go back to the design.

---

## Phase 2: Count shards by itemID
`ScanBags` classifies each slot with a pure function that recognizes shards by itemID 6265 and keeps name matching for stones. The shard core, ring alert, and summon "no shard" check all read the corrected count.

**Files**: `WarlockUtilityKit/Logic.lua`, `WarlockUtilityKit/Core.lua`, `WarlockUtilityKit/tests/run.lua`, `WarlockUtilityKit/CHANGELOG.md`
**Key changes**:
- `WUK.SHARD_ID = 6265` — new constant in `Logic.lua`.
- `WUK.ClassifySlot(itemID: number?, name: string?): kind?` — new in `Logic.lua`. Returns `"shard"` when `itemID == WUK.SHARD_ID`, otherwise `WUK.ClassifyItem(name)`.
- `WUK.ScanBags()` — modified (`Core.lua:35`). Calls `WUK.ClassifySlot(info.itemID, info.itemName or (info.itemID and C_Item.GetItemInfo(info.itemID)))`. Guards against a nil `itemID`.
- Probe from Phase 1 switches its slot filter to `ClassifySlot`.
- `tests/run.lua` — new `eq` cases:
  - `ClassifySlot(6265, nil) == "shard"`
  - `ClassifySlot(6265, "Soul Shard") == "shard"`
  - `ClassifySlot(5512, "Minor Healthstone") == "healthstone"`
  - `ClassifySlot(1234, nil) == nil`
  - `ClassifySlot(nil, nil) == nil`
- CHANGELOG entry and version bump (`.toc` `## Version`).

**Verify**:
- `lua5.1 WarlockUtilityKit/tests/run.lua` prints `all tests passed`.
- Deploy, `/reload`. With N shards in the soul bag, the shard core shows N. Cast a shard-producing spell (Drain Soul kill) and a shard-consuming one (summon a demon), and check the count updates each time. A summon queue row shows no "no shard" when N >= 1. `/wuk probe` shows `counts.shard=N`.

## Testing Checkpoints
- **After Phase 1**: tests pass; `/wuk probe` prints a bags section; the in-game output confirms or refutes the nil-name cause. Counts are unchanged.
- **After Phase 2**: tests pass with the new `ClassifySlot` cases; shards in a soul bag are counted correctly in game; stones behave as before.
