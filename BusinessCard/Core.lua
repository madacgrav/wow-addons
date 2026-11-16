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

local DEFAULTS = { locked = false, frames = {}, lastProbe = {}, seen = {}, channels = BC.DEFAULT_CHANNELS, maxAgeDays = 7,
  view = "seen", filter = "all" }
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

-- ad log: seen[realm][name] = {cats={cat=at}, text, at, req, dest}
function BC.Seen() local r = GetRealmName(); BC.db.seen[r] = BC.db.seen[r] or {}; return BC.db.seen[r] end

BC.onSeen = {} -- hooks(name, result): P3 refresh, P5 card request
local function OnAd(source, text, sender)
  if not source or not BC.db.channels[source] or BC.Secret(text) or BC.Secret(sender) then return end
  local name = Ambiguate(sender, "none")
  if name == UnitName("player") then return end
  local r = BC.Classify(text)
  if not r or r.request then return end -- advertisers only; LF/WTB posts are dropped
  BC.SeenAdd(BC.Seen(), name, r, text, time())
  for _, fn in ipairs(BC.onSeen) do fn(name, r) end
end

table.insert(BC.inits, function()
  BC.On("CHAT_MSG_CHANNEL", function(text, sender, _, _, _, _, _, _, base) OnAd(BC.ChannelKey(base), text, sender) end)
  BC.On("CHAT_MSG_SAY", function(text, sender) OnAd("SAY", text, sender) end)
  BC.On("CHAT_MSG_YELL", function(text, sender) OnAd("YELL", text, sender) end)
  BC.On("CHAT_MSG_WHISPER", function(text, sender) OnAd("WHISPER", text, sender) end)
  local seen = BC.Seen()
  for name, e in pairs(seen) do -- re-check saved entries against the current classifier
    local r = BC.Classify(e.text)
    if not r or r.request then seen[name] = nil end
  end
  if not InCombatLockdown() then BC.SeenPrune(seen, time(), BC.db.maxAgeDays * 86400, 500) end
end)

local function PrintSeen()
  local seen, names, now = BC.Seen(), {}, time()
  for name in pairs(seen) do names[#names + 1] = name end
  table.sort(names, function(a, b) return seen[a].at > seen[b].at end)
  if #names == 0 then return BC.Print("nobody seen yet") end
  for i = 1, math.min(20, #names) do
    local e, cats = seen[names[i]], {}
    for _, c in ipairs(BC.CATS) do if e.cats[c] then cats[#cats + 1] = c end end
    BC.Print(names[i] .. " [" .. table.concat(cats, ",") .. "] "
      .. math.floor((now - e.at) / 60) .. "m: " .. e.text)
  end
  BC.Print(#names .. " seen")
end

function BC.Ping(name)
  local r = C_ChatInfo.SendAddonMessage(BC.PREFIX, "ping", "WHISPER", name)
  BC.ProbeLine("ping " .. name, "result " .. tostring(r) .. " guild " .. tostring(IsInGuild()))
end

SLASH_BUSINESSCARD1 = "/bcard"
SlashCmdList.BUSINESSCARD = function(msg)
  local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "" then BC.TogglePanel()
  elseif cmd == "probe" then BC.Probe()
  elseif cmd == "ping" and arg ~= "" then BC.Ping(arg)
  elseif cmd == "seen" then PrintSeen()
  elseif cmd == "lock" then BC.db.locked = not BC.db.locked; BC.Print(BC.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(BC.db.frames); BC.Print("positions reset - /reload to apply")
  else BC.Print("/bcard (window) | seen | probe | ping <name> | lock | reset") end
end
