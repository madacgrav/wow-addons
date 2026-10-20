# Implementation Plan

## Overview
Replace the `WUKStrip` bar with a ring layout: the shard button is a larger 44px "core" at the center, with six 36px buttons orbiting it (healthstone, soulstone, spellstone, firestone, armor, pet). The dynamic layer has four parts: an alert pulse, a ready shine, a slow spin, and collapse-to-core with bloom on hover. Combat freezes the ring fully open. Secure-button geometry never changes in combat.

## Conventions (apply to every phase)
- Tests: `lua WarlockUtilityKit/tests/run.lua`. It must print `all tests passed`. CI runs Lua 5.1, so use no 5.2+ features.
- Deploy after the tests pass and the phase is committed. Robocopy exit codes 0-7 mean success:
  `robocopy "D:\Source\wow-addons\WarlockUtilityKit" "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\WarlockUtilityKit" /MIR /XD tests /NJH /NJS /NP /NDL`
- Make one commit per phase, then ask the user to `/reload` and run the manual checks.
- Rules for secure buttons (stones, armor, pet):
  - `SetPoint`, `ClearAllPoints`, `EnableMouse` and `SetAttribute` only when `not InCombatLockdown()`.
  - `SetAlpha` on them is also kept out of combat.
  - Textures and their animations are allowed any time.
- Shared constants live at the top of `UI.lua`:
  ```lua
  local R, CORE, BTN, LABELS = 58, 44, 36, 30   -- ring radius, core size, orbit size, label band height
  local ORBIT = { "healthstone", "soulstone", "spellstone", "firestone", "armor", "pet" } -- clockwise from 12
  ```

---

## Phase 1: Static ring layout

### Changes

#### 1. Ring math
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify (append)
```lua
-- slot i of n on a circle, clockwise from 12 o'clock, rotated by offsetDeg; returns CENTER offsets
function WUK.RingPoint(i, n, radius, offsetDeg)
  local a = math.rad(offsetDeg + (i - 1) * 360 / n)
  return radius * math.sin(a), radius * math.cos(a)
end
```

#### 2. Tests
**File**: `WarlockUtilityKit/tests/run.lua`
**Action**: modify. Insert before `print("all tests passed")`.
```lua
-- Ring layout
local function near(got, want, label)
  if math.abs(got - want) > 1e-9 then error(label .. ": expected " .. want .. ", got " .. got, 2) end
end
local x, y = WUK.RingPoint(1, 6, 58, 0); near(x, 0, "ring top x"); near(y, 58, "ring top y")
x, y = WUK.RingPoint(4, 6, 58, 0); near(x, 0, "ring bottom x"); near(y, -58, "ring bottom y")
x = WUK.RingPoint(2, 6, 58, 0); assert(x > 0, "ring goes clockwise")
x, y = WUK.RingPoint(1, 6, 58, 90); near(x, 58, "offset rotates x"); near(y, 0, "offset rotates y")
x, y = WUK.RingPoint(3, 6, 0, 45); near(x, 0, "collapsed x"); near(y, 0, "collapsed y")
```

#### 3. Ring container and layout
**File**: `WarlockUtilityKit/UI.lua`
**Action**: modify
- Add the constants block from Conventions after `KINDS`.
- In the init, change these:
  - Replace the comment and `SetSize` at lines 32-33:
    ```lua
    -- ring of 6 orbit buttons around the shard core; soulstone + assignment lines underneath
    local SIZE = 2 * (R + BTN / 2) + 8
    f:SetSize(SIZE, SIZE + LABELS)
    f.angle, f.radius, f.targetRadius = 0, R, R
    ```
  - In the stone loop, replace `b:SetSize(36, 36); b:SetPoint(...)`. The shard core sits above the orbit, so collapsed buttons hide under it:
    ```lua
    local size = kind == "shard" and CORE or BTN
    b:SetSize(size, size)
    b:SetFrameLevel(f:GetFrameLevel() + (kind == "shard" and 3 or 1))
    ```
  - Center the labels:
    `f.stone:SetPoint("BOTTOM", 0, 20)` and `f.assign:SetPoint("BOTTOM", 0, 6)`.
- Add a layout function above the init:
  ```lua
  -- places core + orbit from strip.radius/angle; out of combat only (secure buttons)
  function WUK.LayoutRing()
    local s = WUK.strip
    if InCombatLockdown() then return end
    local cy = LABELS / 2
    s.icons.shard:ClearAllPoints(); s.icons.shard:SetPoint("CENTER", s, "CENTER", 0, cy)
    for i, kind in ipairs(ORBIT) do
      local b, x, y = s.icons[kind], WUK.RingPoint(i, #ORBIT, s.radius, s.angle)
      b:ClearAllPoints(); b:SetPoint("CENTER", s, "CENTER", x, y + cy)
    end
  end
  ```
- Add `WUK.LayoutRing()` as the last line of the existing refresher (after the stone loop). The first refresh runs after every init (`Core.lua:148-149`), so the armor and pet buttons exist by then. `PLAYER_REGEN_ENABLED -> Refresh` re-applies the layout after combat.

#### 4. Prep buttons join the ring
**File**: `WarlockUtilityKit/Prep.lua`
**Action**: modify
- Line 6: `armorBtn:SetSize(36, 36); armorBtn:SetPoint("TOPLEFT", 4, -4)` becomes `armorBtn:SetSize(36, 36); WUK.strip.icons.armor = armorBtn`.
- Line 23: same change for the pet: `petBtn:SetSize(36, 36); WUK.strip.icons.pet = petBtn`.

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [x] `grep -n "TOPLEFT" WarlockUtilityKit/Prep.lua WarlockUtilityKit/UI.lua` returns no button anchors

#### Manual (after deploy + `/reload`)
- [x] The ring shows: shard at the center, larger; healthstone at the top, then clockwise soulstone, spellstone, firestone, armor and pet
- [x] Every button casts or uses its item. Counts and desaturation still work
- [x] The soulstone timer and assignment lines are centered under the ring
- [x] Shift-drag moves the frame and the position persists after `/reload`
- [x] `/wuk dock` puts the cooldown viewers under the frame. `/wuk hide` and `/wuk show` work
- [x] No Lua errors

---

## Phase 2: Alert pulse (+ AnimationGroup probe)

### Changes

#### 1. Glow helpers
**File**: `WarlockUtilityKit/UI.lua`
**Action**: modify (add above the init)
```lua
-- pulsing purple border on a button; textures only, so safe in combat
function WUK.AddGlow(b)
  local g = b:CreateTexture(nil, "OVERLAY")
  g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); g:SetBlendMode("ADD")
  g:SetVertexColor(0.7, 0.3, 1); g:SetPoint("CENTER"); g:SetSize(b:GetWidth() * 1.8, b:GetHeight() * 1.8); g:Hide()
  local ag = g:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.15); a:SetToAlpha(1); a:SetDuration(0.6)
  b.glow, b.pulse = g, ag
end

function WUK.SetAlert(b, on)
  on = on and true or false
  if b.alerting == on then return end
  b.alerting = on
  if on then b.glow:Show(); b.pulse:Play() else b.pulse:Stop(); b.glow:Hide() end
end
```
- Stone init loop: call `WUK.AddGlow(b)` after `SetSize`. The core gets one as well, for Phase 5.
- Stone refresher, after `SetDesaturated`:
  ```lua
  WUK.SetAlert(b, (kind == "healthstone" or kind == "soulstone") and c[kind] == 0 and WUK.known[kind] ~= nil)
  ```

#### 2. Prep alerts
**File**: `WarlockUtilityKit/Prep.lua`
**Action**: modify
- Armor init: add `WUK.AddGlow(armorBtn)` after `SetSize`. Pet init: add `WUK.AddGlow(petBtn)`. `UI.lua` loads first, so `WUK.AddGlow` already exists.
- Armor refresher: compute the buff once and reuse it:
  ```lua
  local up = spell ~= nil and WUK.ReadPlayerBuffs()[spell] == true
  armorBtn.icon:SetDesaturated(up)
  WUK.SetAlert(armorBtn, spell ~= nil and not up)
  ```
- Pet refresher:
  ```lua
  local out = WUK.PetFamily() == pet
  petBtn.icon:SetDesaturated(not out)
  WUK.SetAlert(petBtn, spell ~= nil and not out)
  ```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual
- [x] **Probe:** a button pulses at all. If you get `CreateAnimationGroup`/`SetFromAlpha` errors, STOP and report back. This is the design's top risk
- [x] Cancel the armor buff: the armor button pulses. Recast it: the pulse stops
- [x] Dismiss the pet: the pet button pulses. Summon the chosen pet: it stops
- [x] With 0 healthstones and Create Healthstone known: the healthstone button pulses
- [x] Pulses keep running in combat, with no Lua errors or "action blocked" messages

---

## Phase 3: Ready shine

### Changes

#### 1. Shine animation
**File**: `WarlockUtilityKit/UI.lua`
**Action**: modify
- Stone init loop, after the icon is created:
  ```lua
  local sh = b.icon:CreateAnimationGroup()
  local up = sh:CreateAnimation("Scale"); up:SetScale(1.3, 1.3); up:SetDuration(0.15); up:SetOrder(1)
  local down = sh:CreateAnimation("Scale"); down:SetScale(1 / 1.3, 1 / 1.3); down:SetDuration(0.2); down:SetOrder(2)
  b.shine = sh
  ```
- Stone refresher, after `b.count:SetText(...)`. `lastCount` is nil on the first refresh, so login causes no shine:
  ```lua
  if b.lastCount == 0 and c[kind] > 0 then b.shine:Play() end
  b.lastCount = c[kind]
  ```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual
- [ ] Starting from 0 healthstones, cast Create Healthstone: the button pops once
- [ ] `/reload` with stones in your bags: no shine
- [ ] A soul shard count going from 1 to 2: no shine

---

## Phase 4: Spin + combat freeze

### Changes

#### 1. Animator and freeze
**File**: `WarlockUtilityKit/UI.lua`
**Action**: modify (add after `WUK.LayoutRing`)
```lua
local SPIN, BLOOM = 6, 0.2 -- deg/sec (one turn per minute), seconds for a full bloom/collapse
local function Step(s, elapsed)
  if InCombatLockdown() then s:SetScript("OnUpdate", nil); return end
  local moving = WUK.db.spin
  if moving then s.angle = (s.angle + SPIN * elapsed) % 360 end
  if s.radius ~= s.targetRadius then
    local d = R / BLOOM * elapsed
    s.radius = s.radius < s.targetRadius and math.min(s.targetRadius, s.radius + d) or math.max(s.targetRadius, s.radius - d)
    moving = true
  end
  WUK.LayoutRing()
  if not moving then s:SetScript("OnUpdate", nil) end
end

-- (re)start the ring animator; it removes itself when idle
function WUK.Animate()
  if not InCombatLockdown() then WUK.strip:SetScript("OnUpdate", Step) end
end

-- PLAYER_REGEN_DISABLED fires before lockdown: last chance to move secure buttons
function WUK.CombatFreeze()
  local s = WUK.strip
  s:SetScript("OnUpdate", nil)
  s.radius, s.targetRadius = R, R
  WUK.LayoutRing()
end
```
- Init: add `WUK.On("PLAYER_REGEN_DISABLED", WUK.CombatFreeze)` at the end.
- Refresher: replace the trailing `WUK.LayoutRing()` with `WUK.LayoutRing(); WUK.Animate()`.

#### 2. Setting + slash
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify
- `DEFAULTS` (line 19): add `spin = true`.
- Slash handler: add before the final `else`:
  ```lua
  elseif cmd == "spin" then
    if InCombatLockdown() then return WUK.Print("not in combat") end
    WUK.db.spin = not WUK.db.spin; WUK.Print("ring spin " .. (WUK.db.spin and "on" or "off")); WUK.Refresh()
  ```
- Usage line: add `spin |` after `dock |`.

#### 3. Settings checkbox
**File**: `WarlockUtilityKit/Settings.lua`
**Action**: modify
- Add to `checks` after the dock checkbox:
  ```lua
  Check(win, "Spin ring", -120, function() return WUK.db.spin end,
    function(on) if on ~= WUK.db.spin then Run("spin") end end),
  ```
- Move these down by 28: the pet `label` from y -132 to -160, and `dd` from -150 to -178.
- Change `win:SetSize(320, 258)` to `win:SetSize(320, 286)`.

### Verification
#### Automated
- [ ] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual
- [ ] The ring rotates about one full turn per minute, smoothly
- [ ] Shift-drag while it spins works, and the position persists
- [ ] Attack a mob: the spin stops at once, every button works in combat, no "action blocked" or taint errors
- [ ] After combat the spin resumes
- [ ] `/wuk spin` toggles it, the Settings "Spin ring" checkbox matches, and the state persists after `/reload`
- [ ] `/wuk spin` in combat prints "not in combat"

---

## Phase 5: Collapse to core

### Changes

#### 1. Collapse, hover and proxy alert
**File**: `WarlockUtilityKit/UI.lua`
**Action**: modify
- In `WUK.LayoutRing`, inside the orbit loop after `SetPoint`:
  ```lua
  b:SetAlpha(s.radius / R); b:EnableMouse(s.radius > 0)
  ```
  After the loop, the core pulses on behalf of hidden alerts:
  ```lua
  local any = false
  for _, kind in ipairs(ORBIT) do any = any or s.icons[kind].alerting end
  WUK.SetAlert(s.icons.shard, any and s.radius < R / 2)
  ```
- Add the hover target and handler after `WUK.Animate`:
  ```lua
  local function Target(s)
    return (WUK.db.collapse and not InCombatLockdown() and not MouseIsOver(s)) and 0 or R
  end
  -- strip and every button share this: OnLeave of the strip fires on entering a child, so check the rect
  local function Hover() local s = WUK.strip; s.targetRadius = Target(s); WUK.Animate() end
  ```
- At the end of the init, after Prep's buttons exist, hook hover. Run it from the refresher once with a flag, because the init runs before Prep registers armor and pet:
  ```lua
  -- in the refresher, before LayoutRing:
  local s = WUK.strip
  if not s.hooked then
    s.hooked = true
    s:HookScript("OnEnter", Hover); s:HookScript("OnLeave", Hover)
    for _, b in pairs(s.icons) do b:HookScript("OnEnter", Hover); b:HookScript("OnLeave", Hover) end
  end
  if not InCombatLockdown() then s.targetRadius = Target(s) end
  ```
- `WUK.CombatFreeze`: after `LayoutRing()`, which now resets alpha to 1 and enables mouse at radius R, nothing more is needed. Confirm the orbit buttons end at alpha 1 with mouse enabled.

#### 2. Setting + slash
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify
- `DEFAULTS`: add `collapse = true`.
- Change the spin branch to handle both commands:
  ```lua
  elseif cmd == "spin" or cmd == "collapse" then
    if InCombatLockdown() then return WUK.Print("not in combat") end
    WUK.db[cmd] = not WUK.db[cmd]; WUK.Print("ring " .. cmd .. " " .. (WUK.db[cmd] and "on" or "off")); WUK.Refresh()
  ```
- Usage line: add `collapse |` after `spin |`.

#### 3. Settings checkbox
**File**: `WarlockUtilityKit/Settings.lua`
**Action**: modify
- Add after "Spin ring":
  ```lua
  Check(win, "Collapse ring until hover", -148, function() return WUK.db.collapse end,
    function(on) if on ~= WUK.db.collapse then Run("collapse") end end),
  ```
- Move the pet `label` to -188 and `dd` to -206. Set `win:SetSize(320, 314)`.

### Verification
#### Automated
- [ ] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual
- [ ] Out of combat with the mouse away, the ring folds into the core and only the core is visible
- [ ] Hovering the frame blooms the ring in about 0.2s. Moving across the orbit buttons keeps it open
- [ ] Moving the mouse off a button straight out of the frame collapses it
- [ ] Collapsed, then attacking a mob: the ring snaps open and every button is clickable in combat
- [ ] Collapsed with the armor buff missing: the core pulses. Opened: the armor button pulses instead
- [ ] `/wuk collapse` off keeps the ring open. The Settings checkbox matches and the state persists after `/reload`
- [ ] Spin and collapse together: the ring spins while open and while blooming

---

## Phase 6: Release

### Changes

#### 1. Version
**File**: `WarlockUtilityKit/WarlockUtilityKit.toc`
**Action**: modify. Change `## Version: 0.2.0` to `## Version: 0.3.0`.

(README.md has no Warlock Utility Kit section, so there is nothing to update there.)

### Verification
#### Automated
- [ ] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [ ] `sed -n 's/^## Version: *\([^[:space:]]*\).*/\1/p' WarlockUtilityKit/WarlockUtilityKit.toc` prints `0.3.0`

#### Manual
- [ ] `/wuk` with no args lists `spin` and `collapse`
- [ ] Settings window: all checkboxes, the pet dropdown and the buttons fit with no overlap
