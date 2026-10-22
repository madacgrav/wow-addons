local ADDON, TB = ...
-- Hand-maintained. Every ID must trace to a line in thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md
TB.DATA = {
  fishingSpells = { [7620] = true }, -- probe run 1: 7620 = Fishing; 131474 does not exist
  castSeconds = 30,   -- probe run 2: channel is 30000 ms; fallback only, times were not secret
  questFish = {},     -- Phase 2
  zones = {}, lures = {}, -- Phase 2b
  fish = {},          -- Phase 3
  campBuffs = {},     -- Phase 4
  waterWalk = { items = {}, auras = {} }, -- Phase 5
}
