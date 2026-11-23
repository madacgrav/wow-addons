# Implementation Plan

## Overview
WarlockCombatKit rotation bar buttons show in full colour by default and grey (desaturate + 0.6 alpha) only while their spell is on its own cooldown; the global cooldown alone never greys a button. The suggested spell is marked by the existing purple pulse alone. A greyed button returns to colour when its cooldown ends. Unknown (secret) or erroring reads show in colour.

Commands:
- Tests: `lua WarlockCombatKit/tests/run.lua` (CI uses `lua5.1`, `.github/workflows/package-wck.yml:21`).
- Lint: `bash /d/Source/wowskill/skills/wow-forever-addon/scripts/lint.sh WarlockCombatKit`.

TOC load order is `Data, Logic, Core, Actions, Panel, Rotation, Settings`. Refreshers registered at `Core.lua` file scope therefore run before the `Rotation.lua` highlight refresher.

## Phase 1: Grey only on cooldown, glow marks the suggestion

### Changes

#### 1. Pure cooldown logic + new ButtonLook
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify. Replace `WCK.ButtonLook` at `Logic.lua:174-179` and add `CooldownState` above it.

```lua
-- cd = non-secret fields of C_Spell.GetSpellCooldown (secret ones already nil'd); onCD true only for a real
-- cooldown (GCD alone does not count), nil when unknown; endsAt = startTime + duration when both are known
function WCK.CooldownState(cd)
  if type(cd) ~= "table" or cd.isActive == nil then return nil end
  if not cd.isActive or cd.isOnGCD == true then return false end
  local s, d = cd.startTime, cd.duration
  return true, (type(s) == "number" and type(d) == "number") and s + d or nil
end

-- bar button look: dim = spell on its own cooldown; fel = a proc on this spell is up -- visual only, it stays clickable
function WCK.ButtonLook(spell, onCD, procs, procList)
  local fel = false
  for _, p in ipairs(procList) do if p.spell == spell and procs[p.key] then fel = true end end
  return { dim = onCD == true, fel = fel }
end
```

#### 2. Cooldown map refresher
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify. Add the following directly after the `WCK.next` refresher at `Core.lua:202-205`, before `WCK.On("SPELL_UPDATE_COOLDOWN", ...)`.

```lua
-- bar cooldowns: every bar spell (rules + known tail), not just rule spells; secret fields read as unknown
local function Clean(v) if WCK.Secret(v) then return nil end return v end
function WCK.BuildCooldowns(spells)
  local onCD, earliest = {}, nil
  for _, name in ipairs(spells) do
    local ok, cd = pcall(C_Spell.GetSpellCooldown, name)
    if ok and type(cd) == "table" then
      local on, ends = WCK.CooldownState({ isActive = Clean(cd.isActive), isOnGCD = Clean(cd.isOnGCD),
        startTime = Clean(cd.startTime), duration = Clean(cd.duration) })
      if on then
        onCD[name] = true
        if ends and (not earliest or ends < earliest) then earliest = ends end
      end
    end
  end
  return onCD, earliest
end
WCK.onCD, WCK.cdEnd = {}, nil
table.insert(WCK.refreshers, function() -- after WCK.next, before Rotation.lua's highlight refresher
  local spells = {}
  for _, e in ipairs(WCK.BarSpells(WCK.char.rules, WCK.DATA.tail, WCK.spellSet, WCK.DATA.core)) do spells[#spells + 1] = e.spell end
  WCK.onCD, WCK.cdEnd = WCK.BuildCooldowns(spells)
end)
```

Two checks while making this change:
- `pcall` on a secret-table index. Indexing `cd.isActive` on a returned table is fine. Only comparing or using a secret value errors, and `Clean` drops those first. If lint flags a missing std global, compare with the existing use at `Core.lua:184-186`.
- `CooldownState` returns two values. Only use them through the `local on, ends = ...` assignment shown above.

#### 3. Rotation highlight uses the map
**File**: `WarlockCombatKit/Rotation.lua`
**Action**: modify line 84 only. Lines 85-87 stay unchanged.

```lua
    local look = b.spell and WCK.ButtonLook(b.spell, WCK.onCD[b.spell], WCK.procs, WCK.DATA.procs) or { dim = false, fel = false }
```

Also update the line-79 comment to: `-- highlights: every refresh, in combat too (textures only); grey = on cooldown, pulse = suggested`.

#### 4. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: replace lines 108-114 (the `-- GH-28 Phase 3` block) with the following:

```lua
-- bar look: grey = own cooldown only; suggestion is the glow (Rotation.lua), not colour
local pl = { { key = "nightfall", spell = "Shadow Bolt" } }
local lk = WCK.ButtonLook("Corruption", nil, {}, pl); eq(lk.dim, false, "unknown cd in colour"); eq(lk.fel, false, "no proc")
eq(WCK.ButtonLook("Fear", false, {}, pl).dim, false, "ready in colour")
eq(WCK.ButtonLook("Fear", true, {}, pl).dim, true, "on cooldown grey")
lk = WCK.ButtonLook("Shadow Bolt", false, { nightfall = true }, pl); eq(lk.fel, true, "nightfall glows bolt"); eq(lk.dim, false, "proc in colour")
eq(WCK.ButtonLook("Fear", false, { nightfall = true }, pl).fel, false, "nightfall not on fear")

-- cooldown state
eq(WCK.CooldownState(nil), nil, "no table unknown")
eq(WCK.CooldownState({}), nil, "secret isActive unknown")
eq(WCK.CooldownState({ isActive = false }), false, "idle ready")
eq(WCK.CooldownState({ isActive = true, isOnGCD = true, startTime = 1, duration = 1.5 }), false, "gcd only ready")
local on, ends = WCK.CooldownState({ isActive = true, isOnGCD = false, startTime = 100, duration = 30 })
eq(on, true, "real cd"); eq(ends, 130, "ends at start+duration")
on, ends = WCK.CooldownState({ isActive = true, isOnGCD = false })
eq(on, true, "real cd, secret timing"); eq(ends, nil, "no end when timing secret")
on = WCK.CooldownState({ isActive = true }); eq(on, true, "isOnGCD missing = real cd")
```

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] Lint is clean for WarlockCombatKit (no new warnings; same 12 pre-existing as main)
- [x] `grep -n "WCK.next" WarlockCombatKit/Logic.lua` returns no hits in `ButtonLook`

#### Manual (deploy with robocopy to `_forever_\Interface\AddOns\WarlockCombatKit`, then `/reload`)
- [x] No Lua errors (BugSack)
- [x] All bar buttons show in full colour out of combat
- [x] The suggested spell's button pulses purple, and the other buttons stay in colour
- [x] Cast Fear, Death Coil or Howl of Terror: that button greys
- [x] Spam Shadow Bolt: it never greys from the global cooldown

---

## Phase 2: Back to colour when the cooldown ends

### Changes

#### 1. One-shot timer at the earliest cooldown end
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify the refresher added in Phase 1.

```lua
local scheduledEnd -- end time of the one pending expiry timer
table.insert(WCK.refreshers, function() -- after WCK.next, before Rotation.lua's highlight refresher
  local spells = {}
  for _, e in ipairs(WCK.BarSpells(WCK.char.rules, WCK.DATA.tail, WCK.spellSet, WCK.DATA.core)) do spells[#spells + 1] = e.spell end
  WCK.onCD, WCK.cdEnd = WCK.BuildCooldowns(spells)
  -- SPELL_UPDATE_COOLDOWN on expiry is unverified on Forever: redraw once at the earliest readable end
  local now, e = GetTime(), WCK.cdEnd
  if e and e > now and (not scheduledEnd or e < scheduledEnd) then
    scheduledEnd = e
    C_Timer.After(e - now + 0.05, function() scheduledEnd = nil; WCK.Refresh() end)
  end
end)
```

How the timer behaves:
- `e > now` stops a 0-delay loop when the client still reports a cooldown as active after its end time.
- A later timer that is already pending is kept. When it fires, it clears `scheduledEnd` and redraws, and that redraw re-arms the timer for the next end.
- Extra `WCK.Refresh` calls are debounced (`Core.lua:35-42`).

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] Lint is clean for WarlockCombatKit (no new warnings)

#### Manual
- [x] Out of combat, with no target, cast Death Coil or Howl of Terror and don't touch anything: the button greys, then returns to colour within about 0.2 s of the cooldown ending
- [x] Stand idle afterwards: `/etrace` shows no repeating activity from WCK

---

## Phase 3: Docs and release bump

### Changes

#### 1. README
**File**: `WarlockCombatKit/README.md`
**Action**: modify line 75.

```markdown
- Buttons stay in colour. A button greys out only while its spell is on cooldown (the global cooldown does not count) and comes back when it is ready. The suggested spell (first passing rule) pulses purple. Grey buttons still cast when clicked.
```

#### 2. CHANGELOG
**File**: `WarlockCombatKit/CHANGELOG.md`
**Action**: insert this above `## [0.2.0]` (line 5):

```markdown
## [0.2.1] — 2026-11-23

### Changed
- Rotation buttons stay in colour and grey out only while their spell is on cooldown (not the global cooldown), then return to colour when it is ready. The suggested spell is shown by its purple pulse alone. Shadow Bolt, Fear and Banish are included.

```

#### 3. TOC
**File**: `WarlockCombatKit/WarlockCombatKit.toc`
**Action**: line 4 becomes `## Version: 0.2.1`.

#### 4. Docs site
`docs/index.html:91` lists WCK by `dir`/`prefix` only, so no edit is needed. Confirm that nothing else hard-codes `0.2.0`: `grep -rn "0\.2\.0" docs WarlockCombatKit README.md`.

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] `grep -n "Version" WarlockCombatKit/WarlockCombatKit.toc` shows `0.2.1`
- [x] `grep -n "0.2.1" WarlockCombatKit/CHANGELOG.md` returns the new heading

#### Manual
- [x] Deploy with robocopy to `_forever_\Interface\AddOns\WarlockCombatKit`
- [ ] Final in-game pass: re-run the Phase 1 and Phase 2 manual checks in combat on a mob pack
