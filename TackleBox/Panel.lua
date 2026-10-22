local ADDON, TB = ...
-- ponytail: fixed 30 rows; collapse sections when they overflow, add a ScrollBox if that bites
local MAX_ROWS = 30
local WIDTH, ROW_W, TOP, TAB_H = 320, 296, 128, 34 -- TOP = header + tab strip height above the first row
local panel

-- deep water, sand and rope
TB.THEME = {
  sea = { 0.02, 0.09, 0.14, 0.94 }, shallows = { 0.08, 0.32, 0.45 }, rope = { 0.72, 0.58, 0.36 },
  sand = { 0.95, 0.85, 0.6 }, foam = { 0.75, 0.9, 1 }, line = { 0.15, 0.55, 0.8 },
}
local T = TB.THEME
local QUIPS = { "Tight lines!", "Patience is the best bait.", "The big one's still out there.",
  "Hook, line and sinker.", "Reel it in.", "A bad day fishing beats a good day questing." }

function TB.MakeMovable(f, key, x, y)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() and not TB.db.locked and not InCombatLockdown() then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, px, py = self:GetPoint()
    TB.db.frames[key] = { p, rp, px, py }
  end)
  local pos = TB.db.frames[key]
  f:ClearAllPoints()
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", UIParent, "CENTER", x, y) end
end

-- tooltip-style backdrop: dark sea fill, rope-coloured edge
function TB.Skin(f, edge)
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = edge or 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  f:SetBackdropColor(T.sea[1], T.sea[2], T.sea[3], T.sea[4])
  f:SetBackdropBorderColor(T.rope[1], T.rope[2], T.rope[3], 1)
end

-- vertical fade, top colour to bottom colour
local function Fade(tex, r, g, b, aTop, aBottom)
  tex:SetColorTexture(1, 1, 1, 1)
  tex:SetGradient("VERTICAL", CreateColor(r, g, b, aBottom), CreateColor(r, g, b, aTop))
end

local function Build()
  panel = CreateFrame("Frame", "TBPanel", UIParent, "BackdropTemplate")
  panel:SetWidth(WIDTH); panel:SetFrameStrata("MEDIUM")
  TB.Skin(panel)
  TB.MakeMovable(panel, "panel", 300, 0)

  -- shallow water glow along the bottom
  local glow = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
  glow:SetPoint("BOTTOMLEFT", 4, 4); glow:SetPoint("BOTTOMRIGHT", -4, 4); glow:SetHeight(90)
  Fade(glow, T.shallows[1], T.shallows[2], T.shallows[3], 0, 0.35)

  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:HookScript("OnClick", function() TB.db.shown = false end)

  -- round fishing portrait: the minimap-button layout (31px frame, 20px icon, 53px border at TOPLEFT) scaled x2
  local holder = CreateFrame("Frame", nil, panel)
  holder:SetSize(62, 62); holder:SetPoint("TOPLEFT", 2, 0)
  local portrait = holder:CreateTexture(nil, "ARTWORK")
  portrait:SetSize(40, 40); portrait:SetPoint("CENTER", 0, 2); portrait:SetTexture("Interface\\Icons\\Trade_Fishing")
  local mask = holder:CreateMaskTexture()
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(portrait); portrait:AddMaskTexture(mask)
  local ring = holder:CreateTexture(nil, "OVERLAY")
  ring:SetSize(106, 106); ring:SetPoint("TOPLEFT"); ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  panel.title:SetPoint("TOPLEFT", 62, -14); panel.title:SetText("TackleBox")
  panel.title:SetTextColor(T.sand[1], T.sand[2], T.sand[3])
  panel.quip = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.quip:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -3)
  panel.quip:SetTextColor(T.foam[1], T.foam[2], T.foam[3], 0.7)
  panel.quip:SetText(QUIPS[math.random(#QUIPS)])

  -- skill as a water-filled bar
  local sk = CreateFrame("StatusBar", nil, panel)
  sk:SetSize(ROW_W - 74, 14); sk:SetPoint("TOPLEFT", 12, -58)
  sk:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); sk:SetStatusBarColor(T.line[1], T.line[2], T.line[3])
  local skbg = sk:CreateTexture(nil, "BACKGROUND"); skbg:SetAllPoints(); skbg:SetColorTexture(0, 0, 0, 0.55)
  sk.text = sk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); sk.text:SetPoint("CENTER")
  panel.skill = sk

  -- got-away counter with a fish
  local fish = panel:CreateTexture(nil, "ARTWORK")
  fish:SetSize(16, 16); fish:SetPoint("LEFT", sk, "RIGHT", 8, 0); fish:SetTexture("Interface\\Icons\\INV_Misc_Fish_02")
  panel.misses = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.misses:SetPoint("LEFT", fish, "RIGHT", 4, 0)

  local rule = panel:CreateTexture(nil, "ARTWORK")
  rule:SetHeight(1); rule:SetPoint("TOPLEFT", 10, -TOP + 8); rule:SetPoint("TOPRIGHT", -10, -TOP + 8)
  rule:SetColorTexture(T.rope[1], T.rope[2], T.rope[3], 0.5)

  -- tab strip: one icon tab per section; tabs are made lazily in RenderPanel once the section list is known
  panel.tabs = {}

  panel.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(ROW_W, 24); row:SetPoint("TOPLEFT", 12, -TOP - (i - 1) * 26)
    row.band = row:CreateTexture(nil, "BACKGROUND"); row.band:SetAllPoints()
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(20, 20); row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trim the icon border
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0); row.text:SetWidth(ROW_W - 50); row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false)
    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -1); row.sub:SetWidth(ROW_W - 50); row.sub:SetJustifyH("LEFT"); row.sub:SetWordWrap(false)
    -- thin progress line under quest fish
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetSize(70, 4); row.bar:SetPoint("RIGHT", -6, -6); row.bar:SetMinMaxValues(0, 1)
    row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local bbg = row.bar:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints(); bbg:SetColorTexture(0, 0, 0, 0.6)
    row:EnableMouse(true)
    row.hl = row:CreateTexture(nil, "HIGHLIGHT"); row.hl:SetAllPoints(); row.hl:SetColorTexture(T.foam[1], T.foam[2], T.foam[3], 0.08)
    row:SetScript("OnEnter", function(self)
      if not self.itemID then return end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetItemByID(self.itemID)
      if self.onTooltip then self.onTooltip(GameTooltip) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    panel.rows[i] = row
  end
  panel:HookScript("OnShow", function(self) self.quip:SetText(QUIPS[math.random(#QUIPS)]) end)
end

local function MakeTab(i, n)
  local w = (ROW_W - (n - 1) * 4) / n
  local t = CreateFrame("Button", nil, panel)
  t:SetSize(w, TAB_H - 4); t:SetPoint("TOPLEFT", 12 + (i - 1) * (w + 4), -82)
  t.bg = t:CreateTexture(nil, "BACKGROUND"); t.bg:SetAllPoints()
  t.icon = t:CreateTexture(nil, "ARTWORK"); t.icon:SetSize(16, 16); t.icon:SetPoint("TOP", 0, -3)
  t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); t.label:SetPoint("BOTTOM", 0, 2)
  t.badge = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); t.badge:SetPoint("TOPRIGHT", -3, -2)
  t.under = t:CreateTexture(nil, "OVERLAY"); t.under:SetHeight(2)
  t.under:SetPoint("BOTTOMLEFT"); t.under:SetPoint("BOTTOMRIGHT"); t.under:SetColorTexture(T.rope[1], T.rope[2], T.rope[3], 1)
  local hl = t:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(T.foam[1], T.foam[2], T.foam[3], 0.12)
  t:SetScript("OnClick", function(self) TB.db.tab = self.key; TB.Refresh() end)
  t:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(self.title, T.sand[1], T.sand[2], T.sand[3]); GameTooltip:Show()
  end)
  t:SetScript("OnLeave", GameTooltip_Hide)
  return t
end

-- tabs = { {key, title, tab, icon, count} }
local function RenderTabs(tabs, active)
  for i, s in ipairs(tabs) do
    local t = panel.tabs[i] or MakeTab(i, #tabs)
    panel.tabs[i] = t
    local on = s.key == active
    t.key, t.title = s.key, s.title
    t.icon:SetTexture(s.icon); t.icon:SetDesaturated(not on); t.icon:SetAlpha(on and 1 or 0.6)
    t.label:SetText(s.tab)
    if on then t.label:SetTextColor(T.sand[1], T.sand[2], T.sand[3]) else t.label:SetTextColor(0.6, 0.6, 0.6) end
    t.badge:SetText(s.count > 0 and s.count or "")
    Fade(t.bg, T.shallows[1], T.shallows[2], T.shallows[3], on and 0.75 or 0.3, on and 0.35 or 0.1)
    t.under:SetShown(on)
  end
end

-- rows = { {text, sub?, icon?, color?={r,g,b}, empty?, itemID?, onTooltip?, progress?} }
function TB.RenderPanel(rows, skill, misses, tabs, active)
  if not panel then Build() end
  RenderTabs(tabs, active)
  local sk = panel.skill
  if skill then
    sk:SetMinMaxValues(0, math.max(1, skill.max)); sk:SetValue(skill.level)
  else
    sk:SetMinMaxValues(0, 1); sk:SetValue(0)
  end
  sk.text:SetText(TB.SkillText(skill))
  panel.misses:SetText("got away: " .. misses)

  local n, stripe = math.min(#rows, MAX_ROWS), false
  for i, row in ipairs(panel.rows) do
    local v = rows[i]
    row:SetShown(v ~= nil)
    if v then
      row.icon:SetShown(not v.empty)
      row.icon:SetTexture(v.icon or 134400)
      row.text:SetText(v.text)
      local c = v.color or (v.empty and { 0.6, 0.6, 0.6 }) or { 1, 1, 1 }
      row.text:SetTextColor(c[1], c[2], c[3])
      row.sub:SetText(v.sub or "")
      stripe = not stripe
      row.band:SetColorTexture(1, 1, 1, stripe and 0.03 or 0)
      row.bar:SetShown(v.progress ~= nil)
      if v.progress then
        row.bar:SetValue(v.progress)
        local done = v.progress >= 1
        row.bar:SetStatusBarColor(done and 0.25 or T.line[1], done and 0.75 or T.line[2], done and 0.25 or T.line[3])
      end
      row.itemID, row.onTooltip = v.itemID, v.onTooltip
    end
  end
  panel:SetHeight(TOP + 10 + math.max(n, 3) * 26) -- keep a little water under short tabs
  panel:Show()
end

TB.sections = {} -- {key, title, tab=short label, icon, empty=placeholder text, build=function() return rows end}

-- name + icon now, or a placeholder and a refresh once the client has loaded the item
function TB.ItemName(id)
  local name = C_Item.GetItemInfo(id)
  if not name then Item:CreateFromItemID(id):ContinueOnItemLoad(TB.Refresh) end
  return name or ("item:" .. id), C_Item.GetItemIconByID(id)
end

table.insert(TB.sections, { key = "quest", title = "Quest fish", tab = "Quest", empty = "No quest fish data.", icon = "Interface\\Icons\\INV_Misc_Note_01", build = function()
  local ids = {}
  for _, q in ipairs(TB.DATA.questFish) do ids[#ids + 1] = q.id end
  local rows = TB.QuestRows(TB.DATA.questFish, TB.CountItems(ids))
  for _, r in ipairs(rows) do r.text, r.icon = TB.ItemName(r.itemID); r.progress = math.min(1, r.have / r.need) end
  return rows
end })

local FLAG_COLORS = { here = { 0.4, 0.9, 0.5 }, outgrown = { 0.5, 0.5, 0.5 }, ["too low"] = { 1, 0.35, 0.35 } }
local FLAG_ICONS = { here = "Interface\\Icons\\Trade_Fishing", outgrown = "Interface\\Icons\\INV_Misc_Map_01", ["too low"] = "Interface\\Icons\\Spell_Frost_Frost" }
table.insert(TB.sections, { key = "where", title = "Where to fish", tab = "Where", empty = "No Fishing skill yet: visit a trainer.", icon = "Interface\\Icons\\INV_Misc_Map_01", build = function()
  local rows = TB.WhereRows(TB.DATA.zones, TB.DATA.lures, TB.skill, GetRealZoneText())
  for _, r in ipairs(rows) do r.color, r.icon = FLAG_COLORS[r.flag], FLAG_ICONS[r.flag] or "Interface\\Icons\\INV_Misc_Map_01" end
  return rows
end })

local CAMP_ITEMS = { 279965, 279966 } -- Fishing Rack, Fishing Hut placeables, for their icons
table.insert(TB.sections, { key = "camp", title = "Camp buffs", tab = "Camp", empty = "No camp buffs known.", icon = "Interface\\Icons\\Spell_Fire_Fire", build = function()
  for _, b in ipairs(TB.DATA.campBuffs) do if b.spellID then TB.auraState[b.spellID] = TB.ReadAura(b.spellID) end end
  local rows = TB.CampRows(TB.DATA.campBuffs, TB.auraState, TB.skill, GetSubZoneText())
  for i, r in ipairs(rows) do r.icon = CAMP_ITEMS[i] and C_Item.GetItemIconByID(CAMP_ITEMS[i]) or "Interface\\Icons\\Spell_Fire_Fire" end
  return rows
end })

-- secure item button on UIParent, not the panel: a secure child would make the panel protected in combat
table.insert(TB.inits, function()
  local b = CreateFrame("Button", "TBWaterButton", UIParent, "SecureActionButtonTemplate")
  b:SetSize(40, 40); b:RegisterForClicks("AnyUp", "AnyDown"); b:SetAttribute("type", "item")
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 3, -3); b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local rim = b:CreateTexture(nil, "OVERLAY"); rim:SetAllPoints()
  rim:SetTexture("Interface\\Buttons\\UI-Quickslot2"); rim:SetTexCoord(0.2, 0.8, 0.2, 0.8); rim:SetVertexColor(T.rope[1], T.rope[2], T.rope[3])
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  -- slow ripple so the button reads as "water"
  local ripple = b:CreateTexture(nil, "BACKGROUND"); ripple:SetPoint("CENTER"); ripple:SetSize(64, 64)
  ripple:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); ripple:SetBlendMode("ADD"); ripple:SetVertexColor(T.line[1], T.line[2], T.line[3])
  local ag = ripple:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.15); a:SetToAlpha(0.7); a:SetDuration(1.2)
  ag:Play()
  TB.MakeMovable(b, "water", 0, -220)
  b:SetScript("OnEnter", function(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetItemByID(self.itemID); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:Hide()
  TB.waterButton = b
end)

-- attributes and visibility only out of combat; PLAYER_REGEN_ENABLED -> Refresh re-applies
local function ApplyWater(id)
  local b = TB.waterButton
  if not b or InCombatLockdown() then return end
  b.itemID = id
  if id then b:SetAttribute("item", "item:" .. id); b.icon:SetTexture(C_Item.GetItemIconByID(id)); b:Show() else b:Hide() end
end

table.insert(TB.sections, { key = "water", title = "Water-walking", tab = "Water", empty = "No Draught of Water Walking or Surfer Shoes in bags.", icon = "Interface\\Icons\\Spell_Frost_WindWalkOn", build = function()
  local ww, counts, active = TB.DATA.waterWalk, {}, false
  for _, id in ipairs(ww.items) do counts[id] = C_Item.GetItemCount(id) + (C_Item.IsEquippedItem(id) and 1 or 0) end
  for _, sid in ipairs(ww.auras) do if TB.ReadAura(sid).active then active = true end end
  local id = TB.WaterWalkPick(ww.items, counts, active)
  ApplyWater(id)
  if active then return { { text = "Walking on water", icon = "Interface\\Icons\\Spell_Frost_WindWalkOn", color = { 0.4, 0.9, 0.5 } } } end
  if id then
    local name, icon = TB.ItemName(id)
    return { { itemID = id, text = name, icon = icon, sub = "click the water button to use (shift-drag to move)" } }
  end
  return {}
end })

table.insert(TB.sections, { key = "catch", title = "Collection", tab = "Catch", empty = "Nothing caught yet. Cast a line!", icon = "Interface\\Icons\\INV_Misc_Fish_02", build = function()
  local rows = TB.CollectionView(TB.DATA.fish, TB.char.catches, function(id) return C_Item.GetItemQualityByID(id) end)
  for _, r in ipairs(rows) do
    r.text, r.icon = TB.ItemName(r.itemID)
    if r.quality then local cr, cg, cb = C_Item.GetItemQualityColor(r.quality); r.color = { cr, cg, cb } end
    if r.knife then r.sub = r.sub .. ", knife: " .. (TB.ItemName(r.knife)) end
    local c = TB.char.catches[r.itemID]
    if c then
      r.onTooltip = function(tt)
        tt:AddLine(" ")
        for _, z in ipairs(TB.TopZones(c.zones, 3)) do tt:AddDoubleLine(z.zone, z.n, 1, 1, 1, 1, 1, 1) end
      end
    end
  end
  return rows
end })
table.insert(TB.refreshers, function()
  if not TB.db.shown then if panel then panel:Hide() end return end
  -- every tab builds so the badges stay current; the sections are small
  local secs = {}
  for _, s in ipairs(TB.sections) do
    local rows = s.build()
    secs[#secs + 1] = { key = s.key, title = s.title, tab = s.tab, icon = s.icon, empty = s.empty, rows = rows, count = #rows }
  end
  local rows, active = TB.TabRows(secs, TB.db.tab)
  TB.RenderPanel(rows, TB.skill, TB.session.misses, secs, active)
end)

table.insert(TB.inits, function()
  local b = CreateFrame("Button", "TBMinimapButton", Minimap)
  b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20); icon:SetPoint("CENTER", 0, 1); icon:SetTexture("Interface\\Icons\\Trade_Fishing")
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  local function Place()
    local a, r = math.rad(TB.db.minimapAngle), Minimap:GetWidth() / 2 + 8
    b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end
  Place()

  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      TB.db.minimapAngle = math.deg(math.atan2(py / s - my, px / s - mx))
      Place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then TB.Print(TB.SkillText(TB.skill)) else TB.db.shown = not TB.db.shown; TB.Refresh() end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("TackleBox", T.sand[1], T.sand[2], T.sand[3])
    GameTooltip:AddLine("Click: panel   Right-click: skill   Drag: move", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
end)
