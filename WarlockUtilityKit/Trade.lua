local ADDON, WUK = ...
local TTL = 600
local hsQueue, tradingWith = {}, nil
-- replies contain no request keyword, so two warlocks running WUK cannot ping-pong
local READY, EMPTY = "Stone ready - open a trade with me.", "Out of stones right now, sorry."

local function Whisper(msg, to) (C_ChatInfo.SendChatMessage or SendChatMessage)(msg, "WHISPER", nil, to) end

-- marks name as owed a stone; the TRADE_SHOW handler below places it in slot 1
function WUK.OfferHealthstone(name) hsQueue[name] = time() end

-- ring right-click: open a trade with the friendly target, stone goes in via TRADE_SHOW
function WUK.TradeHealthstone()
  if InCombatLockdown() then return WUK.Print("not in combat") end
  if not UnitIsPlayer("target") or not UnitIsFriend("player", "target") or UnitIsUnit("target", "player") then
    return WUK.Print("no friendly target")
  end
  if not CheckInteractDistance("target", 2) then return WUK.Print("target out of trade range") end
  if WUK.counts.healthstone < 1 then return WUK.Print("no healthstone") end
  local name = WUK.UnitFull("target") -- same Ambiguate form TRADE_SHOW builds for the partner
  if not name then return end
  WUK.OfferHealthstone(name)
  InitiateTrade("target")
end

table.insert(WUK.inits, function()
  WUK.On("CHAT_MSG_WHISPER", function(text, sender)
    if WUK.Secret(text) or WUK.Secret(sender) or not WUK.IsHealthstoneRequest(text) then return end
    local name = Ambiguate(sender, "none")
    if hsQueue[name] and time() - hsQueue[name] < TTL then return end -- one reply per requester
    if WUK.counts.healthstone > 0 then hsQueue[name] = time(); Whisper(READY, sender)
    else Whisper(EMPTY, sender) end
  end)
  WUK.On("TRADE_SHOW", function()
    local n, realm = UnitName("NPC")
    if not n or WUK.Secret(n) then return end
    local partner = Ambiguate((realm and realm ~= "") and (n .. "-" .. realm) or n, "none")
    local at, slot = hsQueue[partner], WUK.counts.slots.healthstone
    if not at or time() - at >= TTL or not slot or CursorHasItem() then return end
    C_Container.PickupContainerItem(slot[1], slot[2])
    if ClickTradeButton then ClickTradeButton(1) else WUK.Print("drop the healthstone into the trade window") end
    tradingWith = partner
  end)
  WUK.On("UI_INFO_MESSAGE", function(_, msg)
    if msg == ERR_TRADE_COMPLETE and tradingWith then hsQueue[tradingWith] = nil; tradingWith = nil end
  end)
  WUK.On("TRADE_CLOSED", function() C_Timer.After(1, function() tradingWith = nil end) end)
end)
