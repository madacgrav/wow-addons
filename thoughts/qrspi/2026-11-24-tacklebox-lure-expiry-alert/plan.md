# Implementation Plan

## Overview
A fish getting away no longer flashes the screen; the counter stays. When the lure on the equipped fishing pole wears off and the same pole is still in the main hand, TackleBox shows:
- centre raid-warning text;
- a chat line;
- an amber flash (if `/tb flash` is on);
- the raid-warning sound.

`/tb lure` toggles the alert. Released as 1.4.0.

## Commands
- Tests: `lua D:/Source/wow-addons/TackleBox/tests/run.lua` prints `all tests passed` (Lua 5.1 syntax).
- Lint: `bash /c/Users/madac/.claude/plugins/cache/wow-forever-addon-marketplace/wow-forever-addon/1.0.0/skills/wow-forever-addon/scripts/lint.sh D:/Source/wow-addons/TackleBox`. Baseline is `Total: 29 warnings / 0 errors`. The warning count must not grow beyond warnings already of the same kind (line length, etc.), and there must be 0 errors.
- Deploy after each phase commits: `robocopy "D:\Source\wow-addons\TackleBox" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\TackleBox" /MIR /XD tests /NJH /NJS /NP /NDL`. Exit 0-7 = ok. From Git Bash use `//MIR` style flags, or run it from PowerShell. The user runs `/reload`.
- TOC load order: `Logic.lua`, `Core.lua`, `Actions.lua`, `CastBar.lua` (`TackleBox.toc:14-19`). Functions defined in later files may be called only at runtime (after `PLAYER_LOGIN`), never at file load.
- Globals confirmed in the Forever luacheck std: `RaidNotice_AddMessage`, `RaidWarningFrame`, `UIErrorsFrame`, `SOUNDKIT`, `ChatTypeInfo`, `PlaySound`. `WEAPON_ENCHANT_CHANGED` is in the Forever API index (event names need no std entry).

---

## Phase 1: Quiet misses, coloured flash

### Changes

#### 1. Flash colour argument
**File**: `TackleBox/CastBar.lua`
**Action**: modify

Keep the texture reachable (`:27-29`):
```lua
  local t = flash:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints()
  -- LowHealth art is red; desaturate first or the tint multiplies into red
  t:SetTexture("Interface\\FullScreenTextures\\LowHealth"); t:SetDesaturated(true); t:SetBlendMode("ADD"); t:SetVertexColor(0.3, 0.6, 1)
  flash.tex = t
```
Replace `TB.Flash` (`:54`):
```lua
-- default blue (pool alerts); callers pass a tint for other alerts
function TB.Flash(r, g, b) flash.tex:SetVertexColor(r or 0.3, g or 0.6, b or 1); flash.anim:Stop(); flash.anim:Play() end
```
Update the comment at `:24` from "blue screen-edge vignette" to "screen-edge vignette (blue by default)".

#### 2. Remove the got-away flash
**File**: `TackleBox/Core.lua`
**Action**: modify, at `:234-241`

```lua
  C_Timer.After(1, function()
    if TB.IsMiss(stopT, TB.lastLootT) then
      TB.session.misses = TB.session.misses + 1
      TB.Refresh()
    end
  end)
```
Update the comment at `:134` to `-- cast bar + got-away count: a fishing cast that ends with no fishing loot within 1s counts as a miss`.
Leave the pool alert at `:156` unchanged (`TB.Flash()` with no arguments stays blue).

### Verification
#### Automated
- [x] `lua D:/Source/wow-addons/TackleBox/tests/run.lua` prints `all tests passed`
- [x] Lint shows 0 errors, with no new warning kinds
- [x] `grep -n "TB.Flash" TackleBox/*.lua` shows only the definition and the pool call (`Core.lua:156`)

#### Manual (after commit + deploy + `/reload`)
- [x] Cast and let it run out or miss: the "got away" count goes up and the screen does not flash
- [x] Hover a fishing pool (out of combat, `/tb detect` on): chat says `<pool> nearby` and the screen edge flashes blue

---

## Phase 2: Lure-expired alert

### Changes

#### 1. Pure predicate
**File**: `TackleBox/Logic.lua`
**Action**: modify. Add after `TB.ShouldAlert` (`:295-299`):

```lua
-- lure state = { item = slot-16 itemID|nil, pole = bool, lure = bool }; prev nil = first read (login)
-- true only when the lure dropped off the same pole that is still equipped (a swap clears the read too)
function TB.LureExpired(prev, cur)
  return (prev and prev.lure and not cur.lure and cur.pole and prev.item == cur.item) and true or false
end
```

#### 2. Tests
**File**: `TackleBox/tests/run.lua`
**Action**: modify. Add before `print("all tests passed")`:

```lua
-- Lure alert
local on, off = { item = 6256, pole = true, lure = true }, { item = 6256, pole = true, lure = false }
eq(TB.LureExpired(nil, off), false, "lure: first read")
eq(TB.LureExpired(on, off), true, "lure: expired on same pole")
eq(TB.LureExpired(off, off), false, "lure: still off")
eq(TB.LureExpired(on, on), false, "lure: still on")
eq(TB.LureExpired(on, { item = 6365, pole = true, lure = false }), false, "lure: other pole")
eq(TB.LureExpired(on, { item = 2000, pole = false, lure = false }), false, "lure: swapped to weapon")
```

#### 3. Expose the pole check
**File**: `TackleBox/Actions.lua`
**Action**: modify
- `:166`: `local function PoleEquipped()` becomes `function TB.PoleEquipped()` (body unchanged).
- `:179`: `PoleEquipped()` becomes `TB.PoleEquipped()`.

#### 4. Setting, state, alert, wiring, slash
**File**: `TackleBox/Core.lua`
**Action**: modify

`DEFAULTS` (`:19-20`): add `lureAlert = true` (e.g. after `detect = true`). Do not bump `version`; `MergeDefaults` fills it in.

Add a block after the pool-alert section (after the `PLAYER_SOFT_INTERACT_CHANGED` handler, `~:168`):
```lua
-- lure expiry: remember whether the equipped pole has a temp enchant; alert when it drops off the same pole.
-- Only the 1st GetWeaponEnchantInfo return is used (Actions.lua uses it too); the expiry time is unverified on Forever.
TB.LURE_MSG, TB.LURE_COLOR = "Lure expired: reapply", { 1, 0.65, 0.1 }
TB.lureState = nil -- { item, pole, lure }

function TB.ReadLureState()
  local has = GetWeaponEnchantInfo()
  if TB.Secret(has) then return nil end -- unknown: keep the last state
  return { item = GetInventoryItemID("player", 16), pole = TB.PoleEquipped() and true or false, lure = has and true or false }
end

function TB.LureAlert()
  local c = TB.LURE_COLOR
  if not pcall(RaidNotice_AddMessage, RaidWarningFrame, TB.LURE_MSG, ChatTypeInfo["RAID_WARNING"]) then
    UIErrorsFrame:AddMessage(TB.LURE_MSG, c[1], c[2], c[3])
  end
  TB.Print(TB.LURE_MSG)
  if TB.db.flash then TB.Flash(c[1], c[2], c[3]) end
  PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")
end

function TB.CheckLure()
  if not TB.active then return end
  local cur = TB.ReadLureState()
  if not cur then return end
  if TB.db.lureAlert and TB.LureExpired(TB.lureState, cur) then TB.LureAlert() end
  TB.lureState = cur
end
table.insert(TB.refreshers, TB.CheckLure) -- Refresh already runs on UNIT_INVENTORY_CHANGED
TB.On("WEAPON_ENCHANT_CHANGED", TB.CheckLure)
-- backup if no event fires on expiry: poll only while a lure is on the pole (alert lags up to 5s)
table.insert(TB.inits, function()
  C_Timer.NewTicker(5, function() local s = TB.lureState; if s and s.lure and s.pole then TB.CheckLure() end end)
end)
```
Notes:
- `TB.refreshers` run after `PLAYER_LOGIN` (`Core.lua:55-59`), so `TB.PoleEquipped` (Actions.lua) and `TB.Flash` (CastBar.lua) exist by then.
- The `TB.active` guard covers `WEAPON_ENCHANT_CHANGED` firing before login.
- The first refresh after login sets `TB.lureState` with no alert (nil prev).

Slash parser (`:432` area): add after the `flash` branch:
```lua
  elseif cmd == "lure" then TB.db.lureAlert = not TB.db.lureAlert; TB.Print("lure alert " .. (TB.db.lureAlert and "on" or "off"))
```
Help line (`:451`): insert `lure||` after `flash||`:
```lua
  else TB.Print("/tb show||hide||lock||reset||probe||flash||lure||pins map||minimap||detect||camp||bind <key>||unbind") end
```

### Verification
#### Automated
- [x] `lua D:/Source/wow-addons/TackleBox/tests/run.lua` prints `all tests passed` (6 new lure cases)
- [x] Lint shows 0 errors, with no new undefined-global warnings (`RaidNotice_AddMessage`, `RaidWarningFrame`, `ChatTypeInfo`, `UIErrorsFrame`, `SOUNDKIT`, `PlaySound`, `GetWeaponEnchantInfo` are all in the std)
- [x] `grep -n "PoleEquipped" TackleBox/*.lua` shows only `TB.PoleEquipped` (definition + 2 calls)

#### Manual (after commit + deploy + `/reload`)
- [x] Pole equipped, no lure, `/reload`: no alert
- [x] Apply Shiny Bauble with the Lure button. Wait for it to expire (about 10 minutes). Expect `Lure expired: reapply` as centre raid-warning text, a TB chat line, an amber screen-edge flash and the raid-warning sound, once
- [x] Apply a lure, then swap to weapons with the Pole button: no alert
- [x] `/tb lure` prints `lure alert off`; let a lure expire: no alert. `/tb lure` again prints `lure alert on`
- [x] `/tb flash` off; let a lure expire: text, chat and sound, no flash
- [x] Hover a pool: flash is still blue (the amber tint does not stick)

---

## Phase 3: Docs and 1.4.0 release

### Changes

#### 1. README
**File**: `TackleBox/README.md`
**Action**: modify
- Section "Cast bar and 'got away' flash" (`:64-66`): rename to `## Cast bar and "got away" count`. Remove the flash sentences. Keep: the line-style bar counts down the 30-second cast; a cast that ends without a catch raises the header's "got away" count. Keep the sentence that the game does not report bites.
- New section after it, `## Lure expired alert`: when the lure on your equipped fishing pole wears off, TackleBox shows "Lure expired: reapply" in the centre of the screen and in chat, flashes the screen edge amber and plays the raid-warning sound. Swapping the pole off does not trigger it. `/tb lure` turns it off or on; `/tb flash` turns off just the flash. It can take up to 5 seconds to notice.
- Pool-alert sentence (`:36`): "flashes" becomes "flashes blue".
- Slash table (`:94`): `/tb flash` reads `Turn the screen flash for pool and lure alerts on or off`. Add a row `| /tb lure | Turn the lure expired alert on or off |`.

#### 2. CHANGELOG
**File**: `TackleBox/CHANGELOG.md`
**Action**: modify. Insert above `## [1.3.0]`:
```markdown
## [1.4.0] — <commit date, YYYY-MM-DD>

### Added
- **Lure expired alert.** When the lure on your equipped fishing pole wears off, TackleBox shows "Lure expired: reapply" on screen and in chat, flashes the screen edge amber and plays a sound. `/tb lure` turns it off or on; `/tb flash` controls just the flash.

### Changed
- A fish getting away no longer flashes the screen. The "got away" count still counts.
- Pool alerts keep the blue flash; the lure alert flashes amber so the two are easy to tell apart.
```

#### 3. Version
**File**: `TackleBox/TackleBox.toc`
**Action**: modify. `## Version: 1.3.0` becomes `## Version: 1.4.0`.

### Verification
#### Automated
- [x] `lua D:/Source/wow-addons/TackleBox/tests/run.lua` prints `all tests passed`
- [x] Lint shows 0 errors
- [x] `grep -n "Version" TackleBox/TackleBox.toc` shows `1.4.0`; `grep -n "1.4.0" TackleBox/CHANGELOG.md` finds the new heading
- [x] `grep -n "tb lure" TackleBox/README.md` finds the section and the table row

#### Manual (after commit + deploy + `/reload`)
- [ ] `/tb xyz` help line includes `lure`
- [ ] The addon list shows TackleBox 1.4.0
