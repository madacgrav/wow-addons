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

-- Rotation rule editor: pooled rows over WCK.char.rules
-- ponytail: 10 rules max, add a ScrollBox if users want more
local MAX_RULES = 10
local function KnownSpells()
  local out = {}
  for _, name in ipairs(WCK.DATA.rotation) do if WCK.Known(name) then out[#out + 1] = name end end
  return out
end

table.insert(WCK.settingsSections, function(win, y)
  local head = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  head:SetPoint("TOPLEFT", 20, y); head:SetText("Rotation (first matching rule shows in the panel core)")
  local rows = {}
  local function Changed() win:SyncRules(); WCK.Refresh() end
  for i = 1, MAX_RULES do
    local r = CreateFrame("Frame", nil, win); r:SetSize(348, 24); r:SetPoint("TOPLEFT", 14, y - 18 - (i - 1) * 26)
    r.num = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.num:SetPoint("LEFT", 0, 0); r.num:SetText(i .. ".")
    r.spell = CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")
    r.spell:SetWidth(120); r.spell:SetPoint("LEFT", 14, 0)
    r.spell:SetupMenu(function(_, root)
      for _, name in ipairs(KnownSpells()) do
        root:CreateRadio(name, function() return WCK.char.rules[i] and WCK.char.rules[i].spell == name end,
          function() WCK.char.rules[i].spell = name; Changed() end)
      end
    end)
    r.cond = CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")
    r.cond:SetWidth(110); r.cond:SetPoint("LEFT", r.spell, "RIGHT", 4, 0)
    r.cond:SetupMenu(function(_, root)
      for _, c in ipairs(WCK.DATA.conds) do
        if c ~= "usable" or WCK.USABLE_OK then
          root:CreateRadio(WCK.DATA.condLabels[c], function() return WCK.char.rules[i] and WCK.char.rules[i].cond == c end,
            function() WCK.char.rules[i].cond = c; Changed() end)
        end
      end
    end)
    r.n = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
    r.n:SetSize(26, 20); r.n:SetPoint("LEFT", r.cond, "RIGHT", 8, 0); r.n:SetAutoFocus(false); r.n:SetNumeric(true); r.n:SetMaxLetters(3)
    local function SetN(self) if WCK.char.rules[i] then WCK.char.rules[i].n = tonumber(self:GetText()) or 0; WCK.Refresh() end end
    r.n:SetScript("OnEnterPressed", function(self) SetN(self); self:ClearFocus() end)
    r.n:SetScript("OnEditFocusLost", SetN)
    local function Btn(label, x, fn)
      local b = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
      b:SetSize(20, 20); b:SetPoint("RIGHT", x, 0); b:SetText(label); b:SetScript("OnClick", fn)
    end
    Btn("x", 0, function() table.remove(WCK.char.rules, i); Changed() end)
    Btn("v", -22, function() WCK.MoveRule(WCK.char.rules, i, 1); Changed() end)
    Btn("^", -44, function() WCK.MoveRule(WCK.char.rules, i, -1); Changed() end)
    rows[i] = r
  end
  local by = y - 18 - MAX_RULES * 26 - 4
  local add = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  add:SetSize(100, 22); add:SetPoint("TOPLEFT", 16, by); add:SetText("Add rule")
  add:SetScript("OnClick", function() table.insert(WCK.char.rules, { spell = "Shadow Bolt", cond = "ready" }); Changed() end)
  local def = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  def:SetSize(100, 22); def:SetPoint("LEFT", add, "RIGHT", 8, 0); def:SetText("Defaults")
  def:SetScript("OnClick", function() WCK.char.rules = WCK.CopyRules(WCK.DATA.defaultRules); Changed() end)

  function win:SyncRules()
    local rules = WCK.char.rules
    for i, r in ipairs(rows) do
      local rule = rules[i]
      r:SetShown(rule ~= nil)
      if rule then
        r.spell:GenerateMenu(); r.cond:GenerateMenu()
        r.n:SetShown(rule.cond == "notRecent"); r.n:SetText(tostring(rule.n or 0))
      end
    end
    add:SetEnabled(#rules < MAX_RULES)
  end
  table.insert(win.syncs, { Sync = function() win:SyncRules() end })
  return by - 34
end)

local function Build()
  win = CreateFrame("Frame", "WCKSettings", UIParent, "BasicFrameTemplateWithInset")
  win:SetSize(380, 560); win:SetPoint("CENTER"); win:SetFrameStrata("DIALOG")
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
  win:SetHeight(-y + 50) -- room for the sections plus the bottom button row

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
