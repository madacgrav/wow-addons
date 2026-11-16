local dir = ((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
local BC = {}
assert(loadfile(dir .. "/Data.lua"))("BusinessCard", BC)
assert(loadfile(dir .. "/Logic.lua"))("BusinessCard", BC)

local function eq(got, want, label)
  if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end

-- Phase 1
local t = BC.MergeDefaults(nil, { a = 1, f = { x = 2 } })
eq(t.a, 1, "defaults scalar"); eq(t.f.x, 2, "defaults nested")
t = BC.MergeDefaults({ a = 5, f = { y = 3 } }, { a = 1, f = { x = 2 } })
eq(t.a, 5, "existing kept"); eq(t.f.x, 2, "nested default added"); eq(t.f.y, 3, "nested existing kept")

print("all tests passed")
