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
  function b:SetStatus(st)
    local c = BC.StatusColor(st) or T.off
    self.dot:SetVertexColor(c[1], c[2], c[3]); self.text:SetText(ST_TEXT[st] or "")
    self:SetBackdropBorderColor(c[1], c[2], c[3], 0.8); self.st = st
  end
  b:SetScript("OnClick", function(self) if self.owner.onPill then self.owner.onPill(self.key) end end)
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
  b:SetScript("OnClick", function(self) if card.onPill then card.onPill(self.key) end end)
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
