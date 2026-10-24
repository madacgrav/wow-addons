local ADDON, WCK = ...
-- hidden secure buttons driven by Bindings.xml CLICK bindings; own UIParent holder so no visible frame turns protected
BINDING_HEADER_WCK = "Warlock Combat Kit"
for i = 1, WCK.SLOTS do _G["BINDING_NAME_CLICK WCKCast" .. i .. ":LeftButton"] = "Mouseover cast slot " .. i end

local buttons = {}
table.insert(WCK.inits, function()
  local holder = CreateFrame("Frame", "WCKActionHolder", UIParent)
  for i = 1, WCK.SLOTS do
    local b = CreateFrame("Button", "WCKCast" .. i, holder, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown"); b:SetAttribute("type", "macro")
    buttons[i] = b
  end
end)

-- attributes only out of combat; PLAYER_REGEN_ENABLED -> Refresh re-applies
table.insert(WCK.refreshers, function()
  if InCombatLockdown() then return end
  for i, b in ipairs(buttons) do b:SetAttribute("macrotext", WCK.CastMacro(WCK.char.slots[i])) end
end)
