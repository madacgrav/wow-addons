local ADDON, WCK = ...
-- the panel: a summoning circle (next spell at its heart, Nightfall orb on its rim) with soul tethers
-- hanging below it, one per enemy you've cursed. No box. Not secure, so safe to redraw in combat.
local CIRCLE, CORE, ICON, ROW_H, MAX_ROWS, MAX_ICONS, WIDTH = 84, 44, 18, 22, 8, 8, 236
local CX, CY = CIRCLE / 2, -CIRCLE / 2               -- circle centre, from the panel's top-left
local SHADOW, FEL = { 0.58, 0.31, 0.92 }, { 0.45, 1, 0.3 } -- shadow purple, fel green

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

-- cut a texture round with the portrait mask
local function Round(owner, t)
  local m = owner:CreateMaskTexture(); m:SetAllPoints(t)
  m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  t:AddMaskTexture(m)
  return t
end

-- round texture centred on the circle
local function Disc(f, layer, sub, size)
  local t = f:CreateTexture(nil, layer, nil, sub); t:SetPoint("CENTER", f, "TOPLEFT", CX, CY); t:SetSize(size, size)
  return Round(f, t)
end

local function Spin(t, seconds)
  local ag = t:CreateAnimationGroup(); ag:SetLooping("REPEAT")
  local r = ag:CreateAnimation("Rotation"); r:SetDegrees(seconds > 0 and 360 or -360); r:SetDuration(math.abs(seconds))
  ag:Play()
end

local function Breathe(t, from, to, seconds)
  local ag = t:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(seconds); a:SetSmoothing("IN_OUT")
  ag:Play()
end

local function Pop(t)
  local ag = t:CreateAnimationGroup()
  local up = ag:CreateAnimation("Scale"); up:SetScale(1.3, 1.3); up:SetDuration(0.15); up:SetOrder(1)
  local down = ag:CreateAnimation("Scale"); down:SetScale(1 / 1.3, 1 / 1.3); down:SetDuration(0.2); down:SetOrder(2)
  return ag
end

local function Fade(t, dir, c, a1, a2)
  t:SetColorTexture(1, 1, 1, 1)
  t:SetGradient(dir, CreateColor(c[1], c[2], c[3], a1), CreateColor(c[1], c[2], c[3], a2))
end

table.insert(WCK.inits, function()
  local f = CreateFrame("Frame", "WCKPanel", UIParent)
  f:SetSize(WIDTH, CIRCLE + 8); f:SetFrameStrata("MEDIUM")

  -- the summoning circle: breathing aura, rune ring turning one way, shadow swirl the other
  f.aura = Disc(f, "BACKGROUND", 0, CIRCLE + 14); f.aura:SetColorTexture(SHADOW[1], SHADOW[2], SHADOW[3], 1)
  f.aura:SetBlendMode("ADD"); Breathe(f.aura, 0.08, 0.3, 2.4)
  f.rim = Disc(f, "BACKGROUND", 1, CIRCLE); f.rim:SetColorTexture(0.58, 0.51, 0.79, 0.6)
  f.disc = Disc(f, "BACKGROUND", 2, CIRCLE - 6); f.disc:SetColorTexture(0.03, 0, 0.06, 0.92)
  f.runes = f:CreateTexture(nil, "BORDER", nil, 0); f.runes:SetPoint("CENTER", f, "TOPLEFT", CX, CY)
  f.runes:SetSize(CIRCLE + 6, CIRCLE + 6); f.runes:SetTexture("Interface\\Cooldown\\star4")
  f.runes:SetBlendMode("ADD"); f.runes:SetVertexColor(SHADOW[1], SHADOW[2], SHADOW[3], 0.55); Spin(f.runes, -40)
  f.swirl = Disc(f, "BORDER", 1, CIRCLE - 8); f.swirl:SetTexture("Interface\\Icons\\Spell_Shadow_Twilight")
  f.swirl:SetBlendMode("ADD"); f.swirl:SetAlpha(0.4); Spin(f.swirl, 60)

  -- heart of the circle: the next spell, round, on a dark well
  f.well = Disc(f, "ARTWORK", 0, CORE + 6); f.well:SetColorTexture(0, 0, 0, 0.9)
  f.core = Disc(f, "ARTWORK", 1, CORE); f.core:SetTexture("Interface\\Icons\\Spell_Shadow_DeathCoil"); f.core:SetDesaturated(true)
  f.coreShine = Pop(f.core)
  -- textures take no mouse, so a plain frame over the core carries the tooltip
  local hit = CreateFrame("Frame", nil, f); hit:SetSize(CORE, CORE); hit:SetPoint("CENTER", f, "TOPLEFT", CX, CY)
  hit:EnableMouse(true)
  hit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(WCK.next and ("Next: " .. WCK.next) or "No rule matches", SHADOW[1] + 0.3, SHADOW[2] + 0.4, 1)
    GameTooltip:AddLine("Rules: /wck config", 1, 1, 1)
    GameTooltip:Show()
  end)
  hit:SetScript("OnLeave", GameTooltip_Hide)

  -- proc orbs sit on the circle's rim, lower right, glowing fel green when they fire
  f.procs = {}
  for i, p in ipairs(WCK.DATA.procs) do
    local a = math.rad(-35 - (i - 1) * 40)
    local b = CreateFrame("Frame", nil, f); b:SetSize(26, 26); b:SetFrameLevel(f:GetFrameLevel() + 2)
    b:SetPoint("CENTER", f, "TOPLEFT", CX + math.cos(a) * CIRCLE / 2, CY + math.sin(a) * CIRCLE / 2)
    b.rim = b:CreateTexture(nil, "BACKGROUND"); b.rim:SetPoint("CENTER"); b.rim:SetSize(30, 30)
    b.rim:SetColorTexture(0.1, 0.02, 0.15, 1); Round(b, b.rim)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexture(p.icon); Round(b, b.icon)
    WCK.AddGlow(b); b.glow:SetVertexColor(FEL[1], FEL[2], FEL[3])
    b.shine = Pop(b.icon)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Nightfall: instant " .. p.spell); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b.key = p.key; f.procs[i] = b
  end

  -- the tether: a fading cord from the circle down past every row
  f.cord = f:CreateTexture(nil, "BACKGROUND", nil, 3); f.cord:SetWidth(2)
  f.cord:SetPoint("TOP", f, "TOPLEFT", 12, -CIRCLE + 4); Fade(f.cord, "VERTICAL", SHADOW, 0, 0.8)

  f.rows = {}
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, f); r:SetSize(WIDTH - 20, ROW_H)
    r:SetPoint("TOPLEFT", 20, -(CIRCLE + 4) - (i - 1) * (ROW_H + 3))
    -- soul band: purple smoke fading to nothing on the right
    r.band = r:CreateTexture(nil, "BACKGROUND", nil, 0); r.band:SetAllPoints(); Fade(r.band, "HORIZONTAL", SHADOW, 0.42, 0)
    WCK.AddGlow(r) -- 1.8x a 216px row is too wide; hug the row instead
    r.glow:ClearAllPoints(); r.glow:SetPoint("TOPLEFT", -6, 6); r.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    r.glow:SetDrawLayer("BACKGROUND", 1) -- behind the spell icons so they stay readable while pulsing
    -- a soul shard where the row hangs off the cord
    r.shard = r:CreateTexture(nil, "ARTWORK"); r.shard:SetSize(12, 12); r.shard:SetPoint("CENTER", r, "LEFT", -8, 0)
    r.shard:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02"); Round(r, r.shard)
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.label:SetPoint("LEFT", 4, 0)
    r.label:SetWidth(84); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false); r.label:SetTextColor(0.88, 0.8, 1)
    r.label:SetShadowColor(SHADOW[1], 0, SHADOW[3], 0.9); r.label:SetShadowOffset(1, -1)
    r.icons = {}
    for j = 1, MAX_ICONS do
      local x = 92 + (j - 1) * (ICON + 2)
      local ring = r:CreateTexture(nil, "BORDER"); ring:SetSize(ICON + 2, ICON + 2); ring:SetPoint("CENTER", r, "LEFT", x + ICON / 2, 0)
      ring:SetColorTexture(0.05, 0, 0.08, 1); Round(r, ring)
      local t = r:CreateTexture(nil, "ARTWORK"); t:SetSize(ICON, ICON); t:SetPoint("CENTER", ring)
      Round(r, t); t.ring = ring; r.icons[j] = t
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
  if WCK.next and WCK.next ~= f.lastNext then f.coreShine:Play() end
  f.lastNext = WCK.next
  for _, b in ipairs(f.procs) do
    local on = WCK.db.procAlerts and WCK.procs[b.key] or false
    b.icon:SetAlpha(on and 1 or 0.3); b.icon:SetDesaturated(not on)
    WCK.SetAlert(b, on)
    if on and not b.wasOn then b.shine:Play() end
    b.wasOn = on
  end
  local view = WCK.RowsView(WCK.map, GetTime(), WCK.DATA.tracked)
  local shown = math.min(#view, MAX_ROWS)
  for i, r in ipairs(f.rows) do
    local v = view[i]
    if v then
      r.label:SetText(v.label or (v.key == "target" and "Target" or "?"))
      for j, t in ipairs(r.icons) do
        local icon = v.icons[j]
        if icon then t:SetTexture(C_Spell.GetSpellTexture(icon.spell)); t:SetAlpha(icon.alpha); t:Show() else t:Hide() end
        t.ring:SetShown(icon ~= nil)
      end
      local cc = WCK.RowHasCC(v)
      Fade(r.band, "HORIZONTAL", cc and FEL or SHADOW, cc and 0.35 or 0.42, 0) -- feared mobs burn fel green
      WCK.SetAlert(r, cc)
      r:Show()
    else
      WCK.SetAlert(r, false)
      r:Hide()
    end
  end
  f.cord:SetShown(shown > 0); f.cord:SetHeight(math.max(shown, 1) * (ROW_H + 3) + 6)
  RenderMarkers(view)
  f:SetHeight(CIRCLE + 8 + shown * (ROW_H + 3))
end
table.insert(WCK.refreshers, WCK.RenderPanel)
