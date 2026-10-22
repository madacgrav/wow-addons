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
  f.rows = {}
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, f); r:SetSize(WIDTH - 16, ROW_H)
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
  local view = WCK.RowsView(WCK.map, GetTime(), WCK.DATA.tracked)
  for i, r in ipairs(f.rows) do
    local v = view[i]
    if v then
      r.label:SetText(v.label or (v.key == "target" and "Target" or "?"))
      for j, t in ipairs(r.icons) do
        local icon = v.icons[j]
        if icon then t:SetTexture(C_Spell.GetSpellTexture(icon.spell)); t:SetAlpha(icon.alpha); t:Show() else t:Hide() end
      end
      r:Show()
    else
      r:Hide()
    end
  end
  f:SetHeight(CORE + 20 + math.max(math.min(#view, MAX_ROWS), 1) * (ROW_H + 2))
end
table.insert(WCK.refreshers, WCK.RenderPanel)
