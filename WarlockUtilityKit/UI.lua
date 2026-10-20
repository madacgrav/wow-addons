local ADDON, WUK = ...

local KINDS = { "shard", "healthstone", "soulstone", "spellstone", "firestone" }
-- fallback textures for kinds never seen in bags (no item ID to ask the client)
local FALLBACK = {
  shard = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02", healthstone = "Interface\\Icons\\INV_Stone_04",
  soulstone = "Interface\\Icons\\Spell_Shadow_SoulGem", spellstone = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
  firestone = "Interface\\Icons\\INV_Ammo_FireTar",
}
local R, CORE, BTN, LABELS = 58, 44, 36, 30   -- ring radius, core size, orbit size, label band height
local ORBIT = { "healthstone", "soulstone", "spellstone", "firestone", "armor", "pet" } -- clockwise from 12

function WUK.MakeMovable(f, key, x, y)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() and not WUK.db.locked and not InCombatLockdown() then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, px, py = self:GetPoint()
    WUK.db.frames[key] = { p, rp, px, py }
  end)
  local pos = WUK.db.frames[key]
  f:ClearAllPoints()
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", UIParent, "CENTER", x, y) end
end

function WUK.ApplyShown()
  if WUK.db.shown then WUK.strip:Show() else WUK.strip:Hide() end
end

-- places core + orbit from strip.radius/angle; out of combat only (secure buttons)
function WUK.LayoutRing()
  local s = WUK.strip
  if InCombatLockdown() then return end
  local cy = LABELS / 2
  s.icons.shard:ClearAllPoints(); s.icons.shard:SetPoint("CENTER", s, "CENTER", 0, cy)
  for i, kind in ipairs(ORBIT) do
    local b, x, y = s.icons[kind], WUK.RingPoint(i, #ORBIT, s.radius, s.angle)
    b:ClearAllPoints(); b:SetPoint("CENTER", s, "CENTER", x, y + cy)
    b:SetAlpha(s.radius / R); b:EnableMouse(s.radius > 0)
  end
  -- collapsed: the core pulses on behalf of hidden alerts
  local any = false
  for _, kind in ipairs(ORBIT) do any = any or s.icons[kind].alerting end
  WUK.SetAlert(s.icons.shard, any and s.radius < R / 2)
  -- summoning circle closes with the ring
  local d = 2 * (s.radius + BTN / 2) + 8
  s.rim:SetSize(d + 6, d + 6); s.disc:SetSize(d, d); s.swirl:SetSize(d - 6, d - 6)
end

-- circular texture centered on the ring (portrait mask cuts it round)
local function Disc(f, layer, sub)
  local t = f:CreateTexture(nil, layer, nil, sub); t:SetPoint("CENTER", 0, LABELS / 2)
  local m = f:CreateMaskTexture(); m:SetAllPoints(t)
  m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  t:AddMaskTexture(m)
  return t
end

local SPIN, BLOOM = 6, 0.2 -- deg/sec (one turn per minute), seconds for a full bloom/collapse

-- collapsed unless the mouse is over the strip rect (polled: enter/leave events miss child-to-outside moves)
local function Target(s)
  return (WUK.db.collapse and not InCombatLockdown() and not s:IsMouseOver()) and 0 or R
end

local function Step(s, elapsed)
  if InCombatLockdown() then s:SetScript("OnUpdate", nil); return end
  s.targetRadius = Target(s)
  local moving = WUK.db.spin or WUK.db.collapse -- collapse keeps polling the mouse
  if moving then s.angle = (s.angle + SPIN * elapsed) % 360 end
  if s.radius ~= s.targetRadius then
    local d = R / BLOOM * elapsed
    s.radius = s.radius < s.targetRadius and math.min(s.targetRadius, s.radius + d) or math.max(s.targetRadius, s.radius - d)
    moving = true
  end
  WUK.LayoutRing()
  if not moving then s:SetScript("OnUpdate", nil) end
end

-- (re)start the ring animator; it removes itself when idle
function WUK.Animate()
  if not InCombatLockdown() then WUK.strip:SetScript("OnUpdate", Step) end
end

-- PLAYER_REGEN_DISABLED fires before lockdown: last chance to move secure buttons
function WUK.CombatFreeze()
  local s = WUK.strip
  s:SetScript("OnUpdate", nil)
  s.radius, s.targetRadius = R, R
  WUK.LayoutRing()
end

-- pulsing purple border on a button; textures only, so safe in combat
function WUK.AddGlow(b)
  local g = b:CreateTexture(nil, "OVERLAY")
  g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); g:SetBlendMode("ADD")
  g:SetVertexColor(0.7, 0.3, 1); g:SetPoint("CENTER"); g:SetSize(b:GetWidth() * 1.8, b:GetHeight() * 1.8); g:Hide()
  local ag = g:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.15); a:SetToAlpha(1); a:SetDuration(0.6)
  b.glow, b.pulse = g, ag
end

function WUK.SetAlert(b, on)
  on = on and true or false
  if b.alerting == on then return end
  b.alerting = on
  if on then b.glow:Show(); b.pulse:Play() else b.pulse:Stop(); b.glow:Hide() end
end

table.insert(WUK.inits, function()
  local f = CreateFrame("Frame", "WUKStrip", UIParent)
  -- ring of 6 orbit buttons around the shard core; soulstone + assignment lines underneath
  local SIZE = 2 * (R + BTN / 2) + 8
  f:SetSize(SIZE, SIZE + LABELS)
  f.angle, f.radius, f.targetRadius = 0, R, R
  -- summoning circle instead of a box: purple rim, dark disc, shadow swirl turning against the spin
  f.rim = Disc(f, "BACKGROUND", 0); f.rim:SetColorTexture(0.58, 0.51, 0.79, 0.55)
  f.disc = Disc(f, "BACKGROUND", 1); f.disc:SetColorTexture(0.04, 0, 0.07, 0.7)
  f.swirl = Disc(f, "BORDER", 0); f.swirl:SetTexture("Interface\\Icons\\Spell_Shadow_Twilight")
  f.swirl:SetBlendMode("ADD"); f.swirl:SetAlpha(0.35)
  local turn = f.swirl:CreateAnimationGroup(); turn:SetLooping("REPEAT")
  local rot = turn:CreateAnimation("Rotation"); rot:SetDegrees(360); rot:SetDuration(90) -- positive = counter-clockwise
  turn:Play()
  f.icons = {}
  for _, kind in ipairs(KINDS) do
    local b = CreateFrame("Button", "WUKStone_" .. kind, f, "SecureActionButtonTemplate")
    local size = kind == "shard" and CORE or BTN
    b:SetSize(size, size); WUK.AddGlow(b)
    b:SetFrameLevel(f:GetFrameLevel() + (kind == "shard" and 3 or 1)) -- core above orbit so collapsed buttons hide under it
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
    local sh = b.icon:CreateAnimationGroup() -- one-shot pop when a stone becomes available
    local up = sh:CreateAnimation("Scale"); up:SetScale(1.3, 1.3); up:SetDuration(0.15); up:SetOrder(1)
    local down = sh:CreateAnimation("Scale"); down:SetScale(1 / 1.3, 1 / 1.3); down:SetDuration(0.2); down:SetOrder(2)
    b.shine = sh
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    f.icons[kind] = b
  end
  f.stone = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.stone:SetPoint("BOTTOM", 0, 20)
  f.assign = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.assign:SetPoint("BOTTOM", 0, 6)
  WUK.strip = f
  WUK.MakeMovable(f, "strip", 0, -220)
  WUK.ApplyShown()
  WUK.On("PLAYER_REGEN_DISABLED", WUK.CombatFreeze)
end)

table.insert(WUK.refreshers, function()
  local c = WUK.counts
  for _, kind in ipairs(KINDS) do
    local b, id = WUK.strip.icons[kind], c.ids[kind]
    local icon = id and C_Item.GetItemIconByID(id)
    if icon then WUK.db.icons[kind] = icon end -- keep the real icon once the last stone is used
    b.icon:SetTexture(WUK.db.icons[kind] or FALLBACK[kind])
    b.icon:SetDesaturated(c[kind] == 0)
    WUK.SetAlert(b, (kind == "healthstone" or kind == "soulstone") and c[kind] == 0 and WUK.known[kind] ~= nil)
    b.count:SetText(c[kind])
    if b.lastCount == 0 and c[kind] > 0 then b.shine:Play() end -- nil on first refresh: no shine at login
    b.lastCount = c[kind]
    if not InCombatLockdown() then
      local ss = kind == "soulstone" and WUK.MySoulstoneTarget and WUK.MySoulstoneTarget() or nil
      b:SetAttribute("macrotext", WUK.StoneMacro(kind, c[kind], id, WUK.known[kind], ss) or "")
    end
  end
  WUK.LayoutRing(); WUK.Animate()
end)
