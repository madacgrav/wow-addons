local ADDON, TB = ...
-- ponytail: fixed 30 rows; collapse sections when they overflow, add a ScrollBox if that bites
local MAX_ROWS = 30
local panel

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

local function Build()
  panel = CreateFrame("Frame", "TBPanel", UIParent, "BasicFrameTemplateWithInset")
  panel:SetWidth(320)
  TB.MakeMovable(panel, "panel", 300, 0)
  if panel.CloseButton then panel.CloseButton:HookScript("OnClick", function() TB.db.shown = false end) end
  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  panel.title:SetPoint("TOP", 0, -5); panel.title:SetText("TackleBox")
  panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.header:SetPoint("TOPLEFT", 12, -30); panel.header:SetJustifyH("LEFT")
  panel.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(296, 24); row:SetPoint("TOPLEFT", 12, -54 - (i - 1) * 26)
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(20, 20); row.icon:SetPoint("LEFT")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0); row.text:SetWidth(266); row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false)
    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -1); row.sub:SetWidth(266); row.sub:SetJustifyH("LEFT"); row.sub:SetWordWrap(false)
    row:EnableMouse(true)
    row.hl = row:CreateTexture(nil, "HIGHLIGHT"); row.hl:SetAllPoints(); row.hl:SetColorTexture(1, 1, 1, 0.08)
    row:SetScript("OnMouseUp", function(self)
      if self.header then TB.db.collapsed[self.header] = not TB.db.collapsed[self.header] or nil; TB.Refresh() end
    end)
    row:SetScript("OnEnter", function(self)
      if not self.itemID then return end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetItemByID(self.itemID)
      if self.onTooltip then self.onTooltip(GameTooltip) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    panel.rows[i] = row
  end
end

-- rows = { {text, sub?, icon?, color?={r,g,b}, header?, itemID?, onTooltip?} }
function TB.RenderPanel(rows, header)
  if not panel then Build() end
  panel.header:SetText(header)
  local n = math.min(#rows, MAX_ROWS)
  for i, row in ipairs(panel.rows) do
    local v = rows[i]
    row:SetShown(v ~= nil)
    if v then
      row.icon:SetShown(not v.header)
      row.icon:SetTexture(v.icon or 134400)
      row.text:SetFontObject(v.header and "GameFontNormal" or "GameFontHighlightSmall")
      row.text:SetText(v.text)
      local c = v.color or (v.header and { 1, 0.82, 0 }) or { 1, 1, 1 }
      row.text:SetTextColor(c[1], c[2], c[3])
      row.sub:SetText(v.sub or "")
      row.header, row.itemID, row.onTooltip = v.header, v.itemID, v.onTooltip
    end
  end
  panel:SetHeight(64 + n * 26)
  panel:Show()
end

TB.sections = {} -- each phase's init appends {key, title, build=function() return rows end}

-- name + icon now, or a placeholder and a refresh once the client has loaded the item
function TB.ItemName(id)
  local name = C_Item.GetItemInfo(id)
  if not name then Item:CreateFromItemID(id):ContinueOnItemLoad(TB.Refresh) end
  return name or ("item:" .. id), C_Item.GetItemIconByID(id)
end

table.insert(TB.sections, { key = "quest", title = "Quest fish", build = function()
  local ids = {}
  for _, q in ipairs(TB.DATA.questFish) do ids[#ids + 1] = q.id end
  local rows = TB.QuestRows(TB.DATA.questFish, TB.CountItems(ids))
  for _, r in ipairs(rows) do r.text, r.icon = TB.ItemName(r.itemID) end
  return rows
end })

local FLAG_COLORS = { here = { 0.25, 0.75, 0.25 }, outgrown = { 0.5, 0.5, 0.5 }, ["too low"] = { 1, 0.3, 0.3 } }
table.insert(TB.sections, { key = "where", title = "Where to fish", build = function()
  local rows = TB.WhereRows(TB.DATA.zones, TB.DATA.lures, TB.skill, GetRealZoneText())
  for _, r in ipairs(rows) do r.color, r.icon = FLAG_COLORS[r.flag], 136245 end -- 136245 = Fishing profession icon (probe run 1)
  return rows
end })

table.insert(TB.sections, { key = "catch", title = "Collection", build = function()
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
  local secs = {}
  for _, s in ipairs(TB.sections) do secs[#secs + 1] = { key = s.key, title = s.title, rows = s.build() } end
  TB.RenderPanel(TB.BuildView(secs, TB.db.collapsed), TB.SkillText(TB.skill) .. "   got away: " .. TB.session.misses)
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
    GameTooltip:AddLine("TackleBox")
    GameTooltip:AddLine("Click: panel   Right-click: skill   Drag: move", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
end)
