local ADDON, WUK = ...

local KINDS = { "shard", "healthstone", "soulstone", "spellstone", "firestone" }
-- fallback textures for kinds never seen in bags (no item ID to ask the client)
local FALLBACK = {
  shard = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02", healthstone = "Interface\\Icons\\INV_Stone_04",
  soulstone = "Interface\\Icons\\Spell_Shadow_SoulGem", spellstone = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
  firestone = "Interface\\Icons\\INV_Ammo_FireTar",
}
local R, CORE, BTN, LABELS = 58, 44, 36, 30   -- ring radius, core size, orbit size, label band height

-- warlock window theme: void purple body, fel-green edge + accents, purple title bar (strip palette, UI rim/disc)
local WHITE = "Interface\\Buttons\\WHITE8x8"
WUK.THEME = {
  bg = { 0.04, 0, 0.07, 0.94 }, edge = { 0.45, 0.85, 0.3, 0.9 },
  bar = { 0.32, 0.12, 0.48, 1 }, barEnd = { 0.08, 0.02, 0.12, 1 },
  accent = { 0.45, 0.85, 0.3 }, text = { 0.85, 0.8, 0.95 },
  btn = { 0.16, 0.06, 0.24, 0.95 },
}

-- two-colour gradient with a flat fallback; colours are {r,g,b,a}
local function Gradient(t, orient, from, to)
  t:SetColorTexture(1, 1, 1, 1)
  if t.SetGradient and CreateColor then t:SetGradient(orient, CreateColor(unpack(from)), CreateColor(unpack(to)))
  else t:SetVertexColor(unpack(to)) end
end

local function Pulse(region, from, to, secs)
  local ag = region:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(secs)
  ag:Play()
  return ag
end

-- f must inherit BackdropTemplate and already be sized; opts = { close, swirl }; returns the title FontString
function WUK.Skin(f, title, opts)
  local T, A = WUK.THEME, WUK.THEME.accent
  opts = opts or {}
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(unpack(T.bg)); f:SetBackdropBorderColor(unpack(T.edge))
  -- depth: purple haze at the top fading into the void
  local shade = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  shade:SetPoint("TOPLEFT", 1, -1); shade:SetPoint("BOTTOMRIGHT", -1, 1)
  Gradient(shade, "VERTICAL", { 0, 0, 0, 0.45 }, { 0.22, 0.07, 0.34, 0.45 })
  -- slow shadow swirl behind the content (the strip's summoning circle, faint)
  if opts.swirl then
    local d = math.min(f:GetWidth(), f:GetHeight()) * 0.85
    local s = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    s:SetSize(d, d); s:SetPoint("CENTER", 0, -10)
    s:SetTexture("Interface\\Icons\\Spell_Shadow_Twilight"); s:SetBlendMode("ADD"); s:SetAlpha(0.13)
    local m = f:CreateMaskTexture(); m:SetAllPoints(s)
    m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    s:AddMaskTexture(m)
    local turn = s:CreateAnimationGroup(); turn:SetLooping("REPEAT")
    local rot = turn:CreateAnimation("Rotation"); rot:SetDegrees(-360); rot:SetDuration(120)
    turn:Play()
  end
  -- fel aura: soft green halo outside the edge, breathing
  local halo = CreateFrame("Frame", nil, f, "BackdropTemplate")
  halo:SetPoint("TOPLEFT", -4, 4); halo:SetPoint("BOTTOMRIGHT", 4, -4)
  halo:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  halo:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
  halo:SetBackdropBorderColor(A[1], A[2], A[3], 0.8)
  Pulse(halo, 0.25, 0.9, 1.8)
  -- title bar + fel underline
  local bar = f:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("TOPRIGHT", -1, -1); bar:SetHeight(22)
  Gradient(bar, "HORIZONTAL", T.bar, T.barEnd)
  local line = f:CreateTexture(nil, "ARTWORK", nil, 1)
  line:SetPoint("TOPLEFT", bar, "BOTTOMLEFT"); line:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT"); line:SetHeight(1)
  Gradient(line, "HORIZONTAL", { A[1], A[2], A[3], 1 }, { A[1], A[2], A[3], 0.05 })
  -- soul shard with a purple heartbeat
  local icon = f:CreateTexture(nil, "OVERLAY", nil, 2)
  icon:SetSize(16, 16); icon:SetPoint("LEFT", bar, "LEFT", 5, 0)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02"); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local glow = f:CreateTexture(nil, "OVERLAY", nil, 1)
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); glow:SetBlendMode("ADD")
  glow:SetVertexColor(0.7, 0.3, 1); glow:SetSize(36, 36); glow:SetPoint("CENTER", icon)
  Pulse(glow, 0.2, 0.85, 1.2)
  local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("LEFT", icon, "RIGHT", 6, 0); text:SetTextColor(unpack(A)); text:SetText(title)
  text:SetShadowColor(0.3, 0, 0.5, 1); text:SetShadowOffset(1, -1)
  if opts.close then
    local c = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    c:SetSize(24, 24); c:SetPoint("TOPRIGHT", 0, 0)
  end
  -- quick fade-in whenever the window opens
  local fade = f:CreateAnimationGroup()
  local fa = fade:CreateAnimation("Alpha"); fa:SetFromAlpha(0); fa:SetToAlpha(1); fa:SetDuration(0.18)
  f:HookScript("OnShow", function() fade:Play() end)
  f.titleBar, f.titleText = bar, text
  return text
end

-- fel line fading to the right
function WUK.Divider(parent, x, y, width)
  local A = WUK.THEME.accent
  local u = parent:CreateTexture(nil, "ARTWORK")
  u:SetPoint("TOPLEFT", x, y); u:SetSize(width, 1)
  Gradient(u, "HORIZONTAL", { A[1], A[2], A[3], 0.7 }, { A[1], A[2], A[3], 0 })
  return u
end

-- section/column label; width adds a divider under it
function WUK.Header(parent, text, x, y, width)
  local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  h:SetPoint("TOPLEFT", x, y); h:SetTextColor(unpack(WUK.THEME.accent)); h:SetText(text)
  h:SetShadowColor(0, 0, 0, 1); h:SetShadowOffset(1, -1)
  if width then WUK.Divider(parent, x, y - 13, width) end
  return h
end

-- themed push button: void purple, fel edge that lights up on hover
function WUK.Button(parent, label, width, onClick)
  local T, A = WUK.THEME, WUK.THEME.accent
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width, 22)
  b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  b:SetBackdropColor(unpack(T.btn)); b:SetBackdropBorderColor(A[1], A[2], A[3], 0.55)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1); hl:SetBlendMode("ADD")
  Gradient(hl, "VERTICAL", { A[1], A[2], A[3], 0.04 }, { A[1], A[2], A[3], 0.28 })
  b:SetNormalFontObject("GameFontHighlightSmall"); b:SetText(label)
  local fs = b:GetFontString(); fs:SetTextColor(unpack(T.text))
  b:SetPushedTextOffset(1, -1)
  b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.65, 1, 0.45, 1); fs:SetTextColor(1, 1, 1) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(A[1], A[2], A[3], 0.55); fs:SetTextColor(unpack(T.text)) end)
  b:SetScript("OnClick", onClick)
  return b
end

-- free = dialog window: plain drag, ignores the lock, clamped on screen
function WUK.MakeMovable(f, key, x, y, free)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  if free then f:SetClampedToScreen(true) end
  f:SetScript("OnDragStart", function(self)
    if free or (IsShiftKeyDown() and not WUK.db.locked and not InCombatLockdown()) then self:StartMoving() end
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

function WUK.CurrentKeys() return WUK.ViewKeys(WUK.strip.view, WUK.known, WUK.strip.icons) end

-- places core + current view's orbit from strip.radius/angle; out of combat only (secure buttons)
function WUK.LayoutRing()
  local s = WUK.strip
  if InCombatLockdown() then return end
  local cy = LABELS / 2
  s.icons.shard:ClearAllPoints(); s.icons.shard:SetPoint("CENTER", s, "CENTER", 0, cy)
  local keys, on = WUK.CurrentKeys(), {}
  for i, kind in ipairs(keys) do
    on[kind] = true
    local b, x, y = s.icons[kind], WUK.RingPoint(i, #keys, s.radius, s.angle)
    b:ClearAllPoints(); b:SetPoint("CENTER", s, "CENTER", x, y + cy)
    b:SetAlpha(s.radius / R); b:EnableMouse(s.radius > 0)
    if not b:IsShown() then b:Show() end
  end
  for kind, b in pairs(s.icons) do -- only touch buttons whose membership changed
    if kind ~= "shard" and not on[kind] and b:IsShown() then b:Hide() end
  end
  -- collapsed: the core pulses on behalf of hidden alerts
  local any = false
  for _, kind in ipairs(keys) do any = any or s.icons[kind].alerting end
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
  -- collapsed with the mouse away: back to the party ring (targetRadius guard keeps a fresh flip from reverting)
  if s.radius == 0 and s.targetRadius == 0 and s.view ~= "party" then WUK.SetView("party") end
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

local TINT = { party = { 1, 1, 1 }, buff = { 0.5, 0.75, 1 }, demon = { 1, 0.45, 0.45 } }
-- summoning circle per view: rim and disc colours (party = the original purple)
local CIRCLE = {
  party = { rim = { 0.58, 0.51, 0.79, 0.55 }, disc = { 0.04, 0, 0.07, 0.7 } },
  buff = { rim = { 0.35, 0.55, 0.95, 0.55 }, disc = { 0, 0.03, 0.08, 0.7 } },
  demon = { rim = { 0.85, 0.3, 0.3, 0.55 }, disc = { 0.08, 0, 0.01, 0.7 } },
}
local function PaintCircle(s, view)
  local c = CIRCLE[view] or CIRCLE.party
  s.rim:SetColorTexture(unpack(c.rim)); s.disc:SetColorTexture(unpack(c.disc))
end
-- swap the orbit set around the shard core; ring re-blooms from 0 as the "flip"
function WUK.SetView(view)
  local s = WUK.strip
  if InCombatLockdown() or s.view == view then return end
  s.view = view
  s.radius = 0
  local t = TINT[view] or TINT.party
  local b = s.icons.shard
  b.icon:SetVertexColor(t[1], t[2], t[3])
  PaintCircle(s, view)
  WUK.LayoutRing(); WUK.Animate()
  if GameTooltip:IsOwned(b) then b:GetScript("OnEnter")(b) end -- refresh the next-view hint
end

-- PLAYER_REGEN_DISABLED fires before lockdown: last chance to move secure buttons
function WUK.CombatFreeze()
  WUK.SetView("party")
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

-- spell tooltip by name; plain name line when the client gives no ID
function WUK.SpellTooltip(name)
  if not name then return end
  local info = C_Spell.GetSpellInfo(name)
  if info and info.spellID then GameTooltip:SetSpellByID(info.spellID) else GameTooltip:AddLine(name) end
end

-- fill(b) adds the lines; same OnEnter/OnLeave shape as the minimap button (Settings.lua)
function WUK.AttachTooltip(b, fill)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); fill(self); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
end

-- held stone: the bag item; none held: the create spell (or the kind's name if not learned)
local function StoneTooltip(kind)
  local slot = WUK.counts.slots[kind]
  if slot then GameTooltip:SetBagItem(slot[1], slot[2])
  elseif kind == "shard" then GameTooltip:AddLine("Soul Shards: 0")
  elseif WUK.known[kind] then WUK.SpellTooltip(WUK.known[kind])
  else GameTooltip:AddLine((kind:gsub("^%l", string.upper))) end
  if kind == "healthstone" then GameTooltip:AddLine("Right-click: trade to target", 1, 1, 1) end
  if kind == "shard" then
    local nv = WUK.NextView(WUK.strip.view)
    GameTooltip:AddLine("Click: " .. nv:gsub("^%l", string.upper) .. " view", 1, 1, 1)
  end
end

table.insert(WUK.inits, function()
  local f = CreateFrame("Frame", "WUKStrip", UIParent)
  -- ring of 6 orbit buttons around the shard core; soulstone + assignment lines underneath
  local SIZE = 2 * (R + BTN / 2) + 8
  f:SetSize(SIZE, SIZE + LABELS)
  f.angle, f.radius, f.targetRadius = 0, R, R
  f.view = "party"
  -- summoning circle instead of a box: purple rim, dark disc, shadow swirl turning against the spin
  f.rim = Disc(f, "BACKGROUND", 0); f.disc = Disc(f, "BACKGROUND", 1)
  PaintCircle(f, "party")
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
    -- healthstone: right-click is the trade hook, so the macro binds button 1 only
    b:SetAttribute(kind == "healthstone" and "type1" or "type", "macro")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
    local sh = b.icon:CreateAnimationGroup() -- one-shot pop when a stone becomes available
    local up = sh:CreateAnimation("Scale"); up:SetScale(1.3, 1.3); up:SetDuration(0.15); up:SetOrder(1)
    local down = sh:CreateAnimation("Scale"); down:SetScale(1 / 1.3, 1 / 1.3); down:SetDuration(0.2); down:SetOrder(2)
    b.shine = sh
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    f.icons[kind] = b
    WUK.AttachTooltip(b, function() StoneTooltip(kind) end)
    if kind == "healthstone" then
      b:HookScript("OnClick", function(_, button, down)
        if button == "RightButton" and not down then WUK.TradeHealthstone() end
      end)
    end
    if kind == "shard" then -- the core has no macro (StoneMacro: nil), so any click flips the view
      b:HookScript("OnClick", function(_, _, down)
        if not down then WUK.SetView(WUK.NextView(WUK.strip.view)) end
      end)
    end
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
