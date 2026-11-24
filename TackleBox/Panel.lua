local ADDON, TB = ...
-- HEAD = collapsed panel height; the tab strip starts at -HEAD; TOP = first row's y
local WIDTH, ROW_W, PAD, TAB_H, HEAD = 320, 296, 12, 34, 100
local TOP = HEAD + TAB_H + PAD               -- 146
local PITCH, ROW_H = 26, 24                  -- row spacing and height
local SKILL_Y, ZONE_Y = -58, -86             -- skill bar top; zone line centre
local VISIBLE, LIST_W = 10, ROW_W - 20 -- rows shown before scrolling; 20px gutter keeps the scroll bar inside the edge
local panel

-- deep water, sand and rope
TB.THEME = {
  sea = { 0.02, 0.09, 0.14, 0.94 }, shallows = { 0.08, 0.32, 0.45 }, rope = { 0.72, 0.58, 0.36 },
  sand = { 0.95, 0.85, 0.6 }, foam = { 0.75, 0.9, 1 }, line = { 0.15, 0.55, 0.8 },
  muted = { 0.6, 0.6, 0.6 }, -- inactive labels, empty text
  hi = 0.10,                 -- hover alpha for rows and tabs
}
local T = TB.THEME
local QUIPS = { "Tight lines!", "Patience is the best bait.", "The big one's still out there.",
  "Hook, line and sinker.", "Reel it in.", "A bad day fishing beats a good day questing." }

-- 1x1 anchor that the panel and the action bar both hang off. The secure bar anchors here, never to the panel:
-- anchoring a secure frame to the panel would make the panel protected in combat (no tab switches, no resize).
function TB.Dock()
  if TB.dock then return TB.dock end
  local d = CreateFrame("Frame", "TBDock", UIParent)
  d:SetSize(1, 1); d:SetMovable(true)
  local pos = TB.db.frames.dock
  if pos then d:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else d:SetPoint("TOPLEFT", UIParent, "CENTER", 140, 150) end
  TB.dock = d
  return d
end

-- shift-dragging any docked frame moves the whole dock
function TB.DockDrag(f)
  f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function()
    if IsShiftKeyDown() and not TB.db.locked and not InCombatLockdown() then TB.Dock():StartMoving() end
  end)
  f:SetScript("OnDragStop", function()
    local d = TB.Dock()
    d:StopMovingOrSizing()
    local p, _, rp, px, py = d:GetPoint()
    TB.db.frames.dock = { p, rp, px, py }
  end)
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

-- display font with fallback (pattern: BusinessCard/Skin.lua:96-97)
function TB.TitleFont(fs, size)
  if not fs:SetFont("Fonts\\MORPHEUS.ttf", size or 18, "") then fs:SetFontObject("GameFontNormalLarge") end
  fs:SetShadowOffset(1, -1)
end

local function Build()
  panel = CreateFrame("Frame", "TBPanel", UIParent, "BackdropTemplate")
  panel:SetWidth(WIDTH); panel:SetFrameStrata("MEDIUM")
  TB.Skin(panel)
  panel:SetPoint("TOPLEFT", TB.Dock(), "TOPLEFT"); TB.DockDrag(panel)

  -- shallow water glow along the bottom
  local glow = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
  glow:SetPoint("BOTTOMLEFT", 4, 4); glow:SetPoint("BOTTOMRIGHT", -4, 4); glow:SetHeight(90)
  Fade(glow, T.shallows[1], T.shallows[2], T.shallows[3], 0, 0.35)
  -- matching shallows band behind the header
  local band = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
  band:SetPoint("TOPLEFT", 4, -4); band:SetPoint("TOPRIGHT", -4, -4); band:SetHeight(-SKILL_Y - 4)
  Fade(band, T.shallows[1], T.shallows[2], T.shallows[3], 0.35, 0)

  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4) -- same inset as BusinessCard/Panel.lua:108
  close:HookScript("OnClick", function() TB.db.shown = false; TB.Refresh() end)

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
  TB.TitleFont(panel.title)
  panel.title:SetTextColor(T.sand[1], T.sand[2], T.sand[3])
  panel.quip = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.quip:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -3)
  panel.quip:SetTextColor(T.foam[1], T.foam[2], T.foam[3], 0.7)
  panel.quip:SetText(QUIPS[math.random(#QUIPS)])

  -- skill as a water-filled bar
  local sk = CreateFrame("StatusBar", nil, panel)
  sk:SetHeight(14); sk:SetPoint("TOPLEFT", PAD, SKILL_Y) -- right edge set below, against the got-away counter
  sk:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); sk:SetStatusBarColor(T.line[1], T.line[2], T.line[3])
  local skbg = sk:CreateTexture(nil, "BACKGROUND"); skbg:SetAllPoints(); skbg:SetColorTexture(0, 0, 0, 0.55)
  sk.text = sk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); sk.text:SetPoint("CENTER")
  panel.skill = sk

  -- got-away counter pinned to the right edge; the skill bar takes whatever width is left
  panel.misses = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.misses:SetPoint("RIGHT", panel, "TOPRIGHT", -PAD, SKILL_Y - 7); panel.misses:SetJustifyH("RIGHT")
  local fish = panel:CreateTexture(nil, "ARTWORK")
  fish:SetSize(16, 16); fish:SetPoint("RIGHT", panel.misses, "LEFT", -4, 0); fish:SetTexture("Interface\\Icons\\INV_Misc_Fish_02")
  sk:SetPoint("RIGHT", fish, "LEFT", -8, 0)

  -- expand/collapse the tabs; state in TB.db.expanded
  local ex = CreateFrame("Button", nil, panel)
  ex:SetSize(16, 16); ex:SetPoint("RIGHT", panel, "TOPRIGHT", -PAD, ZONE_Y)
  ex:SetScript("OnClick", function() TB.db.expanded = not TB.db.expanded; TB.Refresh() end)
  ex:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(TB.db.expanded and "Hide tabs" or "Show tabs", T.sand[1], T.sand[2], T.sand[3]); GameTooltip:Show()
  end)
  ex:SetScript("OnLeave", GameTooltip_Hide)
  panel.expand = ex
  -- current zone's fishing status, always shown
  panel.zone = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.zone:SetPoint("LEFT", panel, "TOPLEFT", PAD, ZONE_Y); panel.zone:SetPoint("RIGHT", ex, "LEFT", -4, 0)
  panel.zone:SetJustifyH("LEFT"); panel.zone:SetWordWrap(false)

  local rule = panel:CreateTexture(nil, "ARTWORK")
  rule:SetHeight(1); rule:SetPoint("TOPLEFT", 10, -TOP + 8); rule:SetPoint("TOPRIGHT", -10, -TOP + 8)
  rule:SetColorTexture(T.rope[1], T.rope[2], T.rope[3], 0.5)
  panel.rule = rule

  -- tab strip: one icon tab per section; tabs are made lazily in RenderPanel once the section list is known
  panel.tabs = {}

  -- rows scroll inside a box at most VISIBLE rows tall; rows are made lazily by GetRow
  panel.rows = {}
  panel.scroll = CreateFrame("ScrollFrame", "TBPanelScroll", panel, "UIPanelScrollFrameTemplate")
  panel.scroll:SetPoint("TOPLEFT", PAD, -TOP); panel.scroll:SetSize(LIST_W, 3 * PITCH)
  panel.content = CreateFrame("Frame", nil, panel.scroll)
  panel.content:SetSize(LIST_W, PITCH)
  panel.scroll:SetScrollChild(panel.content)
  panel:HookScript("OnShow", function(self) self.quip:SetText(QUIPS[math.random(#QUIPS)]) end)

  -- empty tab: the tab's icon and placeholder text centred in the list area
  panel.emptyIcon = panel:CreateTexture(nil, "ARTWORK")
  panel.emptyIcon:SetSize(32, 32); panel.emptyIcon:SetPoint("TOP", panel.scroll, "TOP", 0, -6)
  panel.emptyIcon:SetDesaturated(true); panel.emptyIcon:SetAlpha(0.5); panel.emptyIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  panel.emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.emptyText:SetPoint("TOP", panel.emptyIcon, "BOTTOM", 0, -4); panel.emptyText:SetWidth(LIST_W - 20)
  panel.emptyText:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
end

local function GetRow(i)
  if panel.rows[i] then return panel.rows[i] end
  local row = CreateFrame("Frame", nil, panel.content)
  row:SetSize(LIST_W, ROW_H); row:SetPoint("TOPLEFT", 0, -(i - 1) * PITCH)
  row.band = row:CreateTexture(nil, "BACKGROUND"); row.band:SetAllPoints()
  row.frame = row:CreateTexture(nil, "BORDER"); row.frame:SetSize(22, 22); row.frame:SetPoint("LEFT", 1, 0) -- 1px rope edge
  row.frame:SetColorTexture(T.rope[1], T.rope[2], T.rope[3], 0.6)
  row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(20, 20); row.icon:SetPoint("LEFT", 2, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trim the icon border
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0); row.text:SetWidth(LIST_W - 50); row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false)
  row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -1); row.sub:SetWidth(LIST_W - 50); row.sub:SetJustifyH("LEFT"); row.sub:SetWordWrap(false)
  -- thin progress line under quest fish
  row.bar = CreateFrame("StatusBar", nil, row)
  row.bar:SetSize(70, 4); row.bar:SetPoint("RIGHT", -6, -6); row.bar:SetMinMaxValues(0, 1)
  row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  local bbg = row.bar:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints(); bbg:SetColorTexture(0, 0, 0, 0.6)
  row:EnableMouse(true)
  row.hl = row:CreateTexture(nil, "HIGHLIGHT"); row.hl:SetAllPoints(); row.hl:SetColorTexture(T.foam[1], T.foam[2], T.foam[3], T.hi)
  row:SetScript("OnEnter", function(self)
    if not self.itemID and self.full then -- spot rows: the sub line is often cut off
      GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine(self.full, 1, 1, 1, true); GameTooltip:Show()
      return
    end
    if not self.itemID and self.hint then -- nearby pool rows
      GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine(self.hint, 1, 1, 1); GameTooltip:Show()
      return
    end
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetItemByID(self.itemID)
    if self.onTooltip then self.onTooltip(GameTooltip) end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  row:SetScript("OnMouseUp", function(self, b) if b == "LeftButton" and self.onClick then self.onClick() end end)
  panel.rows[i] = row
  return row
end

local function MakeTab(i, n)
  local w = (ROW_W - (n - 1) * 4) / n
  local t = CreateFrame("Button", nil, panel)
  t:SetSize(w, TAB_H - 4); t:SetPoint("TOPLEFT", PAD + (i - 1) * (w + 4), -HEAD)
  t.bg = t:CreateTexture(nil, "BACKGROUND"); t.bg:SetAllPoints()
  t.icon = t:CreateTexture(nil, "ARTWORK"); t.icon:SetSize(16, 16); t.icon:SetPoint("TOP", 0, -3)
  t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); t.label:SetPoint("BOTTOM", 0, 2)
  if n >= 6 then -- too narrow for labels: bigger centred icon, title in the tooltip
    t.label:Hide(); t.icon:SetSize(18, 18); t.icon:ClearAllPoints(); t.icon:SetPoint("CENTER", 0, 1)
  end
  t.badge = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); t.badge:SetPoint("TOPRIGHT", -3, -2)
  t.under = t:CreateTexture(nil, "OVERLAY"); t.under:SetHeight(2)
  t.under:SetPoint("BOTTOMLEFT"); t.under:SetPoint("BOTTOMRIGHT"); t.under:SetColorTexture(T.rope[1], T.rope[2], T.rope[3], 1)
  local hl = t:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(T.foam[1], T.foam[2], T.foam[3], T.hi)
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
    if on then t.label:SetTextColor(T.sand[1], T.sand[2], T.sand[3]) else t.label:SetTextColor(T.muted[1], T.muted[2], T.muted[3]) end
    t.badge:SetText(s.count > 0 and s.count or "")
    Fade(t.bg, T.shallows[1], T.shallows[2], T.shallows[3], on and 0.75 or 0.3, on and 0.35 or 0.1)
    t.under:SetShown(on)
  end
end

-- rows = { {text, sub?, icon?, color?={r,g,b}, empty?, itemID?, onTooltip?, progress?} }
function TB.RenderPanel(rows, skill, misses, tabs, active, zone)
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

  local exp = TB.db.expanded
  panel.zone:SetText(zone and zone.text or "")
  local zc = zone and zone.color or { 1, 1, 1 }
  panel.zone:SetTextColor(zc[1], zc[2], zc[3])
  panel.expand:SetNormalTexture(exp and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
  panel.expand:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
  panel.rule:SetShown(exp)
  for _, t in ipairs(panel.tabs) do t:SetShown(exp) end

  local n, stripe = #rows, false
  for i = 1, math.max(n, #panel.rows) do
    local v = rows[i]
    local row = v and GetRow(i) or panel.rows[i]
    row:SetShown(v ~= nil)
    if v then
      local plain = v.empty or v.header -- header rows: sand text, no icon, no stripe
      row.icon:SetShown(not plain); row.frame:SetShown(not plain)
      row.icon:SetTexture(v.icon or 134400)
      row.text:SetText(v.text)
      local c = v.color or (v.empty and T.muted) or (v.header and T.sand) or { 1, 1, 1 }
      row.text:SetTextColor(c[1], c[2], c[3])
      row.sub:SetText(v.sub or "")
      if not v.header then stripe = not stripe end
      row.band:SetColorTexture(1, 1, 1, (stripe and not v.header) and 0.03 or 0)
      row.bar:SetShown(v.progress ~= nil)
      if v.progress then
        row.bar:SetValue(v.progress)
        local done = v.progress >= 1
        row.bar:SetStatusBarColor(done and 0.25 or T.line[1], done and 0.75 or T.line[2], done and 0.25 or T.line[3])
      end
      row.itemID, row.onTooltip = v.itemID, v.onTooltip
      row.full = v.zone and v.sub or nil
      row.onClick, row.hint = v.onClick, v.hint
    end
  end
  local empty = n == 1 and rows[1].empty
  local activeTab
  for _, s in ipairs(tabs) do if s.key == active then activeTab = s end end
  panel.emptyIcon:SetShown(exp and empty); panel.emptyText:SetShown(exp and empty)
  if empty then
    panel.emptyIcon:SetTexture(activeTab and activeTab.icon); panel.emptyText:SetText(rows[1].text)
    panel.rows[1]:Hide()
  end
  local vis = math.min(math.max(n, 3), VISIBLE) -- keep a little water under short tabs
  panel.content:SetHeight(math.max(n, 1) * PITCH)
  panel.scroll:SetHeight(vis * PITCH)
  if panel.scroll.ScrollBar then panel.scroll.ScrollBar:SetShown(n > VISIBLE) end
  if active ~= panel.lastTab then panel.scroll:SetVerticalScroll(0); panel.lastTab = active end
  panel.scroll:SetShown(exp)
  panel:SetHeight(exp and (TOP + 10 + vis * PITCH) or HEAD)
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

table.insert(TB.sections, { key = "camp", title = "Fishing camp", tab = "Camp", empty = "No camp data.", icon = "Interface\\Icons\\Spell_Fire_Fire", build = function()
  local camp, counts = TB.DATA.camp, {}
  for _, c in ipairs(camp) do
    counts[c.item] = C_Item.GetItemCount(c.item)
    for _, r in ipairs(c.reagents or {}) do counts[r[1]] = C_Item.GetItemCount(r[1]) end
  end
  local rows = {}
  -- shared camp buff on top (probe run 7E: one "Camp Benefits" aura for every camp item)
  local a = TB.ReadAura(TB.DATA.campAura)
  TB.auraState[TB.DATA.campAura] = a
  if a.active then rows[1] = { header = true, text = "Camp Benefits: " .. (a.remaining and (TB.FormatTime(a.remaining) .. " left") or "active") }
  else rows[1] = { header = true, text = TB.campCooldownText or "camp ready" } end -- set by the action bar refresher (runs first)
  for _, r in ipairs(TB.CampRows(camp, TB.auraState, TB.skill, counts)) do
    r.icon, r.itemID = C_Item.GetItemIconByID(r.item), r.item
    if r.missing then r.sub = "missing " .. (TB.ItemName(r.missing)) end
    rows[#rows + 1] = r
  end
  return rows
end })

-- the action bar (Actions.lua, refreshed first) owns the secure button; this tab only reports
table.insert(TB.sections, { key = "water", title = "Water-walking", tab = "Water", empty = "No Draught of Water Walking or Surfer Shoes in bags.", icon = "Interface\\Icons\\Spell_Frost_WindWalkOn", build = function()
  if TB.waterActive then return { { text = "Walking on water", icon = "Interface\\Icons\\Spell_Frost_WindWalkOn", color = { 0.4, 0.9, 0.5 } } } end
  local w = TB.actions.water
  if w then
    local name, icon = TB.ItemName(w.item)
    return { { itemID = w.item, text = name, icon = icon, sub = "click it on the fishing bar to use" } }
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
table.insert(TB.sections, { key = "spots", title = "Best spots", tab = "Spots", empty = "No spot data for your skill yet.", icon = "Interface\\Icons\\INV_Misc_Spyglass_01", build = function()
  -- learned pools on this map first (nearest first, click sets a waypoint), then the best zones for your skill
  local rows = {}
  local x, y, map = TB.PlayerPos()
  local list, w, h = map and TB.db.pools[map], nil, nil
  if map then w, h = TB.HBD:GetZoneSize(map) end
  if not map then rows[#rows + 1] = { header = true, text = "No map position here" }
  elseif list and #list > 0 and w and w > 0 then
    rows[#rows + 1] = { header = true, text = "Nearby pools" }
    for _, n in ipairs(TB.NearestPools(list, x, y, w, h, 10)) do
      local p, info = n.pool, TB.PoolByKey(TB.DATA.pools, n.pool.t)
      rows[#rows + 1] = { text = info and info.name or n.pool.t, sub = math.floor(n.yd) .. " yd - seen " .. p.n .. "x",
        icon = info and info.icon, hint = "Click: set waypoint", onClick = function() TB.Waypoint(map, p.x, p.y) end }
    end
  end
  local spots = TB.SpotsRows(TB.DATA.spots, TB.DATA.zones, TB.DATA.pools, TB.skill, GetRealZoneText())
  if #rows > 0 and #spots > 0 then rows[#rows + 1] = { header = true, text = "Best spots" } end
  for _, r in ipairs(spots) do rows[#rows + 1] = r end
  return rows
end })
table.insert(TB.refreshers, function()
  if not TB.db.shown then if panel then panel:Hide() end return end
  -- every tab builds so the badges stay current; the sections are small
  local secs = {}
  for _, s in ipairs(TB.sections) do
    local rows, count = s.build(), 0
    for _, r in ipairs(rows) do if not r.header then count = count + 1 end end -- badges skip section headers
    -- a tab holding only headers (e.g. "No map position here") still counts as empty for the badge, not for the list
    secs[#secs + 1] = { key = s.key, title = s.title, tab = s.tab, icon = s.icon, empty = s.empty, rows = rows, count = count }
  end
  local rows, active = TB.TabRows(secs, TB.db.tab)
  local zone = TB.ZoneStatus(TB.DATA.zones, TB.DATA.lures, TB.skill, GetRealZoneText())
  if zone then zone.color = FLAG_COLORS[zone.flag] or (zone.flag == nil and T.muted) end
  TB.RenderPanel(rows, TB.skill, TB.session.misses, secs, active, zone)
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
