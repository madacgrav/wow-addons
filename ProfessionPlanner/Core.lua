local ADDON, PP = ...

PP.inits, PP.refreshers = {}, {}
function PP.Secret(v) return issecretvalue ~= nil and issecretvalue(v) end
function PP.Print(msg) print("|cff66ccffPP|r " .. tostring(msg)) end

local events, handlers = CreateFrame("Frame"), {}
function PP.On(event, fn)
  if not handlers[event] then handlers[event] = {}; events:RegisterEvent(event) end
  table.insert(handlers[event], fn)
end
events:SetScript("OnEvent", function(_, event, ...) for _, fn in ipairs(handlers[event]) do fn(...) end end)

function PP.Refresh() for _, fn in ipairs(PP.refreshers) do fn() end end

PP.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  -- nil-safe: the Forever beta loader bug can leave these nil
  ProfessionPlannerDB = PP.MergeDefaults(ProfessionPlannerDB, { thresholds = {}, prices = {} })
  ProfessionPlannerCharDB = PP.MergeDefaults(ProfessionPlannerCharDB, { recipes = {}, bank = {}, skill = {} })
  PP.db, PP.char = ProfessionPlannerDB, ProfessionPlannerCharDB
end)
PP.On("PLAYER_LOGIN", function() for _, init in ipairs(PP.inits) do init() end end)

-- prints API facts for the open profession window; output decides Phase 2+ details
function PP.Probe()
  local function P(k, v) PP.Print(k .. ": " .. tostring(v)) end
  local ready = C_TradeSkillUI.IsTradeSkillReady()
  P("tradeskill ready", ready)
  if ready then
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    if info then P("profession", tostring(info.professionID) .. " " .. tostring(info.professionName)
      .. " " .. tostring(info.skillLevel) .. "/" .. tostring(info.maxSkillLevel)) end
    local ids, learned, shown = C_TradeSkillUI.GetAllRecipeIDs(), 0, 0
    for _, id in ipairs(ids) do
      local ri = C_TradeSkillUI.GetRecipeInfo(id)
      if ri and ri.learned then
        learned = learned + 1
        if shown < 5 then
          shown = shown + 1
          local sch = C_TradeSkillUI.GetRecipeSchematic(id, false)
          local slot = sch and sch.reagentSlotSchematics and sch.reagentSlotSchematics[1]
          local rg = slot and slot.reagents and slot.reagents[1]
          P("  " .. tostring(ri.name), "diff=" .. tostring(ri.relativeDifficulty) .. " maxTrivial=" .. tostring(ri.maxTrivialLevel)
            .. " skillUps=" .. tostring(ri.numSkillUps) .. " qtyMin=" .. tostring(sch and sch.quantityMin)
            .. " reagent=" .. tostring(rg and rg.itemID) .. "x" .. tostring(slot and slot.quantityRequired)
            .. " type=" .. tostring(slot and slot.reagentType))
          if shown == 1 and rg and rg.itemID then
            P("  count bags/bank", C_Item.GetItemCount(rg.itemID) .. "/" .. C_Item.GetItemCount(rg.itemID, true))
          end
        end
      end
    end
    P("recipes", #ids .. " total, " .. learned .. " learned")
  end
  local tab = Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
  P("CharacterBankTab_1", tostring(tab) .. " slots=" .. tostring(tab and C_Container.GetContainerNumSlots(tab)))
  P("ReagentBag", tostring(Enum.BagIndex and Enum.BagIndex.ReagentBag))
end

SLASH_PROFESSIONPLANNER1 = "/pp"
SlashCmdList.PROFESSIONPLANNER = function(msg)
  local cmd = (msg or ""):lower():match("^(%S*)")
  if cmd == "probe" then PP.Probe()
  else PP.Print("/pp probe") end
end
