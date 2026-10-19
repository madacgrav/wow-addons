local ADDON, WUK = ...

WUK.inits, WUK.refreshers = {}, {}
WUK.counts = { shard = 0, healthstone = 0, soulstone = 0, spellstone = 0, firestone = 0, ids = {}, slots = {} }
WUK.known = {}

function WUK.Secret(v) return issecretvalue ~= nil and issecretvalue(v) end
function WUK.Print(msg) print("|cff9482c9WUK|r " .. msg) end

local events, handlers = CreateFrame("Frame"), {}
function WUK.On(event, fn)
  if not handlers[event] then handlers[event] = {}; events:RegisterEvent(event) end
  table.insert(handlers[event], fn)
end
events:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do fn(...) end
end)

local DEFAULTS = { locked = false, shown = true, frames = {} }
local CHAR_DEFAULTS = { pet = "imp" }

WUK.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  -- nil-safe: the Forever beta loader bug can leave these nil every session
  WarlockUtilityKitDB = WUK.MergeDefaults(WarlockUtilityKitDB, DEFAULTS)
  WarlockUtilityKitCharDB = WUK.MergeDefaults(WarlockUtilityKitCharDB, CHAR_DEFAULTS)
  WUK.db, WUK.char = WarlockUtilityKitDB, WarlockUtilityKitCharDB
end)

function WUK.ScanBags()
  local c = { shard = 0, healthstone = 0, soulstone = 0, spellstone = 0, firestone = 0, ids = {}, slots = {} }
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local kind = info and WUK.ClassifyItem(info.itemName or C_Item.GetItemInfo(info.itemID))
      if kind then
        c[kind] = c[kind] + (info.stackCount or 1)
        c.ids[kind] = c.ids[kind] or info.itemID
        c.slots[kind] = c.slots[kind] or { bag, slot }
      end
    end
  end
  return c
end

-- Classic-era ranked stone spells have distinct names: highest rank first, first known wins.
-- Same-name ranked spells (Demon Armor) cast their highest rank via /cast Name.
local SPELLS = {
  armor = { "Demon Armor", "Demon Skin" },
  detect = { "Detect Greater Invisibility", "Detect Invisibility", "Detect Lesser Invisibility" },
  imp = { "Summon Imp" }, voidwalker = { "Summon Voidwalker" },
  succubus = { "Summon Succubus" }, felhunter = { "Summon Felhunter" },
  soullink = { "Soul Link" }, ritual = { "Ritual of Summoning" },
  healthstone = { "Create Healthstone (Major)", "Create Healthstone (Greater)", "Create Healthstone",
                  "Create Healthstone (Lesser)", "Create Healthstone (Minor)" },
  soulstone = { "Create Soulstone (Major)", "Create Soulstone (Greater)", "Create Soulstone",
                "Create Soulstone (Lesser)", "Create Soulstone (Minor)" },
}

local function SpellbookNames()
  local names = {}
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    local bank = Enum.SpellBookSpellBank.Player
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
      for j = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local n = C_SpellBook.GetSpellBookItemName(j, bank)
        if n then names[n] = true end
      end
    end
  else -- Classic-style spellbook, in case Forever kept it
    for t = 1, GetNumSpellTabs() do
      local _, _, offset, num = GetSpellTabInfo(t)
      for j = offset + 1, offset + num do
        local n = GetSpellBookItemName(j, "spell")
        if n then names[n] = true end
      end
    end
  end
  return names
end

function WUK.ScanSpells()
  local names, known = SpellbookNames(), {}
  for key, list in pairs(SPELLS) do
    for _, n in ipairs(list) do if names[n] then known[key] = n; break end end
  end
  WUK.known = known
end

local DEMONIC_SACRIFICE = { ["Burning Wish"] = true, ["Fel Stamina"] = true, ["Touch of Shadow"] = true, ["Fel Energy"] = true }
function WUK.ReadPlayerBuffs()
  local set = {}
  for i = 1, 40 do
    local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not a then break end
    local n = a.name
    if n and not WUK.Secret(n) then
      set[n] = true
      if DEMONIC_SACRIFICE[n] then set.demonicSacrifice = true end
    end
  end
  return set
end

function WUK.PetFamily()
  if not UnitExists("pet") then return nil end
  local fam = UnitCreatureFamily("pet")
  if not fam or WUK.Secret(fam) then return nil end
  return fam:lower()
end

function WUK.Refresh()
  if not WUK.active then return end
  WUK.counts = WUK.ScanBags()
  for _, fn in ipairs(WUK.refreshers) do fn() end
end

WUK.On("PLAYER_LOGIN", function()
  local _, class = UnitClass("player")
  if class ~= "WARLOCK" then return end
  WUK.active = true
  WUK.ScanSpells()
  for _, init in ipairs(WUK.inits) do init() end
  WUK.Refresh()
end)
WUK.On("BAG_UPDATE_DELAYED", WUK.Refresh)
WUK.On("PLAYER_REGEN_ENABLED", WUK.Refresh)
WUK.On("SPELLS_CHANGED", function() if WUK.active then WUK.ScanSpells(); WUK.Refresh() end end)
WUK.On("UNIT_AURA", function(u) if u == "player" then WUK.Refresh() end end)
WUK.On("UNIT_PET", function(u) if u == "player" then WUK.Refresh() end end)

WUK.On("UNIT_SPELLCAST_SENT", function(unit, target)
  if unit == "player" then WUK.lastCastTarget = (target and not WUK.Secret(target) and target ~= "") and target or nil end
end)
function WUK.SpellName(spellID)
  if not spellID or WUK.Secret(spellID) then return nil end
  local info = C_Spell.GetSpellInfo(spellID)
  return info and info.name
end

SLASH_WARLOCKUTILITYKIT1 = "/wuk"
SlashCmdList.WARLOCKUTILITYKIT = function(msg)
  if not WUK.active then return WUK.Print("warlocks only") end
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  if InCombatLockdown() and (cmd == "show" or cmd == "hide") then return WUK.Print("not in combat") end
  if cmd == "show" or cmd == "hide" then WUK.db.shown = (cmd == "show"); WUK.ApplyShown()
  elseif cmd == "lock" then WUK.db.locked = not WUK.db.locked; WUK.Print(WUK.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(WUK.db.frames); WUK.Print("positions reset - /reload to apply")
  elseif cmd == "pet" and (arg == "imp" or arg == "voidwalker" or arg == "succubus" or arg == "felhunter") then
    WUK.char.pet = arg; WUK.Print("preferred pet: " .. arg); WUK.Refresh()
  else WUK.Print("/wuk show | hide | lock | reset | pet <imp|voidwalker|succubus|felhunter>") end
end
