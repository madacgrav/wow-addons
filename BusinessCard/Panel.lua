local ADDON, BC = ...
-- ponytail: fixed 20 rows, newest first; add a ScrollBox if 20 isn't enough
local MAX_ROWS, ROW_H, TOP = 20, 24, 64
local win

local function Whisper(name)
  -- Forever names contain spaces ("Thugtar Darkflame"); SendTell targets the name directly
  if ChatFrame_SendTell then ChatFrame_SendTell(name) else ChatFrame_OpenChat("/w " .. name .. " ") end
end

local function RowClick(self, btn)
  if not self.key then return end
  if BC.db.view == "card" then
    if BC.OnCardRowClick then BC.OnCardRowClick(self) end -- Phase 4
  elseif btn == "RightButton" then BC.Seen()[self.key] = nil; BC.RefreshPanel()
  elseif IsShiftKeyDown() then BC.ShowDetail(self.key)
  else Whisper(self.key) end
end

local function RowEnter(self)
  if not self.data or BC.db.view ~= "seen" then return end
  local d = self.data
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(d.name, 1, 0.82, 0)
  GameTooltip:AddLine(BC.CatList(d.cats), 0.8, 0.8, 0.8)
  if d.text then GameTooltip:AddLine(d.text .. " (" .. d.age .. ")", 1, 1, 1, true) end
  GameTooltip:AddLine("Click: whisper  Shift-click: card  Right-click: remove", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function SetView(v) BC.db.view = v; BC.RefreshPanel() end

local function Build()
  win = CreateFrame("Frame", "BusinessCardWin", UIParent, "BasicFrameTemplateWithInset")
  win:SetSize(420, TOP + 30 + MAX_ROWS * ROW_H); win:SetFrameStrata("DIALOG")
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
  local title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5); title:SetText("Business Cards")

  win.seenBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  win.seenBtn:SetSize(80, 22); win.seenBtn:SetPoint("TOPLEFT", 12, -30); win.seenBtn:SetText("Seen")
  win.seenBtn:SetScript("OnClick", function() SetView("seen") end)
  win.cardBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  win.cardBtn:SetSize(80, 22); win.cardBtn:SetPoint("LEFT", win.seenBtn, "RIGHT", 4, 0); win.cardBtn:SetText("My card")
  win.cardBtn:SetScript("OnClick", function() SetView("card") end)

  win.filter = CreateFrame("DropdownButton", nil, win, "WowStyle1DropdownTemplate")
  win.filter:SetWidth(150); win.filter:SetPoint("TOPRIGHT", -14, -30)
  win.filter:SetupMenu(function(_, root)
    local function Radio(label, key)
      root:CreateRadio(label, function() return BC.db.filter == key end, function() BC.db.filter = key; BC.RefreshPanel() end)
    end
    Radio("All", "all")
    for _, c in ipairs(BC.CATS) do Radio(BC.CAT_LABEL[c], c) end
  end)

  win.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, win)
    row:SetSize(392, ROW_H - 2); row:SetPoint("TOPLEFT", 14, -TOP - (i - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.status = row:CreateTexture(nil, "ARTWORK"); row.status:SetSize(8, 8); row.status:SetPoint("LEFT", 2, 0)
    row.status:SetColorTexture(1, 1, 1, 1); row.status:Hide() -- status badge, Phase 5
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 14, 0); row.name:SetWidth(130); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    row.cats = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.cats:SetPoint("LEFT", row.name, "RIGHT", 6, 0); row.cats:SetWidth(200); row.cats:SetJustifyH("LEFT"); row.cats:SetWordWrap(false)
    row.age = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.age:SetPoint("RIGHT", -4, 0); row.age:SetJustifyH("RIGHT")
    local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
    row:SetScript("OnClick", RowClick)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    win.rows[i] = row
  end
  win.footer = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  win.footer:SetPoint("BOTTOMLEFT", 16, 10)
  win:SetScript("OnShow", function() BC.RefreshPanel() end)
  win:Hide() -- new frames start shown; TogglePanel's first call must show, not hide
end

function BC.RenderSeen(rows, total)
  win.filter:Show()
  for i, row in ipairs(win.rows) do
    local v = rows[i]
    row:SetShown(v ~= nil)
    row.key, row.data = v and v.name, v
    if v then
      row.name:SetText(v.name); row.cats:SetText(BC.CatList(v.cats)); row.age:SetText(v.age)
      if BC.DecorateRow then BC.DecorateRow(row, v) end -- Phase 5 badge
    end
  end
  win.footer:SetText(math.min(#rows, MAX_ROWS) .. " shown / " .. total .. " seen")
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
  end)
end

local ST_LABEL = { a = "|cff33ff33Available|r", b = "|cffff3333Busy|r", o = "|cff888888Off|r" }
local SVC_LABEL = {}
for _, s in ipairs(BC.SERVICES) do SVC_LABEL[s.key] = s.label or s.name end

-- My card view: row 1 = overall, then professions, then services; click cycles status
function BC.RenderMyCard(w)
  local card, st = BC.MyCard(), BC.char.status
  local rows = { { key = "g", name = "Overall", st = card.g, skill = "" } }
  for _, p in ipairs(card.profs) do
    rows[#rows + 1] = { key = "p" .. p.id, name = BC.PROF_NAMES[p.id] or ("Profession " .. p.id), st = p.st, skill = tostring(p.skill) }
  end
  for _, s in ipairs(card.svcs) do rows[#rows + 1] = { key = s.key, name = SVC_LABEL[s.key], st = s.st, skill = "" } end
  for i, row in ipairs(w.rows) do
    local v = rows[i]
    row:SetShown(v ~= nil)
    row.key, row.data = v and v.key, nil
    row.status:Hide()
    if v then row.name:SetText(v.name); row.cats:SetText(ST_LABEL[v.st or "a"]); row.age:SetText(v.skill) end
  end
  local cached = {}
  for id, ids in pairs(BC.char.recipes) do cached[#cached + 1] = (BC.PROF_NAMES[id] or id) .. " " .. #ids end
  table.sort(cached)
  w.footer:SetText(#cached > 0 and ("Recipes cached: " .. table.concat(cached, ", ")) or "Open a profession window to cache recipes")
end

function BC.OnCardRowClick(row)
  local cur = BC.char.status[row.key] or "a"
  if row.key == "g" then BC.ChangeStatus("g", cur == "a" and "b" or "a")
  else BC.ChangeStatus(row.key, BC.NextStatus(cur)) end
end

function BC.ShowDetail(name) BC.Print("card detail for " .. name .. " comes in a later version") end

function BC.TogglePanel()
  if InCombatLockdown() then return BC.Print("not in combat") end
  if not win then Build() end
  win:SetShown(not win:IsShown())
end

table.insert(BC.onSeen, BC.RefreshPanel)

BINDING_HEADER_BUSINESSCARD = "BusinessCard"
BINDING_NAME_BUSINESSCARD_TOGGLE = "Toggle window"
function BusinessCard_Toggle() BC.TogglePanel() end
