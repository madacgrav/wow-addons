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
eq(PP.FormatMoney(0), "|cffeda55f0c|r", "zero"); eq(PP.FormatMoney(12345), "|cffffd7001g|r |cffc7c7cf23s|r |cffeda55f45c|r", "gsc")
eq(PP.FormatMoney(166.7), "|cffc7c7cf1s|r |cffeda55f66c|r", "floors fractions")

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

-- Prices phase 3
local pr, src = PP.PickPrice(90, 120, 100, true); eq(pr, 90, "vendor cheaper"); eq(src, "vendor", "vendor src")
pr, src = PP.PickPrice(90, 50); eq(pr, 50, "AH cheaper"); eq(src, "AH", "AH src")
eq(PP.PickPrice(nil, 70), 70, "AH only")
pr, src = PP.PickPrice(nil, nil, 100, true); eq(pr, 100, "seed fallback"); eq(src, "est.", "est src")
eq(PP.PickPrice(nil, nil, 100, false), nil, "seed needs a known vendor")
st = PP.Plan(S({ recipes = { [2] = R[2] }, prices = {} })); eq(st[1].estimated, true, "unpriced reagent is estimated")
st = PP.Plan(S({ recipes = { [2] = R[2] } })); eq(st[1].estimated, nil, "priced not estimated")
list = PP.ShoppingList({ { recipeID = 2, crafts = 1 } }, R, {}, { [11] = 100 }, { [11] = "AH" }); eq(list[1].source, "AH", "source passed")

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

-- Stations
local stn = PP.StationNames({ { type = 0, name = "Loom", met = false }, { type = 1, name = "Other" }, { type = 0, name = "Moonwell", met = true } })
eq(#stn, 2, "only type 0"); eq(stn[1], "Loom", "Loom"); eq(stn[2], "Moonwell", "Moonwell")
eq(#PP.StationNames(nil), 0, "nil reqs")

print("all tests passed")
