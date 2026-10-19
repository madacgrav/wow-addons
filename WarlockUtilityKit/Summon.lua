local ADDON, WUK = ...
local MAX, TTL = 10, 600
local queue, rows, panel = {}, {}, nil

local GroupUnits, UnitFull = WUK.GroupUnits, WUK.UnitFull

local function RosterZone(name)
  if not IsInRaid() then return nil end -- ponytail: party zone unknown; add C_Map.GetBestMapForUnit name lookup if needed
  for i = 1, GetNumGroupMembers() do
    local n, _, _, _, _, _, zone = GetRaidRosterInfo(i)
    if n and Ambiguate(n, "none") == name then return zone end
  end
end

local function Context(name)
  local ctx, target = { shards = WUK.counts.shard }, nil
  for _, unit in ipairs(GroupUnits()) do
    if UnitFull(unit) == name then target = unit end
  end
  if not target then return ctx, nil end
  ctx.inGroup = true
  ctx.connected = UnitIsConnected(target)
  ctx.dead = UnitIsDeadOrGhost(target)
  local zone = RosterZone(name)
  ctx.here = zone ~= nil and zone == GetRealZoneText()
  local helpers = 0
  for _, unit in ipairs(GroupUnits()) do
    if unit ~= target and UnitIsConnected(unit) then
      local inRange = UnitInRange(unit)
      if WUK.Secret(inRange) then helpers = nil; break end
      if inRange then helpers = helpers + 1 end
    end
  end
  ctx.helpers = helpers
  return ctx, zone
end

function WUK.UpdateSummonRows()
  if InCombatLockdown() then return end
  local now = time()
  WUK.QueuePrune(queue, function(r) return now - r.at < TTL end)
  for i, row in ipairs(rows) do
    local r = queue[i]
    if r and WUK.known.ritual then
      local ctx, zone = Context(r.name)
      row:SetAttribute("macrotext1", "/target " .. r.name .. "\n/cast " .. WUK.known.ritual)
      row:SetAttribute("ctrl-macrotext1", "/target " .. r.name)
      row.name = r.name
      row.text:SetText(r.name .. "  |cffaaaaaa" .. (zone or "?") .. "|r  |cffff6060" .. (WUK.SummonFailure(ctx) or "") .. "|r")
      row:Show()
    else
      row:Hide()
    end
  end
  if queue[1] then panel:Show() else panel:Hide() end
end

local function OnChat(text, sender)
  if WUK.Secret(text) or WUK.Secret(sender) or not WUK.IsSummonRequest(text) then return end
  local name = Ambiguate(sender, "none")
  if name == UnitName("player") then return end
  if WUK.QueueAdd(queue, name, MAX) then queue[#queue].at = time() end
  WUK.UpdateSummonRows() -- no-op in combat; PLAYER_REGEN_ENABLED -> Refresh applies it
end

table.insert(WUK.inits, function()
  panel = CreateFrame("Frame", "WUKSummon", UIParent, "BackdropTemplate")
  panel:SetSize(300, 20 + MAX * 20)
  panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); panel:SetBackdropColor(0, 0, 0, 0.6)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", 6, -4); title:SetText("Summon queue (click: summon, ctrl: target, right: remove)")
  WUK.MakeMovable(panel, "summon", 0, -300)
  for i = 1, MAX do
    local row = CreateFrame("Button", "WUKSummonRow" .. i, panel, "SecureActionButtonTemplate")
    row:SetSize(288, 18); row:SetPoint("TOPLEFT", 6, -2 - i * 20)
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetAttribute("type1", "macro"); row:SetAttribute("ctrl-type1", "macro")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.text:SetPoint("LEFT")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:HookScript("OnClick", function(self, button, down)
      if button == "RightButton" and not down and self.name then WUK.QueueRemove(queue, self.name); WUK.UpdateSummonRows() end
    end)
    rows[i] = row
  end
  panel:Hide()
  for _, e in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
                       "CHAT_MSG_GUILD", "CHAT_MSG_SAY", "CHAT_MSG_WHISPER" }) do WUK.On(e, OnChat) end
  WUK.On("GROUP_ROSTER_UPDATE", WUK.UpdateSummonRows)
  WUK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit == "player" and WUK.known.ritual and WUK.SpellName(spellID) == WUK.known.ritual and WUK.lastCastTarget then
      WUK.QueueRemove(queue, Ambiguate(WUK.lastCastTarget, "none")); WUK.UpdateSummonRows()
    end
  end)
end)
table.insert(WUK.refreshers, function() WUK.UpdateSummonRows() end)
