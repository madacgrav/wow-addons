# Implementation Plan

## Overview
TackleBox 1.3.0: one **Camp** button on the fishing bar that places a campfire, then the best fishing camp item (Hut > Rack > Bowl), shows the shared 1 h camp cooldown, and crafts a camp item when none is owned. The Camp tab is driven by probe-confirmed data.

## Conventions (every phase)
- Lint: `bash D:/Source/wowskill/skills/wow-forever-addon/scripts/lint.sh D:/Source/wow-addons/TackleBox`. Baseline is 29 warnings / 0 errors; no new warnings.
- Tests: `lua D:/Source/wow-addons/TackleBox/tests/run.lua` prints `all tests passed` (Lua 5.1 syntax).
- Deploy after commit: `robocopy "D:\Source\wow-addons\TackleBox" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\TackleBox" /MIR /XD tests /NJH /NJS /NP /NDL` (exit 0-7 = ok; from Git Bash use `//MIR` style flags). User runs `/reload`.
- Branch `2026-11-23-tacklebox-camp-place-craft`. Commit only the files the phase names; never `git add` whole folders (other untracked work lives in `thoughts/`).
- Constraints:
  - Interface 16001.
  - No never-emit names; use `C_Container`, `C_Item`, `C_Spell`, `C_SpellBook`, `C_TradeSkillUI`.
  - API names used, all present in `forever-api-index.md` (research Q4/Q5):
    - `C_Container.GetItemCooldown`
    - `C_Spell.GetSpellCooldown`
    - `C_Item.GetItemSpell`
    - `C_SpellBook.IsSpellKnown`
    - `C_TradeSkillUI.GetRecipeInfo`, `CraftRecipe`, `OpenTradeSkill`
    - `C_UnitAuras.GetAuraDataByIndex`
    - events `BAG_UPDATE_COOLDOWN`, `SPELL_UPDATE_COOLDOWN`, `TRADE_SKILL_ITEM_CRAFTED_RESULT`, `UNIT_SPELLCAST_SUCCEEDED`
  - `CooldownFrameTemplate` must be grepped in `templates/luacheck/forever-std.lua` before use in Phase 4. If absent, draw the time as text on the button instead.
- Data provenance: every ID added to `Data.lua` traces to `probe-results.md` Run 7 or the existing DB2 rows (`probe-results.md:71-113`). Third-party values carry a source comment.

---

## Phase 1: Probe camp and crafting

### Changes

#### 1. Camp probe
**File**: `TackleBox/Core.lua`
**Action**: add after `TB.Probe` (before the slash handler)
```lua
-- probe run 7: camp items, campfire/camp buffs, cooldown source, recipe-known check, craft methods
local CAMP_PROBE = {
  items = { 279967, 279965, 279966, 279981, 279961, 279974 },   -- Bowl, Rack, Hut, campfire kits (Basic, Journeyman, Expert)
  recipes = { 1229745, 1262990, 1262998 },                     -- Bowl, Rack, Hut craft spells (probe-results.md:100-113)
  places = { 1307247, 1307246 },                               -- Rack, Hut placement spells
  words = { "Wood", "Steak", "Vial", "Runecloth", "Trout", "Smallfish", "Campfire", "Blueprint" },
}
function TB.CampProbe()
  TB.db.lastProbe = {}
  local function S(v) if TB.Secret(v) then return "SECRET" end return tostring(v) end
  local function P(k, v) local line = k .. ": " .. tostring(v); TB.Print(line); table.insert(TB.db.lastProbe, line) end
  local function Try(k, fn) local ok, err = pcall(fn); if not ok then P(k, "ERROR " .. tostring(err)) end end
  P("combat", InCombatLockdown())
  Try("auras", function()
    for i = 1, 40 do
      local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
      if not a then break end
      P("aura " .. i, S(a.spellId) .. " " .. S(a.name) .. " exp " .. S(a.expirationTime))
    end
  end)
  for _, id in ipairs(CAMP_PROBE.items) do
    Try("item" .. id, function()
      local s, d, e = C_Container.GetItemCooldown(id)
      local sn, sid = C_Item.GetItemSpell(id)
      P("item " .. id, (C_Item.GetItemNameByID(id) or "?") .. " n" .. C_Item.GetItemCount(id) .. " cd " .. S(s) .. "/" .. S(d) .. "/" .. S(e)
        .. " spell " .. tostring(sn) .. " " .. tostring(sid))
    end)
  end
  for _, id in ipairs(CAMP_PROBE.places) do
    Try("place" .. id, function()
      local c = C_Spell.GetSpellCooldown(id)
      P("place " .. id, c and (S(c.startTime) .. "/" .. S(c.duration)) or "nil")
    end)
  end
  for _, id in ipairs(CAMP_PROBE.recipes) do
    Try("recipe" .. id, function()
      local r = C_TradeSkillUI.GetRecipeInfo(id)
      P("recipe " .. id, "known " .. tostring(C_SpellBook.IsSpellKnown(id)) .. " info " .. (r and (tostring(r.name) .. " learned " .. tostring(r.learned)) or "nil"))
    end)
  end
  Try("bags", function()
    for bag = 0, NUM_BAG_SLOTS or 4 do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local it = C_Container.GetContainerItemInfo(bag, slot)
        if it and it.itemID then
          for _, w in ipairs(CAMP_PROBE.words) do
            if (it.itemName or ""):find(w, 1, true) then P("bag " .. it.itemID, it.itemName); break end
          end
        end
      end
    end
  end)
  local t0 = TB.trace[1] and TB.trace[1][1] or 0
  for _, e in ipairs(TB.trace) do P("trace", string.format("+%.2f %s %s", e[1] - t0, e[2], tostring(e[3] or ""))) end
end

-- temporary craft/place test buttons; removed in Phase 2
local testFrame
function TB.CampTestButtons()
  if InCombatLockdown() then return TB.Print("not in combat") end
  if testFrame then testFrame:SetShown(not testFrame:IsShown()) return end
  testFrame = CreateFrame("Frame", "TBCampTest", UIParent, "BackdropTemplate")
  testFrame:SetSize(330, 40); testFrame:SetPoint("CENTER", 0, 200); TB.Skin(testFrame, 12)
  local defs = {
    { "macro", function(b) b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", "/cast Fish Bowl") end },
    { "spell", function(b) b:SetAttribute("type", "spell"); b:SetAttribute("spell", 1229745) end },
    { "api", function(b) b:SetScript("PostClick", function() local ok, err = pcall(C_TradeSkillUI.CraftRecipe, 1229745); TB.Print("CraftRecipe " .. tostring(ok) .. " " .. tostring(err)) end) end },
    { "window", function(b) b:SetScript("PostClick", function() local ok, err = pcall(C_TradeSkillUI.OpenTradeSkill, 356); TB.Print("OpenTradeSkill " .. tostring(ok) .. " " .. tostring(err)) end) end },
    { "kit", function(b) b:SetAttribute("type", "item"); b:SetAttribute("item", "item:279981") end },
    { "bowl", function(b) b:SetAttribute("type", "item"); b:SetAttribute("item", "item:279967") end },
  }
  for i, d in ipairs(defs) do
    local b = CreateFrame("Button", "TBCampTest" .. i, testFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetSize(50, 24); b:SetPoint("LEFT", 6 + (i - 1) * 53, 0); b:SetText(d[1]); b:RegisterForClicks("AnyUp", "AnyDown")
    d[2](b)
  end
end
```
Trace hooks (next to the existing `Trace` users):
```lua
TB.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID) if unit == "player" then Trace("CAST_OK", TB.Secret(spellID) and "SECRET" or tostring(spellID)) end end)
TB.On("TRADE_SKILL_ITEM_CRAFTED_RESULT", function() Trace("CRAFTED") end)
TB.On("UI_ERROR_MESSAGE", function(_, msg) Trace("UI_ERR", TB.Secret(msg) and "SECRET" or tostring(msg)) end)
TB.On("BAG_UPDATE_COOLDOWN", function() Trace("BAG_CD") end)
```
- Slash commands: `elseif cmd == "camp" then if (msg or ""):lower():match("test") then TB.CampTestButtons() else TB.CampProbe() end`. Add `camp` to the help line.
- `UI_ERROR_MESSAGE`, `C_Item.GetItemNameByID` and the `UIPanelButtonTemplate` combo template: grep the index/std first. If `GetItemNameByID` is missing, use `(C_Item.GetItemInfo(id))`.

#### 2. Results
**File**: `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md`
**Action**: append "Run 7: camp" with the pasted lines and a conclusions list:
- campfire aura (id/name or none);
- Bowl/Rack/Hut buff auras;
- cooldown source (item cd non-zero after placing? spell cd?);
- recipe-known check that answers without the window;
- the craft method that produced CAST_OK/CRAFTED;
- placement mode (instant or cursor);
- reagent item IDs (Simple Wood, Seasonal Fish Steaks, Empty Vial, Crystal Vial, Raw Mithril Head Trout, Bolt of Runecloth).

### Verification
#### Automated
- [x] Lint clean
- [x] Tests pass

#### Manual
- [x] Deployed; `/reload` clean
- [x] `/tb camp` away from any campfire, with Fish Bowl + Basic Campfire Kit in bags
- [x] `/tb camp test`: click **kit** (places campfire? cursor?), then `/tb camp` while standing at the fire
- [x] Click **bowl**, wait 1 min seated, `/tb camp` (buff IDs, cooldowns)
- [x] With Bowl reagents (Raw Brilliant Smallfish + Empty Vial) and spare Bowl count noted: click **macro**, **spell**, **api**, **window** one at a time, `/tb camp` after each (Bowl count change + trace)
- [x] Results and conclusions recorded in probe-results.md Run 7
- [x] **Gate:** kit and bowl placement work from the secure item buttons. If not, stop and revisit the design.

---

## Phase 2: Camp data + Camp tab from probe facts

### Changes

#### 1. Remove test scaffolding
**File**: `TackleBox/Core.lua`. Delete `TB.CampTestButtons`, the `test` branch, and the `UI_ERROR_MESSAGE` / `BAG_UPDATE_COOLDOWN` trace hooks; keep `TB.CampProbe` and `/tb camp` as a read-only report.

#### 2. Data
**File**: `TackleBox/Data.lua`. Replace `campBuffs` (`Data.lua:85-89`) with:
```lua
-- fishing camp items, best first. item/recipe/skill: DB2 build 70450 (probe-results.md:71-113); aura/reagents: probe run 7.
-- third-party: reagents also per warcraft.wiki.gg Fish_Bowl / Fishing_Rack / Fishing_Hut
camp = {
  { key = "hut",  name = "Fishing Hut",  item = 279966, recipe = 1262998, skill = 300, aura = <run 7>,
    reagents = { { <Simple Wood>, 5 }, { 14048, 2 }, { <Seasonal Fish Steaks>, 1 } } },
  { key = "rack", name = "Fishing Rack", item = 279965, recipe = 1262990, skill = 140, aura = <run 7>,
    reagents = { { <Simple Wood>, 2 }, { 8925, 1 }, { 8365, 2 } } },
  { key = "bowl", name = "Fish Bowl",    item = 279967, recipe = 1229745, skill = 20,  aura = <run 7>,
    reagents = { { 6291, 1 }, { 3371, 1 } } },
},
-- campfire kits, best first (third-party IDs: wow-professions Forever camping guide); fire aura per run 7 (nil = none found)
campfires = { items = { 279974, 279961, 279981 }, aura = <run 7 or nil> },
campCooldown = "<item|spell per run 7>", -- which API shows the shared 1 h camp cooldown
campCraftMethod = "<macro|spell|api|window per run 7>",
```
- Replace each `<run 7>` placeholder with the probe value before committing.
- Classic reagent IDs (14048 Bolt of Runecloth, 8925 Crystal Vial, 8365 Raw Mithril Head Trout, 6291 Raw Brilliant Smallfish, 3371 Empty Vial) must match the run 7 bag lines or a `/dump C_Item.GetItemInfo(id)`. Correct any that differ.
- If a buff aura was not found, set `aura = nil` and the row shows only "available / needs skill".

#### 3. Logic
**File**: `TackleBox/Logic.lua`. Add:
```lua
-- reagents = { {id, n} }; returns true or false + the first short reagent id
function TB.CanCraft(reagents, counts)
  for _, r in ipairs(reagents) do if (counts[r[1]] or 0) < r[2] then return false, r[1] end end
  return true
end
```
Change `TB.CampRows(buffs, state, skill, subzone)` to `TB.CampRows(camp, state, skill, counts)`:
```lua
function TB.CampRows(camp, state, skill, counts)
  local rows, lvl = {}, skill and skill.level or 0
  for _, c in ipairs(camp) do
    local s = c.aura and state[c.aura]
    local active = s and s.active
    local sub, miss, ok
    if active then sub = s.remaining and (TB.FormatTime(s.remaining) .. " left") or "active"
    elseif lvl < c.skill then sub = "needs skill " .. c.skill
    elseif (counts[c.item] or 0) > 0 then sub = "in bags (" .. counts[c.item] .. ")"
    else
      ok, miss = TB.CanCraft(c.reagents, counts)
      sub = ok and "can craft" or ("missing item:" .. miss) -- panel swaps in the reagent name via r.missing
    end
    rows[#rows + 1] = { text = c.name, sub = sub, item = c.item, missing = miss, active = active, color = active and { 0.25, 0.75, 0.25 } or nil }
  end
  return rows
end
```

#### 4. Camp section
**File**: `TackleBox/Panel.lua` (`Panel.lua:331-337`).
- Drop `CAMP_ITEMS`.
- The build reads auras for each `c.aura`, then builds counts for `c.item` plus all reagent IDs via `C_Item.GetItemCount`, then calls `TB.CampRows(TB.DATA.camp, TB.auraState, TB.skill, counts)`.
- Each row: `r.icon = C_Item.GetItemIconByID(r.item)`, `r.itemID = r.item` (item tooltip).
- When `r.missing` is set, `r.sub = "missing " .. (TB.ItemName(r.missing))`.

#### 5. Tests
**File**: `TackleBox/tests/run.lua`. Replace the CampRows block (`tests/run.lua:63-67`):
```lua
local C = { { key = "hut", name = "Hut", item = 3, skill = 300, aura = 31, reagents = { { 9, 1 } } },
  { key = "bowl", name = "Bowl", item = 1, skill = 20, aura = 11, reagents = { { 7, 1 }, { 8, 1 } } } }
local cr = TB.CampRows(C, { [11] = { active = true, remaining = 65 } }, { level = 200 }, {})
eq(cr[1].sub, "needs skill 300", "camp below skill"); eq(cr[2].sub, "1:05 left", "camp timer")
cr = TB.CampRows(C, {}, { level = 200 }, { [1] = 2 }); eq(cr[2].sub, "in bags (2)", "camp in bags")
cr = TB.CampRows(C, {}, { level = 200 }, { [7] = 1, [8] = 1 }); eq(cr[2].sub, "can craft", "camp can craft")
cr = TB.CampRows(C, {}, { level = 200 }, { [7] = 1 }); eq(cr[2].missing, 8, "camp missing reagent")
cr = TB.CampRows(C, { [11] = { active = true } }, { level = 300 }, {}); eq(cr[2].sub, "active", "camp secret timer")
eq(TB.CanCraft({ { 1, 2 } }, { [1] = 2 }), true, "craft ok"); eq(select(2, TB.CanCraft({ { 1, 2 }, { 5, 1 } }, { [1] = 1 })), 1, "craft first missing")
eq(TB.CanCraft({}, {}), true, "no reagents")
```
- Add a data integrity loop: every `DATA.camp` entry has `item`, `recipe`, `skill` and reagent pairs.

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass (camp block, CanCraft, integrity)

#### Manual
- [ ] Deployed; `/reload`
- [ ] Camp tab: Hut/Rack/Bowl rows with item icons and tooltips; Bowl "in bags (n)" or "can craft"; Rack/Hut "needs skill" or "missing <name>"
- [ ] At a camp with Bowl placed: Bowl row shows the buff timer/active (if run 7 found the aura)

---

## Phase 3: Camp button: place campfire and camp item

### Changes

#### 1. Picker
**File**: `TackleBox/Logic.lua`
```lua
-- st = { skill, owned = {[item]=n}, buffs = {[key]=bool}, fireUp, fires = {kit items best first}, camp = DATA.camp, cooldown? }
-- returns action ("fire" | "place" | nil), item id, usable, need
function TB.CampPick(st)
  local lvl = st.skill and st.skill.level or 0
  for _, c in ipairs(st.camp) do if st.buffs[c.key] then return nil end end -- a camp buff is already up
  if not st.fireUp then
    for _, id in ipairs(st.fires) do if (st.owned[id] or 0) > 0 then return "fire", id, true end end
  end
  local locked
  for _, c in ipairs(st.camp) do
    if (st.owned[c.item] or 0) > 0 then
      if lvl >= c.skill then return "place", c.item, true, (not st.fireUp) and "Place near a campfire" or nil end
      locked = locked or c
    end
  end
  if locked then return "place", locked.item, false, "Requires Fishing " .. locked.skill end
end
```

#### 2. Fire detection + button
**File**: `TackleBox/Actions.lua`
- `ORDER = { "pole", "lure", "water", "camp", "cast" }`; `TIPS.camp = "Set up your fishing camp"`.
- Fire detection, `local function FireUp()`:
  - If `TB.DATA.campfires.aura` is set, return `TB.ReadAura(aura).active`.
  - Otherwise use the heuristic: `TB.lastFire` (set on `UNIT_SPELLCAST_SUCCEEDED` whose spell is `C_Item.GetItemSpell(kit)` for any kit; stores `{t, x, y, map}` from `TB.PlayerPos()`) is under 3600 s old, on the same map, and within 30 yd (via `TB.HBD:GetZoneDistance`).
- In the refresher, after water:
```lua
local st = { skill = TB.skill, owned = {}, buffs = {}, fireUp = FireUp(), fires = TB.DATA.campfires.items, camp = TB.DATA.camp }
for _, id in ipairs(st.fires) do st.owned[id] = C_Item.GetItemCount(id) end
for _, c in ipairs(TB.DATA.camp) do
  st.owned[c.item] = C_Item.GetItemCount(c.item)
  st.buffs[c.key] = c.aura and TB.ReadAura(c.aura).active or false
end
local action, id, ok, need = TB.CampPick(st)
if action then A.camp = { item = id, usable = ok, need = need, action = action } end
```
- `Apply`: add `elseif key == "camp" then b:SetAttribute("type", "item"); b:SetAttribute("item", "item:" .. a.item)` (before the spell `else`).
- `b.tip` for camp: `a.action == "fire" and "Place your campfire" or nil`.

#### 3. Tests
**File**: `TackleBox/tests/run.lua`
```lua
local CC = { { key = "hut", item = 3, skill = 300 }, { key = "bowl", item = 1, skill = 20 } }
local function CS(t) t.camp = CC; t.fires = { 50 }; t.owned = t.owned or {}; t.buffs = t.buffs or {}; return t end
local act, cid, cok = TB.CampPick(CS({ skill = { level = 100 }, owned = { [50] = 1, [1] = 1 } }))
eq(act, "fire", "camp fire first"); eq(cid, 50, "camp kit id")
act, cid = TB.CampPick(CS({ skill = { level = 100 }, owned = { [50] = 1, [1] = 1 }, fireUp = true })); eq(act, "place", "camp place"); eq(cid, 1, "camp bowl")
act, cid = TB.CampPick(CS({ skill = { level = 300 }, owned = { [1] = 1, [3] = 1 }, fireUp = true })); eq(cid, 3, "camp best by skill")
act, cid, cok = TB.CampPick(CS({ skill = { level = 100 }, owned = { [3] = 1 }, fireUp = true })); eq(cok, false, "camp locked")
eq(TB.CampPick(CS({ skill = { level = 100 }, owned = { [1] = 1 }, buffs = { bowl = true }, fireUp = true })), nil, "camp buff up")
eq(TB.CampPick(CS({ skill = { level = 100 } })), nil, "camp nothing owned")
```

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass (CampPick)

#### Manual
- [ ] Deployed; `/reload`
- [ ] With a kit and no fire: camp button shows the kit, click places the campfire (one click, or arm + click per run 7)
- [ ] Next to the fire: button switches to Fish Bowl; click places it; after the buff appears the button hides
- [ ] Bar order: pole, lure, water, camp, cast; no taint when entering/leaving combat (BugSack, `scriptErrors 1`)

---

## Phase 4: Cooldown display

### Changes
- **`Logic.lua`**:
```lua
-- start/duration in seconds (GetTime clock); nil when ready
function TB.CampCooldownText(start, duration, now)
  if not start or not duration or duration <= 1.5 then return nil end -- 1.5: ignore the global cooldown
  local left = start + duration - now
  if left <= 0 then return nil end
  return "camp ready in " .. TB.FormatTime(left)
end
```
- `CampPick`: when `st.cooldown` (text) is set and no buff is up, return `"cooldown", <first owned camp item or kit>, false, st.cooldown` **before** the fire/place checks. Return nil when nothing is owned.
- **`Actions.lua`** refresher reads the cooldown per `TB.DATA.campCooldown`:
  - `"item"`: `C_Container.GetItemCooldown(firstOwnedCampItem)`.
  - `"spell"`: `C_Spell.GetSpellCooldown(placeSpell)` → `.startTime`, `.duration`.
  - Guard with `TB.Secret`. Then `st.cooldown = TB.CampCooldownText(s, d, GetTime())` and keep `TB.campCD = {s, d}`.
- `MakeButton`: for key `camp`, create `b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")`, `b.cd:SetAllPoints(b.icon)` (only if the template is in the std; else a `b.cdText` font string).
- `Apply`: for camp, `if TB.campCD then b.cd:SetCooldown(TB.campCD[1], TB.campCD[2]) else b.cd:Clear() end`.
- **`Core.lua`**:
  - `TB.On("BAG_UPDATE_COOLDOWN", TB.Refresh)` (or `SPELL_UPDATE_COOLDOWN` per run 7).
  - The 1 s ticker condition also checks `TB.campCD and TB.campCD[1] + TB.campCD[2] > GetTime()`.
- **`Panel.lua`** Camp section: prepend a header row `{ header = true, text = st.cooldown or "camp ready" }`. Expose `TB.campCooldownText` from Actions for the panel.
- **Tests**:
```lua
eq(TB.CampCooldownText(100, 3600, 200), "camp ready in 58:20", "cd running"); eq(TB.CampCooldownText(100, 3600, 4000), nil, "cd done")
eq(TB.CampCooldownText(100, 1, 100.5), nil, "gcd ignored"); eq(TB.CampCooldownText(nil, nil, 0), nil, "no cd")
local ca = TB.CampPick(CS({ skill = { level = 100 }, owned = { [1] = 1 }, fireUp = true, cooldown = "camp ready in 1:00" }))
eq(ca, "cooldown", "cooldown beats place")
```

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass

#### Manual
- [ ] Deployed; `/reload`
- [ ] After placing a camp item: button greyed with swipe; tooltip "camp ready in M:SS"; Camp tab header shows the same
- [ ] `/reload` mid-cooldown: still shown
- [ ] When it ends: button returns to place/fire

---

## Phase 5: Camp button: craft

### Changes
- **`Logic.lua`**, at the end of `CampPick` (nothing owned is placeable):
```lua
for _, c in ipairs(st.camp) do
  if lvl >= c.skill and st.known[c.key] then
    local ok, miss = TB.CanCraft(c.reagents, st.counts)
    if ok then return "craft", c.item, true end
    st.short = st.short or { c = c, miss = miss }
  end
end
if st.short then return "craft", st.short.c.item, false, "missing item:" .. st.short.miss end
```
  The refresher replaces `item:N` with `TB.ItemName(N)`.
- **`Actions.lua`** refresher:
  - `st.counts`: counts for every reagent.
  - `st.known[c.key]`: use the run 7 known-check if one answered (`C_SpellBook.IsSpellKnown(c.recipe)`, or `C_TradeSkillUI.GetRecipeInfo(c.recipe).learned`). Otherwise use the heuristic: `c.key == "bowl"`, or the Blueprint (273141 Rack, 273119 Hut) is not in bags while skill ≥ unlock.
  - Add `blueprint` to the Rack/Hut data entries in Phase 2 if this heuristic is needed.
- **`Apply`** camp branch by `a.action`:
  - `"craft"` with `TB.DATA.campCraftMethod`:
    - `"macro"` → `type="macro"`, `macrotext="/cast " .. name`;
    - `"spell"` → `type="spell"`, `spell=c.recipe`;
    - `"api"` → `type=nil`, plus `b:SetScript("PostClick", function() if not InCombatLockdown() then C_TradeSkillUI.CraftRecipe(recipe) end end)`;
    - `"window"` → `type=nil`, PostClick `C_TradeSkillUI.OpenTradeSkill(356)`.
  - Non-craft actions clear PostClick (`b:SetScript("PostClick", nil)`).
  - The recipe/name come from `A.camp.recipe` / `A.camp.name`; the refresher looks up the `DATA.camp` entry by item.
- **Hammer badge**: `b.badge` texture `Interface\\Icons\\Trade_BlackSmithing` 14x14 at BOTTOMLEFT, shown only for craft.
- **Tooltip**: `b.tip = "Craft " .. name` for craft.
- **Tests**:
```lua
local CR = { { key = "bowl", item = 1, skill = 20, reagents = { { 7, 1 } } } }
local function CK(t) t.camp = CR; t.fires = {}; t.owned = t.owned or {}; t.buffs = {}; t.fireUp = true; t.known = t.known or { bowl = true }; t.counts = t.counts or {}; return t end
eq(TB.CampPick(CK({ skill = { level = 50 }, counts = { [7] = 1 } })), "craft", "craft when none owned")
eq(TB.CampPick(CK({ skill = { level = 50 }, owned = { [1] = 1 }, counts = { [7] = 1 } })), "place", "owned beats craft")
local _, _, kok, kneed = TB.CampPick(CK({ skill = { level = 50 } })); eq(kok, false, "craft missing"); eq(kneed, "missing item:7", "craft missing text")
eq(TB.CampPick(CK({ skill = { level = 50 }, known = {}, counts = { [7] = 1 } })), nil, "craft unknown recipe")
```
- Update the Phase 3/4 `CS` helper to set `known = {}` and `counts = {}`.

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass

#### Manual
- [ ] Deployed; `/reload`
- [ ] No Fish Bowl, reagents in bags: camp button shows Bowl with hammer badge; click crafts (or opens Fishing with Create ready for the window method); the button then switches to place
- [ ] Missing a reagent: greyed, tooltip names it
- [ ] In combat: click does nothing harmful, no taint

---

## Phase 6: Docs and release 1.3.0

### Changes
- **`TackleBox/TackleBox.toc`**: `## Version: 1.3.0`.
- **`TackleBox/CHANGELOG.md`**: `## [1.3.0]`:
  - camp button: campfire, place, craft, cooldown;
  - Camp tab: can craft / missing / in bags, cooldown line, confirmed buff IDs;
  - `/tb camp` report.
- **`TackleBox/README.md`**:
  - Fishing bar table: Camp row (shows when / click, campfire first, cooldown, craft method per run 7).
  - Camp tab row update.
  - Commands: `/tb camp`.
  - Notes: camp items need a campfire; shared 1 h cooldown.
- **`README.md`** (root): add "camp" to the TackleBox line.

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass
- [ ] README commands match the `/tb` help line

#### Manual
- [ ] Deployed; `/tb` with an unknown word prints help matching the README
