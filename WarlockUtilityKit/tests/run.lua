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

-- Phase 2
local function state(o)
  local s = { known = { armor = "Demon Armor", detect = "Detect Invisibility", imp = "Summon Imp",
      felhunter = "Summon Felhunter", healthstone = "Create Healthstone", soulstone = "Create Soulstone" },
    counts = { shard = 3, healthstone = 0, soulstone = 0, ids = {} }, buffs = {}, pet = nil,
    preferredPet = "felhunter", soulstoneActive = false }
  for k, v in pairs(o or {}) do s[k] = v end
  return s
end
local steps = WUK.PrepSteps(state())
eq(steps[1].key, "armor", "armor first"); eq(steps[2].key, "detect", "detect second")
eq(steps[3].macro, "/cast Summon Felhunter", "preferred pet"); eq(steps[4].key, "healthstone", "hs")
eq(steps[5].key, "soulstone", "ss create"); eq(#steps, 5, "count fresh")
local done = state({ buffs = { ["Demon Armor"] = true, ["Detect Invisibility"] = true }, pet = "felhunter",
  counts = { shard = 1, healthstone = 1, soulstone = 0, ids = {} }, soulstoneActive = true })
eq(#WUK.PrepSteps(done), 0, "fully prepped")
local noShard = WUK.PrepSteps(state({ buffs = { ["Demon Armor"] = true, ["Detect Invisibility"] = true },
  counts = { shard = 0, healthstone = 1, soulstone = 0, ids = {} } }))
eq(noShard[1].macro, "/cast Summon Imp", "imp fallback"); eq(#noShard, 1, "no shard skips stones")
eq(#WUK.PrepSteps(state({ buffs = { ["Demon Armor"] = true, ["Detect Invisibility"] = true }, pet = "felhunter",
  counts = { shard = 0, healthstone = 1, soulstone = 0, ids = {} } })), 0, "keeps felhunter when broke")
local use = WUK.PrepSteps(state({ buffs = { ["Demon Armor"] = true, ["Detect Invisibility"] = true }, pet = "felhunter",
  counts = { shard = 2, healthstone = 1, soulstone = 1, ids = { soulstone = 16893 } } }))
eq(use[1].key, "usesoulstone", "use ss"); eq(use[1].macro, "/target player\n/use item:16893\n/targetlasttarget", "use macro")
eq(#WUK.PrepSteps(state({ buffs = { demonicSacrifice = true, ["Demon Armor"] = true, ["Detect Invisibility"] = true },
  counts = { shard = 1, healthstone = 1, soulstone = 0, ids = {} }, soulstoneActive = true })), 0, "demonic sacrifice skips pet")

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

print("all tests passed")
