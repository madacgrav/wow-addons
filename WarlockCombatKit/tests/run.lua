local dir = ((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
local WCK = {}
assert(loadfile(dir .. "/Logic.lua"))("WarlockCombatKit", WCK)

local function eq(got, want, label)
  if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end
local function near(got, want, label)
  if math.abs(got - want) > 1e-9 then error(label .. ": expected " .. want .. ", got " .. got, 2) end
end

-- Phase 1
local m = WCK.MergeDefaults(nil, { a = 1, t = { b = 2 } })
eq(m.a, 1, "fills scalar"); eq(m.t.b, 2, "fills nested")
m = WCK.MergeDefaults({ a = 5, t = "bad" }, { a = 1, t = { b = 2 } })
eq(m.a, 5, "keeps saved"); eq(m.t.b, 2, "replaces non-table")

print("all tests passed")
