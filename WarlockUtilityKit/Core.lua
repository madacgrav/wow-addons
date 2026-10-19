local ADDON, WUK = ...

WUK.inits, WUK.refreshers = {}, {}
WUK.counts = { shard = 0, healthstone = 0, soulstone = 0, spellstone = 0, firestone = 0, ids = {}, slots = {} }
WUK.known = {}

function WUK.Secret(v) return issecretvalue ~= nil and issecretvalue(v) end
function WUK.Print(msg) print("|cff9482c9WUK|r " .. msg) end

local events, handlers = CreateFrame("Frame"), {}
function WUK.On(event, fn)
  if not handlers[event] then handlers[event] = {}; events:RegisterEvent(event) end
  table.insert(handlers[event], fn)
end
events:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do fn(...) end
end)

local DEFAULTS = { locked = false, shown = true, frames = {} }
local CHAR_DEFAULTS = { pet = "imp" }

WUK.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  -- nil-safe: the Forever beta loader bug can leave these nil every session
  WarlockUtilityKitDB = WUK.MergeDefaults(WarlockUtilityKitDB, DEFAULTS)
  WarlockUtilityKitCharDB = WUK.MergeDefaults(WarlockUtilityKitCharDB, CHAR_DEFAULTS)
  WUK.db, WUK.char = WarlockUtilityKitDB, WarlockUtilityKitCharDB
end)

function WUK.ScanBags()
  local c = { shard = 0, healthstone = 0, soulstone = 0, spellstone = 0, firestone = 0, ids = {}, slots = {} }
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local kind = info and WUK.ClassifyItem(info.itemName or C_Item.GetItemInfo(info.itemID))
      if kind then
        c[kind] = c[kind] + (info.stackCount or 1)
        c.ids[kind] = c.ids[kind] or info.itemID
        c.slots[kind] = c.slots[kind] or { bag, slot }
      end
    end
  end
  return c
end

function WUK.Refresh()
  if not WUK.active then return end
  WUK.counts = WUK.ScanBags()
  for _, fn in ipairs(WUK.refreshers) do fn() end
end

WUK.On("PLAYER_LOGIN", function()
  local _, class = UnitClass("player")
  if class ~= "WARLOCK" then return end
  WUK.active = true
  for _, init in ipairs(WUK.inits) do init() end
  WUK.Refresh()
end)
WUK.On("BAG_UPDATE_DELAYED", WUK.Refresh)
WUK.On("PLAYER_REGEN_ENABLED", WUK.Refresh)

SLASH_WARLOCKUTILITYKIT1 = "/wuk"
SlashCmdList.WARLOCKUTILITYKIT = function(msg)
  if not WUK.active then return WUK.Print("warlocks only") end
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  if InCombatLockdown() and (cmd == "show" or cmd == "hide") then return WUK.Print("not in combat") end
  if cmd == "show" or cmd == "hide" then WUK.db.shown = (cmd == "show"); WUK.ApplyShown()
  elseif cmd == "lock" then WUK.db.locked = not WUK.db.locked; WUK.Print(WUK.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(WUK.db.frames); WUK.Print("positions reset - /reload to apply")
  else WUK.Print("/wuk show | hide | lock | reset | pet <imp|voidwalker|succubus|felhunter>") end
end
