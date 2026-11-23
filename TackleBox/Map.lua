local ADDON, TB = ...
-- learned pools as world map and minimap pins via HereBeDragons-Pins (handles map canvas, minimap zoom and rotation)
local Pins = LibStub("HereBeDragons-Pins-2.0")
local T = TB.THEME
local frames, used = {}, 0
TB.Pins = {}

local function Acquire()
  used = used + 1
  local f = frames[used]
  if not f then
    f = CreateFrame("Frame", nil, UIParent); f:SetSize(10, 10); f:EnableMouse(true)
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetAllPoints(); f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.name, T.sand[1], T.sand[2], T.sand[3]); GameTooltip:AddLine("seen " .. self.n .. "x", 1, 1, 1)
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)
    frames[used] = f
  end
  f:Show()
  return f
end

local function Fill(f, p)
  local info = TB.PoolByKey(TB.DATA.pools, p.t)
  f.name, f.n = info and info.name or p.t, p.n
  f.icon:SetTexture(info and info.icon or "Interface\\Icons\\INV_Misc_Fish_02")
  return f
end

-- ponytail: full rebuild on every change; fine for hundreds of pins, diff if it ever stutters
function TB.Pins.Refresh()
  Pins:RemoveAllWorldMapIcons(TB.Pins); Pins:RemoveAllMinimapIcons(TB.Pins)
  for i = 1, used do frames[i]:Hide() end
  used = 0
  local _, _, cur = TB.PlayerPos()
  for map, list in pairs(TB.db.pools) do
    for _, p in ipairs(list) do
      if TB.db.pins.map then Pins:AddWorldMapIconMap(TB.Pins, Fill(Acquire(), p), map, p.x, p.y, HBD_PINS_WORLDMAP_SHOW_PARENT) end
      if TB.db.pins.minimap and map == cur then Pins:AddMinimapIconMap(TB.Pins, Fill(Acquire(), p), map, p.x, p.y, false, false) end
    end
  end
end

table.insert(TB.inits, function()
  TB.HBD.RegisterCallback(TB.Pins, "PlayerZoneChanged", TB.Pins.Refresh)
  TB.Pins.Refresh()
end)
