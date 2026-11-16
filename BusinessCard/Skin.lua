local ADDON, BC = ...
local T = BC.THEME

local EDGES = {
  dialog = { bg = "Interface\\FrameGeneral\\UI-Background-Rock", edge = "Interface\\DialogFrame\\UI-DialogBox-Border", size = 24, inset = 6 },
  tooltip = { bg = "Interface\\Buttons\\WHITE8x8", edge = "Interface\\Tooltips\\UI-Tooltip-Border", size = 12, inset = 3 },
}
-- f must inherit BackdropTemplate
function BC.Skin(f, kind, bg)
  local e = EDGES[kind or "dialog"]
  f:SetBackdrop({ bgFile = e.bg, edgeFile = e.edge, edgeSize = e.size, tile = true, tileSize = 256,
    insets = { left = e.inset, right = e.inset, top = e.inset, bottom = e.inset } })
  local c = bg or T.ink
  f:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
  f:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3])
end

function BC.Parchment(f, alpha, inset) -- ForeverDungeonJournal AddClassicParchment
  local i = inset or 6
  local t = f:CreateTexture(nil, "BACKGROUND", nil, -2)
  t:SetTexture("Interface\\QuestFrame\\QuestBG")
  t:SetPoint("TOPLEFT", i, -i); t:SetPoint("BOTTOMRIGHT", -i, i)
  t:SetVertexColor(T.parchment[1], T.parchment[2], T.parchment[3]); t:SetAlpha(alpha or 0.15)
  return t
end

function BC.Rule(parent, y, x1, x2) -- 1px gold line; y from parent TOP
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 0.8); t:SetHeight(1)
  t:SetPoint("TOPLEFT", x1 or 12, y); t:SetPoint("TOPRIGHT", -(x2 or 12), y)
  return t
end

function BC.Fade(t, dir, c, a1, a2) -- TackleBox Panel.lua:51-54
  t:SetColorTexture(1, 1, 1, 1)
  t:SetGradient(dir, CreateColor(c[1], c[2], c[3], a1), CreateColor(c[1], c[2], c[3], a2))
end

function BC.Dot(parent, size, layer) -- round masked texture (WCK Panel.lua:75-80)
  local t = parent:CreateTexture(nil, layer or "ARTWORK"); t:SetSize(size, size); t:SetTexture("Interface\\Buttons\\WHITE8x8")
  local m = parent:CreateMaskTexture(); m:SetAllPoints(t)
  m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  t:AddMaskTexture(m)
  return t
end

function BC.Spin(t, seconds) -- WCK Panel.lua:88-92
  local g = t:CreateAnimationGroup(); g:SetLooping("REPEAT")
  local r = g:CreateAnimation("Rotation"); r:SetDegrees(-360); r:SetDuration(seconds or 1.2)
  return g
end

function BC.TitleFont(fs, size)
  if not fs:SetFont("Fonts\\MORPHEUS.ttf", size or 20, "") then fs:SetFontObject("GameFontNormalLarge") end
  fs:SetTextColor(T.goldBright[1], T.goldBright[2], T.goldBright[3]); fs:SetShadowOffset(1, -1)
end
