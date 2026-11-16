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

function BC.Breathe(t) -- WCK Panel.lua:94-98
  local g = t:CreateAnimationGroup(); g:SetLooping("BOUNCE")
  local a = g:CreateAnimation("Alpha"); a:SetFromAlpha(0.55); a:SetToAlpha(1); a:SetDuration(1.2); a:SetSmoothing("IN_OUT")
  return g
end

function BC.Flash(t) -- TackleBox CastBar.lua:31-33
  local g = t:CreateAnimationGroup()
  local a = g:CreateAnimation("Alpha"); a:SetFromAlpha(0); a:SetToAlpha(0.6); a:SetDuration(0.2); a:SetOrder(1)
  local b = g:CreateAnimation("Alpha"); b:SetFromAlpha(0.6); b:SetToAlpha(0); b:SetDuration(0.6); b:SetOrder(2)
  g:SetScript("OnFinished", function() t:SetAlpha(0) end)
  return g
end

function BC.Pop(f) -- WCK Panel.lua:100-105
  if not f.pop then
    local g = f:CreateAnimationGroup()
    local up = g:CreateAnimation("Scale"); up:SetScaleFrom(1, 1); up:SetScaleTo(1.25, 1.25); up:SetDuration(0.12); up:SetOrder(1)
    local dn = g:CreateAnimation("Scale"); dn:SetScaleFrom(1.25, 1.25); dn:SetScaleTo(1, 1); dn:SetDuration(0.18); dn:SetOrder(2)
    f.pop = g
  end
  f.pop:Stop(); f.pop:Play()
end

-- one gold beam swept across f (ForeverDungeonJournal RPGMode.lua:656-685: Translation inside a clipping frame)
function BC.Sheen(f)
  local clip = CreateFrame("Frame", nil, f); clip:SetAllPoints(); clip:SetClipsChildren(true)
  clip:SetFrameLevel(f:GetFrameLevel() + 5)
  local L = clip:CreateTexture(nil, "OVERLAY"); L:SetSize(40, 400); L:SetPoint("RIGHT", clip, "LEFT", 0, 0)
  BC.Fade(L, "HORIZONTAL", T.goldBright, 0, 0.35); L:SetBlendMode("ADD"); L:SetRotation(math.rad(-20))
  local R = clip:CreateTexture(nil, "OVERLAY"); R:SetSize(40, 400); R:SetPoint("LEFT", L, "RIGHT")
  BC.Fade(R, "HORIZONTAL", T.goldBright, 0.35, 0); R:SetBlendMode("ADD"); R:SetRotation(math.rad(-20))
  L:Hide(); R:Hide()
  local groups = {}
  for i, t in ipairs({ L, R }) do
    local g = t:CreateAnimationGroup(); local m = g:CreateAnimation("Translation"); m:SetDuration(0.9); m:SetSmoothing("IN_OUT")
    g:SetScript("OnFinished", function() t:Hide() end); groups[i] = { g = g, m = m, t = t }
  end
  return { Play = function()
    for _, x in ipairs(groups) do x.m:SetOffset(f:GetWidth() + 120, 0); x.t:Show(); x.g:Stop(); x.g:Play() end
  end }
end

-- border brightens while the mouse is anywhere over f (children included); restore(f) puts it back
function BC.HoverGlow(f, restore)
  f:HookScript("OnEnter", function(self)
    self:SetBackdropBorderColor(T.goldBright[1], T.goldBright[2], T.goldBright[3])
    self:SetScript("OnUpdate", function(s) if not s:IsMouseOver() then s:SetScript("OnUpdate", nil); restore(s) end end)
  end)
end

function BC.TitleFont(fs, size)
  if not fs:SetFont("Fonts\\MORPHEUS.ttf", size or 20, "") then fs:SetFontObject("GameFontNormalLarge") end
  fs:SetTextColor(T.goldBright[1], T.goldBright[2], T.goldBright[3]); fs:SetShadowOffset(1, -1)
end
