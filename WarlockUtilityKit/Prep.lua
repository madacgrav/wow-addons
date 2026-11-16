local ADDON, WUK = ...
-- armor button: highest known armor spell; lit when the buff is missing, grey once it's up
local armorBtn
table.insert(WUK.inits, function()
  armorBtn = CreateFrame("Button", "WUKArmorButton", WUK.strip, "SecureActionButtonTemplate")
  armorBtn:SetSize(36, 36); WUK.strip.icons.armor = armorBtn; WUK.AddGlow(armorBtn)
  armorBtn:RegisterForClicks("AnyUp", "AnyDown")
  armorBtn:SetAttribute("type", "macro")
  armorBtn.icon = armorBtn:CreateTexture(nil, "ARTWORK"); armorBtn.icon:SetAllPoints()
  armorBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  WUK.AttachTooltip(armorBtn, function() WUK.SpellTooltip(WUK.known.armor) end)
end)
table.insert(WUK.refreshers, function()
  local spell = WUK.known.armor
  armorBtn.icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or 134400)
  local up = spell ~= nil and WUK.ReadPlayerBuffs()[spell] == true
  armorBtn.icon:SetDesaturated(up)
  WUK.SetAlert(armorBtn, spell ~= nil and not up)
  if not InCombatLockdown() then armorBtn:SetAttribute("macrotext", spell and ("/cast " .. spell) or "") end
end)

-- pet button: always the /wuk pet choice (Imp if not learned); grey while that pet isn't out
local petBtn
local function PetSpell()
  local pet = WUK.known[WUK.char.pet] and WUK.char.pet or "imp"
  return WUK.known[pet], pet
end
table.insert(WUK.inits, function()
  petBtn = CreateFrame("Button", "WUKPetButton", WUK.strip, "SecureActionButtonTemplate")
  petBtn:SetSize(36, 36); WUK.strip.icons.pet = petBtn; WUK.AddGlow(petBtn)
  petBtn:RegisterForClicks("AnyUp", "AnyDown")
  petBtn:SetAttribute("type", "macro")
  petBtn.icon = petBtn:CreateTexture(nil, "ARTWORK"); petBtn.icon:SetAllPoints()
  petBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  WUK.AttachTooltip(petBtn, function() WUK.SpellTooltip((PetSpell())) end)
end)
table.insert(WUK.refreshers, function()
  local spell, pet = PetSpell()
  petBtn.icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or 134400)
  local out = WUK.PetIsOut(pet, WUK.PetFamily())
  petBtn.icon:SetDesaturated(not out)
  WUK.SetAlert(petBtn, spell ~= nil and not out)
  if not InCombatLockdown() then petBtn:SetAttribute("macrotext", spell and ("/cast " .. spell) or "") end
end)

table.insert(WUK.inits, function()
  WUK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit == "player" and WUK.SpellName(spellID) == "Soulstone Resurrection" then
      WUK.char.soulstone = { target = WUK.lastCastTarget or UnitName("player"), expires = time() + 1800 }
      WUK.Refresh()
    end
  end)
  C_Timer.NewTicker(1, function()
    local rem = WUK.SoulstoneRemaining(WUK.char.soulstone, time())
    WUK.strip.stone:SetText(rem and ("Soulstone: " .. WUK.char.soulstone.target .. "  " .. WUK.FormatTime(rem)) or "Soulstone: none")
  end)
end)

-- one secure button per view spell; LayoutRing shows/hides them by view
local SPELL_KEYS = { "detect", "shadowward", "soullink", "unending", "eye", "sense" }
function WUK.SpellButton(key)
  local b = CreateFrame("Button", "WUKSpell_" .. key, WUK.strip, "SecureActionButtonTemplate")
  b:SetSize(36, 36); b:RegisterForClicks("AnyUp", "AnyDown"); b:SetAttribute("type", "macro")
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  WUK.AttachTooltip(b, function() WUK.SpellTooltip(WUK.known[key]) end)
  b:Hide() -- party view first
  WUK.strip.icons[key] = b
  return b
end
table.insert(WUK.inits, function() for _, k in ipairs(SPELL_KEYS) do WUK.SpellButton(k) end end)
table.insert(WUK.refreshers, function()
  for _, k in ipairs(SPELL_KEYS) do
    local b, spell = WUK.strip.icons[k], WUK.known[k]
    b.icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or 134400)
    if not InCombatLockdown() then b:SetAttribute("macrotext", spell and ("/cast " .. spell) or "") end
  end
end)
