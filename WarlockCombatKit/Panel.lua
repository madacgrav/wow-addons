local ADDON, WCK = ...
-- one movable panel: next-spell core + proc strip in the header, cast-map rows below. Not secure, so safe to redraw in combat.
local CORE, ICON, ROW_H, MAX_ROWS, MAX_ICONS, WIDTH = 44, 18, 22, 8, 8, 236

function WCK.MakeMovable(f, key, x, y)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() and not WCK.db.locked and not InCombatLockdown() then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, px, py = self:GetPoint()
    WCK.db.frames[key] = { p, rp, px, py }
  end)
  local pos = WCK.db.frames[key]
  f:ClearAllPoints()
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", UIParent, "CENTER", x, y) end
end

-- pulsing purple border on a frame; textures only, so safe in combat
function WCK.AddGlow(b)
  local g = b:CreateTexture(nil, "OVERLAY")
  g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); g:SetBlendMode("ADD")
  g:SetVertexColor(0.7, 0.3, 1); g:SetPoint("CENTER"); g:SetSize(b:GetWidth() * 1.8, b:GetHeight() * 1.8); g:Hide()
  local ag = g:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.15); a:SetToAlpha(1); a:SetDuration(0.6)
  b.glow, b.pulse = g, ag
end

function WCK.SetAlert(b, on)
  on = on and true or false
  if b.alerting == on then return end
  b.alerting = on
  if on then b.glow:Show(); b.pulse:Play() else b.pulse:Stop(); b.glow:Hide() end
end

-- probe: textures on enemy plates work in the open world; instances untested, so world only
function WCK.PLATE_OK(kind) return kind == "none" end

-- ponytail: one marker per visible plate; plates are pooled by Blizzard, so key markers by plate frame
local markers = {}
local function PlateMarker(unit, on)
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or not plate or not plate.UnitFrame then return end
  local m = markers[plate]
  if not m and on then
    -- own child frame raised above the plate's level/name widgets, sitting clear above them
    local okF, holder = pcall(CreateFrame, "Frame", nil, plate.UnitFrame)
    if not okF then return end
    holder:SetSize(22, 22); holder:SetPoint("BOTTOM", plate.UnitFrame, "TOP", 0, 18)
    holder:SetFrameLevel(plate.UnitFrame:GetFrameLevel() + 20)
    local t = holder:CreateTexture(nil, "OVERLAY"); t:SetAllPoints()
    t:SetTexture("Interface\\Icons\\Spell_Shadow_Possession") -- Fear icon
    markers[plate], m = holder, holder
  end
  if m then m:SetShown(on) end
end

local function RenderMarkers(view)
  for _, m in pairs(markers) do m:Hide() end
  if not WCK.db.plateMarker or not WCK.PLATE_OK(select(2, IsInInstance())) then return end
  local cc = {}
  for _, v in ipairs(view) do if WCK.RowHasCC(v) then cc[v.key] = true end end
  if next(cc) == nil then return end
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) and cc[(WCK.Identify(u))] then PlateMarker(u, true) end
  end
end

-- circular texture centered on the core (portrait mask cuts it round)
local function Disc(f, layer, sub)
  local t = f:CreateTexture(nil, layer, nil, sub); t:SetPoint("CENTER", f, "TOPLEFT", 8 + CORE / 2, -8 - CORE / 2)
  local m = f:CreateMaskTexture(); m:SetAllPoints(t)
  m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  t:AddMaskTexture(m)
  return t
end

table.insert(WCK.inits, function()
  local f = CreateFrame("Frame", "WCKPanel", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, 60); f:SetFrameStrata("MEDIUM")
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f:SetBackdropColor(0.04, 0, 0.07, 0.85); f:SetBackdropBorderColor(0.58, 0.51, 0.79, 0.9)
  f.rim = Disc(f, "BACKGROUND", 1); f.rim:SetSize(CORE + 10, CORE + 10); f.rim:SetColorTexture(0.58, 0.51, 0.79, 0.55)
  f.disc = Disc(f, "BACKGROUND", 2); f.disc:SetSize(CORE + 4, CORE + 4); f.disc:SetColorTexture(0.04, 0, 0.07, 0.9)
  f.core = f:CreateTexture(nil, "ARTWORK"); f.core:SetSize(CORE, CORE)
  f.core:SetPoint("TOPLEFT", 8, -8); f.core:SetTexture("Interface\\Icons\\Spell_Shadow_DeathCoil"); f.core:SetDesaturated(true)
  -- textures take no mouse, so a plain frame over the core carries the tooltip
  local hit = CreateFrame("Frame", nil, f); hit:SetAllPoints(f.core); hit:EnableMouse(true)
  hit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(WCK.next and ("Next: " .. WCK.next) or "No rule matches")
    GameTooltip:AddLine("Rules: /wck config", 1, 1, 1)
    GameTooltip:Show()
  end)
  hit:SetScript("OnLeave", GameTooltip_Hide)
  f.procs = {}
  for i, p in ipairs(WCK.DATA.procs) do
    local b = CreateFrame("Frame", nil, f); b:SetSize(28, 28); b:SetPoint("TOPLEFT", CORE + 20 + (i - 1) * 32, -16)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexture(p.icon)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    WCK.AddGlow(b)
    -- shine pop when the proc lands (same feel as WUK's stone pop)
    b.shine = b.icon:CreateAnimationGroup()
    local up = b.shine:CreateAnimation("Scale"); up:SetScale(1.3, 1.3); up:SetDuration(0.15); up:SetOrder(1)
    local down = b.shine:CreateAnimation("Scale"); down:SetScale(1 / 1.3, 1 / 1.3); down:SetDuration(0.2); down:SetOrder(2)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Nightfall: instant " .. p.spell); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b.key = p.key; f.procs[i] = b
  end
  f.rows = {}
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, f); r:SetSize(WIDTH - 16, ROW_H)
    WCK.AddGlow(r) -- 1.8x a 220px row is too wide; hug the row instead
    r.glow:ClearAllPoints(); r.glow:SetPoint("TOPLEFT", -6, 6); r.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    r.glow:SetDrawLayer("BACKGROUND") -- behind the spell icons so they stay readable while pulsing
    r:SetPoint("TOPLEFT", 8, -(CORE + 16) - (i - 1) * (ROW_H + 2))
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.label:SetPoint("LEFT")
    r.label:SetWidth(88); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
    r.icons = {}
    for j = 1, MAX_ICONS do
      local t = r:CreateTexture(nil, "ARTWORK"); t:SetSize(ICON, ICON); t:SetPoint("LEFT", 92 + (j - 1) * (ICON + 1), 0)
      t:SetTexCoord(0.07, 0.93, 0.07, 0.93); r.icons[j] = t
    end
    r:Hide(); f.rows[i] = r
  end
  WCK.MakeMovable(f, "panel", 260, -160) -- clear of WUK's strip at CENTER 0,-220
  WCK.panel = f
end)

function WCK.RenderPanel()
  local f = WCK.panel
  f:SetShown(WCK.db.shown)
  f.core:SetTexture(WCK.next and C_Spell.GetSpellTexture(WCK.next) or "Interface\\Icons\\Spell_Shadow_DeathCoil")
  f.core:SetDesaturated(not WCK.next)
  for _, b in ipairs(f.procs) do
    local on = WCK.db.procAlerts and WCK.procs[b.key] or false
    b.icon:SetAlpha(on and 1 or 0.25); b.icon:SetDesaturated(not on)
    WCK.SetAlert(b, on)
    if on and not b.wasOn then b.shine:Play() end
    b.wasOn = on
  end
  local view = WCK.RowsView(WCK.map, GetTime(), WCK.DATA.tracked)
  for i, r in ipairs(f.rows) do
    local v = view[i]
    if v then
      r.label:SetText(v.label or (v.key == "target" and "Target" or "?"))
      for j, t in ipairs(r.icons) do
        local icon = v.icons[j]
        if icon then t:SetTexture(C_Spell.GetSpellTexture(icon.spell)); t:SetAlpha(icon.alpha); t:Show() else t:Hide() end
      end
      WCK.SetAlert(r, WCK.RowHasCC(v))
      r:Show()
    else
      WCK.SetAlert(r, false)
      r:Hide()
    end
  end
  RenderMarkers(view)
  f:SetHeight(CORE + 20 + math.max(math.min(#view, MAX_ROWS), 1) * (ROW_H + 2))
end
table.insert(WCK.refreshers, WCK.RenderPanel)
