local ADDON, BC = ...
local queue, nextSend, failures = {}, 0, 0
BC.commOff = false

-- ponytail: one shared queue with per-message pacing; per-target buckets if stranger requests pile up
local function Flush()
  local m = queue[1]
  if not m or GetTime() < nextSend then return end
  local r = C_ChatInfo.SendAddonMessage(BC.PREFIX, m.msg, m.ch, m.to)
  if r == 0 or r == true then
    table.remove(queue, 1); failures = 0; nextSend = GetTime() + (m.ch == "WHISPER" and 1 or 0.5)
  elseif r == 12 then table.remove(queue, 1) -- TargetOffline
  elseif r == 3 or r == 8 then failures = failures + 1; nextSend = GetTime() + math.min(30, 2 ^ failures) -- throttles
  else -- trial/veteran, lockdown, not in guild, ...
    BC.commOff = true; wipe(queue)
    BC.Print("card sharing unavailable (code " .. tostring(r) .. "); the ad log still works")
  end
end

function BC.Send(msg, ch, to)
  if BC.commOff or #queue >= 64 then return end
  queue[#queue + 1] = { msg = msg, ch = ch, to = to }
end

function BC.Cards() local r = GetRealmName(); BC.db.cards[r] = BC.db.cards[r] or {}; return BC.db.cards[r] end

-- one silent card request per name per session, never from inside an instance
local asked = {}
function BC.Ask(name, force)
  if (asked[name] and not force) or IsInInstance() then return end
  asked[name] = true
  BC.Send(BC.PROTO .. "|Q", "WHISPER", name)
end

local pending = false
local function BroadcastGuild()
  if pending or not IsInGuild() then return end
  pending = true
  C_Timer.After(10, function() pending = false; BC.Send(BC.EncodeCard(BC.MyCard()), "GUILD") end)
end

table.insert(BC.inits, function()
  BC.SeenPrune(BC.Cards(), time(), BC.db.maxAgeDays * 86400, 500)
  C_Timer.NewTicker(0.25, Flush)
  BC.On("CHAT_MSG_ADDON", function(prefix, text, ch, sender)
    if prefix ~= BC.PREFIX or BC.Secret(text) or BC.Secret(sender) then return end
    local name = Ambiguate(sender, "none")
    if name == UnitName("player") then return end
    local m = BC.Decode(text)
    if not m then return end
    if m.kind == "Q" then BC.Send(BC.EncodeCard(BC.MyCard()), "WHISPER", sender)
    elseif m.kind == "C" then
      asked[name] = true
      local cards = BC.Cards()
      -- ~= not >: a peer whose SavedVariables reset starts again at rev 0
      if not cards[name] or cards[name].rev ~= m.rev then m.at = time(); cards[name] = m; BC.RefreshPanel()
      else cards[name].at = time() end
    end
    if BC.OnComm then BC.OnComm(name, m, sender) end -- Phase 6 hook
  end)
  table.insert(BC.onSeen, function(name) BC.Ask(name) end) -- onSeen only fires for advertisers
  table.insert(BC.onStatus, BroadcastGuild)
  BroadcastGuild() -- login broadcast, 10 s after login
end)
