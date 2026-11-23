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
local secs = { { key = "a", title = "A", rows = { { text = "x" } } }, { key = "b", title = "B", empty = "none", rows = {} } }
local v, k = TB.TabRows(secs, "a"); eq(#v, 1, "active rows"); eq(k, "a", "active key")
v, k = TB.TabRows(secs, "b"); eq(v[1].text, "none", "empty placeholder"); eq(v[1].empty, true, "empty flag")
v, k = TB.TabRows(secs, "zzz"); eq(k, "a", "unknown falls back to first")
eq(#TB.TabRows({}, "a"), 0, "no sections")

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
eq(#TB.WhereRows(TB.DATA.zones, TB.DATA.lures, { level = 2, modifier = 25 }, "Orgrimmar"), 13, "real data: 13 starter zones incl. Orgrimmar")

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
local C = { { key = "hut", name = "Hut", item = 3, skill = 300 },
  { key = "bowl", name = "Bowl", item = 1, skill = 20, aura = 11, reagents = { { 7, 1 }, { 8, 1 } } } }
local cr = TB.CampRows(C, { [11] = { active = true, remaining = 65 } }, { level = 200 }, {})
eq(cr[1].sub, "needs skill 300", "camp below skill"); eq(cr[2].sub, "1:05 left", "camp timer")
cr = TB.CampRows(C, {}, { level = 200 }, { [1] = 2 }); eq(cr[2].sub, "in bags (2)", "camp in bags")
cr = TB.CampRows(C, {}, { level = 200 }, { [7] = 1, [8] = 1 }); eq(cr[2].sub, "can craft", "camp can craft")
cr = TB.CampRows(C, {}, { level = 200 }, { [7] = 1 }); eq(cr[2].missing, 8, "camp missing reagent")
cr = TB.CampRows(C, { [11] = { active = true } }, { level = 300 }, {}); eq(cr[2].sub, "active", "camp secret timer"); eq(cr[1].sub, "available", "camp no reagents data")
eq(TB.CanCraft({ { 1, 2 } }, { [1] = 2 }), true, "craft ok"); eq(select(2, TB.CanCraft({ { 1, 2 }, { 5, 1 } }, { [1] = 1 })), 1, "craft first missing")
eq(TB.CanCraft({}, {}), true, "no reagents")
for _, ce in ipairs(TB.DATA.camp) do
  assert(ce.item and ce.recipe and ce.skill, "camp data " .. tostring(ce.key))
  for _, r in ipairs(ce.reagents or {}) do assert(r[1] and r[2], "camp reagent " .. ce.key) end
end

-- Phase 5
eq(TB.WaterWalkPick({ 1, 2 }, {}, false), nil, "none owned")
eq(TB.WaterWalkPick({ 1, 2 }, { [2] = 1 }, false), 2, "first present")
eq(TB.WaterWalkPick({ 1, 2 }, { [1] = 3, [2] = 1 }, false), 1, "preference order")
eq(TB.WaterWalkPick({ 1 }, { [1] = 1 }, true), nil, "aura active")
local wid, wok = TB.WaterWalkPick({ 1, 2 }, { [1] = 1, [2] = 1 }, false, 10, { [1] = 24 })
eq(wid, 2, "skips item above level"); eq(wok, true, "usable")
wid, wok = TB.WaterWalkPick({ 1 }, { [1] = 1 }, false, 10, { [1] = 24 })
eq(wid, 1, "locked water item"); eq(wok, false, "water locked flag")

-- Action bar
eq(TB.PickPole({ { id = 1, classID = 2, subID = 7 }, { id = 6256, classID = 2, subID = 20 } }), 6256, "pole found")
eq(TB.PickPole({ { id = 1, classID = 7, subID = 8 } }), nil, "no pole")
local LL = { { id = 1, bonus = 25, req = 0 }, { id = 2, bonus = 75, req = 100 }, { id = 3, bonus = 50, req = 50 } }
eq(TB.PickLure(LL, { [1] = 5, [3] = 1 }, false, 60), 3, "best usable lure")
eq(TB.PickLure(LL, { [1] = 5, [2] = 1 }, false, 5), 1, "skips lure above skill")
local lid, ok, req = TB.PickLure(LL, { [3] = 1, [2] = 1 }, false, 5)
eq(lid, 3, "locked: lowest requirement"); eq(ok, false, "locked flag"); eq(req, 50, "locked req")
eq(TB.PickLure(LL, { [1] = 5 }, true, 300), nil, "lure already on pole")
eq(TB.PickLure(LL, {}, false, 300), nil, "no lures")

-- Zone line
local ZD, LD = TB.DATA.zones, TB.DATA.lures
local zs = TB.ZoneStatus(ZD, LD, { level = 30, modifier = 0 }, "Orgrimmar")
eq(zs.text, "Orgrimmar: skill 1-55 [here]", "zone here"); eq(zs.flag, "here", "zone here flag")
eq(TB.ZoneStatus(ZD, LD, { level = 60, modifier = 0 }, "Orgrimmar").flag, "outgrown", "zone outgrown")
eq(TB.ZoneStatus(Z, L, { level = 30, modifier = 0 }, "Redridge Mountains").flag, "too low", "zone too low (cast 55)")
eq(TB.ZoneStatus(ZD, LD, { level = 230, modifier = 0 }, "Felwood").text:find("needs", 1, true) ~= nil, true, "zone lure need")
zs = TB.ZoneStatus(ZD, LD, { level = 100, modifier = 0 }, "Moonglade")
eq(zs.text, "Moonglade: no fishing data", "zone unknown"); eq(zs.flag, nil, "zone unknown flag")
eq(TB.ZoneStatus(ZD, LD, nil, "Orgrimmar"), nil, "zone no skill")
eq(TB.ZoneStatus(ZD, LD, { level = 100 }, ""), nil, "zone empty name")

-- Weapons
local bag = { { id = 5, link = "L5a", bag = 0, slot = 3 }, { id = 5, link = "L5b", bag = 1, slot = 2 }, { id = 9, link = "L9", bag = 2, slot = 1 } }
eq(TB.FindWeapon(bag, { id = 5, link = "L5b" }).slot, 2, "weapon exact link")
eq(TB.FindWeapon(bag, { id = 5, link = "Lx" }).slot, 3, "weapon id fallback")
eq(TB.FindWeapon(bag, { id = 7 }), nil, "weapon missing")
eq(TB.FindWeapon(bag, nil), nil, "weapon none remembered")
eq(TB.WeaponsMacro({ bag = 0, slot = 3 }), "/equipslot 16 0 3", "macro mh only")
eq(TB.WeaponsMacro({ bag = 0, slot = 3 }, { bag = 2, slot = 1 }), "/equipslot 16 0 3\n/equipslot 17 2 1", "macro mh+oh")
eq(TB.WeaponsMacro(nil, { bag = 2, slot = 1 }), nil, "macro no mh")

-- Cast key
eq(TB.NormalizeKey(" f "), "F", "key trim+upper"); eq(TB.NormalizeKey("shift-f"), "SHIFT-F", "key modifier")
eq(TB.NormalizeKey(""), nil, "key empty"); eq(TB.NormalizeKey(nil), nil, "key nil")

-- Spots
local SP = { A = { notable = { "Eel" }, pools = { "p1" } }, B = { notable = { "Cod" }, pools = {} }, C = { notable = { "Ray" }, pools = {} } }
local SZ = { { band = 1, max = 50, names = { "A", "B" } }, { band = 50, max = 100, names = { "C" } } }
local SPools = { { key = "p1", name = "Eel Swarm", icon = "i" } }
local sr = TB.SpotsRows(SP, SZ, SPools, { level = 10 }, "C")
eq(sr[1].text, "C [here]", "current zone first"); eq(#sr, 3, "band zones + current")
eq(sr[2].sub, "Eel - Eel Swarm", "notable + pool names"); eq(sr[2].icon, "i", "pool icon")
eq(#TB.SpotsRows(SP, SZ, SPools, nil, "A"), 0, "no skill")
eq(#TB.SpotsRows(SP, SZ, SPools, { level = 10 }, "Nowhere"), 2, "unknown current zone skipped")
eq(TB.PoolKey("Eel Swarm", SPools), "p1", "pool key"); eq(TB.PoolKey("x", SPools), nil, "no pool key")
eq(TB.PoolKey("School of Deviate Fish", TB.DATA.pools), "deviate", "probe 6B tooltip name matches")
for name, s in pairs(TB.DATA.spots) do for _, pk in ipairs(s.pools) do assert(TB.PoolByKey(TB.DATA.pools, pk), name .. " pool " .. pk) end end

-- Pools
local function r3(n) return math.floor(n * 1000 + 0.5) end
local ox, oy = TB.OffsetPos(0.5, 0.5, 0, 10, 1000, 1000); eq(r3(ox), 500, "north keeps x"); eq(r3(oy), 490, "north moves up")
ox, oy = TB.OffsetPos(0.5, 0.5, math.pi / 2, 10, 1000, 1000); eq(r3(ox), 490, "west moves left"); eq(r3(oy), 500, "west keeps y")
local pl = {}
local _, new = TB.MergePool(pl, 0.5, 0.5, "eel", 1, 15, 1000, 1000); eq(new, true, "first pool new")
_, new = TB.MergePool(pl, 0.505, 0.5, "eel", 2, 15, 1000, 1000); eq(new, false, "5 yd merges"); eq(pl[1].n, 2, "count bumped"); eq(pl[1].last, 2, "last updated")
eq(r3(pl[1].x * 10), 5025, "position averaged")
_, new = TB.MergePool(pl, 0.505, 0.5, "oily", 3, 15, 1000, 1000); eq(new, true, "other type separate")
_, new = TB.MergePool(pl, 0.6, 0.5, "eel", 4, 15, 1000, 1000); eq(new, true, "100 yd separate")
local near = TB.NearestPools(pl, 0.6, 0.5, 1000, 1000, 2); eq(#near, 2, "max respected"); eq(near[1].pool.x, 0.6, "nearest first")
eq(#TB.NearestPools({}, 0, 0, 1, 1), 0, "no pools")

-- Detector
local al = {}
eq(TB.ShouldAlert(al, "p", 0, 60), true, "first alert"); eq(TB.ShouldAlert(al, "p", 30, 60), false, "cooldown")
eq(TB.ShouldAlert(al, "q", 30, 60), true, "other pool"); eq(TB.ShouldAlert(al, "p", 61, 60), true, "after cooldown")

-- Camp button
local CC = { { key = "hut", item = 3, skill = 300 }, { key = "bowl", item = 1, skill = 20 } }
local function Pick(st) st.camp = CC; st.fires = { 50 }; st.owned = st.owned or {}; return { TB.CampPick(st) } end
local p1 = Pick({ skill = { level = 100 }, owned = { [50] = 1, [1] = 1 } })
eq(p1[1], "fire", "camp fire first"); eq(p1[2], 50, "camp kit id"); eq(p1[3], true, "camp kit usable")
local p2 = Pick({ skill = { level = 100 }, owned = { [1] = 1 } }); eq(p2[1], "place", "camp no kit places"); eq(p2[4], "Place near a campfire", "camp fire hint")
local p3 = Pick({ skill = { level = 100 }, owned = { [50] = 1, [1] = 1 }, fireUp = true }); eq(p3[1], "place", "camp place"); eq(p3[2], 1, "camp bowl")
eq(Pick({ skill = { level = 300 }, owned = { [1] = 1, [3] = 1 }, fireUp = true })[2], 3, "camp best by skill")
local p5 = Pick({ skill = { level = 100 }, owned = { [3] = 1 }, fireUp = true }); eq(p5[3], false, "camp locked"); eq(p5[4], "Requires Fishing 300", "camp locked need")
eq(Pick({ skill = { level = 100 }, owned = { [1] = 1 }, campActive = true, fireUp = true })[1], nil, "camp buff up")
eq(Pick({ skill = { level = 100 } })[1], nil, "camp nothing owned")

print("all tests passed")
