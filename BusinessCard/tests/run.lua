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

-- Phase 2
local function cats(r) local t = {} for _, c in ipairs(BC.CATS) do if r and r.cats[c] then t[#t + 1] = c end end return table.concat(t, ",") end
local r = BC.Classify("WTS enchants, your mats, tips appreciated")
eq(cats(r), "enchanting", "wts enchants"); eq(r.request, false, "wts is offer")
r = BC.Classify("LF enchanter for crusader"); eq(cats(r), "enchanting", "lf enchanter"); eq(r.request, true, "lf is request")
r = BC.Classify("LFW tailor, can do mooncloth"); eq(cats(r), "tailoring", "lfw tailor"); eq(r.request, false, "lfw is offer")
r = BC.Classify("WTS ports to UC and Org"); eq(cats(r), "portal", "ports"); eq(r.dest, "UC", "first dest")
r = BC.Classify("summons to BRD 5g"); eq(cats(r), "summon", "summons")
r = BC.Classify("LF summon to Strath"); eq(cats(r), "summon", "lf summon"); eq(r.request, true, "lf summon request")
eq(cats(BC.Classify("portal")), "portal", "portal alone")
eq(BC.Classify("supporting important"), nil, "whole token only")
eq(BC.Classify("LF tank for SM"), nil, "lfg post ignored")
eq(cats(BC.Classify("|cffffffff|Henchant:13931|h[Enchant Bracer - Deflection]|h|r 2g")), "enchanting", "enchant link")
eq(cats(BC.Classify("|cffffd000|Htrade:Player-1:333:333|h[Enchanting]|h|r")), "enchanting", "trade link")
eq(cats(BC.Classify("WTS |cff1eff00|Hitem:13446::::::::60:::::|h[Major Healing Potion]|h|r")), "alchemy", "item link")
eq(BC.Classify(nil), nil, "non-string")
eq(BC.Classify("portal to if").dest, nil, "'if' is not a destination")

-- real Trade lines from the 0.2.1 in-game test: ad = true means kept
local function ad(text) local x = BC.Classify(text); return x ~= nil and not x.request end
eq(ad("lfm uldaman enchanting run. 225-250 training"), false, "group post")
eq(ad("~300~  |cffffd000|Htrade:Player-6929-00166F7D:13920:333|h[Enchanting]|h|r Zyns Emporium is now OPEN"), true, "trade link shop")
eq(ad("FREE PORT TO TB"), true, "free port")
eq(ad("BS LFW CAN APPLY ANY SPURS"), true, "bs lfw")
eq(ad("<ChatDPS> is recruiting! Recruiting all classes, engineers welcome"), false, "guild recruit")
eq(ad("can i not train alch pass 75 in undercity???"), false, "question chatter")
eq(ad("Providing Mage services, Water/Food (have 55), can TP to you and provide Portals. Tips appreciated :)!"), true, "mage services")
eq(ad("lf free port to UC cause you're a cool guy B)"), false, "lf free port")
eq(ad("WTS |cffffd000|Henchant:1257412|h[Tailoring: Silk Reagent Bag]|h|r your mats or mine"), true, "wts bag")
eq(ad("Lockpick in the area! Calling all lockboxes (140)!"), true, "lockpick")
eq(ad("youre not a bot, youll never make money enchanting"), false, "chatter")
eq(ad("summons to BRD 5g"), true, "price is offer")

eq(BC.ChannelKey("Trade - English 53"), "Trade", "channel key trade")
eq(BC.ChannelKey("Trade (Services) - English 53"), "Trade (Services)", "channel key services")
eq(BC.ChannelKey("General - Orgrimmar"), "General", "channel key general")
eq(BC.ChannelKey("LookingForGroup"), "LookingForGroup", "channel key bare")
eq(BC.ChannelKey(nil), nil, "channel key nil")

local seen = {}
BC.SeenAdd(seen, "Bob", BC.Classify("WTS enchants"), "WTS enchants", 100)
local e = BC.SeenAdd(seen, "Bob", BC.Classify("WTS ports"), string.rep("x", 200), 200)
eq(e.cats.enchanting, 100, "first cat kept"); eq(e.cats.portal, 200, "second cat added"); eq(#e.text, 120, "text truncated")
eq(e.at, 200, "at updated")

seen = { Old = { cats = {}, at = 0 }, A = { cats = {}, at = 900000 }, B = { cats = {}, at = 900001 }, C = { cats = {}, at = 900002 } }
BC.SeenPrune(seen, 7 * 86400 + 1, 7 * 86400, 2)
eq(seen.Old, nil, "old pruned"); eq(seen.A, nil, "cap drops oldest"); eq(seen.B ~= nil and seen.C ~= nil, true, "newest kept")

-- Phase 3
eq(BC.FormatAge(30), "now", "age now"); eq(BC.FormatAge(125), "2m", "age m")
eq(BC.FormatAge(7200), "2h", "age h"); eq(BC.FormatAge(200000), "2d", "age d")
seen = { A = { cats = { enchanting = 1 }, at = 100, text = "a" }, B = { cats = { portal = 1 }, at = 300, text = "b" },
  C = { cats = { enchanting = 1, portal = 1 }, at = 200, text = "c" } }
local rows = BC.SeenRows(seen, nil, "all", 400)
eq(#rows, 3, "all rows"); eq(rows[1].name, "B", "newest first"); eq(rows[3].name, "A", "oldest last"); eq(rows[1].age, "1m", "row age")
rows = BC.SeenRows(seen, nil, "enchanting", 400)
eq(#rows, 2, "filtered"); eq(rows[1].name, "C", "filtered newest")
eq(rows[1].card, nil, "no cards yet")
eq(BC.CatList({ portal = 1, enchanting = 1 }), "Enchanting, Portals", "cat list order")

-- Phase 4
local card = BC.BuildCard({ { id = 333, name = "Enchanting", skill = 150 }, { id = 197, name = "Tailoring", skill = 124 } },
  { "S" }, { g = "b", p197 = "o" }, 4)
eq(card.rev, 4, "card rev"); eq(card.g, "b", "card global")
eq(card.profs[1].st, "a", "default status"); eq(card.profs[2].st, "o", "status override"); eq(card.profs[1].skill, 150, "skill")
eq(card.svcs[1].key, "S", "service key"); eq(card.svcs[1].st, "a", "service default")
local ch = { status = { g = "a" }, rev = 0 }
eq(BC.SetStatus(ch, "g", "b"), true, "status changed"); eq(ch.rev, 1, "rev bumped")
eq(BC.SetStatus(ch, "g", "b"), false, "unchanged"); eq(ch.rev, 1, "rev kept")
eq(BC.NextStatus("a"), "b", "a->b"); eq(BC.NextStatus("b"), "o", "b->o"); eq(BC.NextStatus("o"), "a", "o->a"); eq(BC.NextStatus(nil), "b", "nil->b")

-- Phase 5
local msg = BC.EncodeCard(card)
local d = BC.Decode(msg)
eq(d.kind, "C", "decode kind"); eq(d.rev, 4, "decode rev"); eq(d.g, "b", "decode g")
eq(#d.profs, 2, "decode profs"); eq(d.profs[2].id, 197, "prof id"); eq(d.profs[2].skill, 124, "prof skill"); eq(d.profs[2].st, "o", "prof st")
eq(d.svcs[1].key, "S", "svc key"); eq(d.svcs[1].st, "a", "svc st")
local empty = BC.EncodeCard(BC.BuildCard({}, {}, { g = "a" }, 0))
eq(empty, "1|C|0|a|-|-|-", "empty card"); eq(#BC.Decode(empty).profs, 0, "empty profs")
local maxProfs, maxSvcs = {}, {}
for i, id in ipairs({ 171, 164, 333, 202, 165, 197 }) do maxProfs[i] = { id = id, skill = 300 } end
for i, sv in ipairs(BC.SERVICES) do maxSvcs[i] = sv.key end
local big = BC.EncodeCard(BC.BuildCard(maxProfs, maxSvcs, { g = "a" }, 99999, string.rep("Z", 60)))
assert(#big <= 255, "max card is " .. #big .. " bytes"); eq(#BC.Decode(big).svcs, #BC.SERVICES, "max card svcs")
eq(BC.Decode("2|C|0|a|-|-"), nil, "wrong proto"); eq(BC.Decode("1|C|0|a|-"), nil, "short C")
eq(BC.Decode("1|C|x|a|-|-"), nil, "bad rev"); eq(BC.Decode("1|C|0|x|-|-"), nil, "bad status"); eq(BC.Decode(nil), nil, "nil msg")
eq(BC.Decode("ping"), nil, "probe ping ignored"); eq(BC.Decode("1|Q").kind, "Q", "request")
local cc = BC.CardCats(d)
eq(cc.enchanting, true, "card cat"); eq(cc.tailoring, nil, "off skipped"); eq(cc.summon, true, "svc cat")
eq(BC.CardStatus(d, "enchanting"), "b", "global busy wins")
d.g = "a"
eq(BC.CardStatus(d, "enchanting"), "a", "available"); eq(BC.CardStatus(d, "tailoring"), nil, "off is unknown")
eq(BC.CardStatus(d, "portal"), nil, "not listed"); eq(BC.CardStatus(nil, "all"), nil, "no card")
rows = BC.SeenRows({ A = { cats = { portal = 1 }, at = 100 } }, { G = d, A = d }, "all", 200)
eq(#rows, 2, "card-only row merged"); eq(rows[1].name, "A", "seen row first"); eq(rows[1].card, d, "card attached")
eq(rows[2].name, "G", "card-only row"); eq(rows[2].cats.enchanting, true, "card-only cats")
eq(#BC.SeenRows({}, { G = d }, "portal", 200), 0, "card-only filtered")

-- Phase 6
for _, n in ipairs({ 0, 35, 36, 1263080 }) do eq(tonumber(BC.B36(n), 36), n, "b36 " .. n) end
local ids = {}
for i = 1, 500 do ids[i] = 1000 + i * 2531 end
local chunks = BC.ChunkIDs(ids, 200)
local back = {}
for _, c in ipairs(chunks) do
  assert(#c <= 200, "chunk " .. #c .. " bytes")
  for t in c:gmatch("[^,]+") do back[#back + 1] = tonumber(t, 36) end
end
eq(#back, 500, "chunks round trip count"); eq(back[500], ids[500], "chunks round trip value")
eq(#BC.ChunkIDs({}, 200), 0, "no ids no chunks")
local buf = {}
eq(BC.Reassemble(buf, "Bob:333", 2, 2, "b", 10), nil, "partial")
local got = BC.Reassemble(buf, "Bob:333", 1, 2, "a,1", 11)
eq(#got, 3, "out of order complete"); eq(got[1], 10, "a"); eq(got[2], 1, "1"); eq(got[3], 11, "b"); eq(buf["Bob:333"], nil, "buffer cleared")
eq(BC.Reassemble(buf, "Bob:197", 1, 3, "a", 20), nil, "missing chunk")
BC.Reassemble(buf, "Other:1", 1, 2, "a", 51); eq(buf["Bob:197"], nil, "stale purged after 30s")
eq(#BC.Reassemble(buf, "Bob:165", 0, 0, "", 60), 0, "total 0 is empty list")
eq(BC.Decode("1|RQ|333").prof, 333, "decode RQ")
local rl = BC.Decode("1|RL|333|2|5|a,b"); eq(rl.seq, 2, "RL seq"); eq(rl.total, 5, "RL total"); eq(rl.part, "a,b", "RL part")
eq(BC.Decode("1|RL|333|0|0|-").part, "", "RL empty")
eq(BC.Decode("1|RL|333|6|5|a"), nil, "seq > total rejected"); eq(BC.Decode("1|RQ|x"), nil, "bad RQ")
local line = table.concat({ "1", "RL", 999999, 999, 999, string.rep("z", 200) }, "|")
assert(#line <= 255, "RL line " .. #line .. " bytes")

-- Location
eq(BC.ChannelZone("General - Orgrimmar"), "Orgrimmar", "zone from general")
eq(BC.ChannelZone("Trade (Local) - Orgrimmar"), "Orgrimmar", "zone from trade local")
eq(BC.ChannelZone("Trade - English 53"), nil, "language channel has no zone")
eq(BC.ChannelZone("LookingForGroup"), nil, "no suffix"); eq(BC.ChannelZone(nil), nil, "nil base")
eq(BC.ChannelZone("General - Ragefire Chasm"), "Ragefire Chasm", "multi-word zone")
seen = {}
BC.SeenAdd(seen, "Z", BC.Classify("WTS enchants"), "WTS enchants", 1, "Orgrimmar")
BC.SeenAdd(seen, "Z", BC.Classify("WTS enchants"), "WTS enchants", 2, nil)
eq(seen.Z.zone, "Orgrimmar", "zone kept when new ad has none")
local zc = BC.Decode(BC.EncodeCard(BC.BuildCard({}, {}, { g = "a" }, 1, "Thunder Bluff")))
eq(zc.zone, "Thunder Bluff", "card zone round trip")
eq(BC.Decode("1|C|0|a|-|-").zone, nil, "old 6-field card decodes")
eq(BC.Decode(BC.EncodeCard(BC.BuildCard({}, {}, { g = "a" }, 1, "a|b"))).zone, "ab", "pipe stripped from zone")
rows = BC.SeenRows(seen, { Z = zc }, "all", 10)
eq(rows[1].zone, "Thunder Bluff", "card zone wins over heard zone")
eq(BC.SeenRows(seen, nil, "all", 10)[1].zone, "Orgrimmar", "heard zone without card")

eq(BC.PickZone({ zone = "Org", whoAt = 20 }, { zone = "TB", at = 10 }), "Org", "newer who beats card")
eq(BC.PickZone({ zone = "Org", whoAt = 5 }, { zone = "TB", at = 10 }), "TB", "newer card beats who")
eq(BC.PickZone({ zone = "Org" }, nil), "Org", "heard zone alone")
eq(BC.PickZone({}, { at = 1 }), nil, "no zone anywhere")

-- UI redesign P2
local ic = BC.RowIcons({ portal = true, enchanting = true, summon = true, alchemy = true }, 3)
eq(#ic, 3, "row icons capped"); eq(ic[1], BC.CAT_ICON.enchanting, "row icons in CATS order")
eq(ic[3], BC.CAT_ICON.summon, "portal dropped past cap")
eq(#BC.RowIcons(nil, 3), 0, "no cats no icons")
eq(BC.StatusColor("a"), BC.THEME.available, "available colour"); eq(BC.StatusColor("b"), BC.THEME.busy, "busy colour")
eq(BC.StatusColor("o"), BC.THEME.off, "off colour"); eq(BC.StatusColor(nil), nil, "unknown no colour")
for _, c in ipairs(BC.CATS) do assert(BC.CAT_ICON[c], "icon for " .. c) end
for _, s in ipairs(BC.SERVICES) do assert(BC.SVC_ICON[s.key], "icon for " .. s.key) end

-- UI redesign P3
eq(BC.SkillFrac(150), 0.5, "skill half"); eq(BC.SkillFrac(400), 1, "skill clamps high")
eq(BC.SkillFrac(nil), 0, "skill nil"); eq(BC.SkillFrac(75, 150), 0.5, "skill custom cap")
local cm = BC.CardModel({ g = "b", profs = { { id = 333, skill = 225, st = "o" } }, svcs = { { key = "P-ORG", st = "a" } } }, { self = true })
eq(cm.g, "b", "model global"); eq(cm.portrait, "player", "self portrait")
eq(cm.profs[1].name, "Enchanting", "model prof name"); eq(cm.profs[1].key, "p333", "model prof key")
eq(cm.profs[1].icon, BC.PROF_ICON[333], "model prof icon"); eq(cm.profs[1].st, "o", "model prof status")
eq(cm.svcs[1].label, "Portal: Orgrimmar", "model svc label")
eq(BC.CardModel({ profs = {}, svcs = { { key = "S", st = "a" } } }).portrait, BC.SVC_ICON.S, "stranger portrait = first svc icon")
eq(BC.CardModel({}).portrait, BC.ICON_FALLBACK, "empty card fallback portrait")

print("all tests passed")
