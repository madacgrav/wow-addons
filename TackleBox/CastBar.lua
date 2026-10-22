local ADDON, TB = ...
local bar, flash
local T = TB.THEME

table.insert(TB.inits, function()
  -- rope-framed holder; the line drains from right to left with a bobber riding its end
  local holder = CreateFrame("Frame", "TBCastBar", UIParent, "BackdropTemplate")
  holder:SetSize(220, 24); TB.Skin(holder, 12); holder:Hide()
  bar = CreateFrame("StatusBar", nil, holder)
  bar:SetPoint("TOPLEFT", 5, -5); bar:SetPoint("BOTTOMRIGHT", -5, 5); bar:SetMinMaxValues(0, 1)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetStatusBarColor(T.line[1], T.line[2], T.line[3])
  local fill = bar:GetStatusBarTexture()
  fill:SetGradient("HORIZONTAL", CreateColor(0.05, 0.3, 0.5, 1), CreateColor(T.line[1], T.line[2] + 0.15, T.line[3] + 0.15, 1))
  local bob = bar:CreateTexture(nil, "OVERLAY"); bob:SetSize(14, 14); bob:SetPoint("CENTER", fill, "RIGHT", 0, 0)
  bob:SetTexture("Interface\\Icons\\INV_Misc_Fish_02"); bob:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local mask = bar:CreateMaskTexture()
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(bob); bob:AddMaskTexture(mask)
  bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); bar.label:SetPoint("LEFT", 4, 0)
  bar.label:SetText("Line in the water"); bar.label:SetTextColor(T.foam[1], T.foam[2], T.foam[3])
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); bar.text:SetPoint("RIGHT", -4, 0)
  bar.holder = holder

  -- blue screen-edge vignette; mouse-transparent so it never blocks a click
  flash = CreateFrame("Frame", "TBFlash", UIParent)
  flash:SetAllPoints(UIParent); flash:SetFrameStrata("FULLSCREEN_DIALOG"); flash:EnableMouse(false)
  local t = flash:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints()
  -- LowHealth art is red; desaturate first or the tint multiplies into red
  t:SetTexture("Interface\\FullScreenTextures\\LowHealth"); t:SetDesaturated(true); t:SetBlendMode("ADD"); t:SetVertexColor(0.3, 0.6, 1)
  flash:SetAlpha(0); flash:Show()
  local ag = flash:CreateAnimationGroup()
  local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(0.8); a1:SetDuration(0.15); a1:SetOrder(1)
  local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(0.8); a2:SetToAlpha(0); a2:SetDuration(0.6); a2:SetOrder(2)
  flash.anim = ag
end)

-- docked under the TackleBox panel; centered low on screen while the panel is hidden
function TB.StartCastBar(st, et)
  local h = bar.holder
  h:ClearAllPoints()
  if TBPanel and TBPanel:IsShown() then
    h:SetPoint("TOPLEFT", TBPanel, "BOTTOMLEFT", 0, 2); h:SetPoint("TOPRIGHT", TBPanel, "BOTTOMRIGHT", 0, 2)
  else
    h:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
  end
  h:Show()
  bar:SetScript("OnUpdate", function(self)
    local f, left = TB.CastProgress(st, et, GetTime() * 1000)
    if not f then return end
    self:SetValue(1 - f); self.text:SetText(string.format("%.0fs", left))
  end)
end
function TB.StopCastBar() bar:SetScript("OnUpdate", nil); bar.holder:Hide() end
function TB.Flash() flash.anim:Stop(); flash.anim:Play() end
