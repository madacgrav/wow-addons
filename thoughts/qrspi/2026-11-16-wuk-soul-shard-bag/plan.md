# Implementation Plan

## Overview
Count Soul Shards by item ID 6265, so shards in a soul bag are counted even when the item name comes back nil. Add a bags section to `/wuk probe` so the cause can be confirmed in game. Stones keep name matching.

Test command (local): `lua WarlockUtilityKit/tests/run.lua` (CI uses `lua5.1`, same file).
Deploy after each phase:
`robocopy "D:\Source\wow-addons\WarlockUtilityKit" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WarlockUtilityKit" /MIR /XD tests /NJH /NJS /NP /NDL` (exit codes 0-7 mean success). The user then runs `/reload`.

## Phase 1: Bag probe

### Changes

#### 1. Bags section in `WUK.Probe`
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify. Insert the block inside `WUK.Probe()` after the cooldown-viewer `for _, f in ipairs({ "EssentialCooldownViewer", ... })` loop and **before** `if not UnitExists("target") then return P("target", "none") end`. The target section returns early, so the bags block must come first.

```lua
  -- bags: what the client returns per bag/slot (soul shard bag debugging)
  P("NUM_BAG_SLOTS", NUM_BAG_SLOTS)
  for bag = 0, NUM_BAG_SLOTS or 4 do
    local free, family = C_Container.GetContainerNumFreeSlots(bag)
    P("bag " .. bag, "slots=" .. tostring(C_Container.GetContainerNumSlots(bag)) .. " free=" .. tostring(free) .. " family=" .. tostring(family))
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.itemID == 6265 or info.itemName == nil) then
        P("  " .. bag .. "/" .. slot, "id=" .. tostring(info.itemID) .. " name=" .. tostring(info.itemName)
          .. " getinfo=" .. tostring(info.itemID and C_Item.GetItemInfo(info.itemID)) .. " stack=" .. tostring(info.stackCount))
      end
    end
  end
  P("counts.shard", WUK.counts.shard)
```

Notes:
- `tostring(info.itemID and C_Item.GetItemInfo(...))` prints the first return (the name) or `nil`.
- Phase 1 changes no counting code.

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [x] Deploy with robocopy (exit code 0-7)

#### Manual
- [ ] In game: `/reload`, put shards in an equipped soul bag, run `/wuk probe`, and paste the `NUM_BAG_SLOTS` / `bag N` / `counts.shard` lines
- [ ] Check that the soul bag shows as bag 1-4 with `family=4` and that the shard rows show `id=6265`. Note the `name=` and `getinfo=` values (nil confirms the cause)
- [ ] If the soul bag is missing from bags 0-4, or the shard rows aren't `id=6265`: stop and return to design

---

## Phase 2: Scan the extra bag slot (revised)

Revised after the Phase 1 probe (2026-11-16): the soul bag is container 5 (`Enum.BagIndex.ReagentBag = 5`, `NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5`, `family=4`), and shard names come back fine (`5/1: id=6265 name=Soul Shard`). `ScanBags` stops at `NUM_BAG_SLOTS = 4`. The item-ID classifier is dropped.

### Changes

#### 1. ScanBags range
**File**: `WarlockUtilityKit/Core.lua` line 32. **Action**: modify.

Before: `for bag = 0, NUM_BAG_SLOTS or 4 do`
After: `for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do -- 5 = extra slot (soul bag on Forever)`

#### 2. Version + changelog
**File**: `WarlockUtilityKit/WarlockUtilityKit.toc`. `## Version: 0.3.1` -> `## Version: 0.3.2`.
**File**: `WarlockUtilityKit/CHANGELOG.md`. Insert a 0.3.2 entry above `## [0.3.1]`: Fixed: shards in a soul bag in the extra (fifth) bag slot are counted. Added: `/wuk probe` bags section.

The `/wuk probe` bags section (-3..12) stays as is.

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [x] Deploy with robocopy (exit code 0-7)

#### Manual
- [x] In game: `/reload` with N shards in the soul bag; the shard core shows N
- [ ] Gain a shard: count +1. Summon a demon: count -1
- [ ] A summon queue row shows no red "no shard" when N >= 1
- [ ] `/wuk probe` shows `counts.shard: N`, matching `GetItemCount(6265)`
