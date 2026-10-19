local ADDON, WUK = ...
local PREFIX = "WUKB"
local queue, nextSend, failures, warned = {}, 0, 0, false

local function Channel()
  if IsInRaid() then return "RAID" elseif IsInGroup() then return "PARTY" end
end

-- ponytail: one shared 0.5s pace (GuildStock-style); a per-prefix token bucket if boards grow past ~20 rows
local function Flush()
  if #queue == 0 or GetTime() < nextSend then return end
  local ch = Channel()
  if not ch then wipe(queue); return end
  local result = C_ChatInfo.SendAddonMessage(PREFIX, queue[1], ch)
  if result == 0 or result == true then
    table.remove(queue, 1); failures = 0; nextSend = GetTime() + 0.5
  else -- throttle, lockdown (11), trial account, ...
    failures = failures + 1; nextSend = GetTime() + math.min(30, 2 ^ failures)
    if not warned then warned = true; WUK.Print("board sync unavailable (code " .. tostring(result) .. "); board works locally") end
    if failures >= 3 then wipe(queue); failures = 0 end
  end
end

function WUK.Send(msg) if Channel() and #queue < 64 then queue[#queue + 1] = msg end end

table.insert(WUK.inits, function()
  C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  C_Timer.NewTicker(0.25, Flush)
  WUK.On("CHAT_MSG_ADDON", function(prefix, text, _, sender)
    if prefix ~= PREFIX or WUK.Secret(text) or WUK.Secret(sender) then return end
    local name = Ambiguate(sender, "none")
    if name == UnitName("player") then return end
    local m = WUK.Decode(text)
    if m and WUK.OnBoardMessage then WUK.OnBoardMessage(name, m) end
  end)
end)
