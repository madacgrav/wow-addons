# Implementation Plan

## Overview
- Every button on the WUK ring gets a tooltip.
- Right-clicking the healthstone trades it to your target.
- Right-clicking the soulstone cycles the ring through three views: Party (today's ring, the default and fallback), Buff, and Demon. The soulstone icon is tinted per view.
- The ring returns to Party view when it collapses and when you enter combat.

All paths are relative to `WarlockUtilityKit/`.

**Test command**: `lua5.1 WarlockUtilityKit/tests/run.lua`, or `lua WarlockUtilityKit/tests/run.lua` if only `lua` is installed. Run it from the repo root.

**Deploy** after each phase, once tests pass and the phase is committed. Exit codes 0-7 mean success:
`robocopy "D:\Source\wow-addons\WarlockUtilityKit" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WarlockUtilityKit" /MIR /XD tests /NJH /NJS /NP /NDL`

**Combat rule** for every phase: `SetAttribute`, `Show`/`Hide`, `SetPoint`, `EnableMouse` and `SetSize` on the strip or its secure buttons must only run when `not InCombatLockdown()`. Texture, tint and tooltip calls are allowed any time.

---

## Phase 1: Tooltips on existing ring buttons

### Changes

#### 1. Tooltip helpers
**File**: `UI.lua`
**Action**: modify. Add after `WUK.SetAlert` (around `UI.lua:105-110`).

```lua
-- spell tooltip by name; plain name line when the client gives no ID
function WUK.SpellTooltip(name)
  if not name then return end
  local info = C_Spell.GetSpellInfo(name)
  if info and info.spellID then GameTooltip:SetSpellByID(info.spellID) else GameTooltip:AddLine(name) end
end

-- fill(b) adds the lines; same OnEnter/OnLeave shape as the minimap button (Settings.lua:102-108)
function WUK.AttachTooltip(b, fill)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); fill(self); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
end

-- held stone: the bag item; none held: the create spell (or the kind's name if not learned)
local function StoneTooltip(kind)
  local slot = WUK.counts.slots[kind]
  if slot then GameTooltip:SetBagItem(slot[1], slot[2])
  elseif kind == "shard" then GameTooltip:AddLine("Soul Shards: 0")
  elseif WUK.known[kind] then WUK.SpellTooltip(WUK.known[kind])
  else GameTooltip:AddLine((kind:gsub("^%l", string.upper))) end
end
```

`StoneTooltip` must be defined before the init function that uses it (`UI.lua:110` onward).

#### 2. Attach to the stone buttons
**File**: `UI.lua`
**Action**: modify. In the `for _, kind in ipairs(KINDS)` loop (`UI.lua:126-143`), after `f.icons[kind] = b`:

```lua
    WUK.AttachTooltip(b, function() StoneTooltip(kind) end)
```

#### 3. Attach to the armor and pet buttons
**File**: `Prep.lua`
**Action**: modify.

- At the end of the armor init (`Prep.lua:4-11`):
  ```lua
  WUK.AttachTooltip(armorBtn, function() WUK.SpellTooltip(WUK.known.armor) end)
  ```
- Pull the pet choice into a local function, placed above the pet init. Use it in both the pet refresher (`Prep.lua:32-33`) and the tooltip:
  ```lua
  local function PetSpell()
    local pet = WUK.known[WUK.char.pet] and WUK.char.pet or "imp"
    return WUK.known[pet], pet
  end
  ```
- The refresher becomes `local spell, pet = PetSpell()`, and the rest is unchanged.
- At the end of the pet init:
  ```lua
  WUK.AttachTooltip(petBtn, function() WUK.SpellTooltip((PetSpell())) end)
  ```

### Verification
#### Automated
- [x] `lua5.1 WarlockUtilityKit/tests/run.lua` passes (no Logic changes; this is a sanity check).
- [x] Deploy with robocopy.

#### Manual
- [x] Hover the shard core, healthstone, soulstone, spellstone and firestone, each with a stone in your bags: the bag item tooltip shows.
- [x] Hover each stone with none in your bags: the "Create X" spell tooltip shows, or the kind's name if the spell is not learned.
- [x] Hover armor and pet: the spell tooltip shows. The pet tooltip matches your `/wuk pet` choice.
- [x] Moving the mouse off a button hides the tooltip. No Lua errors (`/console scriptErrors 1`).

---

## Phase 2: Healthstone right-click trade

### Changes

#### 1. Trade entry points
**File**: `Trade.lua`
**Action**: modify. Add after `local function Whisper` (`Trade.lua:7`).

```lua
-- marks name as owed a stone; the TRADE_SHOW handler below places it in slot 1
function WUK.OfferHealthstone(name) hsQueue[name] = time() end

-- ring right-click: open a trade with the friendly target, stone goes in via TRADE_SHOW
function WUK.TradeHealthstone()
  if InCombatLockdown() then return WUK.Print("not in combat") end
  if not UnitIsPlayer("target") or not UnitIsFriend("player", "target") or UnitIsUnit("target", "player") then
    return WUK.Print("no friendly target")
  end
  if not CheckInteractDistance("target", 2) then return WUK.Print("target out of trade range") end
  if WUK.counts.healthstone < 1 then return WUK.Print("no healthstone") end
  local name = WUK.UnitFull("target") -- same Ambiguate form TRADE_SHOW builds for the partner
  if not name then return end
  WUK.OfferHealthstone(name)
  InitiateTrade("target")
end
```

The existing `TRADE_SHOW` handler (`Trade.lua:17-26`) places the stone. The `UI_INFO_MESSAGE` handler clears the entry. Neither changes.

#### 2. Left-click-only binding and the right-click hook
**File**: `UI.lua`
**Action**: modify, in the stone loop.

- Replace `b:SetAttribute("type", "macro")` (`UI.lua:133`) with:
  ```lua
  -- healthstone: right-click is the trade hook, so the macro binds button 1 only
  b:SetAttribute(kind == "healthstone" and "type1" or "type", "macro")
  ```
- After the `AttachTooltip` line from Phase 1, add:
  ```lua
  if kind == "healthstone" then
    b:HookScript("OnClick", function(_, button, down)
      if button == "RightButton" and not down then WUK.TradeHealthstone() end
    end)
  end
  ```

`macrotext` (no suffix) is still read for button 1 through the secure modified-attribute fallback, so the refresher at `UI.lua:165-168` does not change.

#### 3. Tooltip hint
**File**: `UI.lua`
**Action**: modify. At the end of `StoneTooltip`:

```lua
  if kind == "healthstone" then GameTooltip:AddLine("Right-click: trade to target", 1, 1, 1) end
```

### Verification
#### Automated
- [x] `lua5.1 WarlockUtilityKit/tests/run.lua` passes.
- [x] Deploy with robocopy.

#### Manual
- [x] No healthstone, left-click: casts Create Healthstone.
- [x] Holding a healthstone, left-click: eats it.
- [x] Target a party member within about 10 yards and right-click: a trade window opens with the healthstone in slot 1. Accept completes the trade.
- [x] Right-click with no target, a hostile target, yourself, a far player, or no stone: the matching message prints and no trade opens.
- [x] Right-click never eats or creates a stone.
- [x] Whisper-request trades (someone whispers "hs") still work.

---

## Phase 3: View switching — Party ⇄ Buff

### Changes

#### 1. View helpers
**File**: `Logic.lua`
**Action**: modify. Append after `WUK.RingPoint` (`Logic.lua:174-177`).

```lua
-- ring views: orbit keys clockwise from 12; party = the default ring
WUK.VIEWS = {
  party = { "healthstone", "soulstone", "spellstone", "firestone", "armor", "pet" },
  buff = { "soulstone", "armor", "detect", "shadowward", "soullink", "unending", "eye", "sense" },
}
WUK.VIEW_ORDER = { "party", "buff" }

function WUK.NextView(view)
  local o = WUK.VIEW_ORDER
  for i, v in ipairs(o) do if v == view then return o[i % #o + 1] end end
  return o[1]
end

-- keys to draw: the button must exist (has[k]); spell views also need the spell known (soulstone is the toggle, always kept)
function WUK.ViewKeys(view, known, has)
  local out = {}
  for _, k in ipairs(WUK.VIEWS[view] or WUK.VIEWS.party) do
    if has[k] and (view == "party" or k == "soulstone" or known[k]) then out[#out + 1] = k end
  end
  return out
end

-- new ring offset that keeps one button at the same angle after its slot index/count change
function WUK.FlipAngle(angle, iOld, nOld, iNew, nNew)
  return (angle + (iOld - 1) * 360 / nOld - (iNew - 1) * 360 / nNew) % 360
end
```

#### 2. Tests
**File**: `tests/run.lua`
**Action**: modify. Append before the final line or print, if one exists, otherwise at the end.

```lua
-- Ring views
local function near(a, b, label) if math.abs(a - b) > 1e-6 then error(label .. ": " .. a .. " vs " .. b, 2) end end
eq(WUK.NextView("party"), "buff", "next party"); eq(WUK.NextView("buff"), "party", "next wraps")
eq(WUK.NextView("bogus"), "party", "next unknown")
local all = setmetatable({}, { __index = function() return true end })
eq(#WUK.ViewKeys("party", {}, all), 6, "party unfiltered by known")
local bk = WUK.ViewKeys("buff", { armor = "Demon Armor" }, all)
eq(#bk, 2, "buff known only"); eq(bk[1], "soulstone", "toggle kept"); eq(bk[2], "armor", "known buff")
eq(#WUK.ViewKeys("party", {}, { healthstone = true }), 1, "missing button dropped")
local a = WUK.FlipAngle(10, 2, 6, 1, 8)
local x1, y1 = WUK.RingPoint(2, 6, 58, 10); local x2, y2 = WUK.RingPoint(1, 8, 58, a)
near(x1, x2, "flip x"); near(y1, y2, "flip y")
local b2 = WUK.FlipAngle(a, 1, 8, 2, 6)
x2, y2 = WUK.RingPoint(2, 6, 58, b2); near(x1, x2, "flip back x"); near(y1, y2, "flip back y")
```

#### 3. Spell names
**File**: `Core.lua`
**Action**: modify. Add these entries to `SPELLS` (`Core.lua:48-62`):

```lua
  shadowward = { "Shadow Ward" }, unending = { "Unending Breath" },
  eye = { "Eye of Kilrogg" }, sense = { "Sense Demons" },
```

#### 4. Generic spell buttons
**File**: `Prep.lua`
**Action**: modify. Append at the end of the file.

```lua
-- one secure button per view spell; LayoutRing shows/hides them by view
local SPELL_KEYS = { "detect", "shadowward", "soullink", "unending", "eye", "sense" }
function WUK.SpellButton(key)
  local b = CreateFrame("Button", "WUKSpell_" .. key, WUK.strip, "SecureActionButtonTemplate")
  b:SetSize(36, 36); b:RegisterForClicks("AnyUp", "AnyDown"); b:SetAttribute("type", "macro")
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  WUK.AttachTooltip(b, function() WUK.SpellTooltip(WUK.known[key]) end)
  b:Hide() -- party view first
  WUK.strip.icons[key] = b
  return b
end
table.insert(WUK.inits, function() for _, k in ipairs(SPELL_KEYS) do WUK.SpellButton(k) end end)
table.insert(WUK.refreshers, function()
  for _, k in ipairs(SPELL_KEYS) do
    local b, spell = WUK.strip.icons[k], WUK.known[k]
    b.icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or 134400)
    if not InCombatLockdown() then b:SetAttribute("macrotext", spell and ("/cast " .. spell) or "") end
  end
end)
```

`armor` in the Buff view reuses `WUKArmorButton`; no new button is needed.

#### 5. View-aware ring
**File**: `UI.lua`
**Action**: modify.

- Delete the `ORBIT` local (`UI.lua:11`). `WUK.VIEWS.party` replaces it. `Logic.lua` loads first, so it is defined.
- Add above `WUK.LayoutRing`:
  ```lua
  function WUK.CurrentKeys() return WUK.ViewKeys(WUK.strip.view, WUK.known, WUK.strip.icons) end
  local function IndexOf(list, k) for i, v in ipairs(list) do if v == k then return i end end return 1 end
  ```
- Replace the orbit part of `LayoutRing` (`UI.lua:38-46`) with:
  ```lua
  local keys, on = WUK.CurrentKeys(), {}
  for i, kind in ipairs(keys) do
    on[kind] = true
    local b, x, y = s.icons[kind], WUK.RingPoint(i, #keys, s.radius, s.angle)
    b:ClearAllPoints(); b:SetPoint("CENTER", s, "CENTER", x, y + cy)
    b:SetAlpha(s.radius / R); b:EnableMouse(s.radius > 0)
    if not b:IsShown() then b:Show() end
  end
  for kind, b in pairs(s.icons) do -- only touch buttons whose membership changed
    if kind ~= "shard" and not on[kind] and b:IsShown() then b:Hide() end
  end
  -- collapsed: the core pulses on behalf of hidden alerts
  local any = false
  for _, kind in ipairs(keys) do any = any or s.icons[kind].alerting end
  WUK.SetAlert(s.icons.shard, any and s.radius < R / 2)
  ```
- In the strip init, next to `f.angle, f.radius...` (`UI.lua:115`), add `f.view = "party"`.

#### 6. SetView, tint, and the soulstone toggle
**File**: `UI.lua`
**Action**: modify.

- Add after `WUK.Animate`:
  ```lua
  local TINT = { party = { 1, 1, 1 }, buff = { 0.5, 0.75, 1 }, demon = { 1, 0.45, 0.45 } }
  -- swap the orbit set; soulstone keeps its angle, ring re-blooms from 0 as the "flip"
  function WUK.SetView(view)
    local s = WUK.strip
    if InCombatLockdown() or s.view == view then return end
    local old = WUK.CurrentKeys()
    s.view = view
    local new = WUK.CurrentKeys()
    s.angle = WUK.FlipAngle(s.angle, IndexOf(old, "soulstone"), #old, IndexOf(new, "soulstone"), #new)
    s.radius = 0
    local t = TINT[view] or TINT.party
    s.icons.soulstone.icon:SetVertexColor(t[1], t[2], t[3])
    WUK.LayoutRing(); WUK.Animate()
    local b = s.icons.soulstone
    if GameTooltip:IsOwned(b) then b:GetScript("OnEnter")(b) end -- refresh the next-view hint
  end
  ```
  `SetView` is called only at runtime, after init, so `IndexOf` and `CurrentKeys` must be defined earlier in the file.
- In the stone loop, change the Phase 2 attribute line to:
  ```lua
  b:SetAttribute((kind == "healthstone" or kind == "soulstone") and "type1" or "type", "macro")
  ```
- In the stone loop, add:
  ```lua
  if kind == "soulstone" then
    b:HookScript("OnClick", function(_, button, down)
      if button == "RightButton" and not down then WUK.SetView(WUK.NextView(WUK.strip.view)) end
    end)
  end
  ```
- At the end of `StoneTooltip`:
  ```lua
  if kind == "soulstone" then
    local nv = WUK.NextView(WUK.strip.view)
    GameTooltip:AddLine("Right-click: " .. nv:gsub("^%l", string.upper) .. " view", 1, 1, 1)
  end
  ```

#### 7. Fallbacks to Party
**File**: `UI.lua`
**Action**: modify.

- `CombatFreeze` (`UI.lua:88-93`): make `WUK.SetView("party")` the first line. `PLAYER_REGEN_DISABLED` fires before lockdown, so `SetView` still runs. The existing lines then stop the animator and set radius R.
- `Step` (`UI.lua:68-80`): after `s.targetRadius = Target(s)`, add:
  ```lua
  -- collapsed with the mouse away: back to the party ring (targetRadius guard keeps a fresh flip from reverting)
  if s.radius == 0 and s.targetRadius == 0 and s.view ~= "party" then WUK.SetView("party") end
  ```

### Verification
#### Automated
- [x] `lua5.1 WarlockUtilityKit/tests/run.lua` passes, including the new "Ring views" block.
- [x] `grep -n "ORBIT" WarlockUtilityKit/*.lua` returns nothing.
- [x] Deploy with robocopy.

#### Manual
- [ ] On login, Party view looks and behaves exactly as in v0.3.3: same 6 orbit buttons and order, spin, collapse, alerts.
- [ ] Right-click the soulstone: the ring closes and re-blooms showing the soulstone (tinted blue) plus only the buffs you know. The soulstone stays under the cursor.
- [ ] Clicking each buff casts it (Detect Invisibility on a friendly target works). Tooltips show each spell.
- [ ] Right-click again: back to Party, with a white soulstone.
- [ ] Left-click the soulstone in either view: uses or creates a soulstone, as before.
- [ ] In Buff view, move the mouse off: the ring collapses, and the next hover shows Party.
- [ ] In Buff view, pull a mob: the ring snaps to Party at full radius. Right-click in combat does nothing. No "action blocked" errors.
- [ ] The soulstone tooltip hint reads "Right-click: Buff view", then "Right-click: Party view".

---

## Phase 4: Demon view and ring growth; release 0.4.0

### Changes

#### 1. Demon view and ring radius
**File**: `Logic.lua`
**Action**: modify.

- Add this entry inside `WUK.VIEWS`:
  ```lua
  demon = { "soulstone", "imp", "voidwalker", "succubus", "incubus", "felhunter", "felguard", "inferno", "doom", "feldom" },
  ```
- `WUK.VIEW_ORDER = { "party", "buff", "demon" }`
- Add:
  ```lua
  -- ring grows past minR once n buttons of ~40px no longer fit around it
  function WUK.ViewRadius(n, minR) return math.max(minR, n * 40 / (2 * math.pi)) end
  ```

#### 2. Tests
**File**: `tests/run.lua`
**Action**: modify.

- Change `eq(WUK.NextView("buff"), "party", "next wraps")` to:
  ```lua
  eq(WUK.NextView("buff"), "demon", "next buff"); eq(WUK.NextView("demon"), "party", "next wraps")
  ```
- Add:
  ```lua
  eq(WUK.ViewRadius(6, 58), 58, "radius min"); near(WUK.ViewRadius(10, 58), 400 / (2 * math.pi), "radius grows")
  eq(#WUK.ViewKeys("demon", { imp = "Summon Imp" }, all), 2, "demon known only")
  ```

#### 3. Spell names
**File**: `Core.lua`
**Action**: modify. Add to `SPELLS`:

```lua
  felguard = { "Summon Felguard" }, inferno = { "Inferno" }, doom = { "Ritual of Doom" }, feldom = { "Fel Domination" },
```

#### 4. Demon buttons
**File**: `Prep.lua`
**Action**: modify. Extend `SPELL_KEYS`:

```lua
local SPELL_KEYS = { "detect", "shadowward", "soullink", "unending", "eye", "sense",
  "imp", "voidwalker", "succubus", "incubus", "felhunter", "felguard", "inferno", "doom", "feldom" }
```

The pet button (`strip.icons.pet`) stays Party-only. The demon keys are separate buttons, `WUKSpell_imp` and so on.

#### 5. Radius follows the view
**File**: `UI.lua`
**Action**: modify. The constant `R` stays as the minimum radius; `s.fullR` holds the current view's radius.

- **Strip init**:
  - Size the strip for the largest view, so the mouse-over rect covers grown rings:
    ```lua
    local maxN = 0; for _, v in pairs(WUK.VIEWS) do maxN = math.max(maxN, #v) end
    local SIZE = 2 * (WUK.ViewRadius(maxN, R) + BTN / 2) + 8
    ```
  - Set `f.fullR = R`.
- **`LayoutRing`**:
  - Right after computing `keys`, add `s.fullR = WUK.ViewRadius(#keys, R)`.
  - Use `s.radius / s.fullR` for alpha.
  - Use `s.radius < s.fullR / 2` for the core alert.
- **`Target`** (`UI.lua:64-66`): return `s.fullR` instead of `R`.
- **`Step`**: use `local d = s.fullR / BLOOM * elapsed`.
- **`CombatFreeze`**: `s.radius, s.targetRadius = s.fullR, s.fullR`. `SetView("party")` runs first; the following `LayoutRing` recomputes `fullR` for Party, which is R.

#### 6. Release
- **`WarlockUtilityKit.toc`**: change `## Version: 0.3.3` to `## Version: 0.4.0`.
- **`CHANGELOG.md`**: add above `## [0.3.3]`:

```markdown
## [0.4.0] — 2026-11-16

### Added
- **Ring tooltips.** Every ring button shows its spell or item tooltip on hover.
- **Healthstone trade.** Right-click the healthstone to open a trade with your friendly target with a stone already in the window. Left-click still eats one, or creates one when you have none.
- **Ring views.** Right-click the soulstone to flip the ring: Party (default) → Buff (armor, Detect Invisibility, Shadow Ward, Soul Link, Unending Breath, Eye of Kilrogg, Sense Demons) → Demon (every summon, Inferno, Ritual of Doom, Fel Domination). The soulstone tint shows the view; only spells you know appear. The ring returns to Party when it collapses or you enter combat.
```

### Verification
#### Automated
- [ ] `lua5.1 WarlockUtilityKit/tests/run.lua` passes.
- [ ] `grep -n "Version" WarlockUtilityKit/WarlockUtilityKit.toc` shows `0.4.0`.
- [ ] Deploy with robocopy.

#### Manual
- [ ] Right-click cycles Party → Buff (blue) → Demon (red) → Party (white).
- [ ] Demon view shows every known summon. Each one casts; Inferno enters ground targeting.
- [ ] With 10 known buttons there is no overlap, and the ring is slightly larger. Party and Buff keep the original size.
- [ ] Hovering the outer edge of the grown ring does not collapse it.
- [ ] The collapse fallback and the combat fallback still return to Party from Demon view.
- [ ] Phase 1-3 checks still hold: tooltips, healthstone trade, left-click soulstone.
