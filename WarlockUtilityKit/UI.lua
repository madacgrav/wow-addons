local ADDON, WUK = ...

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

table.insert(WUK.inits, function()
  local f = CreateFrame("Frame", "WUKStrip", UIParent, "BackdropTemplate")
  f:SetSize(300, 44)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  f:SetBackdropColor(0, 0, 0, 0.6); f:SetBackdropBorderColor(0.58, 0.51, 0.79, 1)
  f.counts = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.counts:SetPoint("TOPLEFT", 48, -8)
  f.stone = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.stone:SetPoint("TOPLEFT", f.counts, "BOTTOMLEFT", 0, -4)
  WUK.strip = f
  WUK.MakeMovable(f, "strip", 0, -220)
  WUK.ApplyShown()
end)

table.insert(WUK.refreshers, function()
  local c = WUK.counts
  WUK.strip.counts:SetText(string.format("Shards %d  HS %d  SS %d  Spell %d  Fire %d",
    c.shard, c.healthstone, c.soulstone, c.spellstone, c.firestone))
end)
