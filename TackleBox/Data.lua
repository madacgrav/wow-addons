local ADDON, TB = ...
-- Hand-maintained. Every ID must trace to a line in thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md
TB.DATA = {
  -- the cast spell is the rank: probe run 1: 7620 (Apprentice); run 5: 7732 at skill 205 (Expert).
  -- 7731 Journeyman and 18248 Artisan are the Classic rank IDs, not yet seen in a Forever trace
  fishingSpells = { [7620] = true, [7731] = true, [7732] = true, [18248] = true },
  castSeconds = 30,   -- probe run 2: channel is 30000 ms; fallback only, times were not secret
  -- Artisan quest fish; IDs from wago DB2 build 70450 (probe-results.md). need=1 until the quest text is read in game
  questFish = {
    { id = 16967, need = 1, zone = "Feralas" },            -- Feralas Ahi
    { id = 16970, need = 1, zone = "Swamp of Sorrows" },   -- Misty Reed Mahi Mahi
    { id = 16968, need = 1, zone = "Desolace" },           -- Sar'theris Striker
    { id = 16969, need = 1, zone = "Stranglethorn Vale" }, -- Savage Coast Blue Sailfin
  },
  -- third-party: Gfinity Forever fishing guide 2026-10-22 tiers (band = skill to fish without get-aways there).
  -- Forever-only zone names unverified in game. ponytail: enUS names matched against GetRealZoneText; add a locale table if non-English clients matter
  zones = {
    { band = 1, max = 55, names = { "Elwynn Forest", "Dun Morogh", "Teldrassil", "Durotar", "Mulgore", "Tirisfal Glades",
      "Stormwind City", "Ironforge", "Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity", "Zephras Isle" } },
    { band = 55, max = 135, names = { "Westfall", "Loch Modan", "Darkshore", "The Barrens", "Silverpine Forest", "Redridge Mountains" } },
    { band = 135, max = 205, names = { "Wetlands", "Ashenvale", "Hillsbrad Foothills", "Stonetalon Mountains", "Duskwood", "The Riverglades" } },
    -- old-guide band (not in Gfinity): kept so these zones still list
    { band = 150, max = 225, names = { "Swamp of Sorrows", "Thousand Needles", "Alterac Mountains" } },
    { band = 205, max = 275, names = { "Stranglethorn Vale", "Arathi Highlands", "Desolace", "Dustwallow Marsh", "Feralas", "The Hinterlands", "Shen'Dralas" } },
    -- max 301 so capped anglers still see the top tier; lure = 75 kept from the old Classic band
    { band = 275, max = 301, lure = 75, names = { "Tanaris", "Azshara", "Felwood", "Un'Goro Crater", "Winterspring",
      "Western Plaguelands", "Eastern Plaguelands", "Mount Hyjal" } },
  },
  -- sorted by bonus; IDs from wago DB2 build 70450, bonuses from Forever guides (Classic values)
  lures = {
    -- req = ItemSparse RequiredSkillRank on Fishing (356)
    { id = 6529, name = "Shiny Bauble", bonus = 25, req = 0 },
    { id = 6530, name = "Nightcrawlers", bonus = 50, req = 50 },
    { id = 6811, name = "Aquadynamic Fish Lens", bonus = 50, req = 50 },
    { id = 6532, name = "Bright Baubles", bonus = 75, req = 100 },
    { id = 7307, name = "Flesh Eating Worm", bonus = 75, req = 100 },
    { id = 6533, name = "Aquadynamic Fish Attractor", bonus = 100, req = 100 },
  },
  -- third-party: warcraft.wiki.gg Fishing_Pool (Classic) + WarcraftTavern Classic loot list; Forever placement unverified.
  -- name = the pool's tooltip title (probe 6B: "School of Deviate Fish"), matched exactly
  pools = {
    { key = "oily", name = "Oily Blackmouth School", loot = "Oily Blackmouth", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
    { key = "firefin", name = "Firefin Snapper School", loot = "Firefin Snapper", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
    { key = "mixed", name = "Mixed Ocean School", loot = "Firefin Snapper", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
    { key = "eel", name = "Stonescale Eel Swarm", loot = "Stonescale Eel", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
    { key = "sage", name = "Sagefish School", loot = "Raw Sagefish", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
    { key = "gsage", name = "Greater Sagefish School", loot = "Raw Greater Sagefish", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
    { key = "deviate", name = "School of Deviate Fish", loot = "Deviate Fish", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
    { key = "oilspill", name = "Oil Spill", loot = "Firefin Snapper", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
    { key = "debris", name = "Floating Debris", loot = "Tightly Sealed Trunk", icon = "Interface\\Icons\\INV_Box_02" },
    { key = "wreck", name = "Floating Wreckage", loot = "Mithril Bound Trunk", icon = "Interface\\Icons\\INV_Box_02" },
    { key = "bloodsail", name = "Bloodsail Wreckage", loot = "Mithril Bound Trunk", icon = "Interface\\Icons\\INV_Box_02" },
    { key = "waterlog", name = "Waterlogged Wreckage", loot = "Iron Bound Trunk", icon = "Interface\\Icons\\INV_Box_02" },
    { key = "schooner", name = "Schooner Wreckage", loot = "Watertight Trunk", icon = "Interface\\Icons\\INV_Box_02" },
  },
  -- zone -> notable catches and pool keys; same sources as pools
  spots = {
    ["Darkshore"] = { notable = { "Darkshore Grouper", "Oily Blackmouth" }, pools = { "oily", "debris" } },
    ["Westfall"] = { notable = { "Oily Blackmouth" }, pools = { "debris" } },
    ["Silverpine Forest"] = { notable = { "Sickly Looking Fish", "Oily Blackmouth" }, pools = { "sage", "debris" } },
    ["The Barrens"] = { notable = { "Deviate Fish", "Oil Covered Fish", "Oily Blackmouth" }, pools = { "deviate", "debris" } },
    ["Redridge Mountains"] = { notable = { "Spotted Sunfish" }, pools = { "debris" } },
    ["Wetlands"] = { notable = { "Firefin Snapper", "Oily Blackmouth" }, pools = { "oily", "sage", "schooner" } },
    ["Ashenvale"] = { notable = { "Raw Sagefish", "Oily Blackmouth" }, pools = { "oily", "sage", "schooner" } },
    ["Hillsbrad Foothills"] = { notable = { "Firefin Snapper", "Oily Blackmouth" }, pools = { "oily", "schooner" } },
    ["Stonetalon Mountains"] = { notable = { "Firefin Snapper", "Oil Covered Fish" }, pools = { "oilspill", "schooner" } },
    ["Duskwood"] = { notable = { "Raw Sagefish" }, pools = { "sage", "debris" } },
    ["Swamp of Sorrows"] = { notable = { "Misty Reed Mahi Mahi", "Stonescale Eel" }, pools = { "oily", "eel" } },
    ["Thousand Needles"] = { notable = { "Stonescale Eel" }, pools = { "eel" } },
    ["Stranglethorn Vale"] = { notable = { "Savage Coast Blue Sailfin", "Stonescale Eel", "Firefin Snapper" }, pools = { "mixed", "sage", "wreck", "bloodsail" } },
    ["Arathi Highlands"] = { notable = { "Firefin Snapper", "Oily Blackmouth" }, pools = { "oily" } },
    ["Desolace"] = { notable = { "Sar'theris Striker", "Firefin Snapper" }, pools = { "oily", "waterlog" } },
    ["Dustwallow Marsh"] = { notable = { "Firefin Snapper", "Oily Blackmouth" }, pools = { "waterlog" } },
    ["Feralas"] = { notable = { "Feralas Ahi", "Lightning Eel", "Plated Armorfish", "Stonescale Eel" }, pools = { "waterlog" } },
    ["The Hinterlands"] = { notable = { "Lightning Eel" }, pools = {} },
    ["Tanaris"] = { notable = { "Stonescale Eel", "Firefin Snapper" }, pools = { "oily", "eel" } },
    ["Azshara"] = { notable = { "Darkclaw Lobster", "Lightning Eel", "Stonescale Eel" }, pools = { "oily", "eel", "debris" } },
    ["Felwood"] = { notable = { "Lightning Eel" }, pools = {} },
    ["Un'Goro Crater"] = { notable = { "Lightning Eel" }, pools = {} },
    ["Winterspring"] = { notable = { "Lightning Eel", "Plated Armorfish" }, pools = {} },
    ["Western Plaguelands"] = { notable = { "Lightning Eel", "Raw Greater Sagefish" }, pools = { "gsage", "waterlog" } },
    ["Eastern Plaguelands"] = { notable = { "Lightning Eel", "Plated Armorfish" }, pools = { "gsage" } },
  },
  fish = {},          -- Phase 3
  -- unlock = ItemSparse RequiredSkillRank; aura IDs are the DB2 "Uncommon/Rare Fishing" dummies, mapping unverified in game
  campBuffs = {
    { spellID = 1280341, name = "Fishing Rack (Uncommon)", unlock = 140 },
    { spellID = 1280342, name = "Fishing Hut (Rare)", unlock = 300 },
  },
  -- items in preference order; on-use spells from ItemEffect (Draught -> 11319, Surfer Shoes -> 1299351);
  -- auras = every DB2 "Water Walking"/"Water Walk" aura (type 104), so other sources (shaman, new items) also count
  waterWalk = {
    items = { 8827, 276274 }, -- Draught of Water Walking, Surfer Shoes
    minLevel = { [8827] = 24, [276274] = 1 }, -- ItemSparse RequiredLevel
    auras = { 11319, 1299351, 1310296, 546, 1221095 },
  },
}
