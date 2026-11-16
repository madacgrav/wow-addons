local ADDON, BC = ...
-- ponytail: fixed 20 rows, newest first; add a ScrollBox if 20 isn't enough
local MAX_ROWS, ROW_H, TOP = 20, 24, 64
local win
local ST_LABEL = { a = "|cff33ff33Available|r", b = "|cffff3333Busy|r", o = "|cff888888Off|r" }
local SVC_LABEL = {}
for _, s in ipairs(BC.SERVICES) do SVC_LABEL[s.key] = s.label or s.name end

local function Whisper(name)
  -- Forever names contain spaces ("Thugtar Darkflame"); SendTell targets the name directly
  if ChatFrame_SendTell then ChatFrame_SendTell(name) else ChatFrame_OpenChat("/w " .. name .. " ") end
end

local function RowClick(self, btn)
  if not self.key then return end
  if BC.db.view == "card" then
    if BC.OnCardRowClick then BC.OnCardRowClick(self) end -- Phase 4
  elseif btn == "RightButton" then BC.Seen()[self.key] = nil; BC.RefreshPanel()
  elseif IsShiftKeyDown() then BC.Ask(self.key, true); BC.ShowDetail(self.key)
  elseif IsControlKeyDown() then BC.Who(self.key)
  else Whisper(self.key) end
end

local function RowEnter(self)
  if not self.data or BC.db.view ~= "seen" then return end
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

local function SetView(v) BC.db.view = v; BC.RefreshPanel() end

local function Build()
  win = CreateFrame("Frame", "BusinessCardWin", UIParent, "BasicFrameTemplateWithInset")
  win:SetSize(500, TOP + 30 + MAX_ROWS * ROW_H); win:SetFrameStrata("DIALOG")
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
    row:SetSize(472, ROW_H - 2); row:SetPoint("TOPLEFT", 14, -TOP - (i - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.status = row:CreateTexture(nil, "ARTWORK"); row.status:SetSize(8, 8); row.status:SetPoint("LEFT", 2, 0)
    row.status:SetColorTexture(1, 1, 1, 1); row.status:Hide() -- card status badge
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(12, 12); row.icon:SetPoint("RIGHT", -34, 0)
    row.icon:SetTexture("Interface\\Icons\\INV_Letter_15"); row.icon:Hide() -- runs BusinessCard
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 14, 0); row.name:SetWidth(130); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    row.cats = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.cats:SetPoint("LEFT", row.name, "RIGHT", 6, 0); row.cats:SetWidth(170); row.cats:SetJustifyH("LEFT"); row.cats:SetWordWrap(false)
    row.zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.zone:SetPoint("LEFT", row.cats, "RIGHT", 6, 0); row.zone:SetWidth(96); row.zone:SetJustifyH("LEFT"); row.zone:SetWordWrap(false)
    row.zone:SetTextColor(0.6, 0.8, 1)
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
      row.zone:SetText(v.zone or "")
      local st = BC.CardStatus(v.card, BC.db.filter)
      row.status:SetShown(st ~= nil)
      if st == "a" then row.status:SetColorTexture(0.2, 0.9, 0.2, 1) elseif st == "b" then row.status:SetColorTexture(0.9, 0.2, 0.2, 1) end
      row.icon:SetShown(v.card ~= nil)
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
    BC.RefreshDetail() -- a card may have just arrived
  end)
end


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
    row.status:Hide(); row.icon:Hide()
    if v then row.name:SetText(v.name); row.cats:SetText(ST_LABEL[v.st or "a"]); row.age:SetText(v.skill); row.zone:SetText("") end
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

-- card detail pane (shift-click): professions as buttons, recipe list fetched on demand
local DETAIL_ROWS, detail = 18
local names = {} -- names[key] = sorted recipe names, resolved once per received list

local function RecipeName(id)
  local r = C_TradeSkillUI.GetRecipeInfo(id)
  return (r and r.name) or (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Recipe #" .. id)
end

local function BuildDetail()
  detail = CreateFrame("Frame", "BusinessCardDetail", win, "BasicFrameTemplateWithInset")
  detail:SetSize(300, 560); detail:SetPoint("TOPLEFT", win, "TOPRIGHT", 2, 0)
  tinsert(UISpecialFrames, "BusinessCardDetail")
  detail.title = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); detail.title:SetPoint("TOP", 0, -5)
  detail.svcs = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  detail.svcs:SetPoint("TOPLEFT", 14, -30); detail.svcs:SetWidth(272); detail.svcs:SetJustifyH("LEFT")
  detail.profs = {}
  for i = 1, 6 do
    local b = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    b:SetSize(88, 22); b:SetPoint("TOPLEFT", 12 + ((i - 1) % 3) * 92, -58 - math.floor((i - 1) / 3) * 24)
    b:SetScript("OnClick", function(self)
      detail.prof = self.prof
      if not BC.RecipeList(detail.who, self.prof) then BC.RequestRecipes(detail.who, self.prof) end
      BC.RefreshDetail()
    end)
    detail.profs[i] = b
  end
  detail.search = CreateFrame("EditBox", nil, detail, "SearchBoxTemplate")
  detail.search:SetSize(266, 20); detail.search:SetPoint("TOPLEFT", 18, -112)
  detail.search:HookScript("OnTextChanged", function() BC.RefreshDetail() end)
  detail.rows = {}
  for i = 1, DETAIL_ROWS do
    local fs = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 16, -140 - (i - 1) * 21); fs:SetWidth(270); fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
    detail.rows[i] = fs
  end
  detail.footer = detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); detail.footer:SetPoint("BOTTOMLEFT", 16, 10)
end

function BC.RefreshDetail()
  if not detail or not detail:IsShown() then return end
  local who, card = detail.who, BC.Cards()[detail.who]
  detail.title:SetText(who .. (card and (card.g == "b" and " (busy)" or " (available)") or ""))
  for _, fs in ipairs(detail.rows) do fs:SetText("") end
  for i, b in ipairs(detail.profs) do
    local p = card and card.profs[i]
    b:SetShown(p ~= nil); b.prof = p and p.id
    if p then b:SetText((BC.PROF_NAMES[p.id] or p.id) .. " " .. p.skill) end
  end
  if not card then
    detail.svcs:SetText(""); detail.footer:SetText("")
    detail.rows[1]:SetText("No card yet - they may not run BusinessCard.")
    return
  end
  local sv = {}
  for _, s in ipairs(card.svcs) do sv[#sv + 1] = (SVC_LABEL[s.key] or s.key) .. " " .. ST_LABEL[s.st] end
  detail.svcs:SetText(#sv > 0 and table.concat(sv, ", ") or "No services")
  if not detail.prof then detail.footer:SetText("Pick a profession to see recipes"); return end
  local key, ids = who .. ":" .. detail.prof, BC.RecipeList(who, detail.prof)
  if not ids then detail.rows[1]:SetText("Requesting..."); detail.footer:SetText(""); return end
  if #ids == 0 then detail.rows[1]:SetText("They haven't opened that profession yet."); detail.footer:SetText(""); return end
  if not names[key] or #names[key] ~= #ids then
    local n = {}
    for i, id in ipairs(ids) do n[i] = RecipeName(id) end
    table.sort(n); names[key] = n
  end
  local q, shown = (detail.search:GetText() or ""):lower(), {}
  for _, n in ipairs(names[key]) do if q == "" or n:lower():find(q, 1, true) then shown[#shown + 1] = n end end
  for i, fs in ipairs(detail.rows) do fs:SetText(shown[i] or "") end
  detail.footer:SetText(math.min(#shown, DETAIL_ROWS) .. " of " .. #shown .. " (" .. #ids .. " known)")
end

function BC.ShowDetail(name)
  if not detail then BuildDetail() end
  if detail.who ~= name then detail.prof = nil; detail.search:SetText("") end
  detail.who = name
  detail:Show(); BC.RefreshDetail()
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
