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

local BASIC = (Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1

function PP.ScanProfession()
  if not C_TradeSkillUI.IsTradeSkillReady() then return end
  local info = C_TradeSkillUI.GetBaseProfessionInfo()
  local prof = info and info.professionID
  if not prof or not PP.PROFESSIONS[prof] then PP.current = nil; return end
  PP.current = prof
  PP.char.skill[prof] = { skill = info.skillLevel, max = info.maxSkillLevel }
  -- rebuild each scan (reusing cached schematics) so recipes from a previously open profession can't linger
  local old, cache = PP.char.recipes[prof] or {}, {}
  local prevColors, curColors = {}, {}
  for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
    local ri = C_TradeSkillUI.GetRecipeInfo(id)
    -- right after switching professions the recipe list can still hold the old profession's recipes
    local pi = C_TradeSkillUI.GetProfessionInfoByRecipeID and C_TradeSkillUI.GetProfessionInfoByRecipeID(id)
    local ours = not pi or pi.professionID == prof or pi.parentProfessionID == prof
    if ri and ri.learned and ours then
      local r = old[id]
      if not r then -- reagents never change: fetch the schematic once
        r = { name = ri.name, icon = ri.icon, reagents = {} }
        local sch = C_TradeSkillUI.GetRecipeSchematic(id, false)
        if sch then
          r.qtyMin = sch.quantityMin
          for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
            local rg = slot.reagents and slot.reagents[1]
            if slot.reagentType == BASIC and rg and rg.itemID then
              r.reagents[#r.reagents + 1] = { itemID = rg.itemID, qty = slot.quantityRequired }
            end
          end
        end
      end
      cache[id] = r
      prevColors[id] = r.color
      r.learned = true
      r.color = PP.COLOR[ri.relativeDifficulty] or "grey"
      curColors[id] = r.color
      r.maxTrivial = ri.maxTrivialLevel -- used in Phase 4
    end
  end
  -- right after switching, the list can still be the previous profession's (all filtered out):
  -- keep the old cache and try again once the window settles
  if next(cache) == nil then
    if (PP.retries or 0) < 5 then
      PP.retries = (PP.retries or 0) + 1
      C_Timer.After(0.5, function() PP.ScanProfession(); PP.Refresh() end)
    end
    return
  end
  PP.retries = 0
  PP.char.recipes[prof] = cache
  PP.LearnThresholds(PP.db.thresholds, prevColors, curColors, info.skillLevel)
  for id, r in pairs(cache) do PP.LearnGrey(PP.db.thresholds, id, r.maxTrivial) end
end

local function ScanContainers(first, last, into)
  for bag = first, last do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then into[info.itemID] = (into[info.itemID] or 0) + (info.stackCount or 1) end
    end
  end
  return into
end

function PP.Have()
  local have = ScanContainers(0, (Enum.BagIndex and Enum.BagIndex.ReagentBag) or NUM_BAG_SLOTS or 4, {})
  for id, n in pairs(PP.char.bank) do have[id] = (have[id] or 0) + n end
  return have
end

local bankOpen = false
local function ScanBank()
  if not bankOpen or not Enum.BagIndex then return end
  local bank = {}
  for i = 1, 9 do
    local bag = Enum.BagIndex["CharacterBankTab_" .. i]
    if bag then ScanContainers(bag, bag, bank) end
  end
  PP.char.bank = bank
end

local function ScanMerchant()
  for i = 1, GetMerchantNumItems() do
    local id, info = GetMerchantItemID(i), C_MerchantFrame.GetItemInfo(i)
    if id and info and info.price and info.price > 0 and not info.hasExtendedCost then
      PP.db.prices[id] = info.price / math.max(1, info.stackCount or 1)
    end
  end
end

table.insert(PP.inits, function()
  PP.On("BANKFRAME_OPENED", function() bankOpen = true; ScanBank(); PP.Refresh() end)
  PP.On("BANKFRAME_CLOSED", function() bankOpen = false end)
  PP.On("PLAYERBANKSLOTS_CHANGED", function() ScanBank(); PP.Refresh() end)
  PP.On("BAG_UPDATE_DELAYED", function() ScanBank(); PP.Refresh() end)
  PP.On("MERCHANT_SHOW", function() ScanMerchant(); PP.Refresh() end)
end)

table.insert(PP.inits, function()
  local function Update() PP.ScanProfession(); PP.Refresh() end
  PP.On("TRADE_SKILL_SHOW", Update)
  PP.On("TRADE_SKILL_LIST_UPDATE", Update)
  PP.On("TRADE_SKILL_CLOSE", function() PP.current = nil; PP.Refresh() end)
end)

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
    local unl = 0
    for _, id in ipairs(ids) do
      local ri = C_TradeSkillUI.GetRecipeInfo(id)
      if ri and not ri.learned and unl < 10 then
        unl = unl + 1
        P("  unlearned " .. id .. " " .. tostring(ri.name), "diff=" .. tostring(ri.relativeDifficulty)
          .. " maxTrivial=" .. tostring(ri.maxTrivialLevel) .. " sourceType=" .. tostring(ri.sourceType)
          .. " disabled=" .. tostring(ri.disabled) .. " reason=" .. tostring(ri.disabledReason))
        if C_TradeSkillUI.GetRecipeSourceText then
          P("    source", (tostring(C_TradeSkillUI.GetRecipeSourceText(id)):gsub("\n", " | ")))
        end
        for _, rq in ipairs(C_TradeSkillUI.GetRecipeRequirements and C_TradeSkillUI.GetRecipeRequirements(id) or {}) do
          P("    req", tostring(rq.name) .. " met=" .. tostring(rq.met) .. " type=" .. tostring(rq.type))
        end
      end
    end
    P("recipes", #ids .. " total, " .. learned .. " learned")
  end
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  P("Auctionator API", tostring(api ~= nil))
  if api then
    local ok, p = pcall(api.GetAuctionPriceByItemID, ADDON, 2589) -- Linen Cloth
    P("  AH price 2589", tostring(ok) .. " " .. tostring(p))
  end
  local q = LibQuestieDB
  P("LibQuestieDB", tostring(q ~= nil) .. " contract3=" .. tostring(q and q.RequireContract and q.RequireContract(3)))
  local tab = Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
  P("CharacterBankTab_1", tostring(tab) .. " slots=" .. tostring(tab and C_Container.GetContainerNumSlots(tab)))
  P("ReagentBag", tostring(Enum.BagIndex and Enum.BagIndex.ReagentBag))
end

SLASH_PROFESSIONPLANNER1 = "/pp"
SlashCmdList.PROFESSIONPLANNER = function(msg)
  local cmd = (msg or ""):lower():match("^(%S*)")
  if cmd == "probe" then PP.Probe()
  elseif cmd == "debug" then
    local prof = PP.current
    PP.Print("current=" .. tostring(prof) .. " ready=" .. tostring(C_TradeSkillUI.IsTradeSkillReady()))
    local byColor, n = {}, 0
    for id, r in pairs(prof and PP.char.recipes[prof] or {}) do
      n = n + 1
      local k = tostring(r.color) .. (r.learned and "" or "(unlearned)")
      byColor[k] = (byColor[k] or 0) + 1
      if r.color == "orange" and (byColor.shown or 0) < 2 then
        byColor.shown = (byColor.shown or 0) + 1
        PP.Print("  " .. tostring(r.name) .. " id=" .. id .. " reagents=" .. #(r.reagents or {}))
      end
    end
    local parts = {}
    for k, v in pairs(byColor) do if k ~= "shown" then parts[#parts + 1] = k .. "=" .. v end end
    PP.Print("recipes " .. n .. ": " .. table.concat(parts, " "))
    if prof then
      local id = next(PP.char.recipes[prof] or {})
      local pi = id and C_TradeSkillUI.GetProfessionInfoByRecipeID and C_TradeSkillUI.GetProfessionInfoByRecipeID(id)
      PP.Print("sample recipe prof: " .. tostring(pi and pi.professionID) .. " parent=" .. tostring(pi and pi.parentProfessionID))
    end
  else PP.Print("/pp probe") end
end
