# Implementation Plan

## Overview
TackleBox gains:
- a collapsible panel with an always-visible current-zone fishing status line
- scrolling rows (at most 10 visible) on every tab
- per-character memory of the main-hand and off-hand weapons, with an "Equip weapons" toggle in the pole slot
- `/tb bind <KEY>`: one key that casts Fishing and, while the line is out, reels in through the Interact binding, with soft-target CVars raised temporarily

## Ground rules (every phase)
- **Logic.lua stays pure.** No WoW API in it. New decision functions are tested in `TackleBox/tests/run.lua` with the existing `eq` helper.
- **API names:** every one used below was checked in `refs/forever-api-index.md` (`C_CVar.GetCVar/SetCVar` :358, `C_Container.GetContainerItemLink` :433, `GetInventoryItemID/Link` :1065, `PLAYER_LOGOUT`).
  - **Exception:** `SetOverrideBinding`, `SetOverrideBindingClick` and `ClearOverrideBindings` are not in the index or the lint std. The user approved using them with a runtime guard and a `.luacheckrc` entry (Phase 4).
  - Never emit the global `EquipItemByName` or `PickupContainerItem`.
- **Combat:** secure attributes, bindings and CVars change only when `not InCombatLockdown()`. The panel is not secure, so panel code needs no combat guard.
- **Automated checks, every phase:**
  - `lua TackleBox/tests/run.lua` prints `all tests passed`. Lua 5.4 is on PATH; `lua5.1` from the README is not installed.
  - `bash /d/Source/wowskill/skills/wow-forever-addon/scripts/lint.sh TackleBox` reports **no new warnings** beyond the baseline of 29 (pre-existing W111/W113 for SVs, loot APIs and `TBPanel`, plus 2 PERF lines). Fixing the baseline is out of scope.
- **Deploy after each phase**, after tests pass and the phase commits:
  `robocopy "D:\Source\wow-addons\TackleBox" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\TackleBox" /MIR /XD tests /NJH /NJS /NP /NDL`
  Exit codes 0-7 mean success. Then the user runs `/reload`.

---

## Phase 1: Collapsible panel + zone line

### Changes

#### 1. Shared zone row + `TB.ZoneStatus`
**File**: `TackleBox/Logic.lua`
**Action**: modify `TB.WhereRows` (lines 48-71) and add `TB.ZoneStatus`.

```lua
-- one zone row; shared by the Where tab and the header zone line
local function ZoneRow(z, name, skill, lures, currentZone)
  local sub, need
  if z.noLoss then sub = "no get-aways at " .. z.noLoss else sub = "skill " .. z.band .. "-" .. z.max end
  if z.lure and (skill.modifier or 0) < z.lure then
    local l = LureFor(lures, z.lure); need = l and l.name or ("+" .. z.lure .. " lure"); sub = sub .. ", needs " .. need
  end
  local flag
  if name == currentZone then
    local eff = skill.level + (skill.modifier or 0)
    if eff < (z.cast or 1) then flag = "too low" elseif skill.level >= z.max then flag = "outgrown" else flag = "here" end
  end
  return { text = name .. (flag and (" [" .. flag .. "]") or ""), sub = sub, flag = flag, need = need }
end

function TB.WhereRows(zones, lures, skill, currentZone)
  if not skill then return {} end
  local rows, seen = {}, {}
  for _, z in ipairs(zones) do
    if skill.level >= z.band and skill.level < z.max then
      for _, n in ipairs(z.names) do rows[#rows + 1] = ZoneRow(z, n, skill, lures, currentZone); seen[n] = true end
    end
  end
  -- current zone outside the band: appended last so the flag still shows
  for _, z in ipairs(zones) do for _, n in ipairs(z.names) do
    if n == currentZone and not seen[n] then rows[#rows + 1] = ZoneRow(z, n, skill, lures, currentZone); seen[n] = true end
  end end
  return rows
end

-- header line for the zone you stand in; nil without Fishing or a zone name
function TB.ZoneStatus(zones, lures, skill, zone)
  if not skill or not zone or zone == "" then return nil end
  for _, z in ipairs(zones) do for _, n in ipairs(z.names) do
    if n == zone then
      local r = ZoneRow(z, n, skill, lures, zone)
      return { text = n .. ": skill " .. z.band .. "-" .. z.max .. " [" .. r.flag .. "]" .. (r.need and (", needs " .. r.need) or ""), flag = r.flag }
    end
  end end
  return { text = zone .. ": no fishing data" }
end
```

Row `text` and `sub` stay identical to today, so the existing WhereRows tests (`tests/run.lua:27-39`) must pass unchanged. The extra `need` field is ignored by the panel.

#### 2. Tests
**File**: `TackleBox/tests/run.lua`
**Action**: add before `print("all tests passed")`.

```lua
-- Zone line
local Z, L = TB.DATA.zones, TB.DATA.lures
local zs = TB.ZoneStatus(Z, L, { level = 100, modifier = 0 }, "Orgrimmar")
eq(zs.text, "Orgrimmar: skill 75-150 [here]", "zone here"); eq(zs.flag, "here", "zone here flag")
eq(TB.ZoneStatus(Z, L, { level = 160, modifier = 0 }, "Orgrimmar").flag, "outgrown", "zone outgrown")
eq(TB.ZoneStatus(Z, L, { level = 30, modifier = 0 }, "Redridge Mountains").flag, "too low", "zone too low (cast 55)")
eq(TB.ZoneStatus(Z, L, { level = 230, modifier = 0 }, "Felwood").text:find("needs", 1, true) ~= nil, true, "zone lure need")
zs = TB.ZoneStatus(Z, L, { level = 100, modifier = 0 }, "Moonglade")
eq(zs.text, "Moonglade: no fishing data", "zone unknown"); eq(zs.flag, nil, "zone unknown flag")
eq(TB.ZoneStatus(Z, L, nil, "Orgrimmar"), nil, "zone no skill")
eq(TB.ZoneStatus(Z, L, { level = 100 }, ""), nil, "zone empty name")
```

#### 3. Default
**File**: `TackleBox/Core.lua:17`
**Action**: add `expanded = false` to `DEFAULTS`.

#### 4. Header zone line, expand button, collapse
**File**: `TackleBox/Panel.lua`
**Action**: modify.

- **Constants (line 4):** `local WIDTH, ROW_W, TOP, TAB_H, HEAD = 320, 296, 146, 34, 100`.
  - `TOP` moves 18 px down to make room for the zone line.
  - `HEAD` is the collapsed panel height (header + zone line + padding).
- **In `Build()`**, after the got-away counter (after line 103):

```lua
  -- expand/collapse the tabs; state in TB.db.expanded
  local ex = CreateFrame("Button", nil, panel)
  ex:SetSize(16, 16); ex:SetPoint("RIGHT", panel, "TOPRIGHT", -12, -86)
  ex:SetScript("OnClick", function() TB.db.expanded = not TB.db.expanded; TB.Refresh() end)
  ex:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(TB.db.expanded and "Hide tabs" or "Show tabs", T.sand[1], T.sand[2], T.sand[3]); GameTooltip:Show()
  end)
  ex:SetScript("OnLeave", GameTooltip_Hide)
  panel.expand = ex
  -- current zone's fishing status, always shown
  panel.zone = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.zone:SetPoint("LEFT", panel, "TOPLEFT", 12, -86); panel.zone:SetPoint("RIGHT", ex, "LEFT", -4, 0)
  panel.zone:SetJustifyH("LEFT"); panel.zone:SetWordWrap(false)
```

- **Rule line (105-107):** keep it at `-TOP + 8`. Store it as `panel.rule = rule` so it can be hidden.
- **`MakeTab`, line 145:** tab y from `-82` to `-100`.
- **`TB.RenderPanel` signature:** `function TB.RenderPanel(rows, skill, misses, tabs, active, zone)`. After `panel.misses:SetText(...)`:

```lua
  local exp = TB.db.expanded
  panel.zone:SetText(zone and zone.text or "")
  local zc = zone and zone.color or { 1, 1, 1 }
  panel.zone:SetTextColor(zc[1], zc[2], zc[3])
  panel.expand:SetNormalTexture(exp and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
  panel.expand:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
  panel.rule:SetShown(exp)
  for _, t in ipairs(panel.tabs) do t:SetShown(exp) end
```

  - In the row loop, use `row:SetShown(exp and v ~= nil)`.
  - The height line becomes `panel:SetHeight(exp and (TOP + 10 + math.max(n, 3) * 26) or HEAD)`.
- **Refresher (lines 277-287):** build the zone line and pass it in.

```lua
  local zone = TB.ZoneStatus(TB.DATA.zones, TB.DATA.lures, TB.skill, GetRealZoneText())
  if zone then zone.color = FLAG_COLORS[zone.flag] or (zone.flag == nil and { 0.6, 0.6, 0.6 }) end
  TB.RenderPanel(rows, TB.skill, TB.session.misses, secs, active, zone)
```

  `FLAG_COLORS` (line 234) is a local declared above the refresher, so it is in scope there and not inside `RenderPanel`. That is why the color travels in `zone.color`.

### Verification
#### Automated
- [x] `lua TackleBox/tests/run.lua` prints `all tests passed`. The new zone tests pass, and the WhereRows tests pass unchanged.
- [x] `lint.sh TackleBox` shows no warnings beyond the baseline of 29.
- [x] Deployed with robocopy (exit code 0-7).

#### Manual
- [x] `/reload`: no errors. The panel starts collapsed, showing the header plus the zone line.
- [x] In Orgrimmar (or any listed zone) the line reads `<zone>: skill A-B [flag]`, colored green, grey or red.
- [x] In an unlisted zone it reads `<zone>: no fishing data` in grey.
- [x] Crossing a zone border updates the line within a second.
- [x] The plus button shows the tabs and rows, and the minus button hides them. `/reload` keeps the last state.
- [x] Toggling in combat works with no errors.

---

## Phase 2: Scrollable rows

### Changes

#### 1. Scroll frame and lazy rows
**File**: `TackleBox/Panel.lua`
**Action**: modify.

- Delete lines 2-3 (the ponytail comment and `MAX_ROWS`). Add `local VISIBLE, LIST_W = 10, ROW_W - 20`. The 20 px gutter is for the scroll bar inside the panel edge.
- Move the row construction out of `Build()` (lines 112-138) into a lazy builder. The body is unchanged except for the parent, position and widths.

```lua
local function GetRow(i)
  if panel.rows[i] then return panel.rows[i] end
  local row = CreateFrame("Frame", nil, panel.content)
  row:SetSize(LIST_W, 24); row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
  -- ... existing band / icon / text / sub / bar / highlight / OnEnter / OnLeave code from lines 116-136,
  --     with row.text:SetWidth(LIST_W - 50) and row.sub:SetWidth(LIST_W - 50)
  panel.rows[i] = row
  return row
end
```

- In `Build()`, where the row loop was:

```lua
  panel.rows = {}
  panel.scroll = CreateFrame("ScrollFrame", "TBPanelScroll", panel, "UIPanelScrollFrameTemplate")
  panel.scroll:SetPoint("TOPLEFT", 12, -TOP); panel.scroll:SetSize(LIST_W, 3 * 26)
  panel.content = CreateFrame("Frame", nil, panel.scroll)
  panel.content:SetSize(LIST_W, 26)
  panel.scroll:SetScrollChild(panel.content)
```

  - `UIPanelScrollFrameTemplate` is in the lint std (`forever-std.lua:18824`), so it exists in Forever FrameXML.
  - It gives mouse-wheel scrolling and a `ScrollBar` child.
  - **Fallback**, if `/reload` errors on the template: drop the template argument and add `panel.scroll:EnableMouseWheel(true); panel.scroll:SetScript("OnMouseWheel", function(s, d) s:SetVerticalScroll(math.max(0, math.min(s:GetVerticalScrollRange(), s:GetVerticalScroll() - d * 26))) end)`.
- `GetRow` must be declared after `panel` and above `TB.RenderPanel`. It is a file-local function placed right after `Build()`.

#### 2. RenderPanel rows and height
**File**: `TackleBox/Panel.lua`, in `TB.RenderPanel`.
**Action**: replace the row loop and height line.

```lua
  local n, stripe = #rows, false
  for i = 1, math.max(n, #panel.rows) do
    local v = rows[i]
    local row = v and GetRow(i) or panel.rows[i]
    row:SetShown(v ~= nil)
    if v then
      -- ... existing per-row body (icon, text, color, sub, stripe, bar, itemID/onTooltip), unchanged
    end
  end
  local vis = math.min(math.max(n, 3), VISIBLE)
  panel.content:SetHeight(math.max(n, 1) * 26)
  panel.scroll:SetHeight(vis * 26)
  if panel.scroll.ScrollBar then panel.scroll.ScrollBar:SetShown(n > VISIBLE) end
  if active ~= panel.lastTab then panel.scroll:SetVerticalScroll(0); panel.lastTab = active end
  panel.scroll:SetShown(exp)
  panel:SetHeight(exp and (TOP + 10 + vis * 26) or HEAD)
```

Rows no longer need `exp` in `SetShown`, because hiding `panel.scroll` hides them. Revert Phase 1's `row:SetShown(exp and v ~= nil)` to `row:SetShown(v ~= nil)`.

### Verification
#### Automated
- [x] `lua TackleBox/tests/run.lua` prints `all tests passed`.
- [x] `lint.sh TackleBox` shows no warnings beyond the baseline of 29.
- [x] Deployed with robocopy.

#### Manual
- [x] `/reload`: no errors. The Catch tab with more than 10 entries shows 10 rows, and the wheel scrolls to the last entry (count matches the badge).
- [x] Row tooltips (item plus top zones) still show while scrolled.
- [x] Short tabs (Camp, Water) show no scroll bar and keep at least 3 rows of space.
- [x] Scroll down on Catch, switch to Where, then back. Each tab switch opens at the top.
- [x] Collapse hides the scroll area, and the panel shrinks to the header.

---

## Phase 3: Weapon memory + re-equip button

### Changes

#### 1. Pure helpers
**File**: `TackleBox/Logic.lua`
**Action**: add after `TB.PickLure`.

```lua
-- bag entry for a remembered weapon: exact link first (same enchant/suffix), then any copy by id
function TB.FindWeapon(items, want)
  if not want then return nil end
  local byId
  for _, it in ipairs(items) do
    if want.link and it.link == want.link then return it end
    if not byId and it.id == want.id then byId = it end
  end
  return byId
end

-- /equipslot by bag+slot avoids picking the wrong copy of a duplicate item
function TB.WeaponsMacro(mh, oh)
  if not mh then return nil end
  local m = "/equipslot 16 " .. mh.bag .. " " .. mh.slot
  if oh then m = m .. "\n/equipslot 17 " .. oh.bag .. " " .. oh.slot end
  return m
end
```

#### 2. Tests
**File**: `TackleBox/tests/run.lua`

```lua
-- Weapons
local bag = { { id = 5, link = "L5a", bag = 0, slot = 3 }, { id = 5, link = "L5b", bag = 1, slot = 2 }, { id = 9, link = "L9", bag = 2, slot = 1 } }
eq(TB.FindWeapon(bag, { id = 5, link = "L5b" }).slot, 2, "weapon exact link")
eq(TB.FindWeapon(bag, { id = 5, link = "Lx" }).slot, 3, "weapon id fallback")
eq(TB.FindWeapon(bag, { id = 7 }), nil, "weapon missing")
eq(TB.FindWeapon(bag, nil), nil, "weapon none remembered")
eq(TB.WeaponsMacro({ bag = 0, slot = 3 }), "/equipslot 16 0 3", "macro mh only")
eq(TB.WeaponsMacro({ bag = 0, slot = 3 }, { bag = 2, slot = 1 }), "/equipslot 16 0 3\n/equipslot 17 2 1", "macro mh+oh")
eq(TB.WeaponsMacro(nil, { bag = 2, slot = 1 }), nil, "macro no mh")
```

#### 3. Bag scan with locations
**File**: `TackleBox/Actions.lua:79-91` (`BagItems`)
**Action**: add `bag`, `slot` and `link` to each entry.

```lua
items[#items + 1] = { id = id, classID = classID, subID = subID, bag = bag, slot = slot, link = C_Container.GetContainerItemLink(bag, slot) }
```

#### 4. Snapshot + weapons action
**File**: `TackleBox/Actions.lua`, refresher (lines 100-111).
**Action**: modify.

```lua
local function SlotItem(s)
  local id = GetInventoryItemID("player", s)
  return id and { id = id, link = GetInventoryItemLink("player", s) } or nil
end

table.insert(TB.refreshers, function()
  local A, poleOn, items = {}, PoleEquipped(), BagItems()
  if not poleOn then
    -- any non-pole main hand is the set to come back to; an empty hand keeps the old snapshot
    if GetInventoryItemID("player", 16) then TB.char.weapons = { mh = SlotItem(16), oh = SlotItem(17) } end
    local pole = TB.PickPole(items)
    if pole then A.pole = { item = pole } end
  else
    local w = TB.char.weapons
    if w and w.mh then
      local mh, oh = TB.FindWeapon(items, w.mh), w.oh and TB.FindWeapon(items, w.oh)
      local missing = (not mh and w.mh) or (w.oh and not oh and w.oh) or nil
      A.pole = { item = w.mh.id, weapons = true, macro = TB.WeaponsMacro(mh, oh), usable = not missing,
        need = missing and ((TB.ItemName(missing.id)) .. " not in bags") or nil }
    end
    -- ... existing lure code (counts / PickLure / A.lure) unchanged
  end
  -- ... existing water / cast / TB.actions / Apply unchanged
```

- `TB.ItemName` is defined in `Panel.lua` and only called at refresh time, after every file has loaded.
- `TB.char.weapons` needs no entry in `CHAR_DEFAULTS`, because nil means "nothing remembered".

#### 5. Apply + tooltip
**File**: `TackleBox/Actions.lua`
- In `Apply()`, the pole branch (line 56) becomes `b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", a.macro or ("/equip item:" .. a.item))`.
- After `b.itemID, b.need = a.item, a.need` add `b.tip = a.weapons and "Equip your weapons" or nil`.
- In `OnEnter` (lines 27-32), replace both `TIPS[key]` uses with `self.tip or TIPS[key]`.

### Verification
#### Automated
- [x] `lua TackleBox/tests/run.lua` prints `all tests passed`, including the 7 weapon tests.
- [x] `lint.sh TackleBox` shows no warnings beyond the baseline of 29.
- [x] Deployed with robocopy.

#### Manual
- [x] Main hand and off hand equipped, then click the pole button. The pole is on, the top slot shows the main-hand icon, and the tooltip shows the item plus "Equip your weapons".
- [x] Click it. Both weapons come back, and the slot shows the pole again.
- [x] Repeat with a two-hander. It comes back, and no off-hand line is involved.
- [x] With the pole on, `/reload`. The weapons button is still there (the snapshot persisted in `TackleBoxCharDB`).
- [x] Put the main-hand weapon in the bank with the pole on. The button greys out with "<name> not in bags" in red.
- [x] Two identical weapons in bags: the exact equipped copy (same link) comes back.

---

## Phase 4: One-key cast + reel

### Changes

#### 1. Lint allowance for the binding API
**File**: `TackleBox/.luacheckrc`
**Action**: create. This follows the `BusinessCard/.luacheckrc` pattern of extending, not replacing.

```lua
-- Addon-specific luacheck settings, appended by <skill>/scripts/lint.sh after stds.forever and the base config.
-- Override-binding API: not in the Forever docs or index; used by Forever fishing addons (Fishing-OneKey, BetterFishing).
-- Guarded at runtime in Actions.lua (TB.HasBindAPI). Confirm in game with /tb probe.
read_globals = read_globals or {}
for _, g in ipairs({ "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings" }) do
  read_globals[#read_globals + 1] = g
end
```

#### 2. Key normalizer
**File**: `TackleBox/Logic.lua`

```lua
-- "/tb bind f" -> "F"; modifiers keep their case-folded form ("shift-f" -> "SHIFT-F"); empty -> nil
function TB.NormalizeKey(s)
  if type(s) ~= "string" then return nil end
  s = s:match("^%s*(.-)%s*$"):upper()
  return s ~= "" and s or nil
end
```

Tests (`tests/run.lua`):

```lua
-- Cast key
eq(TB.NormalizeKey(" f "), "F", "key trim+upper"); eq(TB.NormalizeKey("shift-f"), "SHIFT-F", "key modifier")
eq(TB.NormalizeKey(""), nil, "key empty"); eq(TB.NormalizeKey(nil), nil, "key nil")
```

#### 3. Key caster, bindings, reel mode, CVars
**File**: `TackleBox/Actions.lua`
**Action**: add.
- A dedicated 1x1 invisible caster, so the key works while the bar or panel is hidden (design risk "hidden button click").
- The binding owner.
- `TB.BindCast`, `TB.ReelMode` and `TB.RestoreCVars`.

```lua
-- one-key cast: the key clicks TBCastKey; while the line is out the same key is INTERACTTARGET (reels in the bobber)
local owner = CreateFrame("Frame")
local caster -- made in the init below; secure, shown, 1x1, invisible
local REEL_CVARS = { SoftTargetInteract = "3", SoftTargetInteractRange = "60" } -- ponytail: 60 = BetterFishing's value; Forever max unknown
function TB.HasBindAPI() return SetOverrideBinding ~= nil and SetOverrideBindingClick ~= nil and ClearOverrideBindings ~= nil end

function TB.BindCast()
  if InCombatLockdown() or not TB.HasBindAPI() then return end
  ClearOverrideBindings(owner)
  if TB.db.castKey then SetOverrideBindingClick(owner, true, TB.db.castKey, "TBCastKey") end
end

function TB.RestoreCVars()
  local b = TB.db.cvarBackup
  if not b then return end
  for k, v in pairs(b) do C_CVar.SetCVar(k, v) end
  TB.db.cvarBackup = nil
end

TB.reeling = false
function TB.ReelMode(on)
  if not TB.db.castKey or not TB.HasBindAPI() or InCombatLockdown() then return end
  if on then
    if not TB.db.cvarBackup then
      local b = {}
      for k in pairs(REEL_CVARS) do b[k] = C_CVar.GetCVar(k) end -- nil (unknown CVar) is skipped below
      TB.db.cvarBackup = b
    end
    for k, v in pairs(REEL_CVARS) do if TB.db.cvarBackup[k] ~= nil then C_CVar.SetCVar(k, v) end end
    ClearOverrideBindings(owner)
    SetOverrideBinding(owner, true, TB.db.castKey, "INTERACTTARGET")
    TB.reeling = true
  else
    TB.RestoreCVars(); TB.BindCast(); TB.reeling = false
  end
end
```

In the existing init (`Actions.lua:38-44`), after the buttons are created:

```lua
  caster = CreateFrame("Button", "TBCastKey", UIParent, "SecureActionButtonTemplate")
  caster:SetSize(1, 1); caster:SetPoint("TOPLEFT"); caster:SetAlpha(0); caster:EnableMouse(false)
  caster:RegisterForClicks("AnyUp", "AnyDown")
  TB.RestoreCVars() -- a backup left by a crash or disconnect mid-cast
  TB.BindCast()
```

In `Apply()`, after the loop (it is already out of combat there):

```lua
  local cast = TB.actions.cast
  caster:SetAttribute("type", cast and "spell" or nil); caster:SetAttribute("spell", cast and cast.spell or nil)
```

#### 4. Channel wiring + lifecycle
**File**: `TackleBox/Core.lua`
- In the cast-bar `UNIT_SPELLCAST_CHANNEL_START` handler (lines 119-124), add `TB.ReelMode(true)` as the last line. It runs only for fishing spells.
- In the `UNIT_SPELLCAST_CHANNEL_STOP` handler (lines 125-136), add `TB.ReelMode(false)` right after `TB.StopCastBar()`.
- New handlers, next to line 58:

```lua
-- channel ended in combat: the key is still INTERACTTARGET; put it back once combat drops
TB.On("PLAYER_REGEN_ENABLED", function() if TB.reeling and not UnitChannelInfo("player") then TB.ReelMode(false) end end)
TB.On("PLAYER_LOGOUT", function() if TB.db then TB.RestoreCVars() end end) -- SVs save after logout fires, so the backup clears
```

#### 5. Slash commands + probe
**File**: `TackleBox/Core.lua:236-247`
**Action**: add branches before the final `else`, and update the help line.

```lua
  elseif cmd == "bind" then
    local key = TB.NormalizeKey((msg or ""):match("^%s*%S+%s+(.-)%s*$"))
    if not key then TB.Print("usage: /tb bind <KEY>, for example /tb bind F")
    elseif InCombatLockdown() then TB.Print("can't change the cast key in combat")
    elseif not TB.HasBindAPI() then TB.Print("one-key cast is unavailable on your client")
    else
      TB.db.castKey = key; TB.BindCast()
      TB.Print("cast key: " .. key .. ". If reeling in does nothing, turn on Enable Interact Key in the game's options.")
    end
  elseif cmd == "unbind" then
    if InCombatLockdown() then TB.Print("can't change the cast key in combat")
    else TB.db.castKey = nil; TB.BindCast(); TB.Print("cast key cleared") end
```

- The help line becomes `"/tb show||hide||lock||reset||probe||flash||bind <key>||unbind"`.
- In `TB.Probe()` (after the `combat` line, ~170), add: `P("override bindings", TB.HasBindAPI())` and `P("cast key", TB.db.castKey)`.

### Verification
#### Automated
- [x] `lua TackleBox/tests/run.lua` prints `all tests passed`, including the 4 key tests.
- [x] `lint.sh TackleBox` shows no warnings beyond the baseline of 29. There are no W113 warnings for the three binding names, because `.luacheckrc` is picked up.
- [x] Never-emit check: `grep -nE "(^|[^.:A-Za-z0-9_])(EquipItemByName|PickupContainerItem)\b" TackleBox/*.lua` prints nothing.
- [x] Deployed with robocopy.

#### Manual
- [ ] `/tb probe` prints `override bindings: true`. If it is false, stop: one-key cast is unavailable, and Phases 1-3 still ship.
- [ ] `/tb bind F` with the panel closed. F casts, F during the channel reels in the bobber and loots, and F casts again. Do it 5 times.
- [ ] Confirm no double cast (one press gives one cast). If it double-fires, set `caster:RegisterForClicks("AnyDown")` and re-test.
- [ ] During a channel, `/dump C_CVar.GetCVar("SoftTargetInteract")` gives `3`. After the channel it shows your original value again.
- [ ] `/reload` mid-channel. After login the CVars are back to the originals and F casts.
- [ ] Get attacked, then cast in combat. No Lua errors or blocked-action messages. After combat F casts again.
- [ ] `/tb unbind`, then F does its normal job again.
- [ ] After the probe confirms, ask the user before recording "override-binding API exists on Forever (build N)" in `D:\Source\wowskill\skills\wow-forever-addon\references\forever-api-notes.md` (separate repo).

---

## Phase 5: Docs + release

### Changes
#### 1. README
**File**: `TackleBox/README.md`
- `## The panel` (line 14): the plus/minus button collapses the tabs (remembered), the zone line and its colors, and rows scroll at 10 visible.
- `## Fishing bar` (line 28): the pole slot becomes "Equip weapons" while a pole is on; weapons are remembered per character from any non-pole main hand; it greys out when a weapon is not in bags; no swap in combat.
- New `## One-key cast` after `## Cast bar…`: `/tb bind <KEY>`, what the key does when no line is out and while the line is out, the "Enable Interact Key" option, CVars changed during the channel and restored, and known limits (interact can grab a nearby NPC or player, far bobbers may be out of soft-target range, no key swap when the cast starts in combat).
- `## Slash commands` (line 47): add `bind <key>` and `unbind`.
- `## Development` (line 69): the test command becomes `lua TackleBox/tests/run.lua`.

#### 2. Changelog + version
- **File:** `TackleBox/CHANGELOG.md`. Add `## [1.1.0] — <release date>` above 1.0.0, with `### Added` (one-key cast, weapon memory and re-equip, zone line, collapsible tabs) and `### Changed` (rows scroll; Catch list no longer cut off at 30).
- **File:** `TackleBox/TackleBox.toc:4`. `## Version: 1.1.0`. Interface stays `16001`.
- `docs/index.html:90`: no change. The entry is `{ dir, prefix }` only.

### Verification
#### Automated
- [ ] `lua TackleBox/tests/run.lua` prints `all tests passed`.
- [ ] `lint.sh TackleBox` shows no warnings beyond the baseline of 29.
- [ ] `grep -n "Version: 1.1.0" TackleBox/TackleBox.toc` matches, and `grep -n "1.1.0" TackleBox/CHANGELOG.md` matches.
- [ ] Deployed with robocopy.

#### Manual
- [ ] The `/tb` help output lists exactly the commands the README documents.
- [ ] The README renders on GitHub (headings and code blocks intact).
