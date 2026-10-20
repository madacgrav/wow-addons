local ADDON, WUK = ...
-- settings window + minimap button; every option routes through the /wuk handler so there is one code path
local PETS = { "imp", "voidwalker", "succubus", "felhunter" }
local win

local function Run(cmd) SlashCmdList.WARLOCKUTILITYKIT(cmd) end

local function Check(parent, label, y, get, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 16, y)
  local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("LEFT", cb, "RIGHT", 4, 0); text:SetText(label)
  cb:SetScript("OnClick", function(self) onClick(self:GetChecked()); self:SetChecked(get()) end)
  cb.Sync = function(self) self:SetChecked(get()) end
  return cb
end

local function Build()
  win = CreateFrame("Frame", "WUKSettings", UIParent, "BasicFrameTemplateWithInset")
  win:SetSize(320, 286); win:SetPoint("CENTER"); win:SetFrameStrata("DIALOG")
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  tinsert(UISpecialFrames, "WUKSettings") -- Escape closes it
  local title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5); title:SetText("Warlock Utility Kit")

  local checks = {
    Check(win, "Show strip", -36, function() return WUK.db.shown end, function(on) Run(on and "show" or "hide") end),
    Check(win, "Lock frames (no Shift+drag)", -64, function() return WUK.db.locked end,
      function(on) if on ~= WUK.db.locked then Run("lock") end end),
    Check(win, "Dock Blizzard cooldown timers under strip", -92, function() return WUK.db.dockViewers end,
      function(on) if on ~= WUK.db.dockViewers then Run("dock") end end),
    Check(win, "Spin ring", -120, function() return WUK.db.spin end,
      function(on) if on ~= WUK.db.spin then Run("spin") end end),
  }

  local label = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", 20, -160); label:SetText("Preferred pet")
  -- Mainline 11.0+ menu API (UIDropDownMenu is deprecated)
  local dd = CreateFrame("DropdownButton", nil, win, "WowStyle1DropdownTemplate")
  dd:SetWidth(160); dd:SetPoint("TOPLEFT", 18, -178)
  dd:SetupMenu(function(_, root)
    for _, pet in ipairs(PETS) do
      root:CreateRadio(pet:sub(1, 1):upper() .. pet:sub(2),
        function() return WUK.char.pet == pet end,
        function() Run("pet " .. pet) end)
    end
  end)

  local reset = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  reset:SetSize(130, 22); reset:SetPoint("BOTTOMLEFT", 16, 16); reset:SetText("Reset positions")
  reset:SetScript("OnClick", function() Run("reset") end)

  local board = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  board:SetSize(130, 22); board:SetPoint("BOTTOMRIGHT", -16, 16); board:SetText("Assignment board")
  board:SetScript("OnClick", function() Run("board") end)

  function win:Sync()
    for _, cb in ipairs(checks) do cb:Sync() end
    dd:GenerateMenu() -- refresh the shown selection
  end
  win:SetScript("OnShow", win.Sync)
  win:Hide()
end

function WUK.ToggleSettings()
  if not win then Build() end
  win:SetShown(not win:IsShown())
end

table.insert(WUK.inits, function()
  local b = CreateFrame("Button", "WUKMinimapButton", Minimap)
  b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20); icon:SetPoint("CENTER", 0, 1); icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02")
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  local function Place()
    local a, r = math.rad(WUK.db.minimapAngle), Minimap:GetWidth() / 2 + 8
    b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end
  Place()

  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      WUK.db.minimapAngle = math.deg(math.atan2(py / s - my, px / s - mx))
      Place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then WUK.ToggleBoard() else WUK.ToggleSettings() end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Warlock Utility Kit")
    GameTooltip:AddLine("Click: settings   Right-click: board   Drag: move", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
end)
