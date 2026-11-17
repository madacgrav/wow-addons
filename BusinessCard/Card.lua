local ADDON, BC = ...
local T = BC.THEME
local ST_TEXT = { a = "Available", b = "Busy", o = "Off" }
local LINE_H, SVC_PER_ROW, SVC_STEP = 24, 11, 25

-- status pill: round dot + label; owner.onPill(key) on click (nil owner.onPill = display only)
function BC.Pill(parent, w, owner)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w or 74, 18); BC.Skin(b, "tooltip", { 0, 0, 0, 0.5 })
  b.dot = BC.Dot(b, 8); b.dot:SetPoint("LEFT", 6, 0)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.text:SetPoint("LEFT", b.dot, "RIGHT", 4, 0)
  b.owner = owner or parent
  b.breathe = BC.Breathe(b.dot)
  function b:SetStatus(st)
    local c = BC.StatusColor(st) or T.off
    self.dot:SetVertexColor(c[1], c[2], c[3]); self.text:SetText(ST_TEXT[st] or "")
    self:SetBackdropBorderColor(c[1], c[2], c[3], 0.8); self.st = st
    if st == "a" then self.breathe:Play() else self.breathe:Stop(); self.dot:SetAlpha(1) end
  end
  b:SetScript("OnClick", function(self)
    if self.owner.onPill then BC.Pop(self); self.owner.onPill(self.key) end
  end)
  BC.HoverGlow(b, function(self) self:SetStatus(self.st) end)
  return b
end

-- round portrait in the minimap-button ring: 31px frame, 20px icon, 53px border, scaled (TackleBox Panel.lua:70-79)
function BC.RoundPortrait(parent, size)
  local k = size / 20
  local holder = CreateFrame("Frame", nil, parent); holder:SetSize(31 * k, 31 * k)
  local t = BC.Dot(holder, size, "ARTWORK"); t:SetPoint("CENTER", 0, k)
  local ring = holder:CreateTexture(nil, "OVERLAY"); ring:SetSize(53 * k, 53 * k); ring:SetPoint("TOPLEFT")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  t.holder = holder
  function t:SetPortrait(p)
    self:SetVertexColor(1, 1, 1)
    if p == "player" then
      if not (SetPortraitTexture and pcall(SetPortraitTexture, self, "player")) then self:SetTexture(BC.ICON_FALLBACK) end
      self:SetTexCoord(0, 1, 0, 1)
    else self:SetTexture(p); self:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    self.p = p
  end
  return t
end

local function NewLine(card)
  local l = CreateFrame("Frame", nil, card); l:SetSize(336, 22)
  l.icon = l:CreateTexture(nil, "ARTWORK"); l.icon:SetSize(18, 18); l.icon:SetPoint("LEFT"); l.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  l.name = l:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  l.name:SetPoint("LEFT", 24, 0); l.name:SetWidth(90); l.name:SetJustifyH("LEFT"); l.name:SetWordWrap(false)
  l.bar = CreateFrame("StatusBar", nil, l); l.bar:SetSize(100, 8); l.bar:SetPoint("LEFT", 118, 0) -- TackleBox Panel.lua:91-94
  l.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); l.bar:SetStatusBarColor(T.gold[1], T.gold[2], T.gold[3])
  l.bar:SetMinMaxValues(0, 1)
  local bg = l.bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.55)
  l.skill = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); l.skill:SetPoint("LEFT", l.bar, "RIGHT", 4, 0)
  l.pill = BC.Pill(l, 84, card); l.pill:SetPoint("RIGHT")
  return l
end

local function SvcEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(self.label, 1, 0.82, 0); GameTooltip:AddLine(ST_TEXT[self.st] or "", 1, 1, 1)
  GameTooltip:Show()
end

local function NewSvc(card)
  local b = CreateFrame("Button", nil, card); b:SetSize(22, 22)
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b.dot = BC.Dot(b, 8, "OVERLAY"); b.dot:SetPoint("BOTTOMRIGHT", 2, -2)
  b.breathe = BC.Breathe(b.dot)
  b:SetScript("OnClick", function(self) if card.onPill then BC.Pop(self); card.onPill(self.key) end end)
  b:SetScript("OnEnter", SvcEnter); b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

function BC.NewCard(parent)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  card:SetWidth(360); BC.Skin(card, "tooltip", { 0.12, 0.10, 0.07, 0.96 }); BC.Parchment(card, 0.22, 3)
  card.portrait = BC.RoundPortrait(card, 44); card.portrait.holder:SetPoint("TOPLEFT", 6, -6)
  card.title = card:CreateFontString(nil, "OVERLAY"); BC.TitleFont(card.title, 18); card.title:SetPoint("TOPLEFT", 84, -18)
  card.title:SetPoint("RIGHT", -110, 0); card.title:SetJustifyH("LEFT"); card.title:SetWordWrap(false)
  card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
  card.sub:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
  card.g = BC.Pill(card, 96); card.g:SetPoint("TOPRIGHT", -12, -16); card.g.key = "g"
  BC.Rule(card, -82)
  card.lines, card.svcs = {}, {}
  card:EnableMouse(true)
  BC.HoverGlow(card, function(self) self:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3]) end)
  card.sheen = BC.Sheen(card)

  function card:SetModel(m, title, sub)
    self.portrait:SetPortrait(m.portrait); self.title:SetText(title or ""); self.sub:SetText(sub or "")
    self.g:SetStatus(m.g)
    for i, p in ipairs(m.profs) do
      local l = self.lines[i] or NewLine(self); self.lines[i] = l
      l:SetPoint("TOPLEFT", 12, -90 - (i - 1) * LINE_H); l:Show()
      l.icon:SetTexture(p.icon); l.name:SetText(p.name); l.bar:SetValue(p.frac); l.skill:SetText(p.skill)
      l.pill.key = p.key; l.pill:SetStatus(p.st)
    end
    for i = #m.profs + 1, #self.lines do self.lines[i]:Hide() end
    local y0 = -90 - #m.profs * LINE_H - 4
    for i, s in ipairs(m.svcs) do
      local b = self.svcs[i] or NewSvc(self); self.svcs[i] = b
      b:SetPoint("TOPLEFT", 14 + ((i - 1) % SVC_PER_ROW) * SVC_STEP, y0 - math.floor((i - 1) / SVC_PER_ROW) * 26); b:Show()
      b.icon:SetTexture(s.icon); b.key, b.label, b.st = s.key, s.label, s.st
      local c = BC.StatusColor(s.st) or T.off; b.dot:SetVertexColor(c[1], c[2], c[3])
      if s.st == "a" then b.breathe:Play() else b.breathe:Stop(); b.dot:SetAlpha(1) end
    end
    for i = #m.svcs + 1, #self.svcs do self.svcs[i]:Hide() end
    self:SetHeight(96 + #m.profs * LINE_H + (#m.svcs > 0 and (math.ceil(#m.svcs / SVC_PER_ROW) * 26 + 8) or 0) + 10)
  end

  -- unloaded portraits paint black (ForeverDungeonJournal PortraitPool.lua:2-7): re-apply on update and show
  local function Repaint(self) if self.portrait.p == "player" then self.portrait:SetPortrait("player") end end
  card:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
  card:SetScript("OnEvent", Repaint); card:HookScript("OnShow", Repaint)
  return card
end

-- card detail pane (shift-click a Seen row): their card, profession tabs, recipe list fetched on demand
local detail
local names = {} -- names[key] = {{id, name}} sorted by name, resolved once per received list

-- second return true = placeholder; spell data is requested so the next rebuild can resolve it
local function RecipeName(id)
  local r = C_TradeSkillUI.GetRecipeInfo(id)
  local name = (r and r.name) or C_Spell.GetSpellName(id)
  if name then return name end
  C_Spell.RequestLoadSpellData(id)
  return "Recipe #" .. id, true
end

-- hover: materials from the recipe schematic (works with no profession window open), with your bag+bank count
local function RecipeEnter(f)
  local e = f.entry
  GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
  GameTooltip:AddLine(e.name, 1, 0.82, 0)
  local ok, sch = pcall(C_TradeSkillUI.GetRecipeSchematic, e.id, false)
  local mats = ok and BC.Reagents(sch) or {}
  if #mats == 0 then GameTooltip:AddLine("Materials unknown", 0.6, 0.6, 0.6) end
  local loading = false
  for _, m in ipairs(mats) do
    local name = C_Item.GetItemNameByID(m.itemID)
    if not name then
      loading = true
      if Item and Item.CreateFromItemID then
        Item:CreateFromItemID(m.itemID):ContinueOnItemLoad(function() if GameTooltip:IsOwned(f) then RecipeEnter(f) end end)
      end
    end
    local icon = C_Item.GetItemIconByID(m.itemID) or 134400
    local have = C_Item.GetItemCount(m.itemID, true) or 0
    local c = have >= m.qty and BC.THEME.available or BC.THEME.muted
    GameTooltip:AddDoubleLine("|T" .. icon .. ":14|t " .. (name or "...") .. " x" .. m.qty, "you have " .. have,
      1, 1, 1, c[1], c[2], c[3])
  end
  if loading then GameTooltip:AddLine("Loading item names...", 0.6, 0.6, 0.6) end
  GameTooltip:AddLine("Shift-click: link in chat", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function RecipeClick(f)
  if not IsShiftKeyDown() then return end
  local link = C_TradeSkillUI.GetRecipeLink and C_TradeSkillUI.GetRecipeLink(f.entry.id)
  if link then ChatEdit_InsertLink(link) end
end

local STATE = {
  nocard = { BC.ICON_FALLBACK, "No card yet - they may not run BusinessCard." },
  pick = { "Interface\\Icons\\INV_Misc_Book_09", "Pick a profession to see recipes" },
  requesting = { "Interface\\Icons\\INV_Misc_PocketWatch_01", "Requesting..." },
  empty = { "Interface\\Icons\\INV_Misc_Note_01", "They haven't opened that profession yet." },
}
local function DetailState(card, ids, prof)
  if not card then return "nocard" end
  if not prof then return "pick" end
  if not ids then return "requesting" end
  if #ids == 0 then return "empty" end
  return "list"
end

local function TabClick(self)
  detail.prof = self.prof
  if not BC.RecipeList(detail.who, self.prof) then BC.RequestRecipes(detail.who, self.prof) end
  BC.RefreshDetail()
end
local function TabEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(self.label, 1, 0.82, 0); GameTooltip:Show()
end

local function BuildDetail()
  local win = BusinessCardWin
  detail = CreateFrame("Frame", "BusinessCardDetail", win, "BackdropTemplate")
  BC.Skin(detail); BC.Parchment(detail, 0.15)
  detail:SetSize(384, 620); detail:SetPoint("TOPLEFT", win, "TOPRIGHT", 2, 0)
  tinsert(UISpecialFrames, "BusinessCardDetail")
  local close = CreateFrame("Button", nil, detail, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
  local title = detail:CreateFontString(nil, "OVERLAY"); BC.TitleFont(title, 16)
  title:SetPoint("TOPLEFT", 16, -12); title:SetText("Card")
  detail.card = BC.NewCard(detail); detail.card:SetPoint("TOP", 0, -36) -- no onPill: their pills are display-only

  detail.tabs = {}
  for i = 1, 6 do -- Baganator side-tab look (Components.xml:20-46)
    local b = CreateFrame("Button", nil, detail); b:SetSize(28, 28)
    if i == 1 then b:SetPoint("TOPLEFT", detail.card, "BOTTOMLEFT", 2, -8) else b:SetPoint("LEFT", detail.tabs[i - 1], "RIGHT", 6, 0) end
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.sel = b:CreateTexture(nil, "OVERLAY"); b.sel:SetAllPoints()
    b.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight"); b.sel:SetBlendMode("ADD")
    b:SetScript("OnClick", TabClick); b:SetScript("OnEnter", TabEnter); b:SetScript("OnLeave", GameTooltip_Hide)
    detail.tabs[i] = b
  end
  detail.search = CreateFrame("EditBox", nil, detail, "SearchBoxTemplate")
  detail.search:SetSize(350, 20); detail.search:SetPoint("TOPLEFT", detail.card, "BOTTOMLEFT", 6, -44)
  detail.search:HookScript("OnTextChanged", function() BC.RefreshDetail() end)

  detail.list = CreateFrame("Frame", nil, detail, "WowScrollBoxList")
  detail.list:SetPoint("TOPLEFT", detail.card, "BOTTOMLEFT", 0, -70); detail.list:SetPoint("BOTTOMRIGHT", -26, 30)
  detail.bar = CreateFrame("EventFrame", nil, detail, "MinimalScrollBar")
  detail.bar:SetPoint("TOPLEFT", detail.list, "TOPRIGHT", 6, 0); detail.bar:SetPoint("BOTTOMLEFT", detail.list, "BOTTOMRIGHT", 6, 0)
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(18)
  view:SetElementInitializer("Button", function(f, entry)
    if not f.fs then
      f.fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.fs:SetPoint("LEFT", 6, 0)
      f.fs:SetPoint("RIGHT", -4, 0); f.fs:SetJustifyH("LEFT"); f.fs:SetWordWrap(false)
      local hl = f:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); BC.Fade(hl, "HORIZONTAL", T.goldBright, 0.18, 0)
      f:SetScript("OnEnter", RecipeEnter); f:SetScript("OnLeave", GameTooltip_Hide); f:SetScript("OnClick", RecipeClick)
    end
    f.entry = entry; f.fs:SetText(entry.name)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(detail.list, detail.bar, view)

  detail.state = CreateFrame("Frame", nil, detail); detail.state:SetSize(300, 70); detail.state:SetPoint("TOP", detail.list, "TOP", 0, -30)
  detail.state.icon = detail.state:CreateTexture(nil, "ARTWORK"); detail.state.icon:SetSize(32, 32); detail.state.icon:SetPoint("TOP")
  detail.state.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  detail.state.text = detail.state:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  detail.state.text:SetPoint("TOP", detail.state.icon, "BOTTOM", 0, -8); detail.state.text:SetWidth(300)
  detail.spin = BC.Spin(detail.state.icon, 1.2)
  detail.footer = detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); detail.footer:SetPoint("BOTTOMLEFT", 16, 10)
  detail.footer:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
end

function BC.RefreshDetail()
  if not detail or not detail:IsShown() then return end
  local who, card = detail.who, BC.Cards()[detail.who]
  detail.card:SetModel(BC.CardModel(card or {}, {}), who, card and card.zone)
  detail.card.g:SetShown(card ~= nil) -- no card: status unknown
  -- sheen when a card arrives or changes while this player's detail is open (not on first open)
  local rev = card and card.rev
  if detail.shownWho == who and rev and detail.shownRev ~= rev then detail.card.sheen.Play() end
  detail.shownWho, detail.shownRev = who, rev
  for i, b in ipairs(detail.tabs) do
    local p = card and card.profs[i]
    b:SetShown(p ~= nil); b.prof = p and p.id
    if p then
      b.icon:SetTexture(BC.PROF_ICON[p.id] or BC.ICON_FALLBACK)
      b.label = (BC.PROF_NAMES[p.id] or p.id) .. " " .. p.skill
      b.sel:SetShown(p.id == detail.prof)
    end
  end
  local ids = card and detail.prof and BC.RecipeList(who, detail.prof)
  local st = DetailState(card, ids, detail.prof)
  detail.search:SetShown(card ~= nil); detail.bar:SetShown(st == "list")
  if st ~= "list" then
    detail.state:Show(); detail.state.icon:SetTexture(STATE[st][1]); detail.state.text:SetText(STATE[st][2])
    if st == "requesting" then detail.spin:Play() else detail.spin:Stop() end
    detail.list:SetDataProvider(CreateDataProvider({})); detail.footer:SetText("")
    return
  end
  detail.state:Hide(); detail.spin:Stop()
  local key = who .. ":" .. detail.prof
  if not names[key] or #names[key] ~= #ids or names[key].pending then
    local n = {}
    for i, id in ipairs(ids) do
      local name, placeholder = RecipeName(id)
      n[i] = { id = id, name = name }; n.pending = n.pending or placeholder
    end
    table.sort(n, function(a, b) return a.name < b.name end)
    n.tries = (names[key] and names[key].tries or 0) + 1; names[key] = n
    if n.pending and n.tries < 5 then C_Timer.After(1, BC.RefreshDetail) else n.pending = nil end -- 5 x 1 s retries
  end
  local q, shown = (detail.search:GetText() or ""):lower(), {}
  for _, e in ipairs(names[key]) do if q == "" or e.name:lower():find(q, 1, true) then shown[#shown + 1] = e end end
  detail.list:SetDataProvider(CreateDataProvider(shown))
  detail.footer:SetText(#shown .. " of " .. #ids .. " known")
end

function BC.ShowDetail(name)
  if not detail then BuildDetail() end
  if detail.who ~= name then detail.prof = nil; detail.search:SetText("") end
  detail.who = name
  detail:Show(); BC.RefreshDetail()
end
