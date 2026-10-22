local dir = ((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
local WCK = {}
assert(loadfile(dir .. "/Data.lua"))("WarlockCombatKit", WCK)
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

-- Phase 2
local k, l = WCK.EnemyKey("G1", "Boar"); eq(k, "guid:G1", "guid wins"); eq(l, "Boar", "label kept")
eq((WCK.EnemyKey(nil, "Boar")), "name:Boar", "name next"); eq((WCK.EnemyKey(nil, nil)), "target", "all secret")
eq(WCK.PickUnit("Boar", { target = "Wolf", mouseover = "Boar" }), "mouseover", "mouseover match")
eq(WCK.PickUnit("Wolf", { target = "Wolf" }), "target", "target match")
eq(WCK.PickUnit("Boar", { target = "Boar", mouseover = "Boar" }), "target", "same name prefers target")
eq(WCK.PickUnit(nil, { target = "Wolf" }), "target", "secret name")
local map = WCK.NewCastMap()
WCK.CastSent(map, "c1", "Corruption", "guid:G1", "Boar", "G1", 100)
WCK.CastSent(map, "c2", "Fear", "name:Wolf", "Wolf", nil, 100.5)
eq(map.rows["guid:G1"], nil, "not landed yet")
WCK.CastSucceeded(map, "c2", 101); WCK.CastSucceeded(map, "c1", 101.5)
eq(map.rows["guid:G1"].casts.Corruption, 101.5, "c1 landed"); eq(map.rows["name:Wolf"].casts.Fear, 101, "c2 landed")
WCK.CastSent(map, "c3", "Immolate", "guid:G1", "Boar", "G1", 102); WCK.CastFailed(map, "c3"); WCK.CastSucceeded(map, "c3", 103)
eq(map.rows["guid:G1"].casts.Immolate, nil, "failed dropped")
WCK.CastFailed(map, "never-sent"); eq(next(map.pending), nil, "unknown failed is a no-op")
WCK.CastSent(map, "old", "Fear", "x", nil, nil, 0); WCK.CastSent(map, "new", "Fear", "x", nil, nil, 20)
eq(map.pending.old, nil, "stale pending pruned")
near(WCK.IconAlpha(0, 10), 1, "fresh"); near(WCK.IconAlpha(5, 10), 0.65, "half"); near(WCK.IconAlpha(30, 10), 0.3, "floor")
local v = WCK.RowsView(map, 110, WCK.DATA.tracked)
eq(#v, 2, "two rows"); eq(v[1].key, "guid:G1", "newest row first"); eq(v[1].icons[1].spell, "Corruption", "icon")
WCK.CastLanded(map, "guid:G9", "Imp", "G9", "Fear", 111); eq(WCK.ClearGUID(map, "G9"), 1, "cleared one"); eq(map.rows["guid:G9"], nil, "clear by guid")
eq(WCK.ClearGUID(map, "nope"), 0, "no match clears none")
WCK.ClearAll(map); eq(next(map.rows), nil, "clear all")

print("all tests passed")
