local ADDON, TB = ...
-- Fishing action bar: equip pole, apply lure, water-walk, cast. Every button is player-clicked; nothing fires on its own.
-- Secure buttons live on their own UIParent frame: a secure child (or anchor) would make the panel protected in combat.

local ORDER = { "pole", "lure", "water", "cast" }
local TIPS = { pole = "Equip fishing pole", lure = "Apply lure to your pole", water = "Use water-walking", cast = "Cast your line" }
local bar, buttons = nil, {}
TB.actions = {} -- key -> {item=id} | {spell=name} | nil; the panel's Water tab reads TB.actions.water

local function MakeButton(key)
  local T = TB.THEME
  local b = CreateFrame("Button", "TBAction_" .. key, bar, "SecureActionButtonTemplate")
  b:SetSize(40, 40); b:RegisterForClicks("AnyUp", "AnyDown")
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 3, -3); b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local rim = b:CreateTexture(nil, "OVERLAY"); rim:SetAllPoints()
  rim:SetTexture("Interface\\Buttons\\UI-Quickslot2"); rim:SetTexCoord(0.2, 0.8, 0.2, 0.8); rim:SetVertexColor(T.rope[1], T.rope[2], T.rope[3])
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal"); b.count:SetPoint("BOTTOMRIGHT", -3, 3)
  -- slow ripple so the bar reads as water
  local ripple = b:CreateTexture(nil, "BACKGROUND"); ripple:SetPoint("CENTER"); ripple:SetSize(64, 64)
  ripple:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); ripple:SetBlendMode("ADD"); ripple:SetVertexColor(T.line[1], T.line[2], T.line[3])
  local ag = ripple:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.1); a:SetToAlpha(0.6); a:SetDuration(1.2)
  ag:Play()
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if self.itemID then GameTooltip:SetItemByID(self.itemID) else GameTooltip:AddLine(TIPS[key], T.sand[1], T.sand[2], T.sand[3]) end
    GameTooltip:AddLine(TIPS[key], 1, 1, 1); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:Hide()
  return b
end

table.insert(TB.inits, function()
  bar = CreateFrame("Frame", "TBActionBar", UIParent, "BackdropTemplate")
  bar:SetSize(52, 52); TB.Skin(bar, 12)
  -- vertical strip on the panel's left side, hung off the shared dock (see TB.Dock)
  bar:SetPoint("TOPRIGHT", TB.Dock(), "TOPLEFT", 2, 0); TB.DockDrag(bar)
  for _, key in ipairs(ORDER) do buttons[key] = MakeButton(key) end
end)

-- attributes, visibility and layout only out of combat; PLAYER_REGEN_ENABLED -> Refresh re-applies
local function Apply()
  if not bar or InCombatLockdown() then return end
  local y = 6
  for _, key in ipairs(ORDER) do
    local b, a = buttons[key], TB.actions[key]
    if a then
      if key == "pole" then
        b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", "/equip item:" .. a.item)
      elseif key == "lure" then
        -- use the lure, then put it on the main-hand slot (16 = the equipped pole)
        b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", "/use item:" .. a.item .. "\n/use 16")
      elseif key == "water" then
        b:SetAttribute("type", "item"); b:SetAttribute("item", "item:" .. a.item)
      else
        b:SetAttribute("type", "spell"); b:SetAttribute("spell", a.spell)
      end
      b.itemID = a.item
      b.icon:SetTexture(a.item and C_Item.GetItemIconByID(a.item) or a.icon)
      b.count:SetText(a.item and key ~= "pole" and C_Item.GetItemCount(a.item) or "")
      b:ClearAllPoints(); b:SetPoint("TOP", bar, "TOP", 0, -y); b:Show()
      y = y + 44
    else
      b:Hide()
    end
  end
  bar:SetHeight(math.max(52, y + 2))
  bar:SetShown(y > 6 and TB.db.shown) -- only with the panel open; a combat close hides it once combat ends
end

local function BagItems()
  local items = {}
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local id = C_Container.GetContainerItemID(bag, slot)
      if id then
        local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
        items[#items + 1] = { id = id, classID = classID, subID = subID }
      end
    end
  end
  return items
end

local function PoleEquipped()
  local id = GetInventoryItemID("player", 16)
  if not id then return false end
  local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
  return classID == 2 and subID == 20
end

table.insert(TB.refreshers, function()
  local A, poleOn = {}, PoleEquipped()
  if not poleOn then
    local pole = TB.PickPole(BagItems())
    if pole then A.pole = { item = pole } end
  else
    local counts = {}
    for _, l in ipairs(TB.DATA.lures) do counts[l.id] = C_Item.GetItemCount(l.id) end
    local lure = TB.PickLure(TB.DATA.lures, counts, (GetWeaponEnchantInfo())) -- 1st return: main hand has a temp enchant
    if lure then A.lure = { item = lure } end
  end

  local ww, wcounts, active = TB.DATA.waterWalk, {}, false
  for _, id in ipairs(ww.items) do wcounts[id] = C_Item.GetItemCount(id) + (C_Item.IsEquippedItem(id) and 1 or 0) end
  for _, sid in ipairs(ww.auras) do if TB.ReadAura(sid).active then active = true end end
  local water = TB.WaterWalkPick(ww.items, wcounts, active)
  if water then A.water = { item = water } end
  TB.waterActive = active

  if TB.skill then
    local s = C_Spell.GetSpellInfo(7620) -- probe run 1: Fishing = 7620
    if s then A.cast = { spell = s.name, icon = s.iconID } end
  end
  TB.actions = A
  Apply()
end)
