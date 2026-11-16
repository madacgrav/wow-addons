local ADDON, WCK = ...
-- rotation bar: one fixed-spell secure button per rule spell, then Shadow Bolt/Fear/Banish, docked to the right of the
-- summoning circle, whose core is a secure Life Tap button. The spell set changes only out of combat (secure
-- attributes); highlights are plain textures, so they redraw in combat.
-- Anchoring: the panel hangs off the secure Life Tap button, never the reverse. A protected frame anchored TO the
-- panel would block the panel's per-render resize in combat; an insecure panel anchored to a secure frame is fine.
local SIZE, GAP, EGAP, PAD = 32, 4, 8, 6
local bar, bg, core, buttons = nil, nil, nil, {}

table.insert(WCK.inits, function()
  local g, panel = WCK.PANEL_GEOM, WCK.panel
  bar = CreateFrame("Frame", "WCKRotationBar", UIParent)
  bar:SetSize(SIZE + PAD * 2, SIZE + PAD * 2); bar:SetFrameStrata("MEDIUM")
  bar:SetFrameLevel(panel:GetFrameLevel() + 5) -- above the circle so the Life Tap button takes the click
  bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.03, 0, 0.06, 0.6)

  -- the circle's core: Life Tap, clickable; sits left of the strip
  core = CreateFrame("Button", "WCKCoreCast", bar, "SecureActionButtonTemplate")
  core:SetSize(g.core, g.core); core:SetPoint("CENTER", bar, "LEFT", -(g.circle / 2 + 6), 0)
  core:RegisterForClicks("AnyUp", "AnyDown"); core:SetAttribute("type", "macro")
  core:SetAttribute("macrotext", "/cast " .. WCK.DATA.core) -- self spell: no mouseover targeting
  WCK.AddGlow(core)
  core:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(WCK.DATA.core .. " (click to cast)")
    GameTooltip:AddLine(WCK.next and ("Suggested: " .. WCK.next) or "No rule matches", 0.88, 0.71, 1)
    GameTooltip:AddLine("Rules: /wck config", 1, 1, 1)
    GameTooltip:Show()
  end)
  core:SetScript("OnLeave", GameTooltip_Hide)

  -- the panel hangs off the core: circle centre on the Life Tap button; Shift+drag on the panel moves the whole kit
  panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", core, "CENTER", -g.cx, -g.cy)
  WCK.MakeMovable(bar, "bar", 360, -120, { panel }) -- out of combat only

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
  local list = WCK.db.showBar and WCK.BarSpells(WCK.char.rules, WCK.DATA.tail, WCK.spellSet, WCK.DATA.core) or {}
  local x = PAD
  for i, b in ipairs(buttons) do
    local e = list[i]
    if e then
      if e.tail and i > 1 and not list[i - 1].tail then x = x + EGAP end
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
  bg:SetShown(#list > 0)
  bar:SetShown(WCK.db.shown) -- the core button lives on the bar, so the bar shows with the panel
end)

-- highlights: every refresh, in combat too (textures only)
table.insert(WCK.refreshers, function()
  if not core then return end
  WCK.SetAlert(core, WCK.next == WCK.DATA.core)
  for _, b in ipairs(buttons) do WCK.SetAlert(b, b.spell ~= nil and b.spell == WCK.next) end
end)
