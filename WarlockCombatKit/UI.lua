local _, WCK = ...

-- warlock window theme: void purple body, fel-green edge + accents, purple title bar (strip palette, UI rim/disc)
local WHITE = "Interface\\Buttons\\WHITE8x8"
WCK.THEME = {
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

-- f must inherit BackdropTemplate and already be sized; opts = { close }; returns the title FontString
function WCK.Skin(f, title, opts)
  local T, A = WCK.THEME, WCK.THEME.accent
  opts = opts or {}
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(unpack(T.bg)); f:SetBackdropBorderColor(unpack(T.edge))
  -- depth: purple haze at the top fading into the void
  local shade = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  shade:SetPoint("TOPLEFT", 1, -1); shade:SetPoint("BOTTOMRIGHT", -1, 1)
  Gradient(shade, "VERTICAL", { 0, 0, 0, 0.45 }, { 0.22, 0.07, 0.34, 0.45 })
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
function WCK.Divider(parent, x, y, width)
  local A = WCK.THEME.accent
  local u = parent:CreateTexture(nil, "ARTWORK")
  u:SetPoint("TOPLEFT", x, y); u:SetSize(width, 1)
  Gradient(u, "HORIZONTAL", { A[1], A[2], A[3], 0.7 }, { A[1], A[2], A[3], 0 })
  return u
end

-- section/column label; width adds a divider under it
function WCK.Header(parent, text, x, y, width)
  local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  h:SetPoint("TOPLEFT", x, y); h:SetTextColor(unpack(WCK.THEME.accent)); h:SetText(text)
  h:SetShadowColor(0, 0, 0, 1); h:SetShadowOffset(1, -1)
  if width then WCK.Divider(parent, x, y - 13, width) end
  return h
end

-- themed push button: void purple, fel edge that lights up on hover
function WCK.Button(parent, label, width, onClick)
  local T, A = WCK.THEME, WCK.THEME.accent
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

-- dialog window: plain drag (ignores the panel lock), clamped on screen, position saved in db.frames[key]
-- (not MakeMovable: Panel.lua owns that name for the Shift+drag panel/bar)
function WCK.MakeDialogMovable(f, key, x, y)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, px, py = self:GetPoint()
    WCK.db.frames[key] = { p, rp, px, py }
  end)
  local pos = WCK.db.frames[key]
  f:ClearAllPoints()
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", UIParent, "CENTER", x, y) end
end

-- fill(self) adds lines; hooks so template/Button hover visuals keep working
function WCK.AttachTooltip(b, fill)
  b:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); fill(self); GameTooltip:Show()
  end)
  b:HookScript("OnLeave", GameTooltip_Hide)
end

-- one-line tooltip shorthand
function WCK.Tip(b, title, line)
  WCK.AttachTooltip(b, function()
    GameTooltip:AddLine(title)
    if line then GameTooltip:AddLine(line, 1, 1, 1, true) end
  end)
end

-- built-in art; set an entry to nil to fall back to the glyph if it renders blank/green on Forever
local ICONS = {
  up = "Interface\\Buttons\\Arrow-Up-Up", down = "Interface\\Buttons\\Arrow-Down-Up",
  remove = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
local GLYPH = { up = "^", down = "v", remove = "x" }

function WCK.SpellIcon(name)
  if not (name and C_Spell and C_Spell.GetSpellTexture) then return nil end
  local ok, tex = pcall(C_Spell.GetSpellTexture, name)
  return ok and tex or nil
end

-- kind = "up" | "down" | "remove"; dims when disabled
function WCK.IconButton(parent, kind, size, title, line, onClick)
  local b
  if ICONS[kind] then
    b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexture(ICONS[kind])
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints()
    hl:SetColorTexture(unpack(WCK.THEME.accent)); hl:SetAlpha(0.25)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnable", function(self) self.icon:SetDesaturated(false); self:SetAlpha(1) end)
    b:SetScript("OnDisable", function(self) self.icon:SetDesaturated(true); self:SetAlpha(0.35) end)
  else
    b = WCK.Button(parent, GLYPH[kind], size, onClick); b:SetHeight(size)
    b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    b:SetScript("OnDisable", function(self) self:SetAlpha(0.35) end)
  end
  WCK.Tip(b, title, line)
  return b
end
