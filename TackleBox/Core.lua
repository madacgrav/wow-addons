local ADDON, TB = ...

TB.inits, TB.refreshers = {}, {}

function TB.Secret(v) return issecretvalue ~= nil and issecretvalue(v) end
function TB.Print(msg) print("|cff3fa7d6TB|r " .. msg) end

local events, handlers = CreateFrame("Frame"), {}
function TB.On(event, fn)
  if not handlers[event] then handlers[event] = {}; events:RegisterEvent(event) end
  table.insert(handlers[event], fn)
end
events:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do fn(...) end
end)

local DEFAULTS = { locked = false, shown = true, frames = {}, minimapAngle = 200, collapsed = {}, flash = true }
local CHAR_DEFAULTS = { catches = {} }

TB.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  -- nil-safe: the Forever beta loader bug can leave these nil every session
  TackleBoxDB = TB.MergeDefaults(TackleBoxDB, DEFAULTS)
  TackleBoxCharDB = TB.MergeDefaults(TackleBoxCharDB, CHAR_DEFAULTS)
  TB.db, TB.char = TackleBoxDB, TackleBoxCharDB
end)

-- GetProfessions() 4th return is the fishing index; fall back to the skill-line API (356 = Fishing)
function TB.ReadSkill()
  local idx = GetProfessions and select(4, GetProfessions())
  if idx then
    local _, _, level, max, _, _, _, modifier = GetProfessionInfo(idx)
    return { level = level, max = max, modifier = modifier or 0 }
  end
  local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID(356)
  if info and info.maxSkillLevel and info.maxSkillLevel > 0 then
    return { level = info.skillLevel, max = info.maxSkillLevel, modifier = info.skillModifier or 0 }
  end
end

local pending = false
function TB.Refresh()
  if not TB.active or pending then return end
  pending = true
  C_Timer.After(0.1, function()
    pending = false
    TB.skill = TB.ReadSkill()
    for _, fn in ipairs(TB.refreshers) do fn() end
  end)
end

TB.On("PLAYER_LOGIN", function()
  TB.active = true
  for _, init in ipairs(TB.inits) do init() end
  TB.Refresh()
end)
TB.On("SKILL_LINES_CHANGED", TB.Refresh)
TB.On("PLAYER_REGEN_ENABLED", TB.Refresh)
TB.On("BAG_UPDATE_DELAYED", TB.Refresh)
TB.On("BANKFRAME_OPENED", TB.Refresh)
TB.On("PLAYERBANKSLOTS_CHANGED", TB.Refresh)
TB.On("ZONE_CHANGED_NEW_AREA", TB.Refresh)
TB.On("UNIT_INVENTORY_CHANGED", function(u) if u == "player" then TB.Refresh() end end) -- pole/gear changes the skill modifier

-- includeBank=true counts the bank too (PP probe: works on Forever)
function TB.CountItems(ids)
  local counts = {}
  for _, id in ipairs(ids) do counts[id] = C_Item.GetItemCount(id, true) end
  return counts
end

-- probe snapshots: always on so /tb probe can report the last cast and loot
TB.trace = {} -- last 12 {t, event, detail}; the probe reads the event order
local function Trace(ev, d) table.insert(TB.trace, { GetTime(), ev, d }); if #TB.trace > 12 then table.remove(TB.trace, 1) end end
TB.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if unit ~= "player" then return end
  local _, _, _, st, et = UnitChannelInfo("player")
  TB.lastChannelInfo = { spellID = spellID, start = st, finish = et, secret = TB.Secret(st) or TB.Secret(spellID) }
  Trace("CHANNEL_START", TB.Secret(spellID) and "SECRET" or tostring(spellID))
end)
TB.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit) if unit == "player" then Trace("CHANNEL_STOP") end end)
TB.On("LOOT_READY", function()
  local slots = {}
  for i = 1, GetNumLootItems() do
    local _, name, qty, _, quality = GetLootSlotInfo(i)
    slots[#slots + 1] = { link = GetLootSlotLink(i), name = name, qty = qty, quality = quality }
  end
  TB.lastLoot = { slots = slots, fishing = IsFishingLoot and IsFishingLoot(), hasAPI = IsFishingLoot ~= nil }
  Trace("LOOT_READY", #slots)
end)

local PROBE_WORDS = { "Fish", "Surfer", "Water Walk", "Knife", "Lure", "Bauble", "Snapper", "Ahi", "Mahi", "Striker", "Sailfin" }

-- dumps the fishing facts Data.lua needs; output saved to TackleBoxDB.lastProbe for probe-results.md
function TB.Probe()
  TB.db.lastProbe = {}
  local function S(v) if TB.Secret(v) then return "SECRET" end return tostring(v) end
  local function P(k, v) local line = k .. ": " .. tostring(v); TB.Print(line); table.insert(TB.db.lastProbe, line) end
  local function Try(k, fn) local ok, err = pcall(fn); if not ok then P(k, "ERROR " .. tostring(err)) end end

  local ver, build = GetBuildInfo()
  P("build", tostring(ver) .. " " .. tostring(build) .. " project " .. tostring(WOW_PROJECT_ID))
  P("combat", InCombatLockdown())

  Try("professions", function()
    local p = { GetProfessions() }
    P("GetProfessions", table.concat({ tostring(p[1]), tostring(p[2]), tostring(p[3]), tostring(p[4]), tostring(p[5]) }, " "))
    if p[4] then
      local r = { GetProfessionInfo(p[4]) }
      for i = 1, 11 do r[i] = tostring(r[i]) end
      P("GetProfessionInfo(fishing)", table.concat(r, " | "))
    end
  end)
  Try("skillLine356", function()
    local i = C_TradeSkillUI.GetProfessionInfoBySkillLineID(356)
    P("SkillLine 356", i and (tostring(i.skillLevel) .. "/" .. tostring(i.maxSkillLevel) .. " mod " .. tostring(i.skillModifier)) or "nil")
  end)
  for _, id in ipairs({ 7620, 131474 }) do
    Try("spell" .. id, function()
      local s = C_Spell.GetSpellInfo(id)
      P("spell " .. id, s and (tostring(s.name) .. " id " .. tostring(s.spellID)) or "nil")
    end)
  end
  P("IsFishingLoot", type(IsFishingLoot))
  P("zone", tostring(GetRealZoneText()) .. " / " .. tostring(GetSubZoneText()))

  Try("auras", function()
    local first
    for i = 1, 40 do
      local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
      if not a then break end
      first = first or a.spellId
      P("aura " .. i, S(a.spellId) .. " " .. S(a.name) .. " exp " .. S(a.expirationTime))
    end
    if first and not TB.Secret(first) then
      local a = C_UnitAuras.GetPlayerAuraBySpellID(first)
      P("byID " .. first, a and ("ok exp " .. S(a.expirationTime)) or "nil")
    end
  end)

  Try("bags", function()
    for bag = 0, NUM_BAG_SLOTS or 4 do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local it = C_Container.GetContainerItemInfo(bag, slot)
        if it and it.itemID then
          local name = it.itemName or ""
          local classID, subID = select(12, C_Item.GetItemInfo(it.itemID))
          local keep = classID == 7 or classID == 0
          for _, w in ipairs(PROBE_WORDS) do if name:find(w, 1, true) then keep = true end end
          if keep then
            P("item " .. it.itemID, name .. " q" .. tostring(it.quality) .. " class " .. tostring(classID) .. "/" .. tostring(subID))
          end
        end
      end
    end
  end)

  local c = TB.lastChannelInfo
  P("lastChannel", c and (S(c.spellID) .. " start " .. S(c.start) .. " end " .. S(c.finish) .. " secret " .. tostring(c.secret)) or "none")
  local l = TB.lastLoot
  if l then
    P("lastLoot", "hasAPI " .. tostring(l.hasAPI) .. " fishing " .. tostring(l.fishing))
    for i, s in ipairs(l.slots) do P("loot " .. i, tostring(s.link) .. " q" .. tostring(s.quality) .. " x" .. tostring(s.qty)) end
  else
    P("lastLoot", "none")
  end
  local t0 = TB.trace[1] and TB.trace[1][1] or 0
  for _, e in ipairs(TB.trace) do P("trace", string.format("+%.2f %s %s", e[1] - t0, e[2], tostring(e[3] or ""))) end
end

SLASH_TACKLEBOX1 = "/tb"
SlashCmdList.TACKLEBOX = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "show" or cmd == "hide" then TB.db.shown = cmd == "show"; TB.Refresh()
  elseif cmd == "" then TB.db.shown = not TB.db.shown; TB.Refresh()
  elseif cmd == "lock" then TB.db.locked = not TB.db.locked; TB.Print(TB.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(TB.db.frames); TB.Print("positions reset; /reload to apply")
  elseif cmd == "probe" then TB.Probe()
  else TB.Print("/tb show||hide||lock||reset||probe") end -- || prints one pipe; a bare |h starts a chat link escape
end
