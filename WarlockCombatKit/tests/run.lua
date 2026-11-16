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

-- Phase 3
eq(WCK.RowHasCC({ icons = { { kind = "cc", age = 5, stale = 20 } } }), true, "fresh fear")
eq(WCK.RowHasCC({ icons = { { kind = "cc", age = 25, stale = 20 } } }), false, "stale fear")
eq(WCK.RowHasCC({ icons = { { kind = "dot", age = 1, stale = 20 } } }), false, "dot only")

-- Phase 4
local PR = { { key = "nightfall", spell = "Shadow Bolt" } }
eq(WCK.ProcsUp(PR, { ["Shadow Bolt"] = 0 }).nightfall, true, "instant = proc")
eq(WCK.ProcsUp(PR, { ["Shadow Bolt"] = 3000 }).nightfall, nil, "normal cast")
eq(WCK.ProcsUp(PR, {}).nightfall, nil, "unknown spell")
eq(#WCK.NewProcs({}, { nightfall = true }), 1, "rising edge"); eq(#WCK.NewProcs({ nightfall = true }, { nightfall = true }), 0, "no repeat")

-- Phase 5
local st = { known = { ["Corruption"] = true, ["Shadow Bolt"] = true }, ready = {}, usable = {}, lastOnTarget = {}, proc = false, marked = false }
local rules = { { spell = "Corruption", cond = "notRecent", n = 15 }, { spell = "Shadow Bolt", cond = "proc" }, { spell = "Shadow Bolt", cond = "ready" } }
eq(WCK.EvalRules(rules, st), "Corruption", "first rule")
st.lastOnTarget.Corruption = 3; eq(WCK.EvalRules(rules, st), "Shadow Bolt", "recent skips")
st.lastOnTarget.Corruption = 15; eq(WCK.EvalRules(rules, st), "Corruption", "boundary passes")
st.lastOnTarget.Corruption = 1; st.ready["Shadow Bolt"] = false; eq(WCK.EvalRules(rules, st), nil, "cooldown blocks")
st.ready["Shadow Bolt"] = nil; st.known["Shadow Bolt"] = nil; eq(WCK.EvalRules(rules, st), nil, "unknown skipped")
eq(WCK.EvalRules({ { spell = "Corruption", cond = "marked" } }, { known = { Corruption = true }, ready = {}, usable = {}, lastOnTarget = {}, marked = true }), "Corruption", "marked")
eq(WCK.EvalRules({ { spell = "Corruption", cond = "usable" } }, { known = { Corruption = true }, ready = {}, usable = { Corruption = false }, lastOnTarget = {} }), nil, "unusable")
eq(WCK.EvalRules({}, st), nil, "empty list")
eq(WCK.EvalRules({ { spell = "Corruption", cond = "bogus" } }, st), nil, "unknown cond")
local rl = { { spell = "A" }, { spell = "B" } }
eq(WCK.MoveRule(rl, 2, -1), true, "move up"); eq(rl[1].spell, "B", "swapped")
eq(WCK.MoveRule(rl, 1, -1), false, "top edge"); eq(WCK.MoveRule(rl, 2, 1), false, "bottom edge")
local c = WCK.CopyRules(rl); c[1].spell = "Z"; eq(rl[1].spell, "B", "copy is deep")

-- Phase 6
eq(WCK.CastMacro("Corruption"), "/cast [@mouseover,harm,nodead][] Corruption", "macro")
eq(WCK.CastMacro(nil), "", "no spell"); eq(WCK.CastMacro(""), "", "empty spell")
eq(WCK.CastMacro("Curse of Agony"), "/cast [@mouseover,harm,nodead][] Curse of Agony", "spaces kept")

-- GH-28 Phase 1
local tabs, set = WCK.BuildSpellTabs({
  { tab = "General", name = "Auto Attack", itemType = 1 },
  { tab = "Affliction", name = "Wrack", itemType = 1 },
  { tab = "Affliction", name = "Corruption", itemType = 1 },
  { tab = "Affliction", name = "Nightfall", itemType = 1, isPassive = true },
  { tab = "Affliction", name = "Haunt", itemType = 2 },      -- future spell
  { tab = "Demonology", name = "Summon Imp", itemType = 4 },  -- flyout: tab ends up empty
  { tab = "Destruction", name = "Corruption", itemType = 1 }, -- duplicate: first tab wins
})
eq(#tabs, 2, "empty tab dropped"); eq(tabs[1].name, "General", "book order")
eq(tabs[2].spells[1], "Corruption", "sorted"); eq(tabs[2].spells[2], "Wrack", "sorted 2"); eq(#tabs[2].spells, 2, "passive+future dropped")
eq(set.Wrack, true, "set"); eq(set.Nightfall, nil, "passive not in set")
local rs = WCK.RuleSpells({ { spell = "Corruption" }, { spell = "Shadow Bolt" }, { spell = "Corruption" }, { spell = "" }, {} })
eq(#rs, 2, "distinct"); eq(rs[1], "Corruption", "order"); eq(rs[2], "Shadow Bolt", "order 2")
eq(#WCK.RuleSpells(nil), 0, "nil rules")

-- GH-28 Phase 2
local tl = { "Shadow Bolt", "Fear", "Banish" }
local all = { ["Shadow Bolt"] = true, Fear = true, Banish = true }
local bs = WCK.BarSpells({ { spell = "Corruption" }, { spell = "Shadow Bolt" }, { spell = "Immolate" }, { spell = "Corruption" } }, tl, all)
eq(#bs, 5, "rules + tail"); eq(bs[1].spell, "Corruption", "rule order"); eq(bs[2].spell, "Immolate", "bolt pulled out of rules")
eq(bs[2].tail, false, "rule flag"); eq(bs[3].spell, "Shadow Bolt", "bolt first in tail"); eq(bs[3].tail, true, "tail flag")
eq(bs[4].spell, "Fear", "fear second"); eq(bs[5].spell, "Banish", "banish last")
bs = WCK.BarSpells({ { spell = "Fear" } }, tl, { Fear = true })
eq(#bs, 1, "fear moves to tail, unknown tail spells skipped"); eq(bs[1].tail, true, "fear in tail")
eq(#WCK.BarSpells({}, tl, {}), 0, "nothing known")

print("all tests passed")
