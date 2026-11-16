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

local function set(t) local s = {} for _, w in ipairs(t) do s[w] = true end return s end
-- category order = display order
BC.CATS = { "enchanting", "tailoring", "leatherworking", "alchemy", "blacksmithing", "engineering", "jewelcrafting",
  "cooking", "firstaid", "summon", "portal", "other" }
BC.CAT_LABEL = { enchanting = "Enchanting", tailoring = "Tailoring", leatherworking = "Leatherworking", alchemy = "Alchemy",
  blacksmithing = "Blacksmithing", engineering = "Engineering", jewelcrafting = "Jewelcrafting", cooking = "Cooking",
  firstaid = "First Aid", summon = "Summons", portal = "Portals", other = "Other" }
BC.WORDS = {
  enchanting = set{ "ench", "enchant", "enchants", "enchanter", "enchanting", "chanter" },
  tailoring = set{ "tailor", "tailors", "tailoring" },
  leatherworking = set{ "lw", "leatherworker", "leatherworking" },
  alchemy = set{ "alch", "alchemy", "alchemist", "flask", "flasks", "elixir", "elixirs", "transmute", "transmutes", "potion", "potions" },
  blacksmithing = set{ "bs", "blacksmith", "blacksmithing", "smith" },
  engineering = set{ "engi", "engineer", "engineering" },
  jewelcrafting = set{ "jc", "jewelcrafter", "jewelcrafting" },
  cooking = set{ "cook", "cooking" },
  firstaid = set{ "bandage", "bandages" },
  summon = set{ "sum", "summ", "summon", "summons", "summoning" },
  portal = set{ "port", "ports", "portal", "portals", "teleport", "tele" },
  other = set{ "lockpick", "lockpicking", "lockbox", "lockboxes" },
}
-- an ad must carry an offer signal (offer word, price like "5g", or a |Htrade: profession link) and no request word
BC.REQUEST_WORDS = set{ "lf", "lfm", "lfg", "wtb", "need", "needs", "needing", "buying", "anyone", "someone", "somebody",
  "recruiting", "recruit", "guild" }
BC.OFFER_WORDS = set{ "wts", "lfw", "selling", "offering", "avail", "available", "tips", "tip", "free", "providing",
  "service", "services", "open", "pst", "mats", "cheap", "enchanter", "tailor", "alchemist", "blacksmith", "engineer",
  "leatherworker", "jewelcrafter", "lockpick", "lockpicking" }
-- "if" deliberately omitted (common English word)
BC.PORTAL_DEST = { org = "ORG", orgrimmar = "ORG", ogri = "ORG", uc = "UC", undercity = "UC", tb = "TB", thunder = "TB",
  thunderbluff = "TB", sw = "SW", stormwind = "SW", ironforge = "IF", darn = "DARN", darnassus = "DARN" }
-- keys = channelBaseName before " - " (probe-results.md)
BC.DEFAULT_CHANNELS = { Trade = true, General = true, LookingForGroup = true, ["Trade (Services)"] = true,
  ["Trade (Local)"] = true, SAY = true, YELL = true, WHISPER = true }

-- merchant-ledger palette {r,g,b[,a]}
BC.THEME = {
  ink = { 0.07, 0.06, 0.05, 0.97 }, parchment = { 1, 0.96, 0.84 }, cream = { 0.94, 0.88, 0.73 },
  gold = { 0.72, 0.58, 0.32 }, goldBright = { 1, 0.82, 0.30 }, muted = { 0.55, 0.52, 0.46 },
  zone = { 0.6, 0.8, 1 }, available = { 0.25, 0.9, 0.3 }, busy = { 0.95, 0.25, 0.2 }, off = { 0.5, 0.5, 0.5 },
}
