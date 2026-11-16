local ADDON, WUK = ...
local MAX, TTL = 10, 600
local queue, rows, panel = {}, {}, nil

local GroupUnits, UnitFull = WUK.GroupUnits, WUK.UnitFull
local pendingSummon -- name of the row last left-clicked; cleared when the ritual ends
local pinned = false -- opened by hand: shown even with an empty queue

-- set of group member names; nil if any name is secret (membership unknown - don't drop anyone)
local function GroupNames()
  local s = {}
  for _, u in ipairs(GroupUnits()) do
    local n = UnitFull(u)
    if not n then return nil end
    s[n] = true
  end
  return s
end

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
  ctx.class = select(2, UnitClass(target)) -- classFilename is never secret (Core.lua GroupWarlocks)
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
  local now, group = time(), GroupNames()
  WUK.QueuePrune(queue, function(r) return WUK.QueueKeep(r, now, TTL, group) end)
  if InCombatLockdown() then return end -- secure attributes: PLAYER_REGEN_ENABLED -> Refresh re-applies
  for i, row in ipairs(rows) do
    local r = queue[i]
    if r and WUK.known.ritual then
      local ctx, zone = Context(r.name)
      row:SetAttribute("macrotext1", "/target " .. r.name .. "\n/cast " .. WUK.known.ritual)
      row:SetAttribute("ctrl-macrotext1", "/target " .. r.name)
      row.name = r.name
      local c = ctx.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[ctx.class]
      local shown = (c and c.colorStr) and ("|c" .. c.colorStr .. r.name .. "|r") or r.name
      local tc = ctx.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[ctx.class]
      if tc then row.icon:SetTexCoord(unpack(tc)); row.icon:Show() else row.icon:Hide() end
      row.text:SetText(shown .. "  |cffaaaaaa" .. (zone or "?") .. "|r  |cffff6060" .. (WUK.SummonFailure(ctx) or "") .. "|r")
      row:Show()
    else
      row:Hide()
    end
  end
  panel.title:SetText("Summons (" .. #queue .. ")")
  panel:SetHeight(28 + math.max(1, math.min(#queue, MAX)) * 20)
  if pinned or (queue[1] and WUK.known.ritual) then panel:Show() else panel:Hide() end
end

-- opened from settings or /wuk summon: stays up even when empty; the panel parents secure rows, so not in combat
function WUK.ToggleSummon()
  if InCombatLockdown() then return WUK.Print("not in combat") end
  pinned = not pinned
  WUK.UpdateSummonRows()
end

local function OnChat(text, sender)
  if WUK.Secret(text) or WUK.Secret(sender) or not WUK.IsSummonRequest(text) then return end
  local name = Ambiguate(sender, "none")
  if name == UnitName("player") then return end
  local group = GroupNames()
  if group and not group[name] then return end -- only queue party/raid members
  if WUK.QueueAdd(queue, name, MAX) then queue[#queue].at = time() end
  WUK.UpdateSummonRows() -- no-op in combat; PLAYER_REGEN_ENABLED -> Refresh applies it
end

table.insert(WUK.inits, function()
  panel = CreateFrame("Frame", "WUKSummon", UIParent, "BackdropTemplate")
  panel:SetSize(300, 28 + MAX * 20)
  panel.title = WUK.Skin(panel, "Summons")
  WUK.MakeMovable(panel, "summon", 0, -300)
  -- title-bar hit area: tooltip with the click help, forwards drags to the panel (MakeMovable rules)
  local hit = CreateFrame("Frame", nil, panel)
  hit:SetAllPoints(panel.titleBar); hit:EnableMouse(true); hit:RegisterForDrag("LeftButton")
  hit:SetScript("OnDragStart", function() panel:GetScript("OnDragStart")(panel) end)
  hit:SetScript("OnDragStop", function() panel:GetScript("OnDragStop")(panel) end)
  hit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Summon queue")
    GameTooltip:AddLine("Click: summon   Ctrl-click: target   Right-click: remove", 1, 1, 1)
    GameTooltip:AddLine("Shift-drag: move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  hit:SetScript("OnLeave", GameTooltip_Hide)
  for i = 1, MAX do
    local row = CreateFrame("Button", "WUKSummonRow" .. i, panel, "SecureActionButtonTemplate")
    row:SetSize(288, 18); row:SetPoint("TOPLEFT", 6, -26 - (i - 1) * 20)
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetAttribute("type1", "macro"); row:SetAttribute("ctrl-type1", "macro")
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(14, 14); row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    -- fel glow sweeping in from the left on hover
    local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 1); hl:SetBlendMode("ADD")
    if hl.SetGradient and CreateColor then
      hl:SetGradient("HORIZONTAL", CreateColor(0.45, 0.85, 0.3, 0.3), CreateColor(0.45, 0.85, 0.3, 0))
    else hl:SetVertexColor(0.45, 0.85, 0.3, 0.15) end
    if i % 2 == 0 then
      local s = row:CreateTexture(nil, "BACKGROUND"); s:SetAllPoints(); s:SetColorTexture(0.58, 0.51, 0.79, 0.07)
    end
    row:HookScript("OnClick", function(self, button, down)
      if button == "RightButton" and not down and self.name then WUK.QueueRemove(queue, self.name); WUK.UpdateSummonRows() end
    end)
    row:SetScript("PreClick", function(self, button)
      if button == "LeftButton" and not IsControlKeyDown() and self.name then pendingSummon = self.name end
    end)
    rows[i] = row
  end
  panel:Hide()
  for _, e in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
                       "CHAT_MSG_GUILD", "CHAT_MSG_SAY", "CHAT_MSG_WHISPER" }) do WUK.On(e, OnChat) end
  WUK.On("GROUP_ROSTER_UPDATE", WUK.UpdateSummonRows)
  local function IsRitual(unit, spellID)
    return unit == "player" and WUK.known.ritual and WUK.SpellName(spellID) == WUK.known.ritual
  end
  WUK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if not IsRitual(unit, spellID) then return end
    local t = WUK.SummonTarget(pendingSummon, WUK.lastCastTarget)
    pendingSummon = nil
    if t then WUK.QueueRemove(queue, Ambiguate(t, "none")); WUK.UpdateSummonRows() end
  end)
  for _, e in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
    WUK.On(e, function(unit, _, spellID) if IsRitual(unit, spellID) then pendingSummon = nil end end)
  end
end)
table.insert(WUK.refreshers, function() WUK.UpdateSummonRows() end)
