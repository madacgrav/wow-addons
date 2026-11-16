# Implementation Plan

## Overview
Replace the hand-copied preferred-pet lists in WarlockUtilityKit with one `WUK.PETS` list in `Logic.lua`, then add Incubus as a choice. Add a pet-out check that accepts the Incubus reporting its family as "incubus" or "succubus", and a `/wuk probe` line that shows the pet's raw family.

## Conventions
- **Test command** (from the repo root `D:\Source\wow-addons`): `lua WarlockUtilityKit/tests/run.lua`. It must print `all tests passed`.
- **Tests** are straight-line `eq(...)` asserts. Insert each new block above the final `print("all tests passed")`, under a `-- Preferred pet` comment.
- **Load order** (`WarlockUtilityKit.toc`): Logic.lua, Core.lua, …, Settings.lua. `WUK.PETS` is defined in Logic.lua, so it already exists when Core and Settings run.
- **Deploy after each phase** (exit codes 0-7 mean success):
  `robocopy "D:\Source\wow-addons\WarlockUtilityKit" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WarlockUtilityKit" /MIR /XD tests /NJH /NJS /NP /NDL`

---

## Phase 1: One shared pet list

### Changes

#### 1. Pet list and membership test
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify. Insert directly above `WUK.CURSES = {` (around line 86):

```lua
-- preferred-pet keys, in dropdown order; each is also a SPELLS key (Core.lua) and the lower-cased UnitCreatureFamily
WUK.PETS = { "imp", "voidwalker", "succubus", "felhunter" }
function WUK.IsPet(key)
  for _, p in ipairs(WUK.PETS) do if p == key then return true end end
  return false
end
```

#### 2. Slash handler and usage text
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify.

Line 233:
```lua
  elseif cmd == "pet" and (arg == "imp" or arg == "voidwalker" or arg == "succubus" or arg == "felhunter") then
```
becomes
```lua
  elseif cmd == "pet" and WUK.IsPet(arg) then
```

Line 247 ends with `... | probe | pet <imp|voidwalker|succubus|felhunter>") end`. It becomes:
```lua
  else WUK.Print("/wuk config | board | lead | dock | spin | collapse | show | hide | lock | reset | probe | pet <" .. table.concat(WUK.PETS, "|") .. ">") end
```

#### 3. Settings dropdown
**File**: `WarlockUtilityKit/Settings.lua`
**Action**: modify.
- Delete line 3: `local PETS = { "imp", "voidwalker", "succubus", "felhunter" }`.
- In the dropdown loop (around line 45), change `for _, pet in ipairs(PETS) do` to `for _, pet in ipairs(WUK.PETS) do`.

#### 4. Tests
**File**: `WarlockUtilityKit/tests/run.lua`
**Action**: modify. Insert above `print("all tests passed")`:

```lua
-- Preferred pet
eq(WUK.IsPet("imp"), true, "imp is a pet")
eq(WUK.IsPet("felhunter"), true, "felhunter is a pet")
eq(WUK.IsPet("felguard"), false, "felguard not offered")
eq(WUK.IsPet(nil), false, "nil not a pet")
eq(WUK.IsPet(""), false, "empty not a pet")
```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`.
- [x] `grep -n '"voidwalker"' WarlockUtilityKit/*.lua` matches only Logic.lua (`WUK.PETS`). The Core.lua SPELLS key is the bare `voidwalker =`, so it doesn't match.
- [x] Deploy with robocopy.

#### Manual (in game, after `/reload`)
- [x] `/wuk pet voidwalker` prints `preferred pet: voidwalker`, and the pet button switches to the Voidwalker icon.
- [x] `/wuk pet bogus` prints the usage text ending `pet <imp|voidwalker|succubus|felhunter>`.
- [x] In `/wuk config`, the Preferred pet dropdown lists Imp, Voidwalker, Succubus and Felhunter, and picking one sticks.

---

## Phase 2: Incubus end to end

### Changes

#### 1. Add Incubus to the list; add the pet-out helper
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify the Phase 1 block:

```lua
WUK.PETS = { "imp", "voidwalker", "succubus", "incubus", "felhunter" }
```

Add below `WUK.IsPet`:
```lua
-- Forever's Incubus may report creature family "Succubus" (same Sayaad pet); accept either for the incubus choice
function WUK.PetIsOut(choice, family)
  return family ~= nil and (family == choice or (choice == "incubus" and family == "succubus"))
end
```

#### 2. Spell entry and probe line
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify.

In `SPELLS` (line 52):
```lua
  succubus = { "Summon Succubus" }, felhunter = { "Summon Felhunter" },
```
becomes
```lua
  succubus = { "Summon Succubus" }, incubus = { "Summon Incubus" }, felhunter = { "Summon Felhunter" },
```

In `WUK.Probe()`, right after the `P("instance", ...)` line (around line 178), add:
```lua
  P("pet family", UnitExists("pet") and S(UnitCreatureFamily("pet")) or "none")
```
(`S` is the probe's local secret-safe formatter defined on line 176.)

#### 3. Pet button out check
**File**: `WarlockUtilityKit/Prep.lua`
**Action**: modify line 35:
```lua
  local out = WUK.PetFamily() == pet
```
becomes
```lua
  local out = WUK.PetIsOut(pet, WUK.PetFamily())
```

#### 4. Tests
**File**: `WarlockUtilityKit/tests/run.lua`
**Action**: modify. Append to the `-- Preferred pet` block:

```lua
eq(WUK.IsPet("incubus"), true, "incubus is a pet")
eq(WUK.PetIsOut("incubus", "incubus"), true, "incubus family")
eq(WUK.PetIsOut("incubus", "succubus"), true, "incubus reported as succubus")
eq(WUK.PetIsOut("imp", "imp"), true, "imp out")
eq(WUK.PetIsOut("imp", nil), false, "no pet")
eq(WUK.PetIsOut("succubus", "incubus"), false, "alias is one-way")
eq(WUK.PetIsOut("felhunter", "imp"), false, "wrong pet")
```

#### 5. Docs and version
**File**: `WarlockUtilityKit/README.md`. **Action**: modify.
- Line 63: `- `/wuk pet imp | voidwalker | succubus | felhunter`` becomes `- `/wuk pet imp | voidwalker | succubus | incubus | felhunter``.
- Line 151: `| `/wuk pet <imp\|voidwalker\|succubus\|felhunter>` | Set the preferred pet |` becomes `| `/wuk pet <imp\|voidwalker\|succubus\|incubus\|felhunter>` | Set the preferred pet |`.

**File**: `WarlockUtilityKit/CHANGELOG.md`. **Action**: modify. Insert above `## [0.3.1] — 2026-10-22`:
```markdown
## [0.3.2] — 2026-11-16

### Added
- **Incubus as a preferred pet.** `/wuk pet incubus` and the Settings dropdown now offer the Incubus. The pet button counts it as out whether the game reports it as an Incubus or a Succubus.
- **Pet family in `/wuk probe`.** The probe prints your current pet's creature family.
```

**File**: `WarlockUtilityKit/WarlockUtilityKit.toc`. **Action**: modify. Change `## Version: 0.3.1` to `## Version: 0.3.2`.

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`.
- [x] `grep -n "incubus" WarlockUtilityKit/Logic.lua WarlockUtilityKit/Core.lua` shows the PETS entry, the PetIsOut alias and the SPELLS entry.
- [x] Deploy with robocopy.

#### Manual (in game, after `/reload`, on a warlock who has learned Summon Incubus)
- [x] The dropdown lists Imp, Voidwalker, Succubus, Incubus and Felhunter.
- [x] `/wuk pet incubus` prints `preferred pet: incubus`. The pet button shows the Incubus icon and glows while no Incubus is out.
- [x] Clicking the pet button summons the Incubus, and the button then greys out and stops glowing.
- [x] `/wuk probe` prints `pet family: <string>`. Record the exact string and report it back (it decides whether the succubus alias is needed).
- [x] `/wuk pet succubus` and `/wuk pet imp` behave as before.
- [x] On a character without Incubus learned, `/wuk pet incubus` makes the button show and summon the Imp.
