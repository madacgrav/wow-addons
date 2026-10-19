local dir = ((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
local WUK = {}
assert(loadfile(dir .. "/Logic.lua"))("WarlockUtilityKit", WUK)

local function eq(got, want, label)
  if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end

-- Phase 1
eq(WUK.ClassifyItem("Soul Shard"), "shard", "shard")
eq(WUK.ClassifyItem("Major Healthstone"), "healthstone", "hs rank")
eq(WUK.ClassifyItem("Greater Soulstone"), "soulstone", "ss rank")
eq(WUK.ClassifyItem("Spellstone"), "spellstone", "spellstone")
eq(WUK.ClassifyItem("Lesser Firestone"), "firestone", "firestone")
eq(WUK.ClassifyItem("Linen Cloth"), nil, "other item")
eq(WUK.ClassifyItem(nil), nil, "nil name")
local sv = WUK.MergeDefaults(nil, { a = 1, t = { b = 2 } })
eq(sv.a, 1, "merge nil"); eq(sv.t.b, 2, "merge nested")
sv = WUK.MergeDefaults({ a = 5, t = {} }, { a = 1, t = { b = 2 } })
eq(sv.a, 5, "keep existing"); eq(sv.t.b, 2, "fill nested")
eq(WUK.FormatTime(1799), "29:59", "format")

print("all tests passed")
