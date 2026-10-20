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

-- Phase 3
eq(WUK.SoulstoneRemaining(nil, 100), nil, "ss absent")
eq(WUK.SoulstoneRemaining({ expires = 100 }, 100), nil, "ss expired")
eq(WUK.SoulstoneRemaining({ expires = 160 }, 100), 60, "ss active")

-- Phase 4
for _, t in ipairs({ "123", "sum", "Summon pls", "can i get a port?", "SUM me" }) do eq(WUK.IsSummonRequest(t), true, "yes: " .. t) end
for _, t in ipairs({ "1234", "summoner", "portal", "sumo", "", 5 }) do eq(WUK.IsSummonRequest(t), false, "no: " .. tostring(t)) end
local q = {}
eq(WUK.QueueAdd(q, "Bob", 2), true, "add"); eq(WUK.QueueAdd(q, "Bob", 2), false, "dedupe")
WUK.QueueAdd(q, "Ann", 2); eq(WUK.QueueAdd(q, "Cid", 2), false, "max")
WUK.QueueRemove(q, "Bob"); eq(#q, 1, "remove"); eq(q[1].name, "Ann", "order")
WUK.QueuePrune(q, function() return false end); eq(#q, 0, "prune")
local base = { inGroup = true, connected = true, dead = false, here = false, shards = 1, helpers = 2 }
local function with(o) local c = {}; for k, v in pairs(base) do c[k] = v end; for k, v in pairs(o) do c[k] = v end; return c end
eq(WUK.SummonFailure(base), nil, "ok")
eq(WUK.SummonFailure(with({ inGroup = false })), "not in group", "group")
eq(WUK.SummonFailure(with({ connected = false })), "offline", "offline")
eq(WUK.SummonFailure(with({ dead = true })), "dead", "dead")
eq(WUK.SummonFailure(with({ here = true })), "already here", "here")
eq(WUK.SummonFailure(with({ shards = 0 })), "no shard", "shard")
eq(WUK.SummonFailure(with({ helpers = 1 })), "need 2 helpers", "helpers")
local unknown = with({}); unknown.helpers = nil
eq(WUK.SummonFailure(unknown), nil, "unknown helpers ok")

-- Phase 5
eq(WUK.IsHealthstoneRequest("hs pls"), true, "hs"); eq(WUK.IsHealthstoneRequest("Healthstone?"), true, "healthstone")
eq(WUK.IsHealthstoneRequest("this is it"), false, "no hs in words"); eq(WUK.IsHealthstoneRequest("Stone ready - open a trade with me."), false, "reply safe")

-- Phase 7
eq(WUK.StoneMacro("shard", 5, 6265, nil), nil, "shard no action")
eq(WUK.StoneMacro("healthstone", 1, 9421, "Create Healthstone (Major)"), "/use item:9421", "use hs")
eq(WUK.StoneMacro("healthstone", 0, nil, "Create Healthstone (Major)"), "/cast Create Healthstone (Major)", "create hs")
eq(WUK.StoneMacro("soulstone", 1, 16893, nil), "/use [help] item:16893; [@player] item:16893", "use ss")
eq(WUK.StoneMacro("firestone", 0, nil, nil), nil, "unknown spell")

-- v2 Phase 2
eq(WUK.MarkToken(1), "{rt1}", "mark 1"); eq(WUK.MarkToken(8), "{rt8}", "mark 8"); eq(WUK.MarkToken(0), "", "mark none")
eq(WUK.AssignmentText(nil), "No assignment", "no row")
eq(WUK.AssignmentText({ mark = 0 }), "No assignment", "empty row")
eq(WUK.AssignmentText({ curse = "elements", mark = 1, ss = "Healbot" }), "Elements  Banish {rt1}  SS: Healbot", "full row")
eq(WUK.AssignmentText({ curse = "mystery", mark = 0 }), "mystery", "unknown curse key shown raw")
eq(WUK.StoneMacro("soulstone", 1, 16893, nil, "Healbot"), "/use [@Healbot] item:16893", "ss on assigned target")
eq(WUK.NextRev(5, 3), 6, "rev bumps"); eq(WUK.NextRev(5, 100), 100, "rev uses clock")

-- v2 Phase 3
local m = WUK.Decode(WUK.Encode("A", 12, "Lockone", "elements", 3, nil))
eq(m.kind, "A", "decode A"); eq(m.rev, 12, "rev"); eq(m.warlock, "Lockone", "warlock")
eq(m.curse, "elements", "curse"); eq(m.mark, 3, "mark"); eq(m.ss, nil, "ss nil")
eq(WUK.Encode("A", 12, "Lockone", nil, 0, nil), "1|A|12|Lockone|-|0|-", "encode nils")
eq(WUK.Decode(WUK.Encode("R")).kind, "R", "decode R")
eq(WUK.Decode(WUK.Encode("L", 7)).rev, 7, "decode L")
eq(WUK.Decode("2|L|7"), nil, "bad version"); eq(WUK.Decode("1|A|x|a|b|0|-"), nil, "bad rev")
eq(WUK.Decode("1|A|5|-|b|0|-"), nil, "no warlock"); eq(WUK.Decode(nil), nil, "nil msg")
local brd = { lead = "Lead", rev = 10, rows = {} }
eq(WUK.AcceptRow(brd, "Other", 11), false, "non-lead row"); eq(WUK.AcceptRow(brd, "Lead", 9), false, "old row")
eq(WUK.AcceptRow(brd, "Lead", 10), true, "same rev ok")
eq(WUK.AcceptLead(brd, 10), false, "stale claim"); eq(WUK.AcceptLead(brd, 11), true, "newer claim")

-- v2 Phase 4
local lines = WUK.AnnounceLines({ rows = {
  Zed = { curse = "tongues", mark = 0 }, Abe = { curse = "elements", mark = 1, ss = "Healbot" }, Mia = { mark = 0 } } })
eq(#lines, 2, "skips empty"); eq(lines[1], "WUK: Abe - Curse of the Elements - Banish {rt1} - SS: Healbot", "abe line")
eq(lines[2], "WUK: Zed - Curse of Tongues", "zed line")

-- Ring layout
local function near(got, want, label)
  if math.abs(got - want) > 1e-9 then error(label .. ": expected " .. want .. ", got " .. got, 2) end
end
local x, y = WUK.RingPoint(1, 6, 58, 0); near(x, 0, "ring top x"); near(y, 58, "ring top y")
x, y = WUK.RingPoint(4, 6, 58, 0); near(x, 0, "ring bottom x"); near(y, -58, "ring bottom y")
x = WUK.RingPoint(2, 6, 58, 0); assert(x > 0, "ring goes clockwise")
x, y = WUK.RingPoint(1, 6, 58, 90); near(x, 58, "offset rotates x"); near(y, 0, "offset rotates y")
x, y = WUK.RingPoint(3, 6, 0, 45); near(x, 0, "collapsed x"); near(y, 0, "collapsed y")

print("all tests passed")
