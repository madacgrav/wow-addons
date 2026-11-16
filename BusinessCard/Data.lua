local ADDON, BC = ...

-- Classic IDs; confirmed or replaced from probe-results.md after Phase 1
BC.SERVICES = {
  { key = "S", id = 698, name = "Ritual of Summoning", label = "Summon" },
  { key = "T-ORG", id = 3567, name = "Teleport: Orgrimmar" },    { key = "P-ORG", id = 11417, name = "Portal: Orgrimmar" },
  { key = "T-UC", id = 3563, name = "Teleport: Undercity" },     { key = "P-UC", id = 11418, name = "Portal: Undercity" },
  { key = "T-TB", id = 3566, name = "Teleport: Thunder Bluff" }, { key = "P-TB", id = 11420, name = "Portal: Thunder Bluff" },
  { key = "T-SW", id = 3561, name = "Teleport: Stormwind" },     { key = "P-SW", id = 10059, name = "Portal: Stormwind" },
  { key = "T-IF", id = 3562, name = "Teleport: Ironforge" },     { key = "P-IF", id = 11416, name = "Portal: Ironforge" },
  { key = "T-DARN", id = 3565, name = "Teleport: Darnassus" },   { key = "P-DARN", id = 11419, name = "Portal: Darnassus" },
}

BC.PROF_NAMES = { [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
  [165] = "Leatherworking", [197] = "Tailoring", [185] = "Cooking", [129] = "First Aid", [186] = "Mining",
  [182] = "Herbalism", [393] = "Skinning", [356] = "Fishing", [755] = "Jewelcrafting" }
