local ADDON, BC = ...
local ROW_H, TOP = 34, 54
local win
local T = BC.THEME
local ST_LABEL = { a = "|cff33ff33Available|r", b = "|cffff3333Busy|r", o = "|cff888888Off|r" }
local SVC_LABEL = BC.SVC_LABEL
local lastAt, flash = nil, {} -- session-only: newest ad time rendered, names still to flash once

local function Whisper(name)
  -- Forever names contain spaces ("Thugtar Darkflame"); SendTell targets the name directly
  if ChatFrame_SendTell then ChatFrame_SendTell(name) else ChatFrame_OpenChat("/w " .. name .. " ") end
end

local function RowClick(self, btn)
  if not self.key then return end
  if btn == "RightButton" then BC.Seen()[self.key] = nil; BC.RefreshPanel()
  elseif IsShiftKeyDown() then BC.Ask(self.key, true); BC.ShowDetail(self.key)
  elseif IsControlKeyDown() then BC.Who(self.key)
  else Whisper(self.key) end
end

local function RowEnter(self)
  if not self.data then return end
  local d = self.data
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(d.name, 1, 0.82, 0)
  GameTooltip:AddLine(BC.CatList(d.cats), 0.8, 0.8, 0.8)
  if d.zone then GameTooltip:AddLine("Last seen in " .. d.zone, 0.6, 0.8, 1)
  else GameTooltip:AddLine("Zone unknown - ctrl-click to /who", 0.6, 0.8, 1) end
  if d.text then GameTooltip:AddLine(d.text .. " (" .. d.age .. ")", 1, 1, 1, true) end
  if d.card then
    GameTooltip:AddLine(d.card.g == "b" and "Card: busy" or "Card:", 0.9, 0.7, 0.3)
    for _, p in ipairs(d.card.profs) do
      GameTooltip:AddLine("  " .. (BC.PROF_NAMES[p.id] or p.id) .. " " .. p.skill .. " " .. ST_LABEL[p.st], 1, 1, 1)
    end
    for _, sv in ipairs(d.card.svcs) do GameTooltip:AddLine("  " .. (SVC_LABEL[sv.key] or sv.key) .. " " .. ST_LABEL[sv.st], 1, 1, 1) end
  end
  GameTooltip:AddLine("Click: whisper  Ctrl-click: /who  Shift-click: card  Right-click: remove", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function SetView(v) BC.db.view = v; PanelTemplates_SetTab(win, v == "card" and 2 or 1); BC.RefreshPanel() end

-- list rows are created by the ScrollBox; built lazily on first init
local function BuildRow(row)
  row.built = true
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.stripe = row:CreateTexture(nil, "BACKGROUND"); row.stripe:SetAllPoints(); row.stripe:SetColorTexture(1, 1, 1, 0.03)
  local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); BC.Fade(hl, "HORIZONTAL", T.goldBright, 0.18, 0)
  row.glow = row:CreateTexture(nil, "OVERLAY"); row.glow:SetAllPoints(); BC.Fade(row.glow, "HORIZONTAL", T.goldBright, 0.5, 0)
  row.glow:SetAlpha(0); row.flash = BC.Flash(row.glow)
  row.dot = BC.Dot(row, 10); row.dot:SetPoint("LEFT", 6, 0)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.name:SetPoint("LEFT", 22, 0); row.name:SetWidth(150); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
  row.icons = {}
  for i = 1, 3 do
    local ic = row:CreateTexture(nil, "ARTWORK"); ic:SetSize(20, 20); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ic:SetPoint("LEFT", 180 + (i - 1) * 22, 0); row.icons[i] = ic
  end
  row.zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.zone:SetPoint("LEFT", 252, 0); row.zone:SetWidth(150); row.zone:SetJustifyH("LEFT"); row.zone:SetWordWrap(false)
  row.zone:SetTextColor(T.zone[1], T.zone[2], T.zone[3])
  row.badge = row:CreateTexture(nil, "ARTWORK"); row.badge:SetSize(16, 16); row.badge:SetPoint("RIGHT", -48, 0)
  row.badge:SetTexture(BC.ICON_FALLBACK) -- has a card = runs BusinessCard
  row.age = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.age:SetPoint("RIGHT", -8, 0); row.age:SetJustifyH("RIGHT")
  row:SetScript("OnClick", RowClick)
  row:SetScript("OnEnter", RowEnter)
  row:SetScript("OnLeave", GameTooltip_Hide)
end

local function InitRow(row, v)
  if not row.built then BuildRow(row) end
  row.key, row.data = v.key or v.name, v
  row.stripe:SetShown((v.i or 0) % 2 == 1)
  row.name:SetText(v.name)
  local nc = v.card and T.goldBright or T.cream
  row.name:SetTextColor(nc[1], nc[2], nc[3])
  local icons = BC.RowIcons(v.cats, 3)
  for i, ic in ipairs(row.icons) do ic:SetShown(icons[i] ~= nil); if icons[i] then ic:SetTexture(icons[i]) end end
  row.zone:SetText(v.zone or ""); row.age:SetText(v.age)
  local c = BC.StatusColor(BC.CardStatus(v.card, BC.db.filter))
  row.dot:SetShown(c ~= nil); if c then row.dot:SetVertexColor(c[1], c[2], c[3]) end
  row.badge:SetShown(v.card ~= nil)
  -- recycled rows can carry a paused flash (paused animations keep their alpha): always reset first
  row.flash:Stop(); row.glow:SetAlpha(0)
  if flash[v.name] then flash[v.name] = nil; row.flash:Play() end -- once per new ad, even if scrolled
end

local function Build()
  win = CreateFrame("Frame", "BusinessCardWin", UIParent, "BackdropTemplate")
  BC.Skin(win); BC.Parchment(win, 0.15)
  win:SetSize(540, 560); win:SetFrameStrata("DIALOG")
  local pos = BC.db.frames.win
  if pos then win:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else win:SetPoint("CENTER") end
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function(self) if not BC.db.locked then self:StartMoving() end end)
  win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    BC.db.frames.win = { p, rp, x, y }
  end)
  tinsert(UISpecialFrames, "BusinessCardWin")
  local title = win:CreateFontString(nil, "OVERLAY"); BC.TitleFont(title, 20)
  title:SetPoint("TOPLEFT", 18, -14); title:SetText("Business Cards")
  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
  BC.Rule(win, -44)
  local foot = BC.Rule(win, 0); foot:ClearAllPoints()
  foot:SetPoint("BOTTOMLEFT", 12, 28); foot:SetPoint("BOTTOMRIGHT", -12, 28)

  -- bottom tabs; named BusinessCardWinTabN so older PanelTemplates find them too
  win.Tabs = {}
  for i, v in ipairs({ { "Seen", "seen" }, { "My card", "card" } }) do
    local tab = CreateFrame("Button", "BusinessCardWinTab" .. i, win, "PanelTabButtonTemplate")
    tab:SetID(i); tab:SetText(v[1]); tab.view = v[2]
    if i == 1 then tab:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 12, 2)
    else tab:SetPoint("LEFT", win.Tabs[i - 1], "RIGHT", -14, 0) end
    tab:SetScript("OnClick", function(self) SetView(self.view) end)
    PanelTemplates_TabResize(tab, 0)
    win.Tabs[i] = tab
  end
  PanelTemplates_SetNumTabs(win, 2)

  win.filter = CreateFrame("DropdownButton", nil, win, "WowStyle1DropdownTemplate")
  win.filter:SetWidth(150); win.filter:SetPoint("TOPRIGHT", -34, -14)
  win.filter:SetupMenu(function(_, root)
    local function Radio(label, key)
      root:CreateRadio(label, function() return BC.db.filter == key end, function() BC.db.filter = key; BC.RefreshPanel() end)
    end
    Radio("All", "all")
    for _, c in ipairs(BC.CATS) do Radio(BC.CAT_LABEL[c], c) end
  end)

  -- scrolling list (Baganator CharacterSelect.lua:53-97)
  if CreateScrollBoxListLinearView and ScrollUtil and CreateDataProvider then
    win.list = CreateFrame("Frame", nil, win, "WowScrollBoxList")
    win.list:SetPoint("TOPLEFT", 12, -TOP); win.list:SetPoint("BOTTOMRIGHT", -26, 32)
    win.bar = CreateFrame("EventFrame", nil, win, "MinimalScrollBar")
    win.bar:SetPoint("TOPLEFT", win.list, "TOPRIGHT", 6, 0); win.bar:SetPoint("BOTTOMLEFT", win.list, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_H)
    view:SetElementInitializer("Button", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(win.list, win.bar, view)
  else
    BC.Print("scroll list unavailable on this client")
  end
  win.card = BC.NewCard(win); win.card:SetPoint("TOP", 0, -TOP - 8); win.card:Hide()
  win.card.onPill = function(key)
    local cur = BC.char.status[key] or "a"
    if key == "g" then BC.ChangeStatus("g", cur == "a" and "b" or "a") else BC.ChangeStatus(key, BC.NextStatus(cur)) end
  end
  win.footer = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  win.footer:SetPoint("BOTTOMLEFT", 18, 10); win.footer:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
  win:SetScript("OnShow", function() PanelTemplates_SetTab(win, BC.db.view == "card" and 2 or 1); BC.RefreshPanel() end)
  win:Hide() -- new frames start shown; TogglePanel's first call must show, not hide
end

function BC.RenderSeen(rows, total)
  win.filter:Show(); win.card:Hide()
  if not win.list then return end
  win.list:Show(); win.bar:Show()
  for i, v in ipairs(rows) do v.i = i end
  local new; new, lastAt = BC.NewSince(rows, lastAt)
  for n in pairs(new) do flash[n] = true end
  win.list:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
  win.footer:SetText(#rows .. " shown / " .. total .. " seen")
end

local pending = false
function BC.RefreshPanel()
  if not win or not win:IsShown() or pending then return end
  pending = true
  C_Timer.After(0.1, function()
    pending = false
    if BC.db.view == "card" and BC.RenderMyCard then
      win.filter:Hide(); BC.RenderMyCard(win)
    else
      local seen, total = BC.Seen(), 0
      for _ in pairs(seen) do total = total + 1 end
      BC.RenderSeen(BC.SeenRows(seen, BC.Cards and BC.Cards(), BC.db.filter, time()), total)
    end
    BC.RefreshDetail() -- a card may have just arrived
  end)
end


-- My card view: business-card widget; pill clicks cycle status via win.card.onPill
function BC.RenderMyCard(w)
  if w.list then w.list:Hide(); w.bar:Hide() end
  w.card:Show()
  w.card:SetModel(BC.CardModel(BC.MyCard(), { self = true }), UnitName("player"), GetRealZoneText())
  local cached = {}
  for id, ids in pairs(BC.char.recipes) do cached[#cached + 1] = (BC.PROF_NAMES[id] or id) .. " " .. #ids end
  table.sort(cached)
  w.footer:SetText(#cached > 0 and ("Recipes cached: " .. table.concat(cached, ", ")) or "Open a profession window to cache recipes")
end

function BC.TogglePanel()
  if InCombatLockdown() then return BC.Print("not in combat") end
  if not win then Build() end
  win:SetShown(not win:IsShown())
end

table.insert(BC.onSeen, BC.RefreshPanel)

BINDING_HEADER_BUSINESSCARD = "BusinessCard"
BINDING_NAME_BUSINESSCARD_TOGGLE = "Toggle window"
function BusinessCard_Toggle() BC.TogglePanel() end
