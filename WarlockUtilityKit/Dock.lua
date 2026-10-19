local ADDON, WUK = ...
-- Blizzard's Cooldown Manager draws DoT/curse timers we can't read (secrets); we only anchor its frames under the strip
local VIEWERS = { "EssentialCooldownViewer", "BuffIconCooldownViewer" }
local applying = false

function WUK.ApplyDock()
  if not WUK.db.dockViewers or InCombatLockdown() then return end
  local anchor = WUK.strip
  applying = true
  for _, name in ipairs(VIEWERS) do
    local v = _G[name]
    if v then v:ClearAllPoints(); v:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4); anchor = v end
  end
  applying = false
end

table.insert(WUK.inits, function()
  for _, name in ipairs(VIEWERS) do
    local v = _G[name]
    -- Edit Mode re-anchors on layout changes; put it back (out of combat only)
    if v then hooksecurefunc(v, "SetPoint", function() if not applying then C_Timer.After(0, WUK.ApplyDock) end end) end
  end
  WUK.On("EDIT_MODE_LAYOUTS_UPDATED", WUK.ApplyDock)
  WUK.ApplyDock()
end)
table.insert(WUK.refreshers, function() WUK.ApplyDock() end)
