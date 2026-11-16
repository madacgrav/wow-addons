local ADDON, WCK = ...
-- rotation bar: one fixed-spell secure button per rule spell, then Fear/Banish. The spell set changes only out
-- of combat (secure attributes); highlights are plain textures, so they redraw in combat.
-- Own UIParent frame, never anchored to WCKPanel: protected children would lock the panel's resize in combat.
local SIZE, GAP, EGAP, PAD = 32, 4, 8, 6
local bar, buttons = nil, {}

table.insert(WCK.inits, function()
  bar = CreateFrame("Frame", "WCKRotationBar", UIParent)
  bar:SetSize(SIZE + PAD * 2, SIZE + PAD * 2); bar:SetFrameStrata("MEDIUM")
  local bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.03, 0, 0.06, 0.6)
  WCK.MakeMovable(bar, "bar", 260, -60) -- Shift+drag on the padding, out of combat only
  for i = 1, WCK.BAR_MAX do
    local b = CreateFrame("Button", "WCKRotation" .. i, bar, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE); b:RegisterForClicks("AnyUp", "AnyDown"); b:SetAttribute("type", "macro")
    b.rim = b:CreateTexture(nil, "BACKGROUND"); b.rim:SetPoint("CENTER"); b.rim:SetSize(SIZE + 4, SIZE + 4)
    b.rim:SetColorTexture(0.58, 0.51, 0.79, 0.8); WCK.Round(b, b.rim)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); WCK.Round(b, b.icon)
    WCK.AddGlow(b)
    b:SetScript("OnEnter", function(self)
      if not self.spell then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(self.spell); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:Hide(); buttons[i] = b
  end
end)

-- secure part: out of combat only; PLAYER_REGEN_ENABLED -> Refresh applies rule edits made in combat
table.insert(WCK.refreshers, function()
  if InCombatLockdown() or not bar then return end
  local list = WCK.BarSpells(WCK.char.rules, WCK.DATA.emergency, WCK.spellSet)
  local x = PAD
  for i, b in ipairs(buttons) do
    local e = list[i]
    if e then
      if e.emergency and i > 1 and not list[i - 1].emergency then x = x + EGAP end
      b.spell = e.spell
      b:SetAttribute("macrotext", WCK.CastMacro(e.spell))
      b.icon:SetTexture(C_Spell.GetSpellTexture(e.spell) or 134400) -- 134400 = question mark
      b:ClearAllPoints(); b:SetPoint("LEFT", bar, "LEFT", x, 0); b:Show()
      x = x + SIZE + GAP
    else
      b.spell = nil; b:Hide()
    end
  end
  bar:SetWidth(math.max(x - GAP + PAD, SIZE + PAD * 2))
  bar:SetShown(WCK.db.shown and WCK.db.showBar and #list > 0)
end)

-- highlights: every refresh, in combat too (textures only)
table.insert(WCK.refreshers, function()
  for _, b in ipairs(buttons) do WCK.SetAlert(b, b.spell ~= nil and b.spell == WCK.next) end
end)
