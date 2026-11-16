local ADDON, WUK = ...
-- settings window + minimap button; every option routes through the /wuk handler so there is one code path
local win

local function Run(cmd) SlashCmdList.WARLOCKUTILITYKIT(cmd) end

-- fallback demon portraits when the summon spell isn't known yet (Incubus shares the Succubus art)
local PET_ICON = {
  imp = "Interface\\Icons\\Spell_Shadow_SummonImp", voidwalker = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
  succubus = "Interface\\Icons\\Spell_Shadow_SummonSuccubus", incubus = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
  felhunter = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
}

local function Check(parent, label, y, get, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 16, y)
  local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("LEFT", cb, "RIGHT", 4, 0); text:SetText(label)
  text:SetTextColor(unpack(WUK.THEME.text))
  cb:SetScript("OnClick", function(self) onClick(self:GetChecked()); self:SetChecked(get()) end)
  cb.Sync = function(self) self:SetChecked(get()) end
  return cb
end

local function Build()
  win = CreateFrame("Frame", "WUKSettings", UIParent, "BackdropTemplate")
  win:SetSize(320, 336); win:SetFrameStrata("DIALOG")
  WUK.Skin(win, "Warlock Utility Kit", { close = true, swirl = true })
  WUK.MakeMovable(win, "settings", 280, 0, true) -- right of the board default (-180): no overlap
  tinsert(UISpecialFrames, "WUKSettings") -- Escape closes it

  WUK.Header(win, "Strip & ring", 16, -32, 288)
  local checks = {
    Check(win, "Show strip", -46, function() return WUK.db.shown end, function(on) Run(on and "show" or "hide") end),
    Check(win, "Spin ring", -72, function() return WUK.db.spin end,
      function(on) if on ~= WUK.db.spin then Run("spin") end end),
    Check(win, "Collapse ring until hover", -98, function() return WUK.db.collapse end,
      function(on) if on ~= WUK.db.collapse then Run("collapse") end end),
    Check(win, "Dock Blizzard cooldown timers under strip", -124, function() return WUK.db.dockViewers end,
      function(on) if on ~= WUK.db.dockViewers then Run("dock") end end),
  }

  WUK.Header(win, "Pet", 16, -162, 288)
  -- portrait of the chosen demon next to the dropdown
  local petIcon = win:CreateTexture(nil, "ARTWORK")
  petIcon:SetSize(24, 24); petIcon:SetPoint("TOPLEFT", 18, -180); petIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local function ShowPet()
    local p = WUK.char.pet
    local tex = WUK.known[p] and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(WUK.known[p])
    petIcon:SetTexture(tex or PET_ICON[p] or PET_ICON.imp)
  end
  -- Mainline 11.0+ menu API (UIDropDownMenu is deprecated)
  local dd = CreateFrame("DropdownButton", nil, win, "WowStyle1DropdownTemplate")
  dd:SetWidth(160); dd:SetPoint("TOPLEFT", 48, -178)
  dd:SetupMenu(function(_, root)
    for _, pet in ipairs(WUK.PETS) do
      root:CreateRadio(pet:sub(1, 1):upper() .. pet:sub(2),
        function() return WUK.char.pet == pet end,
        function() Run("pet " .. pet); ShowPet() end)
    end
  end)

  WUK.Header(win, "Frames", 16, -218, 288)
  checks[#checks + 1] = Check(win, "Lock frames (no Shift+drag)", -232, function() return WUK.db.locked end,
    function(on) if on ~= WUK.db.locked then Run("lock") end end)

  WUK.Button(win, "Reset positions", 130, function() Run("reset") end):SetPoint("BOTTOMLEFT", 16, 16)
  WUK.Button(win, "Assignment board", 130, function() Run("board") end):SetPoint("BOTTOMRIGHT", -16, 16)
  WUK.Button(win, "Summon queue", 130, function() Run("summon") end):SetPoint("BOTTOMRIGHT", -16, 42)

  function win:Sync()
    for _, cb in ipairs(checks) do cb:Sync() end
    dd:GenerateMenu() -- refresh the shown selection
    ShowPet()
  end
  win:HookScript("OnShow", win.Sync) -- HookScript: keeps the skin's fade-in
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
