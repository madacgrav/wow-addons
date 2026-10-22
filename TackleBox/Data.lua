local ADDON, TB = ...
-- Hand-maintained. Every ID must trace to a line in thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md
TB.DATA = {
  fishingSpells = { [7620] = true, [131474] = true }, -- probe confirms which fires on Forever
  castSeconds = 30,   -- fallback cast length when UnitChannelInfo is secret; set from probe
  questFish = {},     -- Phase 2
  zones = {}, lures = {}, -- Phase 2b
  fish = {},          -- Phase 3
  campBuffs = {},     -- Phase 4
  waterWalk = { items = {}, auras = {} }, -- Phase 5
}
