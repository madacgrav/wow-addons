# Implementation Plan

## Overview
- ProfessionPlanner plans multi-step routes on a fresh character from seed data, generated offline from Forever's own game tables.
- It also considers recipes the character has not learned yet, and tells you where to learn them.
- Reagents are priced at the cheapest of the vendor scan and Auctionator. If neither is known, vendor-sold items fall back to a seeded base price, marked `est.`.
- Shopping rows show a vendor, taken from QuestieDB.
- A short route hint is shown per skill bracket.
- In-game observations always override the seed.
- Auctionator and QuestieDB are both optional.

## Conventions
- **Branch:** `pp-seed-data` from `main`, one commit per phase. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Namespace:** every addon file starts with `local ADDON, PP = ...`.
  - Pure functions go only in `Logic.lua`, tested by `ProfessionPlanner/tests/run.lua`.
  - Code must run on Lua 5.1 (CI uses `lua5.1`) and 5.4 (local). No `//`, no `goto`, no integer-division operators.
- **Test** (repo root): `lua ProfessionPlanner/tests/run.lua` must print `all tests passed`.
- **Syntax check:** `lua -e "assert(loadfile([[ProfessionPlanner/<File>.lua]]))"` for every changed `.lua` file.
- **Deploy after each phase**, after the tests pass and the commit is made. Robocopy exit codes 0–7 mean success. `tools` is excluded from the deployed copy.
  ```powershell
  robocopy "D:\Source\wow-addons\ProfessionPlanner" "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\ProfessionPlanner" /MIR /XD tests tools /NJH /NJS /NP /NDL
  ```
  Then ask the user to `/reload` and run the manual checks.
- **Data rules:**
  - Seed and AH data are never written into `ProfessionPlannerDB` or `ProfessionPlannerCharDB`.
  - All merging happens in memory in the Panel refresher.
- **Third-party calls:**
  - Every call into Auctionator or QuestieDB is nil-guarded and wrapped in `pcall`.
  - Use `ADDON` (= `"ProfessionPlanner"`) as Auctionator's callerID.

---

## Phase 1: Probe unlearned-recipe APIs

### Changes

#### 1. Probe output
**File**: `ProfessionPlanner/Core.lua`
**Action**: modify `PP.Probe()`. Inside `if ready then`, after the existing learned-recipe loop and before `P("recipes", ...)`, add:
```lua
    local unl = 0
    for _, id in ipairs(ids) do
      local ri = C_TradeSkillUI.GetRecipeInfo(id)
      if ri and not ri.learned and unl < 10 then
        unl = unl + 1
        P("  unlearned " .. id .. " " .. tostring(ri.name), "diff=" .. tostring(ri.relativeDifficulty)
          .. " maxTrivial=" .. tostring(ri.maxTrivialLevel) .. " sourceType=" .. tostring(ri.sourceType)
          .. " disabled=" .. tostring(ri.disabled) .. " reason=" .. tostring(ri.disabledReason))
        if C_TradeSkillUI.GetRecipeSourceText then
          P("    source", (tostring(C_TradeSkillUI.GetRecipeSourceText(id)):gsub("\n", " | ")))
        end
        for _, rq in ipairs(C_TradeSkillUI.GetRecipeRequirements and C_TradeSkillUI.GetRecipeRequirements(id) or {}) do
          P("    req", tostring(rq.name) .. " met=" .. tostring(rq.met) .. " type=" .. tostring(rq.type))
        end
      end
    end
```
After the `if ready then ... end` block (before the bank lines), add:
```lua
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  P("Auctionator API", tostring(api ~= nil))
  if api then
    local ok, p = pcall(api.GetAuctionPriceByItemID, ADDON, 2589) -- Linen Cloth
    P("  AH price 2589", tostring(ok) .. " " .. tostring(p))
  end
  local q = LibQuestieDB
  P("LibQuestieDB", tostring(q ~= nil) .. " contract3=" .. tostring(q and q.RequireContract and q.RequireContract(3)))
```

#### 2. Probe results doc
**File**: `thoughts/qrspi/2026-10-20-profession-planner-seed-data-auctionator/probe-results.md`
**Action**: create, after the user pastes the output.
- Record per unlearned recipe: id, diff, sourceType, disabled, source text and requirements.
- Record the Auctionator and LibQuestieDB lines.
- Classify each recipe ID as **pattern-taught** or **trainer** by grepping the Phase 2 `Data.lua` for `taughtBy`. Fill this in after Phase 2 is generated.
- End the doc with one line: **Rule A** or **Rule B** (see Phase 5, change 1).

### Verification
#### Automated
- [x] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`
- [x] `lua -e "assert(loadfile([[ProfessionPlanner/Core.lua]]))"` succeeds

#### Manual
- [x] Deployed; in game with Tailoring open, `/pp probe` prints `unlearned` lines, `Auctionator API true` with a numeric or nil price and no error, and the `LibQuestieDB true contract3=true` line
- [x] Output saved to `probe-results.md` (Rule B)

---

## Phase 2: Seeded thresholds and reagents

### Changes

#### 1. Seed generator (dev only, not loaded by the game)
**File**: `ProfessionPlanner/tools/gen_seed.py`
**Action**: create
```python
"""Generate ProfessionPlanner/Data.lua from Forever client tables (wago.tools CSV export).
Usage (repo root): python -I ProfessionPlanner/tools/gen_seed.py 1.60.1.70450 ProfessionPlanner/Data.lua"""
import csv, io, sys, urllib.request

PROFS = {"197", "333", "165", "171"}  # must match PP.PROFESSIONS

def table(name, build):
    with urllib.request.urlopen(f"https://wago.tools/db2/{name}/csv?build={build}") as r:
        return list(csv.DictReader(io.StringIO(r.read().decode("utf-8"))))

def main(build, out):
    recipes = {}
    for r in table("SkillLineAbility", build):
        hi, lo = int(r["TrivialSkillLineRankHigh"]), int(r["TrivialSkillLineRankLow"])
        if r["SkillLine"] in PROFS and hi > 0 and r["Spell"] not in recipes:  # hi == 0: rank spells, not recipes
            recipes[r["Spell"]] = {"prof": int(r["SkillLine"]), "yellow": lo, "green": -(-(lo + hi) // 2),
                                   "grey": hi, "reagents": [], "taughtBy": []}
    for r in table("SpellReagents", build):
        rec = recipes.get(r["SpellID"])
        if rec:
            rec["reagents"] = [(int(r[f"Reagent_{i}"]), int(r[f"ReagentCount_{i}"]))
                               for i in range(8) if r[f"Reagent_{i}"] not in ("", "0")]
    for r in table("SpellEffect", build):
        rec = recipes.get(r["SpellID"])
        if rec and r["Effect"] == "24" and r["EffectItemType"] not in ("", "0"):  # 24 = create item
            rec.setdefault("item", int(r["EffectItemType"]))
    teach = {r["ID"]: r["SpellID"] for r in table("ItemEffect", build)
             if r["TriggerType"] == "6" and r["SpellID"] in recipes}  # 6 = on learn
    for r in table("ItemXItemEffect", build):
        spell = teach.get(r["ItemEffectID"])
        if spell:
            recipes[spell]["taughtBy"].append(int(r["ItemID"]))
    items = {r["ID"]: r for r in table("ItemSparse", build)}
    price = {}
    for rec in recipes.values():
        rec["taughtBy"] = sorted(set(rec["taughtBy"]))
        ranks = [int(items[str(i)]["RequiredSkillRank"]) for i in rec["taughtBy"]
                 if str(i) in items and items[str(i)]["RequiredSkill"] == str(rec["prof"])
                 and int(items[str(i)]["RequiredSkillRank"]) > 0]
        if ranks:
            rec["learnAt"] = min(ranks)
        for i in [i for i, _ in rec["reagents"]] + rec["taughtBy"]:
            buy = int(items[str(i)]["BuyPrice"]) if str(i) in items else 0
            if buy > 0:
                price[i] = buy
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"-- Generated by tools/gen_seed.py from Forever build {build} (wago.tools). Do not edit.\n")
        f.write("local ADDON, PP = ...\n")
        f.write(f'PP.SEED = {{ build = "{build}", recipes = {{\n')
        for spell in sorted(recipes, key=int):
            rec = recipes[spell]
            rg = ",".join(f"{{itemID={i},qty={q}}}" for i, q in rec["reagents"])
            extra = "".join(f",{k}={rec[k]}" for k in ("item", "learnAt") if k in rec)
            if rec["taughtBy"]:
                extra += ",taughtBy={" + ",".join(map(str, rec["taughtBy"])) + "}"
            f.write(f"[{spell}]={{prof={rec['prof']},yellow={rec['yellow']},green={rec['green']},"
                    f"grey={rec['grey']},reagents={{{rg}}}{extra}}},\n")
        f.write("}, price = {\n")
        f.write("".join(f"[{i}]={p},\n" for i, p in sorted(price.items())))
        f.write("} }\n")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
```
- Run: `python -I ProfessionPlanner/tools/gen_seed.py 1.60.1.70450 ProfessionPlanner/Data.lua`
- If wago.tools is unreachable, stop and tell the user. Do not hand-write Data.lua.
- To pick up a newer Forever build, list builds with `curl -sL https://wago.tools/api/builds | grep -o '"product":"wow_classic_beta","version":"1\.60\.[^"]*"'`. Keep `1.60.1.70450` unless the user asks otherwise.

#### 2. Generated data
**File**: `ProfessionPlanner/Data.lua`
**Action**: create by running the script, then commit.
- Expected: about 1,585 recipe rows, under ~250 KB.
- Check `lua -e "assert(loadfile([[ProfessionPlanner/Data.lua]]))"`.

#### 3. TOC
**File**: `ProfessionPlanner/ProfessionPlanner.toc`
**Action**: modify. The file list becomes:
```
Data.lua
Logic.lua
Core.lua
Panel.lua
```

#### 4. CI zip excludes tools
**File**: `.github/workflows/package-pp.yml`
**Action**: modify line 31:
```yaml
        run: zip -r "ProfessionPlanner-${{ steps.version.outputs.version }}.zip" ProfessionPlanner -x 'ProfessionPlanner/tests/*' 'ProfessionPlanner/tools/*'
```

#### 5. Merge functions
**File**: `ProfessionPlanner/Logic.lua`
**Action**: add after `PP.NextThreshold`:
```lua
-- per color, an in-game learned threshold wins over the seed
function PP.MergeThresholds(learned, seed)
  if not seed then return learned end
  local th = { yellow = seed.yellow, green = seed.green, grey = seed.grey }
  for k, v in pairs(learned or {}) do th[k] = v end
  return th
end

-- the scanned schematic wins; seed reagents only fill a recipe the scan couldn't read
function PP.MergeReagents(scanned, seed)
  if scanned and #scanned > 0 then return scanned end
  return seed and seed.reagents or scanned or {}
end
```

#### 6. Panel builds an in-memory view
**File**: `ProfessionPlanner/Panel.lua`
**Action**: modify. Add above the refresher:
```lua
local function copy(t) local c = {}; for k, v in pairs(t) do c[k] = v end; return c end

-- scanned recipes annotated with seed data, in memory only (never saved)
local function View(prof)
  local recipes, thresholds, seed = {}, {}, PP.SEED and PP.SEED.recipes or {}
  for id, r in pairs(PP.char.recipes[prof] or {}) do
    local v = copy(r)
    v.reagents = PP.MergeReagents(r.reagents, seed[id])
    recipes[id] = v
    thresholds[id] = PP.MergeThresholds(PP.db.thresholds[id], seed[id])
  end
  return recipes, thresholds
end
```
In the refresher:
- Replace `local recipes, have = PP.char.recipes[PP.current], PP.Have()` with:
  ```lua
  local recipes, thresholds = View(PP.current)
  local have = PP.Have()
  ```
- Pass `thresholds = thresholds` instead of `PP.db.thresholds` to `PP.Plan`.
- Replace the footer line with:
  ```lua
  .. "\n|cff999999" .. known .. " thresholds learned  |  seed " .. (PP.SEED and PP.SEED.build or "none") .. "|r"
  ```
  The `known` loop stays on `PP.db.thresholds`.

#### 7. Tests
**File**: `ProfessionPlanner/tests/run.lua`
**Action**: add before `print("all tests passed")`:
```lua
-- Seed phase 2
local m = PP.MergeThresholds({ green = 61 }, { yellow = 50, green = 60, grey = 70 })
eq(m.yellow, 50, "seed yellow"); eq(m.green, 61, "learned wins"); eq(m.grey, 70, "seed grey")
eq(PP.MergeThresholds(nil, nil), nil, "no data")
eq(PP.MergeReagents({}, { reagents = { { itemID = 9, qty = 2 } } })[1].itemID, 9, "seed fills empty scan")
eq(PP.MergeReagents({ { itemID = 8, qty = 1 } }, { reagents = { { itemID = 9, qty = 2 } } })[1].itemID, 8, "scan wins")
local seeded = { [2] = PP.MergeThresholds(nil, { yellow = 40, green = 60, grey = 70 }),
  [1] = PP.MergeThresholds(nil, { yellow = 55, green = 65, grey = 75 }) }
st = PP.Plan(S({ thresholds = seeded }))
eq(#st >= 2, true, "seed-only plan is multi-step"); eq(st[1].toSkill, 60, "seed gives toSkill")
assert(loadfile(dir .. "/Data.lua"))("ProfessionPlanner", PP)
local d = PP.SEED.recipes[3755]
eq(d.grey, 65, "Linen Bag grey"); eq(d.yellow, 30, "Linen Bag yellow"); eq(d.green, 48, "Linen Bag green"); eq(d.item, 4238, "Linen Bag item")
eq(PP.SEED.recipes[3757].grey, 110, "Woolen Bag grey"); eq(PP.SEED.recipes[3757].green, 93, "Woolen Bag green (in game: green at 93)")
eq(PP.SEED.recipes[7457].green, 120, "learned green 120 matches seed")
eq(PP.SEED.price[2320], 10, "Coarse Thread base price")
```

### Verification
#### Automated
- [x] `python -I ProfessionPlanner/tools/gen_seed.py 1.60.1.70450 ProfessionPlanner/Data.lua` completes; `ProfessionPlanner/Data.lua` < 300 KB
- [x] `lua -e "assert(loadfile([[ProfessionPlanner/Data.lua]]))"`, then the same for Logic.lua and Panel.lua
- [x] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`

#### Manual
- [x] Deployed; `/reload` gives no Lua errors
- [x] A profession on a character with few learned thresholds shows ≥2 plan rows with `-> N` targets
- [x] The footer shows `seed 1.60.1.70450`
- [x] Fill in the trainer/pattern classification in `probe-results.md` (Phase 1, change 2)

---

## Phase 3: Auctionator prices and price sources

### Changes

#### 1. TOC
**File**: `ProfessionPlanner/ProfessionPlanner.toc`
**Action**: add after `## SavedVariablesPerCharacter`:
```
## OptionalDeps: Auctionator, QuestieDB
```

#### 2. Logic: price pick, estimate flag, sources
**File**: `ProfessionPlanner/Logic.lua`
**Action**: modify.
- Add near the top constants:
  ```lua
  PP.UNKNOWN_COST = 10000 -- 1g per unpriced reagent; such costs are flagged `estimated`
  ```
- Add the price picker:
  ```lua
  -- cheapest of vendor scan and AH; the seed base price only for items a vendor is known to sell
  function PP.PickPrice(vendor, ah, seed, vendorSold)
    if vendor and (not ah or vendor <= ah) then return vendor, "vendor" end
    if ah then return ah, "AH" end
    if vendorSold and seed then return seed, "est." end
    return nil
  end
  ```
- `CraftCost` returns `cost, estimated`:
  ```lua
  local function CraftCost(r, crafts, have, prices, unknownCost)
    local cost, est = 0, false
    for _, rg in ipairs(r.reagents) do
      local need = rg.qty * crafts
      local use = math.min(have[rg.itemID] or 0, need)
      have[rg.itemID] = (have[rg.itemID] or 0) - use
      local p = prices[rg.itemID]
      if need > use and not p then est = true end
      cost = cost + (need - use) * (p or unknownCost)
    end
    return cost, est
  end
  ```
  The score line stays as it is (`CraftCost(...) / PP.CHANCE[c]` takes the first value).
- In `PP.Plan`, the step build becomes:
  ```lua
      local cost, est = CraftCost(r, crafts, have, s.prices, s.unknownCost)
      steps[#steps + 1] = { recipeID = best, name = r.name, icon = r.icon, color = bestColor, crafts = crafts,
        toSkill = nextT and toSkill or nil, untilColorChange = (not nextT) or nil, cost = cost, estimated = est or nil }
  ```
- `PP.ShoppingList(steps, recipes, have, prices, sources)` gets the extra param. The entry adds `source = sources and sources[id] or nil`.

#### 3. Core: Auctionator lookup and refresh hook
**File**: `ProfessionPlanner/Core.lua`
**Action**: add after `ScanMerchant`:
```lua
-- Auctionator's last-seen buyout in copper; nil when absent, not scanned or the API errors
function PP.AHPrice(id)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not (api and api.GetAuctionPriceByItemID) then return nil end
  local ok, p = pcall(api.GetAuctionPriceByItemID, ADDON, id)
  if ok and type(p) == "number" and p > 0 then return p end
end

table.insert(PP.inits, function()
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.RegisterForDBUpdate then pcall(api.RegisterForDBUpdate, ADDON, PP.Refresh) end
end)
```

#### 4. Panel: prices per refresh, source tags, estimate marker
**File**: `ProfessionPlanner/Panel.lua`
**Action**: modify.
- Delete `local UNKNOWN_COST = 10000` and use `PP.UNKNOWN_COST`.
- Add:
  ```lua
  -- per-refresh price table for every reagent in view; AH prices are read live, never saved
  local function Prices(recipes)
    local prices, sources = {}, {}
    local function add(id)
      if sources[id] ~= nil then return end
      prices[id], sources[id] = PP.PickPrice(PP.db.prices[id], PP.AHPrice(id), nil, false)
      sources[id] = sources[id] or false
    end
    for _, r in pairs(recipes) do for _, rg in ipairs(r.reagents) do add(rg.itemID) end end
    return prices, sources, add
  end
  ```
- In the refresher, after `View`:
  ```lua
  local prices, sources = Prices(recipes)
  ```
  Pass `prices = prices, unknownCost = PP.UNKNOWN_COST` to Plan, and call `PP.ShoppingList(steps, recipes, have, prices, sources)`.
- Step row sub-text:
  ```lua
  goal .. "   " .. (st.estimated and "~" or "") .. PP.FormatMoney(st.cost)
  ```
- Shopping row: when `it.unitPrice` is set, append `" @ " .. PP.FormatMoney(it.unitPrice) .. " " .. it.source`.

#### 5. Tests
**File**: `ProfessionPlanner/tests/run.lua`
**Action**: add:
```lua
-- Prices phase 3
local pr, src = PP.PickPrice(90, 120, 100, true); eq(pr, 90, "vendor cheaper"); eq(src, "vendor", "vendor src")
pr, src = PP.PickPrice(90, 50); eq(pr, 50, "AH cheaper"); eq(src, "AH", "AH src")
eq(PP.PickPrice(nil, 70), 70, "AH only")
pr, src = PP.PickPrice(nil, nil, 100, true); eq(pr, 100, "seed fallback"); eq(src, "est.", "est src")
eq(PP.PickPrice(nil, nil, 100, false), nil, "seed needs a known vendor")
st = PP.Plan(S({ recipes = { [2] = R[2] }, prices = {} })); eq(st[1].estimated, true, "unpriced reagent is estimated")
st = PP.Plan(S({ recipes = { [2] = R[2] } })); eq(st[1].estimated, nil, "priced not estimated")
list = PP.ShoppingList({ { recipeID = 2, crafts = 1 } }, R, {}, { [11] = 100 }, { [11] = "AH" }); eq(list[1].source, "AH", "source passed")
```

### Verification
#### Automated
- [x] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`
- [x] loadfile syntax check for Logic.lua, Core.lua and Panel.lua

#### Manual
- [x] Deployed; at the AH, run an Auctionator full scan, and the panel refreshes by itself afterwards
- [x] Shopping rows show `vendor` or `AH` after the price; costs that use an unknown price show a `~` prefix
- [x] Disable Auctionator (AddOns list), `/reload`: the panel works, there are no errors, and only `vendor` sources appear

---

## Phase 4: QuestieDB vendors and seed price fallback

### Changes

#### 1. Core: vendor lookup
**File**: `ProfessionPlanner/Core.lua`
**Action**: add after `PP.AHPrice`:
```lua
-- first vendor (QuestieDB) friendly to the player's faction: { name, zone? }; nil without QuestieDB
local vendorCache = {}
local function FindVendor(q, id)
  local my = (UnitFactionGroup("player") or ""):sub(1, 1) -- "A" / "H"
  for _, npc in ipairs(q.Item.vendors(id) or {}) do
    local f = q.Npc.friendlyToFaction(npc)
    if not f or f:find(my, 1, true) then
      local area = q.Npc.zoneID(npc)
      return { name = q.Npc.name(npc), zone = area and C_Map.GetAreaInfo(area) or nil }
    end
  end
  return false
end
function PP.VendorFor(id)
  local q = LibQuestieDB
  if not (q and q.RequireContract and q.RequireContract(3)) then return nil end
  if vendorCache[id] == nil then
    local ok, v = pcall(FindVendor, q, id)
    vendorCache[id] = ok and v or false -- static data: cache misses too
  end
  return vendorCache[id] or nil
end
```

#### 2. Panel: seed fallback and vendor text
**File**: `ProfessionPlanner/Panel.lua`
**Action**: modify.
- In `Prices`, the `add` line becomes:
  ```lua
  prices[id], sources[id] = PP.PickPrice(PP.db.prices[id], PP.AHPrice(id), PP.SEED and PP.SEED.price[id], PP.VendorFor(id) ~= nil)
  ```
- Shopping row: after the price text, when `it.buy > 0`:
  ```lua
  local v = PP.VendorFor(it.itemID)
  if v then sub = sub .. " - " .. v.name .. (v.zone and (" (" .. v.zone .. ")") or "") end
  ```

### Verification
#### Automated
- [x] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed` (PickPrice fallback already covered)
- [x] loadfile syntax check for Core.lua and Panel.lua

#### Manual
- [ ] Deployed; a plan needing Coarse Thread shows a vendor of the player's faction with a zone
- [ ] A vendor reagent never bought from a merchant shows a price with `est.`
- [ ] Disable QuestieDB, `/reload`: no vendor text, no `est.` prices, no errors

---

## Phase 5: Unlearned recipes in the plan

### Changes

#### 1. Core: scan stores unlearned recipes
**File**: `ProfessionPlanner/Core.lua`
**Action**: modify `PP.ScanProfession`.
- Change the filter `if ri and ri.learned and ours then` to `if ri and ours then`.
- Replace the block after `cache[id] = r` (current lines 57-62) with:
  ```lua
      cache[id] = r
      local wasLearned = r.learned
      r.learned = ri.learned and true or false
      if r.learned then
        prevColors[id] = wasLearned and r.color or nil -- a just-learned recipe has no previous color
        r.color = PP.COLOR[ri.relativeDifficulty] or "grey"
        curColors[id] = r.color
        r.maxTrivial = ri.maxTrivialLevel
      else
        r.source = C_TradeSkillUI.GetRecipeSourceText and C_TradeSkillUI.GetRecipeSourceText(id) or nil
        -- trainer signal, chosen from probe-results.md:
        -- Rule A (unlearned recipes report relativeDifficulty and `disabled` is false exactly when learnable now):
        --   r.color = PP.COLOR[ri.relativeDifficulty]; r.trainerLearnable = (ri.disabled == false) or nil
        -- Rule B (no such signal): leave r.color and r.trainerLearnable nil
      end
  ```
  Implement exactly one rule, as recorded at the end of `probe-results.md`, and delete the other rule's comment.
- Change the `LearnGrey` loop to: `for id, r in pairs(cache) do if r.learned then PP.LearnGrey(PP.db.thresholds, id, r.maxTrivial) end end`.

#### 2. Logic: learnability and plan candidates
**File**: `ProfessionPlanner/Logic.lua`
**Action**: modify.
- Add:
  ```lua
  -- an unlearned recipe is a candidate once its pattern's skill is reached, or the game says a trainer can teach it now
  function PP.Learnable(r, seed, skill)
    if r.learned then return false end
    if seed and seed.learnAt then return seed.learnAt <= skill end
    return r.trainerLearnable == true
  end
  ```
- In `PP.Plan`, replace the candidate loop body:
  ```lua
        for id, r in pairs(s.recipes) do
          local c
          if r.learned or r.learnable then
            -- unlearned without a game color: orange from its learn skill, projected with (seed) thresholds
            local base, baseSkill = r.color, s.skill
            if not r.learned and not r.color then base, baseSkill = "orange", r.learnAt end
            c = base and baseSkill and PP.ProjectColor(s.thresholds[id], base, baseSkill, skill)
          end
          if c and ((pass == 1 and (c == "orange" or c == "yellow")) or (pass == 2 and c == "green")) then
            local reach = math.min(PP.NextThreshold(s.thresholds[id], c, skill) or s.target, s.target)
            local learn = r.learned and 0 or (r.learnCost or 0) / math.max(1, reach - skill) -- one-time cost per point
            local score = CraftCost(r, 1, copy(have), s.prices, s.unknownCost) / PP.CHANCE[c] + learn
            local b = best and s.recipes[best]
            if not best or score < bestScore
              or (score == bestScore and ((r.learned and not b.learned) or (r.learned == b.learned and id < best))) then
              best, bestScore, bestColor = id, score, c
            end
          end
        end
  ```
- In the step build, add the learn cost and info:
  ```lua
      local cost, est = CraftCost(r, crafts, have, s.prices, s.unknownCost)
      steps[#steps + 1] = { recipeID = best, name = r.name, icon = r.icon, color = bestColor, crafts = crafts,
        toSkill = nextT and toSkill or nil, untilColorChange = (not nextT) or nil,
        cost = cost + (r.learned and 0 or (r.learnCost or 0)), estimated = est or nil,
        learn = (not r.learned) and { item = r.learnItem, source = r.source } or nil }
  ```
- A plan step for an unlearned recipe must not be considered again as unlearned by later steps. Plan does not mutate recipes, so later steps would add the learn cost a second time. Prevent this by keeping a local `learnedNow = {}` set in Plan:
  - After choosing `best`, set `learnedNow[best] = true`.
  - In the candidate loop, treat `r.learned or learnedNow[id]` as learned. Use a local `isLearned` everywhere `r.learned` appears in the loop and the step build.
  - The base color/skill for a `learnedNow` recipe stays `"orange", r.learnAt` (or `r.color`).

#### 3. Panel: learn annotations, pattern prices, learn row
**File**: `ProfessionPlanner/Panel.lua`
**Action**: modify.
- In `View(prof)`, pass the skill (`View(prof, skill)`). Inside the loop add:
  ```lua
    local sd = seed[id]
    if sd then v.learnAt, v.taughtBy = sd.learnAt, sd.taughtBy end
    v.learnable = PP.Learnable(r, sd, skill)
  ```
- In `Prices`, also call `add(r.taughtBy[1..n])` for unlearned learnable recipes. In the refresher after `Prices`:
  ```lua
  -- a pattern recipe is only plannable when one of its patterns has a price (vendor/AH/est.)
  for _, v in pairs(recipes) do
    if v.learnable and v.taughtBy then
      local bestItem
      for _, it in ipairs(v.taughtBy) do
        if prices[it] and (not bestItem or prices[it] < prices[bestItem]) then bestItem = it end
      end
      v.learnable, v.learnItem, v.learnCost = bestItem ~= nil, bestItem, bestItem and prices[bestItem]
    end
  end
  ```
- When rendering a step with `st.learn`, insert a row before the craft row:
  ```lua
  local learnName, learnIcon = "Trainer", nil
  if st.learn.item then learnName, learnIcon = ItemName(st.learn.item, Rerender) end
  local where = st.learn.item and PP.VendorFor(st.learn.item)
  rows[#rows + 1] = { icon = learnIcon or st.icon, text = "Learn: " .. learnName,
    sub = (where and (where.name .. (where.zone and (" (" .. where.zone .. ")") or "")))
      or (st.learn.source and st.learn.source:match("^[^\n]*")) or "" }
  ```
- Rule B only: add `"  |  N unlearned at trainer"` to the footer, where N = unlearned recipes with no `taughtBy`.

#### 4. Tests
**File**: `ProfessionPlanner/tests/run.lua`
**Action**: add:
```lua
-- Unlearned phase 5
eq(PP.Learnable({ learned = false }, { learnAt = 60 }, 50), false, "learnAt above skill")
eq(PP.Learnable({ learned = false }, { learnAt = 40 }, 50), true, "learnAt reached")
eq(PP.Learnable({ learned = false }, nil, 50), false, "trainer without signal")
eq(PP.Learnable({ learned = false, trainerLearnable = true }, nil, 50), true, "trainer signal")
eq(PP.Learnable({ learned = true }, { learnAt = 1 }, 50), false, "already learned")
local NEW = { learned = false, learnable = true, learnAt = 40, learnCost = 500, learnItem = 99, name = "New", reagents = { { itemID = 13, qty = 1 } } }
local thU = { [4] = { yellow = 70, green = 80, grey = 90 } }
st = PP.Plan(S({ recipes = { [1] = R[1], [4] = NEW }, thresholds = thU, prices = { [10] = 1000, [13] = 10 } }))
eq(st[1].recipeID, 4, "cheaper unlearned chosen"); eq(st[1].learn.item, 99, "learn step")
eq(st[1].toSkill, 70, "orange until yellow 70"); eq(st[1].cost, 20 * 10 + 500, "pattern cost included once")
eq(st[2] and st[2].recipeID == 4 and st[2].learn, nil, "no second learn for same recipe")
local NOPE = { learned = false, learnable = false, learnAt = 60, name = "Later", reagents = { { itemID = 13, qty = 1 } } }
st = PP.Plan(S({ recipes = { [1] = R[1], [4] = NOPE }, thresholds = thU, prices = { [10] = 1000, [13] = 10 } }))
eq(st[1].recipeID, 1, "unlearnable excluded")
local TWIN = { learned = false, learnable = true, learnAt = 40, learnCost = 0, name = "Twin", reagents = { { itemID = 13, qty = 1 } } }
st = PP.Plan(S({ recipes = { [4] = TWIN, [5] = { learned = true, color = "orange", name = "Known", reagents = { { itemID = 13, qty = 1 } } } },
  thresholds = { [4] = thU[4], [5] = thU[4] }, prices = { [13] = 10 } }))
eq(st[1].recipeID, 5, "learned preferred on tie")
```

### Verification
#### Automated
- [ ] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`, and the existing Phase 3/4 tests still pass (learned recipes unchanged)
- [ ] loadfile syntax check for Core.lua, Logic.lua and Panel.lua

#### Manual
- [ ] Deployed; `/pp debug` lists `(unlearned)` counts, and no thresholds are learned from unlearned recipes
- [ ] Tailoring around skill 90–110 can show `Learn: Pattern: Red Woolen Bag` with a vendor and zone, followed by an `xN Red Woolen Bag` row whose cost includes the pattern
- [ ] Rule A only: an unlearned trainer recipe can appear with `Learn: Trainer`

---

## Phase 6: Flyout toggle on the profession window

### Changes

#### 1. Saved state
**File**: `ProfessionPlanner/Core.lua`
**Action**: the `ProfessionPlannerDB` defaults become `{ thresholds = {}, prices = {}, panelOpen = true }`.

#### 2. Edge tab and toggle
**File**: `ProfessionPlanner/Panel.lua`
**Action**: add above `PP.RenderPanel`:
```lua
local tab
-- below the last shown side profession tab; fixed offset if Blizzard's tab list isn't there
local function AnchorTab()
  local last
  for _, t in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do if t:IsShown() then last = t end end
  tab:ClearAllPoints()
  if last then tab:SetPoint("TOP", last, "BOTTOM", 0, -12)
  else tab:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 8, -420) end -- ponytail: tune if the fallback is ever used
end

local function BuildTab()
  tab = CreateFrame("Button", "PPToggleTab", ProfessionsFrame)
  tab:SetSize(36, 36)
  tab.icon = tab:CreateTexture(nil, "ARTWORK"); tab.icon:SetAllPoints(); tab.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  tab:SetScript("OnClick", function() PP.db.panelOpen = not PP.db.panelOpen; PP.Refresh() end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(PP.db.panelOpen and "Hide Profession Planner" or "Show Profession Planner")
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", GameTooltip_Hide)
end

-- the tab shows whenever a supported profession window is open
function PP.RenderTab(shown)
  if not shown then if tab then tab:Hide() end return end
  if not tab then BuildTab() end
  AnchorTab()
  tab:Show()
end
```
- In `Build()`, after creating `panel`:
  ```lua
  if panel.CloseButton then panel.CloseButton:HookScript("OnClick", function() PP.db.panelOpen = false; PP.Refresh() end) end
  ```
- In the refresher, replace the first line with:
  ```lua
  local open = PP.current and ProfessionsFrame and ProfessionsFrame:IsShown()
  PP.RenderTab(open)
  if not open or not PP.db.panelOpen then return PP.RenderPanel(nil) end
  ```

### Verification
#### Automated
- [ ] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`
- [ ] loadfile syntax check for Core.lua and Panel.lua

#### Manual
- [ ] Deployed; with Tailoring open, a book-icon tab sits under the side profession tabs and its tooltip reads Hide/Show
- [ ] Clicking the tab hides the panel, and clicking again shows it
- [ ] The state survives `/reload` and reopening the window
- [ ] The panel's X closes it; the tab reopens it
- [ ] With a non-supported profession (e.g. Cooking) open, no tab and no panel

---

## Phase 7: Click a plan step to craft

### Changes

#### 1. Select / craft
**File**: `ProfessionPlanner/Core.lua`
**Action**: add after `PP.VendorFor`:
```lua
-- select a recipe in the profession window with the craft count filled in; with `now`, craft immediately
-- (must run inside the click handler: crafting needs the hardware event)
function PP.SelectRecipe(id, crafts, now)
  local n = math.min(crafts, C_TradeSkillUI.GetCraftableCount(id) or 0)
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  local info = C_TradeSkillUI.GetRecipeInfo(id)
  if page and page.SelectRecipe and info then page:SelectRecipe(info) else C_TradeSkillUI.OpenRecipe(id) end
  if now then
    if n > 0 then C_TradeSkillUI.CraftRecipe(id, n) else PP.Print("Missing reagents for " .. tostring(info and info.name)) end
    return
  end
  local box = page and page.CreateMultipleInputBox
  if box and n > 0 then C_Timer.After(0, function() box:SetValue(n) end) end -- after Blizzard's own count reset
end
```

#### 2. Clickable rows
**File**: `ProfessionPlanner/Panel.lua`
**Action**: modify.
- In `Build()`, for each row:
  ```lua
  row:EnableMouse(true)
  row.hl = row:CreateTexture(nil, "HIGHLIGHT"); row.hl:SetAllPoints(); row.hl:SetColorTexture(1, 1, 1, 0.08)
  row:SetScript("OnMouseUp", function(self) if self.recipeID then PP.SelectRecipe(self.recipeID, self.crafts, IsShiftKeyDown()) end end)
  row:SetScript("OnEnter", function(self)
    if not self.recipeID then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Click: select recipe")
    GameTooltip:AddLine("Shift-click: craft " .. self.crafts, 1, 1, 1)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  ```
- In `PP.RenderPanel`, for each shown row: `row.recipeID, row.crafts = v.recipeID, v.crafts`.
- In the refresher, a craft step row (not `Learn:` rows or shopping rows) adds `recipeID = (not st.learn) and st.recipeID or nil, crafts = st.crafts`. A step that starts with a `Learn:` row is not craftable until learned.
- The `HIGHLIGHT` layer only shows on mouse-enabled frames. Shopping rows are mouse-enabled too but do nothing, so set `row.hl:SetShown(v.recipeID ~= nil)` in `RenderPanel`.

### Verification
#### Automated
- [ ] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed`
- [ ] loadfile syntax check for Core.lua and Panel.lua

#### Manual
- [ ] Deployed; clicking a step row selects that recipe in the list/schematic, and the count box shows min(step crafts, craftable)
- [ ] Shift-click on a row with reagents crafts that many (watch the cast bar / count)
- [ ] Shift-click with no reagents prints "Missing reagents for …" and does not craft
- [ ] Hovering a step shows the tooltip; shopping rows and `Learn:` rows show no highlight and do nothing

---

## Phase 8: Route hints

### Changes

#### 1. Hints data
**File**: `ProfessionPlanner/Hints.lua`
**Action**: create:
```lua
local ADDON, PP = ...
-- hand-written leveling route per profession: craft `recipeID` from `from` to `to`; checked against PP.SEED by tests
PP.HINTS = {
  [197] = { -- Tailoring
    { from = 1, to = 50, recipeID = 2963 }, -- Bolt of Linen Cloth (seed: yellow 25, grey 50)
    -- ...
  },
  [333] = { --[[ Enchanting ]] },
  [165] = { --[[ Leatherworking ]] },
  [171] = { --[[ Alchemy ]] },
}
```
- **Authoring rules:**
  - Our own choices; no guide text.
  - 6–12 rows per profession, ranges contiguous from 1 to 300.
  - Each recipe must be non-grey for its whole range per the seed (orange from `learnAt`, or from 1 when absent).
  - If it has `learnAt`, that must be ≤ `from`.
  - Prefer recipes with no `taughtBy` (trainer/auto-learned). Otherwise use patterns sold by vendors; check with QuestieDB in game via `PP.VendorFor`.
  - Avoid drop-only patterns.
- **List candidates** from the seed with:
  ```bash
  lua -e "local PP={}; assert(loadfile('ProfessionPlanner/Data.lua'))('x',PP); for id,r in pairs(PP.SEED.recipes) do if r.prof==197 then print(r.yellow,r.green,r.grey,id,r.learnAt or '-',r.taughtBy and 'pattern' or 'trainer') end end" | sort -n
  ```
  Look up names with `C_Spell.GetSpellName(id)` in game, or the wago SpellName CSV.

#### 2. TOC
**File**: `ProfessionPlanner/ProfessionPlanner.toc`
**Action**: the file list becomes `Data.lua`, `Hints.lua`, `Logic.lua`, `Core.lua`, `Panel.lua`. Bump `## Version: 0.2.0` (CI publishes a new release only on a version change).

#### 3. Logic: hint lookup
**File**: `ProfessionPlanner/Logic.lua`
**Action**: add:
```lua
-- the hint row covering `skill` (from <= skill < to)
function PP.HintFor(prof, skill)
  for _, h in ipairs(PP.HINTS and PP.HINTS[prof] or {}) do
    if skill >= h.from and skill < h.to then return h end
  end
end
```

#### 4. Panel: hint line and fallback
**File**: `ProfessionPlanner/Panel.lua`
**Action**: modify the refresher.
```lua
local hint = PP.HintFor(PP.current, s.skill)
local hintName = hint and ((recipes[hint.recipeID] and recipes[hint.recipeID].name)
  or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(hint.recipeID)) or ("spell:" .. hint.recipeID))
```
- Header: append `"\n|cff999999Guide: " .. hintName .. " until " .. hint.to .. "|r"` when `hint` is set.
- Empty plan: the row becomes `{ text = hint and ("Guide: " .. hintName) or "No recipe gives skill-ups here", sub = hint and ("until " .. hint.to) or "train new recipes" }`.
- Raise the header offset so the first row doesn't overlap the third header line. In `Build`, change the row anchor `-64` to `-78` and the panel height base in `RenderPanel` from `74` to `88`.

#### 5. Tests
**File**: `ProfessionPlanner/tests/run.lua`
**Action**: add (after Data.lua is loaded):
```lua
-- Hints phase 6
assert(loadfile(dir .. "/Hints.lua"))("ProfessionPlanner", PP)
for prof, rows in pairs(PP.HINTS) do
  eq(rows[1].from, 1, prof .. " hints start at 1"); eq(rows[#rows].to, 300, prof .. " hints end at 300")
  for i, h in ipairs(rows) do
    if i > 1 then eq(h.from, rows[i - 1].to, prof .. " hints contiguous at " .. h.from) end
    local sd = PP.SEED.recipes[h.recipeID]
    eq(sd ~= nil, true, "hint recipe " .. h.recipeID .. " in seed"); eq(sd.prof, prof, "hint " .. h.recipeID .. " profession")
    if sd.learnAt then eq(sd.learnAt <= h.from, true, "hint " .. h.recipeID .. " learnable at " .. h.from) end
    for skill = h.from, h.to - 1 do
      local c = PP.ProjectColor(sd, "orange", sd.learnAt or 1, skill)
      eq(c ~= nil and c ~= "grey", true, "hint " .. h.recipeID .. " not grey at " .. skill)
    end
  end
end
eq(PP.HintFor(197, 10).recipeID, 2963, "hint lookup")
eq(PP.HintFor(197, 300), nil, "no hint at cap")
```
`ProjectColor(th, ...)` reads `th.yellow/green/grey`. A seed recipe row has those fields, so it can be passed directly.

### Verification
#### Automated
- [ ] `lua ProfessionPlanner/tests/run.lua` prints `all tests passed` with all four professions' hints filled
- [ ] loadfile syntax check for Hints.lua, Logic.lua and Panel.lua

#### Manual
- [ ] Deployed; the header shows `Guide: <recipe> until N` matching the current skill, and rows don't overlap the header
- [ ] A profession with no skill-up recipe shows the guide row instead of "No recipe gives skill-ups here"
- [ ] Push the branch and open a PR. CI (`package-pp.yml`) runs the tests under Lua 5.1 and the zip has no `tools/` folder
