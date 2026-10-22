local ADDON, TB = ...
local bar, flash

table.insert(TB.inits, function()
  bar = CreateFrame("StatusBar", "TBCastBar", UIParent)
  bar:SetSize(200, 14); bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetStatusBarColor(0.25, 0.65, 0.9)
  bar:SetMinMaxValues(0, 1)
  local bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.5)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); bar.text:SetPoint("CENTER")
  TB.MakeMovable(bar, "castbar", 0, -180)
  bar:Hide()

  -- blue screen-edge vignette; mouse-transparent so it never blocks a click
  flash = CreateFrame("Frame", "TBFlash", UIParent)
  flash:SetAllPoints(UIParent); flash:SetFrameStrata("FULLSCREEN_DIALOG"); flash:EnableMouse(false)
  local t = flash:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints()
  t:SetTexture("Interface\\FullScreenTextures\\LowHealth"); t:SetBlendMode("ADD"); t:SetVertexColor(0.3, 0.6, 1)
  flash:SetAlpha(0); flash:Show()
  local ag = flash:CreateAnimationGroup()
  local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(0.8); a1:SetDuration(0.15); a1:SetOrder(1)
  local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(0.8); a2:SetToAlpha(0); a2:SetDuration(0.6); a2:SetOrder(2)
  flash.anim = ag
end)

function TB.StartCastBar(st, et)
  bar:Show()
  bar:SetScript("OnUpdate", function(self)
    local f, left = TB.CastProgress(st, et, GetTime() * 1000)
    if not f then return end
    self:SetValue(1 - f); self.text:SetText(string.format("%.0fs", left))
  end)
end
function TB.StopCastBar() bar:SetScript("OnUpdate", nil); bar:Hide() end
function TB.Flash() flash.anim:Stop(); flash.anim:Play() end
