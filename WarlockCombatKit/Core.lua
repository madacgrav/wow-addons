local ADDON, WCK = ...

WCK.inits, WCK.refreshers = {}, {}

function WCK.Secret(v) return issecretvalue ~= nil and issecretvalue(v) end
function WCK.Print(msg) print("|cff9482c9WCK|r " .. msg) end

-- RegisterEvent under pcall: an event this client doesn't know raises an error; returns false then
local events, handlers = CreateFrame("Frame"), {}
function WCK.On(event, fn)
  if not handlers[event] then
    if not pcall(events.RegisterEvent, events, event) then return false end
    handlers[event] = {}
  end
  table.insert(handlers[event], fn)
  return true
end
events:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do fn(...) end
end)

local DEFAULTS = { locked = false, shown = true, frames = {}, minimapAngle = 240 }
local CHAR_DEFAULTS = {}

WCK.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  -- nil-safe: the Forever beta loader bug can leave these nil every session
  WarlockCombatKitDB = WCK.MergeDefaults(WarlockCombatKitDB, DEFAULTS)
  WarlockCombatKitCharDB = WCK.MergeDefaults(WarlockCombatKitCharDB, CHAR_DEFAULTS)
  WCK.db, WCK.char = WarlockCombatKitDB, WarlockCombatKitCharDB
end)

local pending = false
function WCK.Refresh()
  if not WCK.active or pending then return end
  pending = true
  C_Timer.After(0.1, function()
    pending = false
    for _, fn in ipairs(WCK.refreshers) do fn() end
  end)
end

WCK.On("PLAYER_LOGIN", function()
  local _, class = UnitClass("player")
  if class ~= "WARLOCK" then return end
  WCK.active = true
  for _, init in ipairs(WCK.inits) do init() end
  WCK.Refresh()
end)
WCK.On("PLAYER_REGEN_ENABLED", WCK.Refresh)

-- probe snapshots: always on so /wck probe can report event order and secrecy
WCK.trace = {} -- last 20 {t, event, detail}
function WCK.Trace(ev, d)
  table.insert(WCK.trace, { GetTime(), ev, d })
  if #WCK.trace > 20 then table.remove(WCK.trace, 1) end
end
local function S(v) if WCK.Secret(v) then return "SECRET" end return tostring(v) end
WCK.S = S

WCK.On("UNIT_SPELLCAST_SENT", function(unit, target, castGUID, spellID)
  if unit == "player" then WCK.Trace("SENT", S(spellID) .. " tgt=" .. S(target) .. " guid=" .. S(castGUID)) end
end)
for _, ev in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
  WCK.On(ev, function(unit, castGUID, spellID)
    if unit == "player" or unit == "pet" then WCK.Trace(ev:sub(16), unit .. " " .. S(spellID) .. " guid=" .. S(castGUID)) end
  end)
end
for _, ev in ipairs({ "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" }) do
  if not WCK.On(ev, function(spellID) WCK.Trace(ev:sub(18), S(spellID)) end) then WCK.Trace("noevent", ev) end
end
for _, ev in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
  WCK.On(ev, function(unit) WCK.Trace(ev:sub(12), S(unit) .. " guid=" .. S(UnitGUID(unit))) end)
end
WCK.On("PLAYER_REGEN_DISABLED", function() WCK.Trace("REGEN_DISABLED") end)
WCK.On("PLAYER_REGEN_ENABLED", function() WCK.Trace("REGEN_ENABLED") end)

local function SpellName(id)
  local info = id and not WCK.Secret(id) and C_Spell.GetSpellInfo(id)
  return info and info.name or S(id)
end

-- dumps the in-combat facts WCK needs; output saved to WarlockCombatKitDB.lastProbe for probe-results.md
function WCK.Probe()
  WCK.db.lastProbe = {}
  local function P(k, v) local line = k .. ": " .. tostring(v); WCK.Print(line); table.insert(WCK.db.lastProbe, line) end
  local function Try(k, fn) local ok, err = pcall(fn); if not ok then P(k, "ERROR " .. tostring(err)) end end

  local ver, build = GetBuildInfo()
  local inInst, kind = IsInInstance()
  P("ctx", tostring(ver) .. " " .. tostring(build) .. " instance " .. tostring(inInst) .. " " .. tostring(kind)
    .. " combat " .. tostring(InCombatLockdown()))

  for _, u in ipairs({ "target", "focus", "mouseover", "nameplate1", "nameplate2" }) do
    Try("unit " .. u, function()
      if not UnitExists(u) then return end
      local okU, isT = pcall(UnitIsUnit, u, "target")
      P("unit " .. u, "guid " .. S(UnitGUID(u)) .. " name " .. S(UnitName(u)) .. " mark " .. S(GetRaidTargetIndex(u))
        .. " dead " .. S(UnitIsDead(u)) .. " hostile " .. S(UnitCanAttack("player", u))
        .. " isTarget " .. (okU and S(isT) or "ERROR"))
    end)
  end

  for _, n in ipairs({ "Shadow Bolt", "Corruption" }) do
    Try("spell " .. n, function()
      local usable, noMana = C_Spell.IsSpellUsable(n)
      local cd = C_Spell.GetSpellCooldown(n)
      P("spell " .. n, "usable " .. S(usable) .. "/" .. S(noMana) .. " range " .. S(C_Spell.IsSpellInRange(n, "target"))
        .. " cd " .. (cd and ("active " .. S(cd.isActive) .. " gcd " .. S(cd.isOnGCD) .. " enabled " .. S(cd.isEnabled)
        .. " start " .. S(cd.startTime)) or "nil"))
    end)
  end

  Try("secrets", function()
    P("secrecy 17941", S(C_Secrets.GetSpellAuraSecrecy(17941)))
    P("secrecy Shadow Trance", S(C_Secrets.GetSpellAuraSecrecy("Shadow Trance")))
  end)

  local AC = C_AssistedCombat
  if AC then
    Try("assisted available", function() P("assisted available", S(AC.IsAvailable())) end)
    Try("assisted rotation", function()
      local ids = AC.GetRotationSpells()
      if not ids or WCK.Secret(ids) then return P("assisted rotation", ids and "SECRET" or "nil") end
      local names = {}
      for _, id in ipairs(ids) do names[#names + 1] = SpellName(id) end
      P("assisted rotation", #ids .. ": " .. table.concat(names, ", "))
    end)
    Try("assisted next", function() P("assisted next", SpellName(AC.GetNextCastSpell())) end)
  else
    P("C_AssistedCombat", "missing")
  end

  local f = CreateFrame("Frame")
  local okC, errC = pcall(f.RegisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED")
  P("CLEU register", okC and "ok" or tostring(errC))
  f:UnregisterAllEvents()

  Try("plate", function()
    local p = C_NamePlate.GetNamePlateForUnit("target")
    if not p then return P("plate", "nil") end
    if not p.UnitFrame then return P("plate", "no UnitFrame") end
    local okT, t = pcall(p.UnitFrame.CreateTexture, p.UnitFrame, nil, "OVERLAY")
    if okT then t:Hide() end
    P("plate texture", okT and "ok" or tostring(t))
  end)

  if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCountByUnit then
    Try("loc", function() P("loc target", S(C_LossOfControl.GetActiveLossOfControlDataCountByUnit("target"))) end)
  end

  local t0 = WCK.trace[1] and WCK.trace[1][1] or 0
  for _, e in ipairs(WCK.trace) do P("trace", string.format("+%.2f %s %s", e[1] - t0, e[2], tostring(e[3] or ""))) end
end

SLASH_WARLOCKCOMBATKIT1 = "/wck"
SlashCmdList.WARLOCKCOMBATKIT = function(msg)
  if not WCK.active then return WCK.Print("warlocks only") end
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "probe" then WCK.Probe()
  elseif cmd == "lock" then WCK.db.locked = not WCK.db.locked; WCK.Print(WCK.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(WCK.db.frames); WCK.Print("positions reset - /reload to apply")
  else WCK.Print("/wck probe||lock||reset") end -- || prints one pipe; a bare |h starts a chat link escape
end
