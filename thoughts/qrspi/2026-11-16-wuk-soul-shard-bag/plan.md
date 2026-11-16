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

## Phase 2: Count shards by itemID

### Changes

#### 1. Pure classifier
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify. Add after `WUK.ClassifyItem`:

```lua
WUK.SHARD_ID = 6265

-- shards by itemID (name can be nil when uncached / field absent on this client); stones by name
function WUK.ClassifySlot(itemID, name)
  if itemID == WUK.SHARD_ID then return "shard" end
  return WUK.ClassifyItem(name)
end
```

#### 2. ScanBags uses ClassifySlot
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify line 35 in `WUK.ScanBags`.

Before:
```lua
      local kind = info and WUK.ClassifyItem(info.itemName or C_Item.GetItemInfo(info.itemID))
```
After:
```lua
      local kind = info and WUK.ClassifySlot(info.itemID, info.itemName or (info.itemID and C_Item.GetItemInfo(info.itemID)))
```

#### 3. Probe filter uses ClassifySlot
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify the Phase 1 probe condition.

Before:
```lua
      if info and (info.itemID == 6265 or info.itemName == nil) then
```
After:
```lua
      if info and (WUK.ClassifySlot(info.itemID, info.itemName) or info.itemName == nil) then
```

#### 4. Tests
**File**: `WarlockUtilityKit/tests/run.lua`
**Action**: modify. Add after the `ClassifyItem(nil)` case (line 16):

```lua
eq(WUK.ClassifySlot(6265, nil), "shard", "shard by id, nil name")
eq(WUK.ClassifySlot(6265, "Soul Shard"), "shard", "shard by id")
eq(WUK.ClassifySlot(5512, "Minor Healthstone"), "healthstone", "stone by name")
eq(WUK.ClassifySlot(1234, nil), nil, "unknown id nil name")
eq(WUK.ClassifySlot(nil, nil), nil, "nil slot")
```

#### 5. Version + changelog
**File**: `WarlockUtilityKit/WarlockUtilityKit.toc`. **Action**: `## Version: 0.3.1` -> `## Version: 0.3.2`.

**File**: `WarlockUtilityKit/CHANGELOG.md`. **Action**: insert above `## [0.3.1]`:

```markdown
## [0.3.2] — 2026-11-16

### Fixed
- **Soul shard bag count.** Shards are counted by item ID, so shards in a soul bag (Soul Pouch, Felcloth Bag, etc.) show on the shard core and summon checks even when the client has not returned the item name.

### Added
- **`/wuk probe` bags section.** Prints each bag's slots, free slots and bag family, plus shard slots with item ID and name, for debugging.
```

### Verification
#### Automated
- [ ] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed` (includes 5 new ClassifySlot cases)
- [ ] `grep -n "ClassifySlot" WarlockUtilityKit/Core.lua` shows 2 hits (ScanBags and Probe)
- [ ] Deploy with robocopy (exit code 0-7)

#### Manual
- [ ] In game: `/reload` with N shards in the soul bag; the shard core shows N
- [ ] Gain a shard (Drain Soul kill): the count goes up by 1. Summon a demon: the count goes down by 1
- [ ] A summon queue row shows no red "no shard" when N >= 1
- [ ] `/wuk probe` shows `counts.shard: N`
- [ ] Healthstone/soulstone counts are unchanged from before
