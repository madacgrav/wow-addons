local ADDON, BC = ...

BC.inits, BC.refreshers = {}, {}
BC.PREFIX = "BCARD"

function BC.Secret(v) return issecretvalue ~= nil and issecretvalue(v) end
function BC.Print(msg) print("|cffe0b050BC|r " .. msg) end

local events, handlers = CreateFrame("Frame"), {}
function BC.On(event, fn)
  if not handlers[event] then handlers[event] = {}; events:RegisterEvent(event) end
  table.insert(handlers[event], fn)
end
events:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do fn(...) end
end)

local DEFAULTS = { locked = false, frames = {}, lastProbe = {} }
local CHAR_DEFAULTS = {}

BC.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  -- nil-safe: the Forever beta loader bug (ForeverSVFix) can leave these nil every session
  BusinessCardDB = BC.MergeDefaults(BusinessCardDB, DEFAULTS)
  BusinessCardCharDB = BC.MergeDefaults(BusinessCardCharDB, CHAR_DEFAULTS)
  BC.db, BC.char = BusinessCardDB, BusinessCardCharDB
end)

BC.On("PLAYER_LOGIN", function()
  BC.active = true
  for _, init in ipairs(BC.inits) do init() end
end)

function BC.ProbeLine(k, v) local line = k .. ": " .. tostring(v); BC.Print(line); table.insert(BC.db.lastProbe, line) end

-- probe: chat capture armed by /bcard probe, prints the next 5 channel messages' secrecy
local capture = 0
BC.On("CHAT_MSG_CHANNEL", function(text, sender, _, _, _, _, _, idx, base, _, _, guid)
  if capture <= 0 then return end
  capture = capture - 1
  BC.ProbeLine("chan msg", tostring(base) .. "#" .. tostring(idx) .. " text " .. (BC.Secret(text) and "SECRET" or "ok")
    .. " sender " .. (BC.Secret(sender) and "SECRET" or "ok") .. " guid " .. (BC.Secret(guid) and "SECRET" or "ok")
    .. " combat " .. tostring(InCombatLockdown()) .. " inst " .. tostring((select(2, IsInInstance()))))
end)

-- dumps the facts Phases 2-6 depend on; output saved to BusinessCardDB.lastProbe for probe-results.md
function BC.Probe()
  BC.db.lastProbe = {}
  local P = BC.ProbeLine
  local function Try(k, fn) local ok, err = pcall(fn); if not ok then P(k, "ERROR " .. tostring(err)) end end
  local ver, build = GetBuildInfo()
  P("build", tostring(ver) .. " " .. tostring(build))
  P("ctx", "combat " .. tostring(InCombatLockdown()) .. " inst " .. tostring((select(2, IsInInstance())))
    .. " trial " .. tostring(IsTrialAccount and IsTrialAccount()) .. " vet " .. tostring(IsVeteranTrialAccount and IsVeteranTrialAccount()))
  Try("chan", function()
    local l = { GetChannelList() } -- id, name, disabled triples
    for i = 1, #l, 3 do P("channel", tostring(l[i]) .. " " .. tostring(l[i + 1]) .. " disabled " .. tostring(l[i + 2])) end
  end)
  for _, s in ipairs(BC.SERVICES) do
    Try("spell " .. s.key, function()
      local byId, byName = C_Spell.GetSpellInfo(s.id), C_Spell.GetSpellInfo(s.name)
      P("spell " .. s.key, tostring(byId and byId.name) .. " id " .. s.id .. " player " .. tostring(IsPlayerSpell(s.id))
        .. " byName " .. tostring(byName and byName.spellID))
    end)
  end
  Try("prof", function()
    local p = { GetProfessions() }
    for i = 1, 6 do if p[i] then
      local name, _, rank, max, _, _, line = GetProfessionInfo(p[i])
      P("prof " .. i, tostring(name) .. " line " .. tostring(line) .. " " .. tostring(rank) .. "/" .. tostring(max))
    end end
  end)
  Try("recipe", function() -- a recipe this character likely does not know (Classic Enchant Bracer - Minor Health 7418)
    local r = C_TradeSkillUI.GetRecipeInfo(7418)
    P("recipe 7418", tostring(r and r.name) .. " spellName " .. tostring(C_Spell.GetSpellName and C_Spell.GetSpellName(7418)))
  end)
  capture = 5
  P("chat", "capturing next 5 channel messages")
end

table.insert(BC.inits, function()
  C_ChatInfo.RegisterAddonMessagePrefix(BC.PREFIX)
  BC.On("CHAT_MSG_ADDON", function(prefix, text, ch, sender)
    if prefix ~= BC.PREFIX or BC.Secret(text) or BC.Secret(sender) then return end
    if text == "ping" then
      BC.ProbeLine("ping from", tostring(sender) .. " via " .. tostring(ch))
      C_ChatInfo.SendAddonMessage(BC.PREFIX, "pong", "WHISPER", sender)
    elseif text == "pong" then BC.ProbeLine("pong from", sender) end
  end)
end)

function BC.Ping(name)
  local r = C_ChatInfo.SendAddonMessage(BC.PREFIX, "ping", "WHISPER", name)
  BC.ProbeLine("ping " .. name, "result " .. tostring(r) .. " guild " .. tostring(IsInGuild()))
end

SLASH_BUSINESSCARD1 = "/bcard"
SlashCmdList.BUSINESSCARD = function(msg)
  local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "probe" then BC.Probe()
  elseif cmd == "ping" and arg ~= "" then BC.Ping(arg)
  elseif cmd == "lock" then BC.db.locked = not BC.db.locked; BC.Print(BC.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(BC.db.frames); BC.Print("positions reset - /reload to apply")
  else BC.Print("/bcard probe | ping <name> | lock | reset") end
end
