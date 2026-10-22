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

print("all tests passed")
