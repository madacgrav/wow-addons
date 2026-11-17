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

local DEFAULTS = { locked = false, frames = {}, seen = {}, channels = BC.DEFAULT_CHANNELS, maxAgeDays = 7,
  view = "seen", filter = "all", cards = {} }
local CHAR_DEFAULTS = { status = { g = "a" }, recipes = {}, rev = 0 }

BC.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  -- nil-safe: the Forever beta loader bug (ForeverSVFix) can leave these nil every session
  BusinessCardDB = BC.MergeDefaults(BusinessCardDB, DEFAULTS)
  BusinessCardCharDB = BC.MergeDefaults(BusinessCardCharDB, CHAR_DEFAULTS)
  BusinessCardDB.lastProbe = nil -- removed probe output (0.8.6)
  BC.db, BC.char = BusinessCardDB, BusinessCardCharDB
end)

BC.On("PLAYER_LOGIN", function()
  BC.active = true
  for _, init in ipairs(BC.inits) do init() end
end)

-- ad log: seen[realm][name] = {cats={cat=at}, text, at, req, dest}
function BC.Seen() local r = GetRealmName(); BC.db.seen[r] = BC.db.seen[r] or {}; return BC.db.seen[r] end

BC.onSeen = {} -- hooks(name, result): P3 refresh, P5 card request
local function OnAd(source, text, sender, zone)
  if not source or not BC.db.channels[source] or BC.Secret(text) or BC.Secret(sender) then return end
  local name = Ambiguate(sender, "none")
  if name == UnitName("player") then return end
  local r = BC.Classify(text)
  if not r or r.request then return end -- advertisers only; LF/WTB posts are dropped
  BC.SeenAdd(BC.Seen(), name, r, text, time(), zone)
  for _, fn in ipairs(BC.onSeen) do fn(name, r) end
end

table.insert(BC.inits, function()
  BC.On("CHAT_MSG_CHANNEL", function(text, sender, _, _, _, _, _, _, base) OnAd(BC.ChannelKey(base), text, sender, BC.ChannelZone(base)) end)
  -- say/yell come from nearby, so they are in our zone
  BC.On("CHAT_MSG_SAY", function(text, sender) OnAd("SAY", text, sender, GetRealZoneText()) end)
  BC.On("CHAT_MSG_YELL", function(text, sender) OnAd("YELL", text, sender, GetRealZoneText()) end)
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

-- my card: professions need no open window (TackleBox/Core.lua:28-35); 7th return is the skill line
function BC.ReadProfessions()
  local out, p = {}, { GetProfessions() }
  for i = 1, 6 do if p[i] then
    local name, _, rank, _, _, _, line = GetProfessionInfo(p[i])
    if line then out[#out + 1] = { id = line, name = name, skill = rank } end
  end end
  return out
end

function BC.ReadServices()
  local out = {}
  for _, s in ipairs(BC.SERVICES) do
    if IsPlayerSpell(s.id) or C_Spell.GetSpellInfo(s.name) then out[#out + 1] = s.key end
  end
  return out
end

function BC.MyCard() return BC.BuildCard(BC.ReadProfessions(), BC.ReadServices(), BC.char.status, BC.char.rev,
  GetRealZoneText()) end

-- learned recipe IDs per profession; window must be open (ProfessionPlanner/Core.lua:28-40)
local tries = 0
function BC.ScanRecipes()
  if not C_TradeSkillUI.IsTradeSkillReady() then return end
  local info = C_TradeSkillUI.GetBaseProfessionInfo()
  local prof = info and info.professionID
  if not prof then return end
  local ids = {}
  for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
    local ri, pi = C_TradeSkillUI.GetRecipeInfo(id), C_TradeSkillUI.GetProfessionInfoByRecipeID(id)
    if ri and ri.learned and pi and (pi.professionID == prof or pi.parentProfessionID == prof) then ids[#ids + 1] = id end
  end
  if #ids == 0 and tries < 5 then tries = tries + 1; return C_Timer.After(0.5, BC.ScanRecipes) end
  tries = 0
  if #ids > 0 then BC.char.recipes[prof] = ids; if BC.RefreshPanel then BC.RefreshPanel() end end
end

BC.onStatus = {} -- hooks after any status change (Phase 5 broadcasts)
function BC.ChangeStatus(key, st)
  if not BC.SetStatus(BC.char, key, st) then return end
  for _, fn in ipairs(BC.onStatus) do fn() end
  if BC.RefreshPanel then BC.RefreshPanel() end
end

table.insert(BC.inits, function()
  BC.On("TRADE_SKILL_SHOW", BC.ScanRecipes)
  BC.On("TRADE_SKILL_LIST_UPDATE", BC.ScanRecipes)
  BC.On("SKILL_LINES_CHANGED", function() if BC.RefreshPanel then BC.RefreshPanel() end end)
end)

-- /who lookup for one name: SendWho needs a hardware event, so only call this from a click
local whoTarget, wasOpen
-- Forever shows /who results in the group finder (LFGParentFrame > LFGWhoListFrame), found with /fstack
local WHO_FRAMES = { "LFGParentFrame", "LFGWhoListFrame", "FriendsFrame", "WhoFrame" }
local function WhoOpen() for _, n in ipairs(WHO_FRAMES) do local f = _G[n]; if f and f:IsShown() then return true end end end

-- close the Who/Friends window for 3 s after our lookup (it opens late, from Blizzard's own handlers)
local function SuppressWhoWindow()
  if wasOpen then return end
  local t = 0
  local ticker
  ticker = C_Timer.NewTicker(0.1, function()
    t = t + 0.1
    for _, n in ipairs(WHO_FRAMES) do
      local f = _G[n]
      if f and f:IsShown() and not InCombatLockdown() then HideUIPanel(f); if f:IsShown() then f:Hide() end end
    end
    if t >= 3 then ticker:Cancel() end
  end)
end

function BC.Who(name)
  if not C_FriendList or not C_FriendList.SendWho then return BC.Print("/who is not available") end
  whoTarget, wasOpen = name, WhoOpen()
  SuppressWhoWindow()
  C_FriendList.SetWhoToUi(true)
  C_FriendList.SendWho('n-"' .. name .. '"')
  BC.Print("looking up " .. name .. "...")
end

BC.On("WHO_LIST_UPDATE", function()
  if not whoTarget then return end
  local target = whoTarget
  whoTarget = nil

  for i = 1, C_FriendList.GetNumWhoResults() do
    local w = C_FriendList.GetWhoInfo(i)
    if w and not BC.Secret(w.fullName) and Ambiguate(w.fullName, "none") == target and not BC.Secret(w.area) then
      local e = BC.Seen()[target] or (BC.Cards and BC.Cards()[target])
      if e then e.zone, e.whoAt = w.area, time() end
      BC.Print(target .. ": level " .. tostring(w.level) .. " " .. tostring(w.classStr) .. " in " .. tostring(w.area))
      if BC.RefreshPanel then BC.RefreshPanel() end
      return
    end
  end
  BC.Print(target .. " not found by /who (offline or hidden)")
end)

SLASH_BUSINESSCARD1 = "/bcard"
SlashCmdList.BUSINESSCARD = function(msg)
  local cmd = (msg or ""):match("^(%S*)")
  cmd = cmd:lower()
  if cmd == "" then BC.TogglePanel()
  elseif cmd == "seen" then PrintSeen()
  elseif cmd == "busy" then BC.ChangeStatus("g", "b"); BC.Print("you are busy")
  elseif cmd == "avail" then BC.ChangeStatus("g", "a"); BC.Print("you are available")
  elseif cmd == "lock" then BC.db.locked = not BC.db.locked; BC.Print(BC.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(BC.db.frames); BC.Print("positions reset - /reload to apply")
  else BC.Print("/bcard (window) | seen | busy | avail | lock | reset") end
end
