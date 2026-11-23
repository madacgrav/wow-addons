local ADDON, WCK = ...

WCK.inits, WCK.refreshers = {}, {}
WCK.targetSlot = 1 -- bumped per target switch; keys rows when the game hides enemy identity

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

local DEFAULTS = { locked = false, shown = true, frames = {}, minimapAngle = 240, plateMarker = false,
  procAlerts = true, procSound = true, showBar = true, settingsTab = 1 }
local CHAR_DEFAULTS = { slots = {}, alts = {} }

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
WCK.trace = {} -- last 40 {t, event, detail}
function WCK.Trace(ev, d)
  table.insert(WCK.trace, { GetTime(), ev, d })
  if #WCK.trace > 40 then table.remove(WCK.trace, 1) end
end
local function S(v) if WCK.Secret(v) then return "SECRET" end return tostring(v) end
WCK.S = S
-- trace handlers are diagnostics: a failing read must never error on every event
local function Safe(fn) return function(...) pcall(fn, ...) end end

WCK.On("UNIT_SPELLCAST_SENT", Safe(function(unit, target, castGUID, spellID)
  if unit == "player" then WCK.Trace("SENT", S(spellID) .. " tgt=" .. S(target) .. " guid=" .. S(castGUID)) end
end))
for _, ev in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
  WCK.On(ev, Safe(function(unit, castGUID, spellID)
    if unit == "player" or unit == "pet" then WCK.Trace(ev:sub(16), unit .. " " .. S(spellID) .. " guid=" .. S(castGUID)) end
  end))
end
-- OVERLAY_HIDE fires every few seconds with a nil spellID; skip only that one so it doesn't flood the 20-entry ring
WCK.overlayReg = {}
for _, ev in ipairs({ "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" }) do
  WCK.overlayReg[ev] = WCK.On(ev, Safe(function(spellID)
    if spellID ~= nil or ev ~= "SPELL_ACTIVATION_OVERLAY_HIDE" then WCK.Trace(ev:sub(18), S(spellID)) end
  end))
end

-- Blizzard's own proc glow on action buttons (GlowWatcher-style): post-hooks only, never replace
local function ButtonSpell(b)
  local action = b and (b.action or (b.GetAction and b:GetAction()))
  if not action or WCK.Secret(action) then return "?" end
  local kind, id = GetActionInfo(action)
  return S(kind) .. ":" .. S(id)
end
WCK.On("PLAYER_LOGIN", function()
  local M = ActionButtonSpellAlertManager
  if M and M.ShowAlert then
    -- HideAlert runs on every button on each bar update; trace a hide only for a button we saw shown
    local shown = {}
    hooksecurefunc(M, "ShowAlert", Safe(function(_, b) shown[b] = true; WCK.Trace("ALERT_SHOW", ButtonSpell(b)) end))
    hooksecurefunc(M, "HideAlert", Safe(function(_, b)
      if shown[b] then shown[b] = nil; WCK.Trace("ALERT_HIDE", ButtonSpell(b)) end
    end))
    WCK.alertHook = "ActionButtonSpellAlertManager"
  elseif ActionButton_ShowOverlayGlow then
    hooksecurefunc("ActionButton_ShowOverlayGlow", Safe(function(b) WCK.Trace("GLOW_SHOW_BTN", ButtonSpell(b)) end))
    hooksecurefunc("ActionButton_HideOverlayGlow", Safe(function(b) WCK.Trace("GLOW_HIDE_BTN", ButtonSpell(b)) end))
    WCK.alertHook = "ActionButton_ShowOverlayGlow"
  end
end)
for _, ev in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
  WCK.On(ev, Safe(function(unit) WCK.Trace(ev:sub(12), S(unit) .. " guid=" .. S(UnitGUID(unit)) .. " dead=" .. S(UnitIsDead(unit))) end))
end
WCK.On("PLAYER_REGEN_DISABLED", function() WCK.Trace("REGEN_DISABLED") end)
WCK.On("PLAYER_REGEN_ENABLED", function() WCK.Trace("REGEN_ENABLED") end)

-- cast map: what I cast on which enemy, from my own cast events (enemy auras are unreadable in combat)
local function NonSecret(v) if WCK.Secret(v) then return nil end return v end

function WCK.SpellName(spellID)
  if not spellID or WCK.Secret(spellID) then return nil end
  local info = C_Spell.GetSpellInfo(spellID)
  return info and info.name
end

-- key, label, guid, marked, secret; marks are secret in combat once set, so only "is there one" is known
-- secret = { rawName } when the name is secret (dungeon combat): only ever handed to SetText, never compared
function WCK.Identify(unit, slot)
  local okG, guid = pcall(UnitGUID, unit)
  local okN, raw = pcall(UnitName, unit)
  local okM, m = pcall(GetRaidTargetIndex, unit)
  local secret = okN and WCK.Secret(raw) and { raw } or nil
  guid = okG and NonSecret(guid) or nil
  local name = okN and NonSecret(raw) or nil
  local key, label = WCK.EnemyKey(guid, name, slot)
  return key, label, guid, okM and (WCK.Secret(m) or m ~= nil) or false, secret
end

-- procs: Nightfall on Forever has no overlay event or button glow (probe runs 7-12), but it makes
-- Shadow Bolt instant and castTime is readable in combat, so castTime 0 = proc up.
-- ponytail: an instant-cast talent/rank for the proc spell would read as a permanent proc
WCK.procs = {}
table.insert(WCK.refreshers, function() -- file scope: runs before the panel's refresher
  local times = {}
  for _, p in ipairs(WCK.DATA.procs) do
    local ok, info = pcall(C_Spell.GetSpellInfo, p.spell)
    local ct = ok and info and info.castTime
    if ct ~= nil and not WCK.Secret(ct) and IsPlayerSpell(info.spellID) then times[p.spell] = ct end
  end
  local up = WCK.ProcsUp(WCK.DATA.procs, times)
  if WCK.db.procAlerts and WCK.db.procSound and #WCK.NewProcs(WCK.procs, up) > 0 then
    PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")
  end
  WCK.procs = up
end)
WCK.On("UNIT_AURA", function(u) if not WCK.Secret(u) and u == "player" then WCK.Refresh() end end) -- event only; the aura payload is never read
WCK.On("SPELL_UPDATE_USABLE", WCK.Refresh)
WCK.On("PLAYER_TALENT_UPDATE", WCK.Refresh)

-- rotation helper: display only, the player presses their own key
WCK.USABLE_OK = true -- probe run 1: IsSpellUsable is non-secret in combat (open world); pcall/Secret still guard it

-- spellbook cache feeding the rule/slot dropdowns and rule state; rebuilt at login and on SPELLS_CHANGED
WCK.spellTabs, WCK.spellSet = {}, {}
function WCK.ScanSpellbook()
  local ok, entries = pcall(function()
    local out, bank = {}, Enum.SpellBookSpellBank.Player
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
      if line and not line.shouldHide then
        for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
          local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
          if info then out[#out + 1] = { tab = line.name, name = info.name, itemType = info.itemType, isPassive = info.isPassive } end
        end
      end
    end
    return out
  end)
  if not ok then return end -- keep the last good cache (secret reads or a missing API land here)
  local okB, tabs, set = pcall(WCK.BuildSpellTabs, entries)
  if okB then WCK.spellTabs, WCK.spellSet = tabs, set end
end

function WCK.Known(name)
  local ok, info = pcall(C_Spell.GetSpellInfo, name)
  return ok and info and IsPlayerSpell(info.spellID) or false
end

function WCK.BuildRuleState(now)
  local s = { known = {}, ready = {}, usable = {}, lastOnTarget = {}, proc = next(WCK.procs) ~= nil, marked = false }
  for _, name in ipairs(WCK.RuleSpells(WCK.char.rules)) do
    if WCK.spellSet[name] then
      s.known[name] = true
      local okC, cd = pcall(C_Spell.GetSpellCooldown, name)
      if okC and cd and not WCK.Secret(cd.isActive) and not WCK.Secret(cd.isOnGCD) then
        s.ready[name] = not cd.isActive or cd.isOnGCD == true -- GCD alone does not block
      end
      if WCK.USABLE_OK then
        local okU, u = pcall(C_Spell.IsSpellUsable, name)
        if okU and not WCK.Secret(u) then s.usable[name] = u end
      end
    end
  end
  if UnitExists("target") then
    local key, _, _, marked = WCK.Identify("target", WCK.targetSlot)
    s.marked = marked
    local row = WCK.map.rows[key]
    if row then for spell, t in pairs(row.casts) do s.lastOnTarget[spell] = now - t end end
  end
  return s
end

table.insert(WCK.refreshers, function() -- file scope: runs after the proc refresher, before the panel's
  WCK.ruleState = WCK.BuildRuleState(GetTime())
  WCK.next = WCK.EvalRules(WCK.char.rules, WCK.ruleState)
end)

-- bar cooldowns: every bar spell (rules + known tail), not just rule spells; secret fields read as unknown
local function Clean(v) if WCK.Secret(v) then return nil end return v end
function WCK.BuildCooldowns(spells)
  local onCD, earliest = {}, nil
  for _, name in ipairs(spells) do
    local ok, cd = pcall(C_Spell.GetSpellCooldown, name)
    if ok and type(cd) == "table" then
      local on, ends = WCK.CooldownState({ isActive = Clean(cd.isActive), isOnGCD = Clean(cd.isOnGCD),
        startTime = Clean(cd.startTime), duration = Clean(cd.duration) })
      if on then
        onCD[name] = true
        if ends and (not earliest or ends < earliest) then earliest = ends end
      end
    end
  end
  return onCD, earliest
end
WCK.onCD, WCK.cdEnd = {}, nil
local scheduledEnd -- end time of the one pending expiry timer
table.insert(WCK.refreshers, function() -- after WCK.next, before Rotation.lua's highlight refresher
  local spells = {}
  for _, e in ipairs(WCK.BarSpells(WCK.char.rules, WCK.DATA.tail, WCK.spellSet, WCK.DATA.core)) do spells[#spells + 1] = e.spell end
  WCK.onCD, WCK.cdEnd = WCK.BuildCooldowns(spells)
  -- SPELL_UPDATE_COOLDOWN on expiry is unverified on Forever: redraw once at the earliest readable end
  local now, e = GetTime(), WCK.cdEnd
  if e and e > now and (not scheduledEnd or e < scheduledEnd) then
    scheduledEnd = e
    C_Timer.After(e - now + 0.05, function() scheduledEnd = nil; WCK.Refresh() end)
  end
end)
WCK.On("SPELL_UPDATE_COOLDOWN", WCK.Refresh)
WCK.On("PLAYER_TARGET_CHANGED", WCK.Refresh)
WCK.On("RAID_TARGET_UPDATE", WCK.Refresh)

-- true only for a readable "dead"; a secret or erroring read counts as alive (comparing a secret errors)
function WCK.IsDead(unit)
  local ok, d = pcall(UnitIsDead, unit)
  return ok and not WCK.Secret(d) and d == true
end

table.insert(WCK.inits, function()
  -- not via MergeDefaults: a merged list would mix the saved rules with the defaults
  if WCK.char.rules == nil then WCK.char.rules = WCK.CopyRules(WCK.DATA.defaultRules) end
  WCK.ScanSpellbook()
  WCK.On("SPELLS_CHANGED", function() WCK.ScanSpellbook(); WCK.Refresh() end)
  WCK.map = WCK.NewCastMap()
  WCK.On("UNIT_SPELLCAST_SENT", function(unit, target, castGUID, spellID)
    if unit ~= "player" then return end
    local spell = WCK.SpellName(spellID)
    -- trace casts lost to secrecy so a dungeon run shows whether SENT itself is blind
    if WCK.Secret(spellID) or (spell and WCK.DATA.tracked[spell] and WCK.Secret(castGUID)) then
      WCK.Trace("DROP", "spell=" .. S(spellID) .. " guid=" .. S(castGUID)); return
    end
    if not spell or not WCK.DATA.tracked[spell] then return end
    local names = {}
    for _, u in ipairs({ "mouseover", "target", "focus" }) do names[u] = NonSecret(UnitName(u)) end
    local u = WCK.PickUnit(NonSecret(target), names)
    local key, label, guid, _, secret = WCK.Identify(u, u == "target" and WCK.targetSlot or nil)
    label = label or NonSecret(target)
    WCK.Trace("KEY", u .. " " .. key .. " lbl=" .. S(label) .. (secret and " secret" or ""))
    WCK.CastSent(WCK.map, castGUID, spell, key, label, guid, GetTime(), secret)
  end)
  WCK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, castGUID, spellID)
    if unit == "player" and not WCK.Secret(castGUID) then WCK.CastSucceeded(WCK.map, castGUID, GetTime()); WCK.Refresh()
    elseif unit == "pet" then -- Seduction: pet casts have no SENT; key on the pet's target
      local spell = WCK.SpellName(spellID)
      if spell and WCK.DATA.tracked[spell] then
        -- probe run 13: the pet/target comparison is secret in dungeons, so this usually lands on "pet"
        local okS, same = pcall(UnitIsUnit, "pettarget", "target")
        local slot = (okS and not WCK.Secret(same) and same == true) and WCK.targetSlot or "pet"
        local key, label, guid, _, secret = WCK.Identify("pettarget", slot)
        WCK.CastLanded(WCK.map, key, label, guid, spell, GetTime(), secret); WCK.Refresh()
      end
    end
  end)
  for _, ev in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
    WCK.On(ev, function(unit, castGUID) if unit == "player" and not WCK.Secret(castGUID) then WCK.CastFailed(WCK.map, castGUID) end end)
  end
  -- probe: removal on a kill reads dead=true; a leash/evade reads dead=false and keeps the row
  WCK.On("NAME_PLATE_UNIT_REMOVED", function(unit)
    local guid = NonSecret(UnitGUID(unit))
    if guid and WCK.IsDead(unit) then WCK.Trace("CLR_PLATE", guid .. " rows=" .. WCK.ClearGUID(WCK.map, guid)); WCK.Refresh() end
  end)
  WCK.On("PLAYER_TARGET_CHANGED", function() WCK.targetSlot = WCK.targetSlot + 1 end)
  -- Refresh is debounced 0.1s, so this clear lands before the redraw
  WCK.On("PLAYER_REGEN_ENABLED", function() WCK.ClearAll(WCK.map); WCK.targetSlot = 1 end)
  local lastDeadTarget -- trace each dead target once, matched or not
  C_Timer.NewTicker(0.5, function()
    if next(WCK.map.rows) == nil then return end
    if WCK.IsDead("target") then
      -- dungeons hide the guid: fall back to the row key (the current target slot)
      local key, _, guid = WCK.Identify("target", WCK.targetSlot)
      local n = guid and WCK.ClearGUID(WCK.map, guid) or WCK.ClearRow(WCK.map, key)
      local id = guid or key
      if id ~= lastDeadTarget then lastDeadTarget = id; WCK.Trace("CLR_TARGET", id .. " rows=" .. n) end
    end
    WCK.Refresh()
  end)
end)

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

  for _, u in ipairs({ "target", "focus", "mouseover", "pettarget", "nameplate1", "nameplate2" }) do
    Try("unit " .. u, function()
      if not UnitExists(u) then return end
      local okU, isT = pcall(UnitIsUnit, u, "target")
      P("unit " .. u, "guid " .. S(UnitGUID(u)) .. " name " .. S(UnitName(u)) .. " mark " .. S(GetRaidTargetIndex(u))
        .. " dead " .. S(UnitIsDead(u)) .. " hostile " .. S(UnitCanAttack("player", u))
        .. " isTarget " .. (okU and S(isT) or "ERROR"))
    end)
  end
  if C_Secrets then
    Try("secrets identity", function() P("secrets identity", S(C_Secrets.ShouldUnitIdentityBeSecret("target"))) end)
    Try("secrets compare", function()
      P("secrets compare", "can " .. S(C_Secrets.CanCompareUnitTokens("target", "nameplate1"))
        .. " secret " .. S(C_Secrets.ShouldUnitComparisonBeSecret("target", "nameplate1")))
    end)
    Try("secrets restricted", function() P("secrets restricted", S(C_Secrets.HasSecretRestrictions())) end)
  else
    P("secrets", "C_Secrets: missing")
  end

  for _, n in ipairs({ "Shadow Bolt", "Corruption" }) do
    Try("spell " .. n, function()
      local usable, noMana = C_Spell.IsSpellUsable(n)
      local cd = C_Spell.GetSpellCooldown(n)
      P("spell " .. n, "usable " .. S(usable) .. "/" .. S(noMana) .. " range " .. S(C_Spell.IsSpellInRange(n, "target"))
        .. " cd " .. (cd and ("active " .. S(cd.isActive) .. " gcd " .. S(cd.isOnGCD) .. " enabled " .. S(cd.isEnabled)
        .. " start " .. S(cd.startTime)) or "nil"))
      -- Nightfall makes Shadow Bolt instant: castTime 0 while the proc is up would be a non-aura proc signal
      local info = C_Spell.GetSpellInfo(n)
      P("castTime " .. n, info and S(info.castTime) or "nil")
    end)
  end

  Try("secrets", function()
    P("secrecy 17941", S(C_Secrets.GetSpellAuraSecrecy(17941)))
    P("secrecy Shadow Trance", S(C_Secrets.GetSpellAuraSecrecy("Shadow Trance")))
  end)
  -- direct lookup by id; GetAuraDataByIndex errors in combat (WUK), this may too
  Try("aura 17941", function()
    local a = C_UnitAuras.GetPlayerAuraBySpellID(17941)
    P("aura 17941", a and ("up exp " .. S(a.expirationTime)) or "nil")
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

  -- no CLEU test: registering it is a forbidden action on Midnight-era clients (blocked-action popup, not a Lua error)

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

  local reg = {}
  for ev, ok in pairs(WCK.overlayReg) do reg[#reg + 1] = ev:sub(26) .. "=" .. tostring(ok) end
  P("overlay events", table.concat(reg, " "))
  P("alert hook", WCK.alertHook or "none")
  if WCK.map then
    for key, row in pairs(WCK.map.rows) do
      local spells = {}
      for spell, t in pairs(row.casts) do spells[#spells + 1] = spell .. string.format("@%.0fs", GetTime() - t) end
      P("row " .. key, tostring(row.label) .. " guid " .. tostring(row.guid) .. (row.secret and " secretName" or "")
        .. " " .. table.concat(spells, ", "))
    end
    local tk, _, tg = WCK.Identify("target", WCK.targetSlot)
    P("target key", tk .. " dead " .. tostring(WCK.IsDead("target")) .. " guid " .. tostring(tg))
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
  elseif cmd == "config" then WCK.ToggleSettings()
  elseif cmd == "show" or cmd == "hide" then WCK.db.shown = (cmd == "show"); WCK.Refresh()
  else WCK.Print("/wck config||show||hide||lock||reset||probe") end -- || prints one pipe; a bare |h starts a chat link escape
end
