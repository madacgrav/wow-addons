local ADDON, WCK = ...
-- settings window + minimap button; later phases append sections via WCK.settingsSections
local win
WCK.settingsSections = {} -- function(win, y) -> next y; each may set win:Sync helpers via win.syncs

function WCK.Check(parent, label, y, get, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 16, y)
  local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("LEFT", cb, "RIGHT", 4, 0); text:SetText(label)
  cb:SetScript("OnClick", function(self) onClick(self:GetChecked()); self:SetChecked(get()) end)
  cb.Sync = function(self) self:SetChecked(get()) end
  return cb
end

local function Build()
  win = CreateFrame("Frame", "WCKSettings", UIParent, "BasicFrameTemplateWithInset")
  win:SetSize(380, 620); win:SetPoint("CENTER"); win:SetFrameStrata("DIALOG")
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  tinsert(UISpecialFrames, "WCKSettings") -- Escape closes it
  local title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5); title:SetText("Warlock Combat Kit")

  win.syncs = {
    WCK.Check(win, "Show panel", -36, function() return WCK.db.shown end,
      function(on) WCK.db.shown = on; WCK.Refresh() end),
    WCK.Check(win, "Lock panel (no Shift+drag)", -64, function() return WCK.db.locked end,
      function(on) WCK.db.locked = on end),
    WCK.Check(win, "Mark CC'd mobs on nameplates (open world)", -92, function() return WCK.db.plateMarker end,
      function(on) WCK.db.plateMarker = on; WCK.Refresh() end),
    WCK.Check(win, "Proc alerts (Nightfall)", -120, function() return WCK.db.procAlerts end,
      function(on) WCK.db.procAlerts = on; WCK.Refresh() end),
    WCK.Check(win, "Proc sound", -148, function() return WCK.db.procSound end,
      function(on) WCK.db.procSound = on end),
  }
  local y = -184
  for _, section in ipairs(WCK.settingsSections) do y = section(win, y) end

  local reset = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  reset:SetSize(130, 22); reset:SetPoint("BOTTOMLEFT", 16, 16); reset:SetText("Reset positions")
  reset:SetScript("OnClick", function() wipe(WCK.db.frames); WCK.Print("positions reset - /reload to apply") end)

  function win:Sync() for _, s in ipairs(self.syncs) do s:Sync() end end
  win:SetScript("OnShow", win.Sync)
  win:Hide()
end

function WCK.ToggleSettings()
  if not win then Build() end
  win:SetShown(not win:IsShown())
end

table.insert(WCK.inits, function()
  local b = CreateFrame("Button", "WCKMinimapButton", Minimap)
  b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20); icon:SetPoint("CENTER", 0, 1); icon:SetTexture("Interface\\Icons\\Spell_Shadow_DeathCoil")
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  local function Place()
    local a, r = math.rad(WCK.db.minimapAngle), Minimap:GetWidth() / 2 + 8
    b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end
  Place()

  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      WCK.db.minimapAngle = math.deg(math.atan2(py / s - my, px / s - mx))
      Place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then WCK.db.shown = not WCK.db.shown; WCK.Refresh() else WCK.ToggleSettings() end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Warlock Combat Kit")
    GameTooltip:AddLine("Click: settings   Right-click: panel   Drag: move", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
end)
