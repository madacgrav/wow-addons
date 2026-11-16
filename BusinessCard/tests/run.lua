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

print("all tests passed")
