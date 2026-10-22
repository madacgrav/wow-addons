local dir = ((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
local TB = {}
assert(loadfile(dir .. "/Data.lua"))("TackleBox", TB)
assert(loadfile(dir .. "/Logic.lua"))("TackleBox", TB)

local function eq(got, want, label)
  if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end

-- Phase 1
local t = TB.MergeDefaults(nil, { a = 1, f = {} }); eq(t.a, 1, "defaults scalar"); eq(type(t.f), "table", "defaults table")
eq(TB.FormatTime(75), "1:15", "format time")
eq(TB.SkillText(nil), "No Fishing skill", "no skill")
eq(TB.SkillText({ level = 120, max = 150, modifier = 25 }), "Fishing 120/150 (+25)", "skill with mod")
local v = TB.BuildView({ { key = "a", title = "A", rows = { { text = "x" } } }, { key = "b", title = "B", rows = {} } }, {})
eq(#v, 2, "empty section hidden"); eq(v[1].header, "a", "header row"); eq(v[1].text, "- A (1)", "open header")
v = TB.BuildView({ { key = "a", title = "A", rows = { { text = "x" } } } }, { a = true })
eq(#v, 1, "collapsed hides rows"); eq(v[1].text, "+ A (1)", "closed header")

-- Phase 2
local q = TB.QuestRows({ { id = 1, need = 2, zone = "Z" }, { id = 2, need = 1, zone = "Y" } }, { [1] = 2 })
eq(q[1].itemID, 2, "incomplete first"); eq(q[2].done, true, "complete"); eq(q[1].sub, "0/1  Y", "zero have")
eq(#TB.DATA.questFish, 4, "four quest fish")

-- Phase 2b
local Z = { { band = 1, max = 75, noLoss = 25, names = { "Elwynn Forest" } }, { band = 75, max = 150, cast = 55, noLoss = 150, names = { "Redridge Mountains" } },
  { band = 225, max = 300, lure = 75, names = { "Feralas" } } }
local L = { { name = "Bright Baubles", bonus = 75 } }
local w = TB.WhereRows(Z, L, { level = 1, modifier = 0 }, "Elwynn Forest")
eq(#w, 1, "skill 1 one zone"); eq(w[1].flag, "here", "here flag"); eq(w[1].text, "Elwynn Forest [here]", "here text")
w = TB.WhereRows(Z, L, { level = 80, modifier = 0 }, "Elwynn Forest")
eq(w[1].text, "Redridge Mountains", "band 75 zone"); eq(w[2].flag, "outgrown", "outgrown current")
w = TB.WhereRows(Z, L, { level = 230, modifier = 0 }, "Feralas")
eq(w[1].sub, "skill 225-300, needs Bright Baubles", "lure note")
w = TB.WhereRows(Z, L, { level = 230, modifier = 75 }, "Nowhere"); eq(w[1].sub, "skill 225-300", "lure satisfied")
w = TB.WhereRows(Z, L, { level = 40, modifier = 0 }, "Redridge Mountains"); eq(w[#w].flag, "too low", "too low")
eq(#TB.WhereRows(Z, L, nil, "x"), 0, "no skill")
eq(#TB.WhereRows(TB.DATA.zones, TB.DATA.lures, { level = 2, modifier = 25 }, "Orgrimmar"), 7, "real data: 6 starting zones + Orgrimmar")

-- Phase 3
local S = { [7620] = true }
eq(TB.IsFishingCatch(true, nil, 0, S), true, "api true"); eq(TB.IsFishingCatch(false, { spellID = 7620, stopT = 0 }, 1, S), false, "api false wins")
eq(TB.IsFishingCatch(nil, { spellID = 7620, stopT = 10 }, 12, S), true, "fallback recent")
eq(TB.IsFishingCatch(nil, { spellID = 7620, stopT = 10 }, 50, S), false, "fallback stale")
eq(TB.IsFishingCatch(nil, { spellID = 1, stopT = 10 }, 11, S), false, "other spell")
local c = TB.RecordCatch({}, 5, 1, 100, "Z", 1); TB.RecordCatch(c, 5, 2, 200, "Z", 2); TB.RecordCatch(c, 5, 1, 300, "Y", 1)
eq(c[5].n, 4, "accumulate"); eq(c[5].first, 100, "first kept"); eq(c[5].zones.Z, 3, "zone count"); eq(c[5].q, 2, "best quality kept")
local cv = TB.CollectionView({ [9] = { tier = "rare" }, [8] = { tier = "unique", knife = 77 } }, { [5] = c[5], [6] = { n = 1, zones = {} } }, function() return 1 end)
eq(cv[1].itemID, 5, "loot quality 2 -> uncommon first"); eq(cv[2].itemID, 9, "rare"); eq(cv[2].caught, false, "not caught")
eq(cv[3].knife, 77, "knife"); eq(cv[4].tier, "other", "other bucket"); eq(cv[4].quality, 1, "base quality fallback")
local tz = TB.TopZones({ A = 1, B = 5, C = 3, D = 2 }, 3); eq(#tz, 3, "top 3"); eq(tz[1].zone, "B", "most first")

-- Phase 3b
local f, left = TB.CastProgress(1000, 21000, 1000); eq(f, 0, "start"); eq(left, 20, "left at start")
f = TB.CastProgress(1000, 21000, 11000); eq(f, 0.5, "mid")
f, left = TB.CastProgress(1000, 21000, 30000); eq(f, 1, "clamped end"); eq(left, 0, "no negative")
eq(TB.CastProgress(nil, 21000, 0), nil, "nil start")
eq(TB.IsMiss(10, nil), true, "no loot"); eq(TB.IsMiss(10, 9.7), false, "loot just before stop")
eq(TB.IsMiss(10, 10.01), false, "loot after stop"); eq(TB.IsMiss(10, 5), true, "old loot")

-- Phase 4
local B = { { spellID = 1, name = "Rack", unlock = 140 }, { spellID = 2, name = "Hut", unlock = 300 }, { name = "Fire", unlock = 1, subzone = "Camp" } }
local cr = TB.CampRows(B, { [1] = { active = true, remaining = 65 }, [2] = { active = false } }, { level = 200 }, "Camp")
eq(cr[1].sub, "1:05 left", "timer"); eq(cr[2].sub, "needs skill 300", "below unlock"); eq(cr[3].sub, "active", "subzone active")
cr = TB.CampRows(B, { [1] = { active = true } }, { level = 300 }, nil)
eq(cr[1].sub, "active", "secret timer"); eq(cr[2].sub, "available", "eligible")

print("all tests passed")
