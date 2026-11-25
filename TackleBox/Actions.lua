local ADDON, TB = ...
-- Fishing action bar: equip pole, apply lure, water-walk, cast. Every button is player-clicked; nothing fires on its own.
-- Secure buttons live on their own UIParent frame: a secure child (or anchor) would make the panel protected in combat.

local ORDER = { "pole", "lure", "water", "camp", "cast" }
local TIPS = { pole = "Equip fishing pole", lure = "Apply lure to your pole", water = "Use water-walking", camp = "Set up your fishing camp", cast = "Cast your line" }
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
  if key == "camp" then
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate"); b.cd:SetAllPoints(b.icon)
    b.badge = b:CreateTexture(nil, "OVERLAY", nil, 2); b.badge:SetSize(14, 14); b.badge:SetPoint("BOTTOMLEFT", 3, 3)
    b.badge:SetTexture("Interface\\Icons\\Trade_BlackSmithing"); b.badge:Hide() -- marks "craft" vs "place"
  end
  -- slow ripple so the bar reads as water
  local ripple = b:CreateTexture(nil, "BACKGROUND"); ripple:SetPoint("CENTER"); ripple:SetSize(64, 64)
  ripple:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); ripple:SetBlendMode("ADD"); ripple:SetVertexColor(T.line[1], T.line[2], T.line[3])
  local ag = ripple:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.1); a:SetToAlpha(0.6); a:SetDuration(1.2)
  ag:Play()
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local tip = self.tip or TIPS[key]
    if self.itemID then GameTooltip:SetItemByID(self.itemID) else GameTooltip:AddLine(tip, T.sand[1], T.sand[2], T.sand[3]) end
    if self.need then GameTooltip:AddLine(self.need, 1, 0.3, 0.3) else GameTooltip:AddLine(tip, 1, 1, 1) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:Hide()
  return b
end

-- one-key cast: the key clicks TBCastKey; while the line is out the same key is INTERACTTARGET (reels in the bobber)
local owner = CreateFrame("Frame")
local caster -- made in the init below; secure, shown, 1x1, invisible
local REEL_CVARS = { SoftTargetInteract = "3", SoftTargetInteractRange = "60" } -- ponytail: 60 = BetterFishing's value; Forever max unknown
function TB.HasBindAPI() return SetOverrideBinding ~= nil and SetOverrideBindingClick ~= nil and ClearOverrideBindings ~= nil end

function TB.BindCast()
  if InCombatLockdown() or not TB.HasBindAPI() then return end
  ClearOverrideBindings(owner)
  if TB.db.castKey then SetOverrideBindingClick(owner, true, TB.db.castKey, "TBCastKey") end
end

function TB.RestoreCVars()
  local b = TB.db.cvarBackup
  if not b then return end
  for k, v in pairs(b) do C_CVar.SetCVar(k, v) end
  TB.db.cvarBackup = nil
end

TB.reeling = false
function TB.ReelMode(on)
  if not TB.db.castKey or not TB.HasBindAPI() or InCombatLockdown() then return end
  if on then
    if not TB.db.cvarBackup then
      local b = {}
      for k in pairs(REEL_CVARS) do b[k] = C_CVar.GetCVar(k) end -- nil (unknown CVar) is skipped below
      TB.db.cvarBackup = b
    end
    for k, v in pairs(REEL_CVARS) do if TB.db.cvarBackup[k] ~= nil then C_CVar.SetCVar(k, v) end end
    ClearOverrideBindings(owner)
    SetOverrideBinding(owner, true, TB.db.castKey, "INTERACTTARGET")
    TB.reeling = true
  else
    TB.RestoreCVars(); TB.BindCast(); TB.reeling = false
  end
end

table.insert(TB.inits, function()
  bar = CreateFrame("Frame", "TBActionBar", UIParent, "BackdropTemplate")
  bar:SetSize(52, 52); TB.Skin(bar, 12)
  -- vertical strip on the panel's left side, hung off the shared dock (see TB.Dock)
  bar:SetPoint("TOPRIGHT", TB.Dock(), "TOPLEFT", 2, 0); TB.DockDrag(bar)
  for _, key in ipairs(ORDER) do buttons[key] = MakeButton(key) end
  caster = CreateFrame("Button", "TBCastKey", UIParent, "SecureActionButtonTemplate")
  caster:SetSize(1, 1); caster:SetPoint("TOPLEFT"); caster:SetAlpha(0); caster:EnableMouse(false)
  caster:RegisterForClicks("AnyUp", "AnyDown")
  TB.RestoreCVars() -- a backup left by a crash or disconnect mid-cast
  TB.BindCast()
end)

-- attributes, visibility and layout only out of combat; PLAYER_REGEN_ENABLED -> Refresh re-applies
local function Apply()
  if not bar or InCombatLockdown() then return end
  local shown = {}
  for _, key in ipairs(ORDER) do
    local b, a = buttons[key], TB.actions[key]
    if a then
      if a.usable == false then
        b:SetAttribute("type", nil) -- greyed out: visible, does nothing
      elseif key == "pole" then
        b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", a.macro or ("/equip item:" .. a.item))
      elseif key == "lure" then
        -- use the lure, then put it on the main-hand slot (16 = the equipped pole)
        b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", "/use item:" .. a.item .. "\n/use 16")
      elseif key == "camp" and a.action == "craft" then
        -- probe run 7: /cast and type=spell do not craft; DATA.campCraftMethod "window" opens Fishing to press Create
        b:SetAttribute("type", nil)
      elseif key == "water" or key == "camp" then -- camp items open a placement cursor; the second click places (probe run 7B)
        b:SetAttribute("type", "item"); b:SetAttribute("item", "item:" .. a.item)
      else
        b:SetAttribute("type", "spell"); b:SetAttribute("spell", a.spell)
      end
      b.itemID, b.need = a.item, a.need
      b.tip = (a.weapons and "Equip your weapons") or (a.action == "fire" and "Place your campfire")
        or (a.action == "craft" and ("Craft " .. a.name .. ": opens Fishing")) or nil
      if key == "camp" then
        local craft = a.action == "craft" and a.usable ~= false
        b:SetScript("PostClick", craft and function() if not InCombatLockdown() then C_TradeSkillUI.OpenTradeSkill(356) end end or nil)
        b.badge:SetShown(a.action == "craft")
      end
      b.icon:SetTexture(a.item and C_Item.GetItemIconByID(a.item) or a.icon)
      b.icon:SetDesaturated(a.usable == false); b.icon:SetAlpha(a.usable == false and 0.5 or 1)
      b.count:SetText(a.item and key ~= "pole" and C_Item.GetItemCount(a.item) or "")
      if b.cd then
        local cd = a.action == "cooldown" and TB.campCD
        if cd then b.cd:SetCooldown(cd[1], cd[2]) else b.cd:Clear() end
      end
      shown[#shown + 1] = b
    else
      b:Hide()
    end
  end
  local cast = TB.actions.cast
  caster:SetAttribute("type", cast and "spell" or nil); caster:SetAttribute("spell", cast and cast.spell or nil)
  -- expanded: one column down the tall panel; collapsed: two rows so the bar is as tall as the panel (TB.PANEL_HEAD)
  local n = #shown
  local rows = TB.db.expanded and n or math.min(n, 2)
  local cols = math.max(1, math.ceil(n / math.max(rows, 1)))
  local h = TB.db.expanded and math.max(52, rows * 44 + 8) or (TB.PANEL_HEAD or 100)
  local top = TB.db.expanded and 6 or math.floor((h - (rows * 44 - 4)) / 2)
  for i, b in ipairs(shown) do
    local c, r = math.floor((i - 1) / rows), (i - 1) % rows
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", bar, "TOPLEFT", 6 + c * 44, -(top + r * 44)); b:Show()
  end
  bar:SetSize(cols * 44 + 8, h)
  bar:SetShown(n > 0 and TB.db.shown) -- only with the panel open; a combat close hides it once combat ends
end

local function BagItems()
  local items = {}
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local id = C_Container.GetContainerItemID(bag, slot)
      if id then
        local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
        items[#items + 1] = { id = id, classID = classID, subID = subID, bag = bag, slot = slot, link = C_Container.GetContainerItemLink(bag, slot) }
      end
    end
  end
  return items
end

function TB.PoleEquipped()
  local id = GetInventoryItemID("player", 16)
  if not id then return false end
  local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
  return classID == 2 and subID == 20
end

local function SlotItem(s)
  local id = GetInventoryItemID("player", s)
  return id and { id = id, link = GetInventoryItemLink("player", s) } or nil
end

table.insert(TB.refreshers, function()
  local A, poleOn, items = {}, TB.PoleEquipped(), BagItems()
  if not poleOn then
    -- any non-pole main hand is the set to come back to; an empty hand keeps the old snapshot
    if GetInventoryItemID("player", 16) then TB.char.weapons = { mh = SlotItem(16), oh = SlotItem(17) } end
    local pole = TB.PickPole(items)
    if pole then A.pole = { item = pole } end
  else
    local w = TB.char.weapons
    if w and w.mh then
      local mh, oh = TB.FindWeapon(items, w.mh), w.oh and TB.FindWeapon(items, w.oh)
      local missing = (not mh and w.mh) or (w.oh and not oh and w.oh) or nil
      A.pole = { item = w.mh.id, weapons = true, macro = TB.WeaponsMacro(mh, oh), usable = not missing,
        need = missing and ((TB.ItemName(missing.id)) .. " not in bags") or nil }
    end
    local counts = {}
    for _, l in ipairs(TB.DATA.lures) do counts[l.id] = C_Item.GetItemCount(l.id) end
    -- 1st return of GetWeaponEnchantInfo: the main hand already has a temp enchant (a lure)
    local lure, ok, req = TB.PickLure(TB.DATA.lures, counts, (GetWeaponEnchantInfo()), TB.skill and TB.skill.level)
    if lure then A.lure = { item = lure, usable = ok, need = not ok and ("Requires Fishing " .. req) or nil } end
  end

  local ww, wcounts, active = TB.DATA.waterWalk, {}, false
  for _, id in ipairs(ww.items) do wcounts[id] = C_Item.GetItemCount(id) + (C_Item.IsEquippedItem(id) and 1 or 0) end
  for _, sid in ipairs(ww.auras) do if TB.ReadAura(sid).active then active = true end end
  local water, wok = TB.WaterWalkPick(ww.items, wcounts, active, UnitLevel("player"), ww.minLevel)
  if water then A.water = { item = water, usable = wok, need = not wok and ("Requires level " .. ww.minLevel[water]) or nil } end
  TB.waterActive = active

  -- camp: campfire first, then the best camp item your skill allows; hidden while Camp Benefits is up
  -- shared camp cooldown (probe run 7D: item cooldown on every camp item, owned or not)
  local cs, cdur = C_Container.GetItemCooldown(TB.DATA.camp[1].item)
  if TB.Secret(cs) or TB.Secret(cdur) then cs, cdur = nil, nil end
  TB.campCooldownText = TB.CampCooldownText(cs, cdur, GetTime())
  TB.campCD = TB.campCooldownText and { cs, cdur } or nil
  local cf = TB.DATA.campfires
  local st = { skill = TB.skill, owned = {}, fires = cf.items, camp = TB.DATA.camp,
    campActive = TB.ReadAura(TB.DATA.campAura).active, fireUp = TB.ReadAura(cf.aura).active, cooldown = TB.campCooldownText }
  for _, id in ipairs(cf.items) do st.owned[id] = C_Item.GetItemCount(id) end
  for _, c in ipairs(TB.DATA.camp) do st.owned[c.item] = C_Item.GetItemCount(c.item) end
  st.known, st.counts = {}, {}
  for _, c in ipairs(TB.DATA.camp) do
    st.known[c.key] = C_SpellBook.IsSpellKnown(c.recipe) -- answers without the profession window (probe run 7E)
    for _, r in ipairs(c.reagents or {}) do st.counts[r[1]] = C_Item.GetItemCount(r[1]) end
  end
  local action, cid, cok, cneed = TB.CampPick(st)
  if action then
    local miss = cneed and tonumber(cneed:match("^missing item:(%d+)"))
    if miss then cneed = "Missing " .. (TB.ItemName(miss)) end
    local name
    for _, c in ipairs(TB.DATA.camp) do if c.item == cid then name = c.name end end
    A.camp = { item = cid, usable = cok, need = cneed, action = action, name = name }
  end

  if TB.skill then
    local s = C_Spell.GetSpellInfo(7620) -- probe run 1: Fishing = 7620
    if s then A.cast = { spell = s.name, icon = s.iconID } end
  end
  TB.actions = A
  Apply()
end)
