local dir = ((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
local PP = {}
assert(loadfile(dir .. "/Logic.lua"))("ProfessionPlanner", PP)

local function eq(got, want, label)
  if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end

-- Phase 1
local sv = PP.MergeDefaults(nil, { a = 1, t = { b = 2 } }); eq(sv.t.b, 2, "merge nested")
sv = PP.MergeDefaults({ a = 5 }, { a = 1 }); eq(sv.a, 5, "keep existing")

-- Phase 2
eq(PP.NextBracket(0, 75), 75, "0->75"); eq(PP.NextBracket(75, 150), 150, "75->150")
eq(PP.NextBracket(87, 300), 150, "87->150"); eq(PP.NextBracket(140, 75), 75, "capped by max")
eq(PP.NextBracket(299, 300), 300, "299->300"); eq(PP.NextBracket(300, 300), 300, "at cap")
eq(PP.COLOR[0], "orange", "color 0"); eq(PP.CHANCE.yellow, 0.6, "yellow chance")

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

print("all tests passed")
