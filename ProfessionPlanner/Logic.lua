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
