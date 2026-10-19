local ADDON, WUK = ...
local btn

local function State()
  return {
    known = WUK.known, counts = WUK.counts, buffs = WUK.ReadPlayerBuffs(), pet = WUK.PetFamily(),
    preferredPet = WUK.char.pet, mounted = IsMounted(),
    soulstoneActive = WUK.SoulstoneRemaining and WUK.SoulstoneRemaining(WUK.char.soulstone, time()) ~= nil or false,
  }
end

local function SetBorder(r, g, b) btn:SetBackdropBorderColor(r, g, b, 1) end

function WUK.UpdatePrepButton()
  if InCombatLockdown() then return SetBorder(0.9, 0.1, 0.1) end
  local steps = WUK.PrepSteps(State())
  local step = steps[1]
  btn:SetAttribute("macrotext", step and step.macro or "")
  btn.badge:SetText(#steps > 0 and #steps or "")
  local spell = step and step.macro:match("^/cast (.+)$")
  btn.icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or (step and 134400) or 136195)
  if step then SetBorder(1, 0.82, 0) else SetBorder(0.1, 0.9, 0.1) end
end

table.insert(WUK.inits, function()
  btn = CreateFrame("Button", "WUKPrepButton", WUK.strip, "SecureActionButtonTemplate,BackdropTemplate")
  btn:SetSize(36, 36); btn:SetPoint("TOPLEFT", 4, -4)
  btn:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
  btn.icon = btn:CreateTexture(nil, "ARTWORK"); btn.icon:SetPoint("TOPLEFT", 2, -2); btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  btn.badge = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal"); btn.badge:SetPoint("BOTTOMRIGHT", -2, 2)
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn:SetAttribute("type", "macro")
  WUK.On("PLAYER_REGEN_DISABLED", function() SetBorder(0.9, 0.1, 0.1) end)
end)
table.insert(WUK.refreshers, function() WUK.UpdatePrepButton() end)

-- pet button: always the /wuk pet choice (Imp if not learned); grey while that pet isn't out
local petBtn
table.insert(WUK.inits, function()
  petBtn = CreateFrame("Button", "WUKPetButton", WUK.strip, "SecureActionButtonTemplate")
  petBtn:SetSize(36, 36); petBtn:SetPoint("TOPLEFT", 44, -4)
  petBtn:RegisterForClicks("AnyUp", "AnyDown")
  petBtn:SetAttribute("type", "macro")
  petBtn.icon = petBtn:CreateTexture(nil, "ARTWORK"); petBtn.icon:SetAllPoints()
  petBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
end)
table.insert(WUK.refreshers, function()
  local pet = WUK.known[WUK.char.pet] and WUK.char.pet or "imp"
  local spell = WUK.known[pet]
  petBtn.icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or 134400)
  petBtn.icon:SetDesaturated(WUK.PetFamily() ~= pet)
  if not InCombatLockdown() then petBtn:SetAttribute("macrotext", spell and ("/cast " .. spell) or "") end
end)

table.insert(WUK.inits, function()
  WUK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit == "player" and WUK.SpellName(spellID) == "Soulstone Resurrection" then
      WUK.char.soulstone = { target = WUK.lastCastTarget or UnitName("player"), expires = time() + 1800 }
      WUK.Refresh()
    end
  end)
  local wasActive = false
  C_Timer.NewTicker(1, function()
    local rem = WUK.SoulstoneRemaining(WUK.char.soulstone, time())
    WUK.strip.stone:SetText(rem and ("Soulstone: " .. WUK.char.soulstone.target .. "  " .. WUK.FormatTime(rem)) or "Soulstone: none")
    if wasActive and not rem then WUK.Refresh() end -- expiry re-enables the prep steps
    wasActive = rem ~= nil
  end)
end)
