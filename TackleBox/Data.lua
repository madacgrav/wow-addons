local ADDON, TB = ...
-- Hand-maintained. Every ID must trace to a line in thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md
TB.DATA = {
  fishingSpells = { [7620] = true }, -- probe run 1: 7620 = Fishing; 131474 does not exist
  castSeconds = 30,   -- probe run 2: channel is 30000 ms; fallback only, times were not secret
  -- Artisan quest fish; IDs from wago DB2 build 70450 (probe-results.md). need=1 until the quest text is read in game
  questFish = {
    { id = 16967, need = 1, zone = "Feralas" },            -- Feralas Ahi
    { id = 16970, need = 1, zone = "Swamp of Sorrows" },   -- Misty Reed Mahi Mahi
    { id = 16968, need = 1, zone = "Desolace" },           -- Sar'theris Striker
    { id = 16969, need = 1, zone = "Stranglethorn Vale" }, -- Savage Coast Blue Sailfin
  },
  -- skill bands from third-party Forever guides (fishing-gaps research.md:70-73); band/max use base skill,
  -- cast = min effective skill to catch anything, noLoss = skill where fish stop getting away, lure = bonus needed
  -- ponytail: enUS zone names matched against GetRealZoneText; add a locale table if non-English clients matter
  zones = {
    { band = 1, max = 75, noLoss = 25, names = { "Elwynn Forest", "Dun Morogh", "Teldrassil", "Durotar", "Mulgore", "Tirisfal Glades" } },
    { band = 75, max = 150, noLoss = 75, names = { "Stormwind City", "Ironforge", "Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity" } },
    { band = 75, max = 150, names = { "The Barrens", "Darkshore", "Loch Modan", "Silverpine Forest", "Westfall" } },
    { band = 75, max = 150, cast = 55, noLoss = 150, names = { "Redridge Mountains" } },
    { band = 150, max = 225, names = { "Dustwallow Marsh", "Alterac Mountains", "Arathi Highlands", "Desolace",
      "Stranglethorn Vale", "Swamp of Sorrows", "Thousand Needles" } },
    { band = 225, max = 300, lure = 75, names = { "Felwood", "Feralas", "The Hinterlands", "Tanaris", "Un'Goro Crater", "Western Plaguelands" } },
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
