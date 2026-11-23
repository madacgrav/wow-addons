local ADDON, WCK = ...
-- settings window + minimap button; tabs via WCK.settingsTabs
local win
WCK.settingsTabs = {} -- { title, hint, build = function(page, win) }; build pushes its syncs into win.syncs
local ROW = 26

function WCK.Check(parent, label, y, get, onClick, tip)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 16, y)
  local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("LEFT", cb, "RIGHT", 4, 0); text:SetText(label)
  cb:SetScript("OnClick", function(self) onClick(self:GetChecked()); self:SetChecked(get()) end)
  cb.Sync = function(self) self:SetChecked(get()) end
  if tip then WCK.Tip(cb, label, tip) end
  return cb
end

-- Rotation rule editor: pooled rows over WCK.char.rules
-- ponytail: 10 rules max, add a ScrollBox if users want more
local MAX_RULES = 10
-- one submenu per spellbook tab; radios inside
local function SpellMenu(root, isChecked, pick)
  for _, tab in ipairs(WCK.spellTabs) do
    local sub = root:CreateButton(tab.name)
    for _, name in ipairs(tab.spells) do
      sub:CreateRadio(name, function() return isChecked(name) end, function() pick(name) end)
    end
  end
end

table.insert(WCK.settingsTabs, { title = "General", hint = "Panel, nameplate and alert options.", build = function(page, win)
  local y = -22
  local function Group(name) WCK.Header(page, name, 16, y, 428); y = y - 20 end
  local function Add(label, get, set, tip)
    table.insert(win.syncs, WCK.Check(page, label, y, get, set, tip)); y = y - ROW
  end
  Group("DISPLAY")
  Add("Show panel", function() return WCK.db.shown end,
    function(on) WCK.db.shown = on; WCK.Refresh() end)
  Add("Show rotation buttons", function() return WCK.db.showBar end,
    function(on) WCK.db.showBar = on; WCK.Refresh()
      if InCombatLockdown() then WCK.Print("rotation bar change applies after combat") end end)
  Add("Lock panel (no Shift+drag)", function() return WCK.db.locked end,
    function(on) WCK.db.locked = on end)
  y = y - 8; Group("NAMEPLATES")
  Add("Mark CC'd mobs on nameplates (open world)", function() return WCK.db.plateMarker end,
    function(on) WCK.db.plateMarker = on; WCK.Refresh() end)
  y = y - 8; Group("ALERTS")
  Add("Proc alerts (Nightfall)", function() return WCK.db.procAlerts end,
    function(on) WCK.db.procAlerts = on; WCK.Refresh() end)
  Add("Proc sound", function() return WCK.db.procSound end,
    function(on) WCK.db.procSound = on end)
  local reset = WCK.Button(page, "Reset positions", 130, function()
    wipe(WCK.db.frames); WCK.Print("positions reset - /reload to apply") end)
  reset:SetPoint("BOTTOMLEFT", 16, 16)
end })

table.insert(WCK.settingsTabs, { title = "Rotation", hint = "First matching rule lights the core button.", build = function(page, win)
  local y = -22
  local rows = {}
  local function Changed() win:Sync(); WCK.Refresh() end -- all syncs: the alt-click rows follow the bar spells
  for i = 1, MAX_RULES do
    local r = CreateFrame("Frame", nil, page); r:SetSize(428, 24); r:SetPoint("TOPLEFT", 14, y - (i - 1) * ROW)
    r.num = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.num:SetPoint("LEFT", 0, 0); r.num:SetText(i .. ".")
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 14, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.spell = CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")
    r.spell:SetWidth(120); r.spell:SetPoint("LEFT", 38, 0)
    r.spell:SetupMenu(function(_, root)
      SpellMenu(root, function(name) return WCK.char.rules[i] and WCK.char.rules[i].spell == name end,
        function(name) WCK.char.rules[i].spell = name; Changed() end)
    end)
    r.cond = CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")
    r.cond:SetWidth(150); r.cond:SetPoint("LEFT", r.spell, "RIGHT", 4, 0)
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
    r.sfx = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.sfx:SetPoint("LEFT", r.n, "RIGHT", 2, 0); r.sfx:SetText("s")
    r.del  = WCK.IconButton(r, "remove", 18, "Remove rule", nil, function() table.remove(WCK.char.rules, i); Changed() end)
    r.down = WCK.IconButton(r, "down", 18, "Move down", "Lower priority", function() WCK.MoveRule(WCK.char.rules, i, 1); Changed() end)
    r.up   = WCK.IconButton(r, "up", 18, "Move up", "Higher priority", function() WCK.MoveRule(WCK.char.rules, i, -1); Changed() end)
    r.del:SetPoint("RIGHT", 0, 0); r.down:SetPoint("RIGHT", -20, 0); r.up:SetPoint("RIGHT", -40, 0)
    rows[i] = r
  end
  local by = y - MAX_RULES * ROW - 4
  local add = WCK.Button(page, "Add rule", 100, function()
    table.insert(WCK.char.rules, { spell = "Shadow Bolt", cond = "ready" }); Changed() end)
  add:SetPoint("TOPLEFT", 16, by)
  local def = WCK.Button(page, "Restore defaults", 120, function()
    WCK.char.rules = WCK.CopyRules(WCK.DATA.defaultRules); Changed() end)
  def:SetPoint("LEFT", add, "RIGHT", 8, 0)

  function win:SyncRules()
    local rules = WCK.char.rules
    for i, r in ipairs(rows) do
      local rule = rules[i]
      r:SetShown(rule ~= nil)
      if rule then
        r.spell:GenerateMenu(); r.cond:GenerateMenu()
        r.n:SetShown(rule.cond == "notRecent"); r.n:SetText(tostring(rule.n or 0))
        r.icon:SetTexture(WCK.SpellIcon(rule.spell) or "Interface\\Icons\\INV_Misc_QuestionMark")
        local rb = WCK.RowButtons(i, #rules); r.up:SetEnabled(rb.up); r.down:SetEnabled(rb.down)
        r.sfx:SetShown(rule.cond == "notRecent")
      end
    end
    add:SetEnabled(#rules < MAX_RULES)
  end
  table.insert(win.syncs, { Sync = function() win:SyncRules() end })
end })

-- Mouseover cast slots: pick a spell per slot here, bind the key in Blizzard's Key Bindings
table.insert(WCK.settingsTabs, { title = "Cast slots", hint = "Bind keys: Esc > Options > Keybindings > AddOns > Warlock Combat Kit", build = function(page, win)
  local y = -22
  local rows = {}
  for i = 1, WCK.SLOTS do
    local r = CreateFrame("Frame", nil, page); r:SetSize(428, 24); r:SetPoint("TOPLEFT", 14, y - (i - 1) * ROW)
    r.key = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.key:SetPoint("LEFT", 4, 0)
    r.key:SetWidth(110); r.key:SetJustifyH("LEFT")
    r.spell = CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")
    r.spell:SetWidth(170); r.spell:SetPoint("LEFT", 120, 0)
    local function Set(name)
      WCK.char.slots[i] = name; WCK.Refresh()
      if InCombatLockdown() then WCK.Print("slot change applies after combat") end
    end
    r.spell:SetupMenu(function(_, root)
      root:CreateRadio("(none)", function() return WCK.char.slots[i] == nil end, function() Set(nil) end)
      SpellMenu(root, function(name) return WCK.char.slots[i] == name end, Set)
    end)
    rows[i] = r
  end
  table.insert(win.syncs, { Sync = function()
    for i, r in ipairs(rows) do
      r.key:SetText("Slot " .. i .. " [" .. (GetBindingKey("CLICK WCKCast" .. i .. ":LeftButton") or "unbound") .. "]")
      r.spell:GenerateMenu()
    end
  end })
end })

-- Alt clicks: a situational spell per bar spell; keyed by spell name so it follows rule reorders
table.insert(WCK.settingsTabs, { title = "Alt clicks", hint = "Extra spells on the rotation bar buttons.", build = function(page, win)
  local y = -22
  for _, c in ipairs({ { 134, "Right-click" }, { 248, "Shift+click" } }) do
    local t = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); t:SetPoint("TOPLEFT", c[1] + 14, y - 2); t:SetText(c[2])
  end
  local rows = {}
  local function Set(spell, key, name)
    local a = WCK.char.alts[spell] or {}
    a[key] = name
    WCK.char.alts[spell] = next(a) and a or nil
    WCK.Refresh()
    if InCombatLockdown() then WCK.Print("alt click change applies after combat") end
  end
  local function AltMenu(dd, key)
    dd:SetupMenu(function(_, root)
      local spell = dd:GetParent().spell
      if not spell then return end
      local function cur() local a = WCK.char.alts[spell]; return a and a[key] end
      root:CreateRadio("(none)", function() return cur() == nil end, function() Set(spell, key, nil) end)
      SpellMenu(root, function(name) return cur() == name end, function(name) Set(spell, key, name) end)
    end)
  end
  for i = 1, WCK.BAR_MAX do
    local r = CreateFrame("Frame", nil, page); r:SetSize(428, 24); r:SetPoint("TOPLEFT", 14, y - 18 - (i - 1) * ROW)
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.label:SetPoint("LEFT", 4, 0)
    r.label:SetWidth(110); r.label:SetJustifyH("LEFT")
    r.right = CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")
    r.right:SetWidth(110); r.right:SetPoint("LEFT", 120, 0); AltMenu(r.right, "right")
    r.shift = CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")
    r.shift:SetWidth(110); r.shift:SetPoint("LEFT", r.right, "RIGHT", 4, 0); AltMenu(r.shift, "shift")
    rows[i] = r
  end
  table.insert(win.syncs, { Sync = function()
    local list = WCK.BarSpells(WCK.char.rules, WCK.DATA.tail, WCK.spellSet, WCK.DATA.core)
    for i, r in ipairs(rows) do
      local e = list[i]
      r.spell = e and e.spell
      r:SetShown(e ~= nil)
      if e then r.label:SetText(e.spell); r.right:GenerateMenu(); r.shift:GenerateMenu() end
    end
  end })
end })

local function Build()
  win = CreateFrame("Frame", "WCKSettings", UIParent, "BackdropTemplate")
  win:SetSize(460, 520); win:SetFrameStrata("DIALOG")
  WCK.Skin(win, "Warlock Combat Kit", { close = true })
  WCK.MakeDialogMovable(win, "settings", 0, 0)
  tinsert(UISpecialFrames, "WCKSettings") -- Escape closes it
  win.syncs = {}
  local tabs, pages, n = {}, {}, #WCK.settingsTabs
  local tw = (460 - 24 - (n - 1) * 4) / n
  local function Select(i)
    if not pages[i] then i = 1 end
    for j, p in ipairs(pages) do
      p:SetShown(j == i); tabs[j].line:SetShown(j == i)
      tabs[j]:GetFontString():SetTextColor(unpack(j == i and WCK.THEME.accent or WCK.THEME.text))
    end
    WCK.db.settingsTab = i
  end
  for i, t in ipairs(WCK.settingsTabs) do
    local b = WCK.Button(win, t.title, tw, function() Select(i) end)
    b:SetPoint("TOPLEFT", 12 + (i - 1) * (tw + 4), -28)
    b.line = b:CreateTexture(nil, "OVERLAY"); b.line:SetColorTexture(unpack(WCK.THEME.accent))
    b.line:SetPoint("BOTTOMLEFT", 1, 1); b.line:SetPoint("BOTTOMRIGHT", -1, 1); b.line:SetHeight(2)
    -- Button's OnLeave resets the text colour; keep the active tab green
    b:HookScript("OnLeave", function(self)
      if self.line:IsShown() then self:GetFontString():SetTextColor(unpack(WCK.THEME.accent)) end
    end)
    local p = CreateFrame("Frame", nil, win)
    p:SetPoint("TOPLEFT", 0, -56); p:SetPoint("BOTTOMRIGHT", 0, 0)
    local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -4); hint:SetPoint("RIGHT", -16, 0); hint:SetJustifyH("LEFT"); hint:SetText(t.hint)
    t.build(p, win)
    tabs[i], pages[i] = b, p
  end
  function win:Sync() for _, s in ipairs(self.syncs) do s:Sync() end end
  win:HookScript("OnShow", win.Sync) -- hook: Skin already hooked the fade-in
  Select(WCK.db.settingsTab)
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
