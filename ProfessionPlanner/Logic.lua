local ADDON, PP = ...

function PP.MergeDefaults(sv, defaults)
  if type(sv) ~= "table" then sv = {} end
  for k, v in pairs(defaults) do
    if type(v) == "table" then sv[k] = PP.MergeDefaults(sv[k], v)
    elseif sv[k] == nil then sv[k] = v end
  end
  return sv
end

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

-- "1g 2s 3c"; pure so it doesn't depend on GetCoinTextureString (moved under C_CurrencyInfo on Mainline)
function PP.FormatMoney(copper)
  copper = math.floor(copper or 0)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = "|cffffd700" .. g .. "g|r" end
  if s > 0 then parts[#parts + 1] = "|cffc7c7cf" .. s .. "s|r" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = "|cffeda55f" .. c .. "c|r" end
  return table.concat(parts, " ")
end

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

-- Forever fills maxTrivialLevel: the skill where the recipe turns grey
function PP.LearnGrey(th, id, maxTrivial)
  if type(maxTrivial) == "number" and maxTrivial > 0 then
    th[id] = th[id] or {}
    if not th[id].grey or maxTrivial < th[id].grey then th[id].grey = maxTrivial; return true end
  end
  return false
end
