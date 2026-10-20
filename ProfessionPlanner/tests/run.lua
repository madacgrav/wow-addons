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

print("all tests passed")
