local ADDON, WUK = ...

local KINDS = { "shard", "healthstone", "soulstone", "spellstone", "firestone" }
-- fallback textures for kinds never seen in bags (no item ID to ask the client)
local FALLBACK = {
  shard = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02", healthstone = "Interface\\Icons\\INV_Stone_04",
  soulstone = "Interface\\Icons\\Spell_Shadow_SoulGem", spellstone = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
  firestone = "Interface\\Icons\\INV_Ammo_FireTar",
}

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
  -- prep + pet + 5 stone buttons, 36px each with 4px gaps; soulstone line underneath
  f:SetSize(4 + 7 * 40, 76)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  f:SetBackdropColor(0, 0, 0, 0.6); f:SetBackdropBorderColor(0.58, 0.51, 0.79, 1)
  f.icons = {}
  for i, kind in ipairs(KINDS) do
    local b = CreateFrame("Button", "WUKStone_" .. kind, f, "SecureActionButtonTemplate")
    b:SetSize(36, 36); b:SetPoint("TOPLEFT", 4 + (i + 1) * 40, -4)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    f.icons[kind] = b
  end
  f.stone = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.stone:SetPoint("BOTTOMLEFT", 6, 20)
  f.assign = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.assign:SetPoint("BOTTOMLEFT", 6, 6)
  WUK.strip = f
  WUK.MakeMovable(f, "strip", 0, -220)
  WUK.ApplyShown()
end)

table.insert(WUK.refreshers, function()
  local c = WUK.counts
  for _, kind in ipairs(KINDS) do
    local b, id = WUK.strip.icons[kind], c.ids[kind]
    local icon = id and C_Item.GetItemIconByID(id)
    if icon then WUK.db.icons[kind] = icon end -- keep the real icon once the last stone is used
    b.icon:SetTexture(WUK.db.icons[kind] or FALLBACK[kind])
    b.icon:SetDesaturated(c[kind] == 0)
    b.count:SetText(c[kind])
    if not InCombatLockdown() then
      local ss = kind == "soulstone" and WUK.MySoulstoneTarget and WUK.MySoulstoneTarget() or nil
      b:SetAttribute("macrotext", WUK.StoneMacro(kind, c[kind], id, WUK.known[kind], ss) or "")
    end
  end
end)
