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
  zones = {}, lures = {}, -- Phase 2b
  fish = {},          -- Phase 3
  campBuffs = {},     -- Phase 4
  waterWalk = { items = {}, auras = {} }, -- Phase 5
}
