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

-- version 2: pools/pins/detect added; nothing to convert from v1, MergeDefaults fills them. Bump + migrate here on schema change.
-- pools[uiMapID] = { {x, y, t = poolKey, n, last} }, x/y are 0-1 zone coordinates
local DEFAULTS = { version = 2, locked = false, shown = true, frames = {}, minimapAngle = 200, tab = "where", flash = true, expanded = false,
  pools = {}, pins = { map = true, minimap = true }, detect = true }
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
-- channel ended in combat: the key is still INTERACTTARGET; put it back once combat drops
TB.On("PLAYER_REGEN_ENABLED", function() if TB.reeling and not UnitChannelInfo("player") then TB.ReelMode(false) end end)
TB.On("PLAYER_LOGOUT", function() if TB.db then TB.RestoreCVars() end end) -- SVs save after logout fires, so the backup clears
TB.On("BAG_UPDATE_DELAYED", TB.Refresh)
TB.On("BANKFRAME_OPENED", TB.Refresh)
TB.On("PLAYERBANKSLOTS_CHANGED", TB.Refresh)
TB.On("ZONE_CHANGED_NEW_AREA", TB.Refresh)
TB.On("UNIT_INVENTORY_CHANGED", function(u) if u == "player" then TB.Refresh() end end) -- pole/gear changes the skill modifier

TB.auraState = {}
function TB.ReadAura(spellID)
  if InCombatLockdown() then return TB.auraState[spellID] or { active = false } end -- combat aura reads error on Forever (WUK probe)
  local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
  if not ok or not a then return { active = false } end
  local exp = a.expirationTime
  if TB.Secret(exp) or not exp or exp == 0 then return { active = true } end
  return { active = true, remaining = math.max(0, exp - GetTime()) }
end
TB.On("UNIT_AURA", function(u) if u == "player" then TB.Refresh() end end)
-- tick the camp countdown once a second while a camp buff is up
table.insert(TB.inits, function()
  C_Timer.NewTicker(1, function()
    for _, s in pairs(TB.auraState) do if s.remaining then return TB.Refresh() end end
  end)
end)

-- includeBank=true counts the bank too (PP probe: works on Forever)
function TB.CountItems(ids)
  local counts = {}
  for _, id in ipairs(ids) do counts[id] = C_Item.GetItemCount(id, true) end
  return counts
end

-- probe snapshots: always on so /tb probe can report the last cast and loot
TB.trace = {} -- last 20 {t, event, detail}; the probe reads the event order
local function Trace(ev, d) table.insert(TB.trace, { GetTime(), ev, d }); if #TB.trace > 20 then table.remove(TB.trace, 1) end end
-- probe run 6: does a fishing pool become the soft-interact target, and is its name readable?
local function SoftName()
  local ok, n = pcall(function()
    if UnitExists("softinteract") then return (UnitIsGameObject("softinteract") and "obj " or "unit ") .. tostring(UnitName("softinteract")) end
  end)
  if not ok then return "ERR" end
  if TB.Secret(n) then return "SECRET" end
  return n or "none"
end
TB.On("PLAYER_SOFT_INTERACT_CHANGED", function(_, new) Trace("SOFT", (TB.Secret(new) and "SECRET" or tostring(new)) .. " " .. SoftName()) end)
TB.On("UNIT_SPELLCAST_CHANNEL_START", function(unit) if unit == "player" then Trace("SOFT@CAST", SoftName()) end end)
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

-- catch tracking: LOOT_READY arrives ~10ms after CHANNEL_STOP (probe run 4)
TB.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if unit == "player" and not TB.Secret(spellID) then TB.lastChannel = { spellID = spellID, t = GetTime() } end
end)
TB.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit)
  if unit == "player" and TB.lastChannel then TB.lastChannel.stopT = GetTime() end
end)
-- cast bar + got-away: a fishing cast that ends with no fishing loot within 1s counts as a miss
TB.session = { misses = 0 }
TB.Trace = Trace
-- probe run 7 traces: casts, crafts, error text, item cooldown updates
TB.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID) if unit == "player" then Trace("CAST_OK", TB.Secret(spellID) and "SECRET" or tostring(spellID)) end end)
TB.On("TRADE_SKILL_ITEM_CRAFTED_RESULT", function() Trace("CRAFTED") end)
TB.On("UI_ERROR_MESSAGE", function(_, msg) Trace("UI_ERR", TB.Secret(msg) and "SECRET" or tostring(msg)) end)
TB.On("BAG_UPDATE_COOLDOWN", function() Trace("BAG_CD") end)
local function IsFishing(spellID) return spellID and not TB.Secret(spellID) and TB.DATA.fishingSpells[spellID] end

-- pool learning: name at cast time, position = player + offset along facing, saved on confirmed fishing loot
TB.HBD = LibStub("HereBeDragons-2.0")
TB.POOL_OFFSET, TB.POOL_MERGE, TB.HOVER_SECONDS = 15, 15, 60 -- yards, yards, seconds; tune if one pool splits or two merge

-- probe 6B: pools never become softinteract; the name only shows in the hover tooltip. Remember the last
-- hovered pool so a cast within HOVER_SECONDS of hovering still learns it (one-key casters rarely hover at cast time).
TB.lastHover = nil -- { name, t }

-- detector: chat line + flash when a pool is hovered or soft-targeted; once per pool per minute, never in combat
TB.alerts = {}
local function Alert(name)
  if not TB.active or not TB.db.detect or InCombatLockdown() then return end
  if TB.ShouldAlert(TB.alerts, name, GetTime(), 60) then
    TB.Print(name .. " nearby")
    if TB.db.flash then TB.Flash() end
  end
end
table.insert(TB.inits, function()
  GameTooltip:HookScript("OnShow", function()
    local t = GameTooltipTextLeft1:GetText()
    if t and not TB.Secret(t) and TB.PoolKey(t, TB.DATA.pools) then TB.lastHover = { name = t, t = GetTime() }; Alert(t) end
  end)
end)
-- probe 6B saw no pool as softinteract; kept so the alert fires if a later build makes pools soft-targetable
TB.On("PLAYER_SOFT_INTERACT_CHANGED", function()
  local ok, n = pcall(function() if UnitExists("softinteract") and UnitIsGameObject("softinteract") then return UnitName("softinteract") end end)
  if ok and n and not TB.Secret(n) and TB.PoolKey(n, TB.DATA.pools) then Alert(n) end
end)

-- pool under soft-interact, else the tooltip, else a recent hover; nil when secret or not a known pool
function TB.ReadPoolTarget()
  local ok, n = pcall(function() if UnitExists("softinteract") and UnitIsGameObject("softinteract") then return UnitName("softinteract") end end)
  if ok and n and not TB.Secret(n) and TB.PoolKey(n, TB.DATA.pools) then return n end
  if GameTooltip:IsShown() then
    local t = GameTooltipTextLeft1:GetText()
    if t and not TB.Secret(t) and TB.PoolKey(t, TB.DATA.pools) then return t end
  end
  if TB.lastHover and GetTime() - TB.lastHover.t < TB.HOVER_SECONDS then return TB.lastHover.name end
end

function TB.PlayerPos()
  local x, y, map = TB.HBD:GetPlayerZonePosition()
  if not x or TB.Secret(x) or not map then return end
  return x, y, map
end

TB.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if unit ~= "player" then return end
  if not IsFishing(spellID) then TB.castPool = nil return end
  local name = TB.ReadPoolTarget()
  local x, y, map = TB.PlayerPos()
  TB.castPool = name and x and { key = TB.PoolKey(name, TB.DATA.pools), x = x, y = y, map = map, facing = GetPlayerFacing() } or nil
  local raw = GameTooltip:IsShown() and GameTooltipTextLeft1:GetText()
  local hv = TB.lastHover and string.format("%s %.0fs", TB.lastHover.name, GetTime() - TB.lastHover.t) or "none"
  Trace("POOL@CAST", tostring(name) .. " | tt " .. (TB.Secret(raw) and "SECRET" or tostring(raw)) .. " | hover " .. hv
    .. " | pos " .. (x and string.format("%.3f,%.3f m%s", x, y, tostring(map)) or "nil"))
end)

function TB.LearnPool()
  local c = TB.castPool
  TB.castPool = nil
  if not c then Trace("LEARN", "no castPool") return end
  if not c.facing or TB.Secret(c.facing) then Trace("LEARN", "no facing") return end
  local w, h = TB.HBD:GetZoneSize(c.map)
  if not w or w == 0 then Trace("LEARN", "no zone size m" .. tostring(c.map)) return end
  local x, y = TB.OffsetPos(c.x, c.y, c.facing, TB.POOL_OFFSET, w, h)
  TB.db.pools[c.map] = TB.db.pools[c.map] or {}
  local _, isNew = TB.MergePool(TB.db.pools[c.map], x, y, c.key, time(), TB.POOL_MERGE, w, h)
  Trace("LEARN", c.key .. (isNew and " new" or " merged"))
  if isNew then TB.Print("learned " .. TB.PoolByKey(TB.DATA.pools, c.key).name) end
  if TB.Pins then TB.Pins.Refresh() end
end

function TB.Waypoint(map, x, y)
  if not C_Map.CanSetUserWaypointOnMap(map) then return TB.Print("can't set a waypoint on this map") end
  C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
  C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end
-- nearby distances go stale as you walk; refresh only while the Spots tab is on screen
table.insert(TB.inits, function()
  C_Timer.NewTicker(2, function() if TB.db.shown and TB.db.expanded and TB.db.tab == "spots" then TB.Refresh() end end)
end)
TB.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if unit ~= "player" or not IsFishing(spellID) then return end
  local _, _, _, st, et = UnitChannelInfo("player")
  if not st or TB.Secret(st) or TB.Secret(et) then st = GetTime() * 1000; et = st + TB.DATA.castSeconds * 1000 end
  TB.StartCastBar(st, et)
  TB.ReelMode(true)
end)
TB.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit)
  if unit ~= "player" or not (TB.lastChannel and IsFishing(TB.lastChannel.spellID)) then return end
  TB.StopCastBar()
  TB.ReelMode(false)
  local stopT = GetTime()
  C_Timer.After(1, function()
    if TB.IsMiss(stopT, TB.lastLootT) then
      TB.session.misses = TB.session.misses + 1
      if TB.db.flash then TB.Flash() end
      TB.Refresh()
    end
  end)
end)

local looted = false -- LOOT_READY can fire twice per window
TB.On("LOOT_CLOSED", function() looted = false end)
TB.On("LOOT_READY", function()
  if looted then return end
  local isFL -- nil = API missing; keep false distinct from nil
  if IsFishingLoot then isFL = IsFishingLoot() and true or false end
  if not TB.IsFishingCatch(isFL, TB.lastChannel, GetTime(), TB.DATA.fishingSpells) then return end
  looted = true
  TB.LearnPool() -- only confirmed fishing loot learns a pool
  TB.lastLootT = GetTime()
  local sub = GetSubZoneText()
  local zone = GetRealZoneText() .. ((sub and sub ~= "") and (" - " .. sub) or "")
  for i = 1, GetNumLootItems() do
    local link = GetLootSlotLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    local _, _, qty, _, quality = GetLootSlotInfo(i)
    if id then TB.RecordCatch(TB.char.catches, id, qty, time(), zone, quality) end
  end
  TB.Refresh()
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
  P("override bindings", TB.HasBindAPI())
  P("cast key", TB.db.castKey)

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
  Try("softinteract", function()
    P("softinteract", tostring(UnitExists("softinteract")) .. " obj " .. tostring(UnitIsGameObject("softinteract"))
      .. " name " .. S(UnitName("softinteract")) .. " guid " .. S(UnitGUID("softinteract")))
  end)
  Try("tooltip", function() P("tooltip", tostring(GameTooltip:IsShown()) .. " " .. S(GameTooltipTextLeft1:GetText())) end)
  Try("cvar", function() P("SoftTargetInteract", tostring(C_CVar.GetCVar("SoftTargetInteract"))) end)
  Try("map", function()
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    P("map", tostring(m) .. " pos " .. (pos and (S(pos.x) .. "," .. S(pos.y)) or "nil") .. " facing " .. S(GetPlayerFacing()))
  end)
  Try("pools", function()
    local x, y, m = TB.PlayerPos()
    local w, h; if m then w, h = TB.HBD:GetZoneSize(m) end
    local n = 0
    for _, l in pairs(TB.db.pools) do n = n + #l end
    P("pools", "HBD pos " .. tostring(x) .. "," .. tostring(y) .. " m" .. tostring(m) .. " size " .. tostring(w) .. "x" .. tostring(h)
      .. " saved " .. n .. " hover " .. (TB.lastHover and TB.lastHover.name or "none"))
  end)
  P("map hooks", "AddDataProvider " .. type(WorldMapFrame and WorldMapFrame.AddDataProvider) .. " mixin " .. type(MapCanvasDataProviderMixin))

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

-- probe run 7: camp items, campfire/camp buffs, cooldown source, recipe-known check, craft methods
local CAMP_PROBE = {
  items = { 279967, 279965, 279966, 279981, 279961, 279974 }, -- Bowl, Rack, Hut, campfire kits (Basic, Journeyman, Expert)
  recipes = { 1229745, 1262990, 1262998 },                   -- Bowl, Rack, Hut craft spells (probe-results.md:100-113)
  places = { 1307247, 1307246 },                             -- Rack, Hut placement spells
  words = { "Wood", "Steak", "Vial", "Runecloth", "Trout", "Smallfish", "Campfire", "Blueprint" },
}
function TB.CampProbe()
  TB.db.lastProbe = {}
  local function S(v) if TB.Secret(v) then return "SECRET" end return tostring(v) end
  local function P(k, v) local line = k .. ": " .. tostring(v); TB.Print(line); table.insert(TB.db.lastProbe, line) end
  local function Try(k, fn) local ok, err = pcall(fn); if not ok then P(k, "ERROR " .. tostring(err)) end end
  P("combat", InCombatLockdown())
  Try("auras", function()
    for i = 1, 40 do
      local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
      if not a then break end
      P("aura " .. i, S(a.spellId) .. " " .. S(a.name) .. " exp " .. S(a.expirationTime))
    end
  end)
  for _, id in ipairs(CAMP_PROBE.items) do
    Try("item" .. id, function()
      local st, d, e = C_Container.GetItemCooldown(id)
      local sn, sid = C_Item.GetItemSpell(id)
      P("item " .. id, tostring(C_Item.GetItemNameByID(id)) .. " n" .. C_Item.GetItemCount(id) .. " cd " .. S(st) .. "/" .. S(d) .. "/" .. S(e)
        .. " spell " .. tostring(sn) .. " " .. tostring(sid))
    end)
  end
  for _, id in ipairs(CAMP_PROBE.places) do
    Try("place" .. id, function()
      local c = C_Spell.GetSpellCooldown(id)
      P("place " .. id, c and (S(c.startTime) .. "/" .. S(c.duration)) or "nil")
    end)
  end
  for _, id in ipairs(CAMP_PROBE.recipes) do
    Try("recipe" .. id, function()
      local info = C_TradeSkillUI.GetRecipeInfo(id)
      P("recipe " .. id, "known " .. tostring(C_SpellBook.IsSpellKnown(id)) .. " info "
        .. (info and (tostring(info.name) .. " learned " .. tostring(info.learned)) or "nil"))
    end)
  end
  Try("bags", function()
    for bag = 0, NUM_BAG_SLOTS or 4 do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local it = C_Container.GetContainerItemInfo(bag, slot)
        if it and it.itemID then
          for _, w in ipairs(CAMP_PROBE.words) do
            if (it.itemName or ""):find(w, 1, true) then P("bag " .. it.itemID, it.itemName .. " x" .. tostring(it.stackCount)); break end
          end
        end
      end
    end
  end)
  local t0 = TB.trace[1] and TB.trace[1][1] or 0
  for _, e in ipairs(TB.trace) do P("trace", string.format("+%.2f %s %s", e[1] - t0, e[2], tostring(e[3] or ""))) end
end

-- temporary craft/place test buttons (probe run 7); removed once the results are in Data.lua
local testFrame
function TB.CampTestButtons()
  if InCombatLockdown() then return TB.Print("not in combat") end
  if testFrame then testFrame:SetShown(not testFrame:IsShown()) return end
  testFrame = CreateFrame("Frame", "TBCampTest", UIParent, "BackdropTemplate")
  testFrame:SetSize(330, 40); testFrame:SetPoint("CENTER", 0, 200); TB.Skin(testFrame, 12)
  local defs = {
    { "macro", function(b) b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", "/cast Fish Bowl") end },
    { "spell", function(b) b:SetAttribute("type", "spell"); b:SetAttribute("spell", 1229745) end },
    { "api", function(b) b:SetScript("PostClick", function()
      local ok, err = pcall(C_TradeSkillUI.CraftRecipe, 1229745); TB.Print("CraftRecipe " .. tostring(ok) .. " " .. tostring(err)) end) end },
    { "window", function(b) b:SetScript("PostClick", function()
      local ok, err = pcall(C_TradeSkillUI.OpenTradeSkill, 356); TB.Print("OpenTradeSkill " .. tostring(ok) .. " " .. tostring(err)) end) end },
    { "kit", function(b) b:SetAttribute("type", "item"); b:SetAttribute("item", "item:279981") end },
    { "bowl", function(b) b:SetAttribute("type", "item"); b:SetAttribute("item", "item:279967") end },
  }
  for i, d in ipairs(defs) do
    local b = CreateFrame("Button", "TBCampTest" .. i, testFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetSize(50, 24); b:SetPoint("LEFT", 6 + (i - 1) * 53, 0); b:SetText(d[1]); b:RegisterForClicks("AnyUp", "AnyDown")
    d[2](b)
  end
end

SLASH_TACKLEBOX1 = "/tb"
SlashCmdList.TACKLEBOX = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "show" or cmd == "hide" then TB.db.shown = cmd == "show"; TB.Refresh()
  elseif cmd == "" then TB.db.shown = not TB.db.shown; TB.Refresh()
  elseif cmd == "lock" then TB.db.locked = not TB.db.locked; TB.Print(TB.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(TB.db.frames); TB.Print("positions reset; /reload to apply")
  elseif cmd == "probe" then TB.Probe()
  elseif cmd == "flash" then TB.db.flash = not TB.db.flash; TB.Print("flash " .. (TB.db.flash and "on" or "off"))
  elseif cmd == "camp" then if (msg or ""):lower():match("test") then TB.CampTestButtons() else TB.CampProbe() end
  elseif cmd == "detect" then TB.db.detect = not TB.db.detect; TB.Print("pool alerts " .. (TB.db.detect and "on" or "off"))
  elseif cmd == "pins" then
    local which = (msg or ""):lower():match("^%s*%S+%s+(%S+)")
    if which ~= "map" and which ~= "minimap" then TB.Print("usage: /tb pins map||minimap")
    else TB.db.pins[which] = not TB.db.pins[which]; TB.Pins.Refresh(); TB.Print(which .. " pins " .. (TB.db.pins[which] and "on" or "off")) end
  elseif cmd == "bind" then
    local key = TB.NormalizeKey((msg or ""):match("^%s*%S+%s+(.-)%s*$"))
    if not key then TB.Print("usage: /tb bind <KEY>, for example /tb bind F")
    elseif InCombatLockdown() then TB.Print("can't change the cast key in combat")
    elseif not TB.HasBindAPI() then TB.Print("one-key cast is unavailable on your client")
    else
      TB.db.castKey = key; TB.BindCast()
      TB.Print("cast key: " .. key .. ". If reeling in does nothing, turn on Enable Interact Key in the game's options.")
    end
  elseif cmd == "unbind" then
    if InCombatLockdown() then TB.Print("can't change the cast key in combat")
    else TB.db.castKey = nil; TB.BindCast(); TB.Print("cast key cleared") end
  else TB.Print("/tb show||hide||lock||reset||probe||flash||pins map||minimap||detect||camp||bind <key>||unbind") end -- || prints one pipe; a bare |h starts a chat link escape
end
