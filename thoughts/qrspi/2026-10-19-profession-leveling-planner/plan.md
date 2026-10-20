# Implementation Plan

## Overview
New standalone addon `ProfessionPlanner/`, namespace `PP`. It adds a panel docked to `ProfessionsFrame` for Tailoring, Enchanting, Leatherworking and Alchemy. The panel shows:
- the next 3 greedy-cheapest crafting steps toward the next skill bracket;
- a shopping list (bags + cached bank, with vendor prices);
- skill-up thresholds learned from observed color changes.

The addon also has `/pp probe` and its own CI release (`pp-v<version>`).

## Conventions
- **Branch:** work on `profession-planner` (created from `main`), one commit per phase.
- **No sharing with WarlockUtilityKit:** copy patterns, never require its files.
- **Namespace:** every file starts with `local ADDON, PP = ...`.
- **Pure logic** lives only in `Logic.lua`, tested by `ProfessionPlanner/tests/run.lua`. Code must run under Lua 5.1 and 5.4.
- **Test command (repo root):** `lua ProfessionPlanner/tests/run.lua` must print `all tests passed`. Lua is at `C:\Users\madac\AppData\Local\Programs\Lua\bin`, so add it to PATH in PowerShell.
- **Syntax check:** `lua -e "assert(loadfile([[<file>]]))"` for every `.lua` file.
- **Deploy after every phase**, before the in-game check (robocopy exit codes 0–7 mean success):
  ```powershell
  robocopy "D:\Source\wow-addons\ProfessionPlanner" "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\ProfessionPlanner" /MIR /XD tests /NJH /NJS /NP /NDL
  ```
- **Money:** copper integers, displayed with Blizzard's `GetCoinTextureString(copper)`. `UNKNOWN_COST = 10000` (1g per reagent unit).

---

## Phase 1: Skeleton, probe, CI

### Changes

#### 1. TOC
**File**: `ProfessionPlanner/ProfessionPlanner.toc`
**Action**: create
```
## Interface: 16001
## Title: Profession Planner
## Notes: Docked leveling planner and shopping list for the profession window.
## Version: 0.1.0
## IconTexture: Interface\Icons\Trade_Tailoring
## SavedVariables: ProfessionPlannerDB
## SavedVariablesPerCharacter: ProfessionPlannerCharDB

Logic.lua
Core.lua
```

#### 2. Pure logic (start)
**File**: `ProfessionPlanner/Logic.lua`
**Action**: create
```lua
local ADDON, PP = ...

function PP.MergeDefaults(sv, defaults)
  if type(sv) ~= "table" then sv = {} end
  for k, v in pairs(defaults) do
    if type(v) == "table" then sv[k] = PP.MergeDefaults(sv[k], v)
    elseif sv[k] == nil then sv[k] = v end
  end
  return sv
end
```

#### 3. Core
**File**: `ProfessionPlanner/Core.lua`
**Action**: create
```lua
local ADDON, PP = ...

PP.inits, PP.refreshers = {}, {}
function PP.Secret(v) return issecretvalue ~= nil and issecretvalue(v) end
function PP.Print(msg) print("|cff66ccffPP|r " .. tostring(msg)) end

local events, handlers = CreateFrame("Frame"), {}
function PP.On(event, fn)
  if not handlers[event] then handlers[event] = {}; events:RegisterEvent(event) end
  table.insert(handlers[event], fn)
end
events:SetScript("OnEvent", function(_, event, ...) for _, fn in ipairs(handlers[event]) do fn(...) end end)

function PP.Refresh() for _, fn in ipairs(PP.refreshers) do fn() end end

PP.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  -- nil-safe: the Forever beta loader bug can leave these nil
  ProfessionPlannerDB = PP.MergeDefaults(ProfessionPlannerDB, { thresholds = {}, prices = {} })
  ProfessionPlannerCharDB = PP.MergeDefaults(ProfessionPlannerCharDB, { recipes = {}, bank = {}, skill = {} })
  PP.db, PP.char = ProfessionPlannerDB, ProfessionPlannerCharDB
end)
PP.On("PLAYER_LOGIN", function() for _, init in ipairs(PP.inits) do init() end end)
```

Probe (prints facts for the open profession window):
```lua
function PP.Probe()
  local function P(k, v) PP.Print(k .. ": " .. tostring(v)) end
  local ready = C_TradeSkillUI.IsTradeSkillReady()
  P("tradeskill ready", ready)
  if ready then
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    if info then P("profession", tostring(info.professionID) .. " " .. tostring(info.professionName)
      .. " " .. tostring(info.skillLevel) .. "/" .. tostring(info.maxSkillLevel)) end
    local ids, learned, shown = C_TradeSkillUI.GetAllRecipeIDs(), 0, 0
    for _, id in ipairs(ids) do
      local ri = C_TradeSkillUI.GetRecipeInfo(id)
      if ri and ri.learned then
        learned = learned + 1
        if shown < 5 then
          shown = shown + 1
          local sch = C_TradeSkillUI.GetRecipeSchematic(id, false)
          local slot = sch and sch.reagentSlotSchematics and sch.reagentSlotSchematics[1]
          local rg = slot and slot.reagents and slot.reagents[1]
          P("  " .. tostring(ri.name), "diff=" .. tostring(ri.relativeDifficulty) .. " maxTrivial=" .. tostring(ri.maxTrivialLevel)
            .. " skillUps=" .. tostring(ri.numSkillUps) .. " qtyMin=" .. tostring(sch and sch.quantityMin)
            .. " reagent=" .. tostring(rg and rg.itemID) .. "x" .. tostring(slot and slot.quantityRequired)
            .. " type=" .. tostring(slot and slot.reagentType))
          if shown == 1 and rg and rg.itemID then
            P("  count bags/bank", C_Item.GetItemCount(rg.itemID) .. "/" .. C_Item.GetItemCount(rg.itemID, true))
          end
        end
      end
    end
    P("recipes", #ids .. " total, " .. learned .. " learned")
  end
  local tab = Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
  P("CharacterBankTab_1", tostring(tab) .. " slots=" .. tostring(tab and C_Container.GetContainerNumSlots(tab)))
  P("ReagentBag", tostring(Enum.BagIndex and Enum.BagIndex.ReagentBag))
end

SLASH_PROFESSIONPLANNER1 = "/pp"
SlashCmdList.PROFESSIONPLANNER = function(msg)
  local cmd = (msg or ""):lower():match("^(%S*)")
  if cmd == "probe" then PP.Probe()
  else PP.Print("/pp probe") end
end
```

#### 4. Tests
**File**: `ProfessionPlanner/tests/run.lua`
**Action**: create. Same header as WUK's `tests/run.lua:1-7`, with `PP` in place of `WUK`.
```lua
local dir = ((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
local PP = {}
assert(loadfile(dir .. "/Logic.lua"))("ProfessionPlanner", PP)
local function eq(got, want, label)
  if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end

-- Phase 1
local sv = PP.MergeDefaults(nil, { a = 1, t = { b = 2 } }); eq(sv.t.b, 2, "merge nested")
sv = PP.MergeDefaults({ a = 5 }, { a = 1 }); eq(sv.a, 5, "keep existing")

print("all tests passed")
```

#### 5. CI
**File**: `.github/workflows/package-pp.yml`
**Action**: create. Copy `.github/workflows/package-wuk.yml` and change only these strings:

| Field | Value |
|---|---|
| name | `Package Profession Planner` |
| paths | `"ProfessionPlanner/**"`, `".github/workflows/package-pp.yml"` |
| test | `lua5.1 ProfessionPlanner/tests/run.lua` |
| version | `sed` on `ProfessionPlanner/ProfessionPlanner.toc` |
| zip | `ProfessionPlanner-<v>.zip ProfessionPlanner -x 'ProfessionPlanner/tests/*'` |
| `TAG` | `pp-v<v>` |
| `ZIP` | `ProfessionPlanner-<v>.zip` |
| title | `"Profession Planner $TAG"` |

### Verification
#### Automated
- [x] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`
- [x] Every `.lua` file passes the syntax check
- [x] `package-pp.yml` contains no `WarlockUtilityKit` or `wuk` strings (`grep -ci "warlock\|wuk" .github/workflows/package-pp.yml` prints 0)

#### Manual
- [x] Deployed to AddOns with robocopy
- [x] The addon list shows "Profession Planner"; no Lua errors at login
- [x] With Tailoring open, `/pp probe` prints the profession ID (expect 197), 5 recipes with `diff`, `maxTrivial`, `reagent` and `type`, and bag/bank counts
- [x] (Enchanting 333 confirmed; LW/Alchemy not owned, unverified) Repeat for Enchanting (expect 333), Leatherworking (165) and Alchemy (171)
- [x] With the bank open, the `CharacterBankTab_1` line shows slots > 0
- [x] Save the output to `thoughts/qrspi/2026-10-19-profession-leveling-planner/probe-results.md`. Correct `PP.PROFESSIONS` IDs and the Basic reagent type in Phase 2 if they differ.

---

## Phase 2: Recipe scan + docked panel

### Changes

#### 1. Logic
**File**: `ProfessionPlanner/Logic.lua`
**Action**: modify (append)
```lua
PP.PROFESSIONS = { [197] = "Tailoring", [333] = "Enchanting", [165] = "Leatherworking", [171] = "Alchemy" }
PP.COLOR = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "grey" }
PP.RANK = { orange = 0, yellow = 1, green = 2, grey = 3 }
-- ponytail: guessed skill-up odds (no official formula); only used to rank recipes, plan re-runs every craft
PP.CHANCE = { orange = 1, yellow = 0.6, green = 0.25, grey = 0 }
PP.BRACKETS = { 75, 150, 225, 300 }

function PP.NextBracket(skill, maxSkill)
  for _, b in ipairs(PP.BRACKETS) do
    if b > skill then return math.min(b, maxSkill or b) end
  end
  return maxSkill or 300
end
```

#### 2. Scan
**File**: `ProfessionPlanner/Core.lua`
**Action**: modify. Add `PP.ScanProfession()`, plus events.
```lua
local BASIC = (Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1

function PP.ScanProfession()
  if not C_TradeSkillUI.IsTradeSkillReady() then return end
  local info = C_TradeSkillUI.GetBaseProfessionInfo()
  local prof = info and info.professionID
  if not prof or not PP.PROFESSIONS[prof] then PP.current = nil; return end
  PP.current = prof
  PP.char.skill[prof] = { skill = info.skillLevel, max = info.maxSkillLevel }
  local cache = PP.char.recipes[prof] or {}
  PP.char.recipes[prof] = cache
  local prevColors, curColors = {}, {}
  for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
    local ri = C_TradeSkillUI.GetRecipeInfo(id)
    if ri and ri.learned then
      local r = cache[id]
      if not r then -- reagents never change: fetch the schematic once
        r = { name = ri.name, icon = ri.icon, reagents = {} }
        local sch = C_TradeSkillUI.GetRecipeSchematic(id, false)
        if sch then
          r.qtyMin = sch.quantityMin
          for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
            local rg = slot.reagents and slot.reagents[1]
            if slot.reagentType == BASIC and rg and rg.itemID then
              r.reagents[#r.reagents + 1] = { itemID = rg.itemID, qty = slot.quantityRequired }
            end
          end
        end
        cache[id] = r
      end
      prevColors[id] = r.color
      r.learned = true
      r.color = PP.COLOR[ri.relativeDifficulty] or "grey"
      curColors[id] = r.color
      r.maxTrivial = ri.maxTrivialLevel -- used in Phase 4
    end
  end
  PP.lastScan = { prof = prof, skill = info.skillLevel, prev = prevColors, cur = curColors } -- Phase 4 learns from this
end
```
Inside an init:
```lua
table.insert(PP.inits, function()
  local function Update() PP.ScanProfession(); PP.Refresh() end
  PP.On("TRADE_SKILL_SHOW", Update)
  PP.On("TRADE_SKILL_LIST_UPDATE", Update)
  PP.On("TRADE_SKILL_CLOSE", function() PP.current = nil; PP.Refresh() end)
end)
```

#### 3. Panel
**File**: `ProfessionPlanner/Panel.lua`
**Action**: create. The frame is created lazily on the first refresh where `ProfessionsFrame` exists.
```lua
local ADDON, PP = ...
local MAX_ROWS = 16
local panel

local function Build()
  panel = CreateFrame("Frame", "PPPanel", ProfessionsFrame, "BasicFrameTemplateWithInset")
  panel:SetWidth(260)
  panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 2, 0)
  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  panel.title:SetPoint("TOP", 0, -5); panel.title:SetText("Profession Planner")
  panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.header:SetPoint("TOPLEFT", 12, -30); panel.header:SetJustifyH("LEFT")
  panel.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(236, 28); row:SetPoint("TOPLEFT", 12, -50 - (i - 1) * 30)
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(24, 24); row.icon:SetPoint("LEFT")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0); row.text:SetWidth(200); row.text:SetJustifyH("LEFT")
    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2); row.sub:SetWidth(200); row.sub:SetJustifyH("LEFT")
    panel.rows[i] = row
  end
end

local COLORS = { orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 }, green = { 0.25, 0.75, 0.25 }, grey = { 0.5, 0.5, 0.5 } }

-- view = { header = string, rows = { {icon, text, sub, color?} } }
function PP.RenderPanel(view)
  if not view then if panel then panel:Hide() end return end
  if not panel then Build() end
  panel.header:SetText(view.header)
  local n = math.min(#view.rows, MAX_ROWS)
  for i, row in ipairs(panel.rows) do
    local v = view.rows[i]
    row:SetShown(v ~= nil)
    if v then
      row.icon:SetTexture(v.icon or 134400)
      row.text:SetText(v.text)
      local c = COLORS[v.color] or { 1, 1, 1 }
      row.text:SetTextColor(c[1], c[2], c[3])
      row.sub:SetText(v.sub or "")
    end
  end
  panel:SetHeight(60 + n * 30)
  panel:Show()
end
```
Phase 2 view refresher (Phase 3 replaces it): learned recipes that aren't grey, sorted by color rank then name.
```lua
table.insert(PP.refreshers, function()
  if not PP.current or not (ProfessionsFrame and ProfessionsFrame:IsShown()) then return PP.RenderPanel(nil) end
  local s, rows = PP.char.skill[PP.current], {}
  for _, r in pairs(PP.char.recipes[PP.current]) do
    if r.learned and r.color ~= "grey" then rows[#rows + 1] = { icon = r.icon, text = r.name, sub = r.color, color = r.color } end
  end
  table.sort(rows, function(a, b) if a.color ~= b.color then return PP.RANK[a.color] < PP.RANK[b.color] end return a.text < b.text end)
  PP.RenderPanel({ header = PP.PROFESSIONS[PP.current] .. "  " .. s.skill .. " → " .. PP.NextBracket(s.skill, s.max), rows = rows })
end)
```
Hiding: `TRADE_SKILL_CLOSE` triggers a refresh with `PP.current = nil`. As a safety net, the panel is parented to `ProfessionsFrame`, so it hides with it.

TOC: add `Panel.lua` after `Core.lua`.

#### 4. Tests
Append before `print`:
```lua
-- Phase 2
eq(PP.NextBracket(0, 75), 75, "0->75"); eq(PP.NextBracket(75, 150), 150, "75->150")
eq(PP.NextBracket(87, 300), 150, "87->150"); eq(PP.NextBracket(140, 75), 75, "capped by max")
eq(PP.NextBracket(299, 300), 300, "299->300"); eq(PP.NextBracket(300, 300), 300, "at cap")
eq(PP.COLOR[0], "orange", "color 0"); eq(PP.CHANCE.yellow, 0.6, "yellow chance")
```

### Verification
#### Automated
- [x] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`
- [x] Every `.lua` file passes the syntax check

#### Manual
- [x] Deployed to AddOns with robocopy
- [x] Opening Tailoring shows the panel at the right edge of the profession window, with header "Tailoring N → bracket" and orange recipes listed first
- [x] After a craft, colors and order update
- [x] Cooking or First Aid show no panel; closing the window hides the panel

---

## Phase 3: Inventory, prices, planner, shopping list

### Changes

#### 1. Pure planner
**File**: `ProfessionPlanner/Logic.lua`
**Action**: modify (append)

```lua
local function copy(t) local c = {}; for k, v in pairs(t or {}) do c[k] = v end; return c end

-- color at `skill`, walking known thresholds from the current color; nil if any needed threshold is unknown
function PP.ProjectColor(th, curColor, curSkill, skill)
  if skill == curSkill then return curColor end
  if not th then return nil end
  local order, c = { "orange", "yellow", "green", "grey" }, curColor
  for i = PP.RANK[curColor] + 2, 4 do
    local t = th[order[i]]
    if not t then return nil end
    if skill >= t then c = order[i] else break end
  end
  return c
end

-- skill at which `color` turns worse, if known
function PP.NextThreshold(th, color, skill)
  local nextColor = ({ orange = "yellow", yellow = "green", green = "grey" })[color]
  local t = th and nextColor and th[nextColor]
  if t and t > skill then return t end
  return nil
end

-- cost of `crafts` crafts; owned reagents are free and consumed from `have` (mutated)
local function CraftCost(r, crafts, have, prices, unknownCost)
  local cost = 0
  for _, rg in ipairs(r.reagents) do
    local need = rg.qty * crafts
    local use = math.min(have[rg.itemID] or 0, need)
    have[rg.itemID] = (have[rg.itemID] or 0) - use
    cost = cost + (need - use) * (prices[rg.itemID] or unknownCost)
  end
  return cost
end

-- s = { skill, target, recipes={[id]=r}, have={[itemID]=n}, prices={[itemID]=copper}, thresholds={[id]=th}, unknownCost }
-- ponytail: greedy cheapest-per-point, 3 steps; DP over skill points if plans look poor
function PP.Plan(s)
  local steps, skill, have = {}, s.skill, copy(s.have)
  while #steps < 3 and skill < s.target do
    local best, bestScore, bestColor
    for pass = 1, 2 do -- pass 1 orange/yellow, pass 2 green only if nothing else
      for id, r in pairs(s.recipes) do
        local c = r.learned and PP.ProjectColor(s.thresholds[id], r.color, s.skill, skill)
        if c and ((pass == 1 and (c == "orange" or c == "yellow")) or (pass == 2 and c == "green")) then
          local score = CraftCost(r, 1, copy(have), s.prices, s.unknownCost) / PP.CHANCE[c]
          if not best or score < bestScore or (score == bestScore and id < best) then best, bestScore, bestColor = id, score, c end
        end
      end
      if best then break end
    end
    if not best then break end
    local r = s.recipes[best]
    local nextT = PP.NextThreshold(s.thresholds[best], bestColor, skill)
    local toSkill = math.min(nextT or s.target, s.target)
    local crafts = math.ceil((toSkill - skill) / PP.CHANCE[bestColor])
    steps[#steps + 1] = { recipeID = best, name = r.name, icon = r.icon, color = bestColor, crafts = crafts,
      toSkill = nextT and toSkill or nil, untilColorChange = (not nextT) or nil,
      cost = CraftCost(r, crafts, have, s.prices, s.unknownCost) }
    if not nextT then break end -- unknown how long this color lasts; stop projecting
    skill = toSkill
  end
  return steps
end

function PP.ShoppingList(steps, recipes, have, prices)
  local need = {}
  for _, st in ipairs(steps) do
    for _, rg in ipairs(recipes[st.recipeID].reagents) do need[rg.itemID] = (need[rg.itemID] or 0) + rg.qty * st.crafts end
  end
  local out = {}
  for id, n in pairs(need) do
    local h = have[id] or 0
    out[#out + 1] = { itemID = id, need = n, have = h, buy = math.max(0, n - h), unitPrice = prices[id] }
  end
  table.sort(out, function(a, b) if a.buy ~= b.buy then return a.buy > b.buy end return a.itemID < b.itemID end)
  return out
end
```
Notes on the planner:
- When no next threshold is known, `untilColorChange` is true. The step's crafts then cover up to the target bracket, which is the worst case; the panel labels it "until color changes".
- Deviation from structure.md: `ProjectColor` and `NextThreshold` move here from Phase 4, because `Plan` needs them. Without thresholds they return nil or the current color, so Phase 3 behaves as specified. Phase 4 adds only learning.

#### 2. Inventory + prices
**File**: `ProfessionPlanner/Core.lua`
**Action**: modify
```lua
local function ScanContainers(first, last, into)
  for bag = first, last do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then into[info.itemID] = (into[info.itemID] or 0) + (info.stackCount or 1) end
    end
  end
  return into
end

function PP.Have()
  local have = ScanContainers(0, (Enum.BagIndex and Enum.BagIndex.ReagentBag) or NUM_BAG_SLOTS or 4, {})
  for id, n in pairs(PP.char.bank) do have[id] = (have[id] or 0) + n end
  return have
end

local bankOpen = false
local function ScanBank()
  if not bankOpen or not Enum.BagIndex then return end
  local bank = {}
  for i = 1, 9 do
    local bag = Enum.BagIndex["CharacterBankTab_" .. i]
    if bag then ScanContainers(bag, bag, bank) end
  end
  PP.char.bank = bank
end

local function ScanMerchant()
  for i = 1, GetMerchantNumItems() do
    local id, info = GetMerchantItemID(i), C_MerchantFrame.GetItemInfo(i)
    if id and info and info.price and info.price > 0 and not info.hasExtendedCost then
      PP.db.prices[id] = info.price / math.max(1, info.stackCount or 1)
    end
  end
end
```
Events in the init:
- `BANKFRAME_OPENED`: set `bankOpen = true`, then `ScanBank()` and `PP.Refresh()`.
- `BANKFRAME_CLOSED`: set `bankOpen = false`.
- `PLAYERBANKSLOTS_CHANGED` and `BAG_UPDATE_DELAYED`: `ScanBank()` then `PP.Refresh()`.
- `MERCHANT_SHOW`: `ScanMerchant()` then `PP.Refresh()`.

#### 3. Panel view
**File**: `ProfessionPlanner/Panel.lua`
**Action**: modify. Replace the Phase 2 refresher.
```lua
local UNKNOWN_COST = 10000
local function ItemName(id, onLoad)
  local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
  if not name then Item:CreateFromItemID(id):ContinueOnItemLoad(onLoad) end
  return name or ("item:" .. id), icon or C_Item.GetItemIconByID(id)
end

local pending = false
local function Rerender() if not pending then pending = true; C_Timer.After(0.1, function() pending = false; PP.Refresh() end) end end

table.insert(PP.refreshers, function()
  if not PP.current or not (ProfessionsFrame and ProfessionsFrame:IsShown()) then return PP.RenderPanel(nil) end
  local s = PP.char.skill[PP.current]
  local target = PP.NextBracket(s.skill, s.max)
  local recipes, have = PP.char.recipes[PP.current], PP.Have()
  local steps = PP.Plan({ skill = s.skill, target = target, recipes = recipes, have = have,
    prices = PP.db.prices, thresholds = PP.db.thresholds, unknownCost = UNKNOWN_COST })
  local rows = {}
  for _, st in ipairs(steps) do
    local goal = st.toSkill and ("→ " .. st.toSkill) or (st.untilColorChange and "(until color changes)") or ("→ " .. target)
    rows[#rows + 1] = { icon = st.icon, text = "×" .. st.crafts .. " " .. st.name, sub = goal .. "   " .. GetCoinTextureString(math.floor(st.cost)), color = st.color }
  end
  if #steps == 0 then rows[#rows + 1] = { text = "No recipe gives skill-ups here", sub = "train new recipes" } end
  for _, it in ipairs(PP.ShoppingList(steps, recipes, have, PP.db.prices)) do
    local name, icon = ItemName(it.itemID, Rerender)
    local sub = it.have .. "/" .. it.need
    if it.buy > 0 then sub = sub .. "   buy " .. it.buy .. (it.unitPrice and (" @ " .. GetCoinTextureString(math.floor(it.unitPrice))) or "") end
    rows[#rows + 1] = { icon = icon, text = name, sub = sub }
  end
  PP.RenderPanel({ header = PP.PROFESSIONS[PP.current] .. "  " .. s.skill .. " → " .. target, rows = rows })
end)
```

#### 4. Tests
Append before `print`:
```lua
-- Phase 3
local R = {
  [1] = { learned = true, color = "orange", name = "Pricey", reagents = { { itemID = 10, qty = 1 } } },
  [2] = { learned = true, color = "yellow", name = "Cheap", reagents = { { itemID = 11, qty = 1 } } },
  [3] = { learned = true, color = "green", name = "Greeny", reagents = { { itemID = 12, qty = 1 } } },
}
local function S(o) local s = { skill = 50, target = 75, recipes = R, have = {}, prices = { [10] = 1000, [11] = 100, [12] = 1 }, thresholds = {}, unknownCost = 10000 }
  for k, v in pairs(o or {}) do s[k] = v end; return s end
local st = PP.Plan(S())
eq(st[1].recipeID, 2, "cheaper per point wins (100/0.6 < 1000/1)"); eq(#st, 1, "stops when threshold unknown")
eq(st[1].untilColorChange, true, "until color change"); eq(st[1].crafts, math.ceil(25 / 0.6), "crafts to target worst case")
st = PP.Plan(S({ have = { [10] = 99 } })); eq(st[1].recipeID, 1, "owned reagents make it free")
st = PP.Plan(S({ recipes = { [3] = R[3] } })); eq(st[1].recipeID, 3, "green used when nothing else")
eq(PP.Plan(S({ skill = 75 }))[1], nil, "at target no steps")
local th = { [2] = { green = 60, grey = 70 } }
st = PP.Plan(S({ thresholds = th }))
eq(st[1].toSkill, 60, "yellow until 60"); eq(st[1].crafts, math.ceil(10 / 0.6), "crafts to threshold")
eq(PP.ProjectColor(th[2], "yellow", 50, 65), "green", "project green"); eq(PP.ProjectColor(nil, "orange", 50, 60), nil, "unknown")
eq(PP.NextThreshold(th[2], "green", 60), 70, "green->grey at 70")
local list = PP.ShoppingList({ { recipeID = 2, crafts = 3 }, { recipeID = 2, crafts = 2 } }, R, { [11] = 1 }, { [11] = 100 })
eq(list[1].need, 5, "sums steps"); eq(list[1].buy, 4, "minus have"); eq(list[1].unitPrice, 100, "price")
```

### Verification
#### Automated
- [x] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`
- [x] Every `.lua` file passes the syntax check

#### Manual
- [x] Deployed to AddOns with robocopy
- [ ] Tailoring shows "×N Recipe (until color changes)" plus a cost, and shopping rows with have/need matching your bags
- [ ] After visiting the bank, the "have" counts include bank items
- [ ] After visiting a trade-goods vendor, thread/dye prices appear and the step ranking accounts for them
- [ ] Crafting updates the plan

---

## Phase 4: Threshold learning

### Changes

#### 1. Pure learning
**File**: `ProfessionPlanner/Logic.lua`
**Action**: modify (append)
```lua
-- record the skill at which a recipe moved to a worse color; keep the lowest observation
function PP.LearnThresholds(th, prev, cur, skill)
  local changed = false
  for id, c in pairs(cur) do
    local p = prev[id]
    if p and PP.RANK[c] and PP.RANK[p] and PP.RANK[c] > PP.RANK[p] then
      th[id] = th[id] or {}
      if not th[id][c] or skill < th[id][c] then th[id][c] = skill; changed = true end
    end
  end
  return changed
end

function PP.LearnGrey(th, id, maxTrivial)
  if type(maxTrivial) == "number" and maxTrivial > 0 then
    th[id] = th[id] or {}
    if not th[id].grey or maxTrivial < th[id].grey then th[id].grey = maxTrivial; return true end
  end
  return false
end
```

#### 2. Wire into the scan
**File**: `ProfessionPlanner/Core.lua`
**Action**: modify. At the end of `ScanProfession`:
```lua
PP.LearnThresholds(PP.db.thresholds, prevColors, curColors, info.skillLevel)
for id, r in pairs(cache) do PP.LearnGrey(PP.db.thresholds, id, r.maxTrivial) end
```
Remove the `PP.lastScan` line added in Phase 2; it is no longer needed.

#### 3. Panel
**File**: `ProfessionPlanner/Panel.lua`
**Action**: modify
- The header gains a second line, `"N thresholds learned"`, counting `PP.db.thresholds` entries for recipes of the current profession.
- Steps whose `toSkill` comes from a learned threshold get a `" ✓"` suffix in `sub`. A plain `*` is used if the font lacks the glyph.

#### 4. Tests
Append before `print`:
```lua
-- Phase 4
local T = {}
eq(PP.LearnThresholds(T, { [5] = "orange" }, { [5] = "yellow" }, 112), true, "learn yellow"); eq(T[5].yellow, 112, "yellow=112")
PP.LearnThresholds(T, { [5] = "orange" }, { [5] = "yellow" }, 110); eq(T[5].yellow, 110, "lower replaces")
PP.LearnThresholds(T, { [5] = "orange" }, { [5] = "yellow" }, 120); eq(T[5].yellow, 110, "higher ignored")
eq(PP.LearnThresholds(T, { [5] = "yellow" }, { [5] = "yellow" }, 130), false, "same color no change")
eq(PP.LearnThresholds(T, { [6] = nil }, { [6] = "green" }, 130), false, "first sighting no change")
eq(PP.LearnGrey(T, 7, 150), true, "grey from maxTrivial"); eq(T[7].grey, 150, "grey=150"); eq(PP.LearnGrey(T, 8, 0), false, "zero ignored")
local th3 = { [2] = { green = 60, grey = 70 }, [1] = { yellow = 55, green = 65, grey = 75 } }
local p3 = PP.Plan(S({ thresholds = th3, prices = { [10] = 50, [11] = 100 } }))
eq(#p3 >= 2, true, "multi-step with thresholds"); eq(p3[1].toSkill ~= nil, true, "step has toSkill")
```

### Verification
#### Automated
- [ ] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`
- [ ] Every `.lua` file passes the syntax check

#### Manual
- [ ] Deployed to AddOns with robocopy
- [ ] Craft an orange recipe until it turns yellow; that step then shows "→ S ✓" for the yellow→green transition once that is learned too, and the header count increases
- [ ] Thresholds survive `/reload`, and an alt with the same recipe sees them
- [ ] If the probe showed `maxTrivial` populated, grey thresholds appear immediately for all learned recipes

---

## Final checks
- [ ] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`
- [ ] `lua WarlockUtilityKit/tests/run.lua` still passes (untouched)
- [ ] `git status` shows changes only under `ProfessionPlanner/`, `.github/workflows/package-pp.yml` and `thoughts/`
- [ ] Open a PR from `profession-planner`; after merge, CI publishes `pp-v0.1.0`, and the WUK workflow does not run (its paths filter)
