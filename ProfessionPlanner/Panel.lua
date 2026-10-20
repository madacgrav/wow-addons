local ADDON, PP = ...
local MAX_ROWS = 16
local panel

local function Build()
  panel = CreateFrame("Frame", "PPPanel", ProfessionsFrame, "BasicFrameTemplateWithInset")
  panel:SetWidth(360)
  -- Forever's profession window has a column of side tabs past its right edge; sit beyond them
  panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 60, 0)
  if panel.CloseButton then panel.CloseButton:HookScript("OnClick", function() PP.db.panelOpen = false; PP.Refresh() end) end
  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  panel.title:SetPoint("TOP", 0, -5); panel.title:SetText("Profession Planner")
  panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.header:SetPoint("TOPLEFT", 12, -30); panel.header:SetJustifyH("LEFT")
  panel.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(336, 28); row:SetPoint("TOPLEFT", 12, -64 - (i - 1) * 30)
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(24, 24); row.icon:SetPoint("LEFT")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0); row.text:SetWidth(300); row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false) -- long names truncate instead of spilling into the next row
    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2); row.sub:SetWidth(300); row.sub:SetJustifyH("LEFT"); row.sub:SetWordWrap(false)
    row:EnableMouse(true)
    row.hl = row:CreateTexture(nil, "HIGHLIGHT"); row.hl:SetAllPoints(); row.hl:SetColorTexture(1, 1, 1, 0.08)
    row:SetScript("OnMouseUp", function(self) if self.recipeID then PP.SelectRecipe(self.recipeID, self.crafts, IsShiftKeyDown()) end end)
    row:SetScript("OnEnter", function(self)
      if not self.recipeID then return end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText("Click: select recipe")
      GameTooltip:AddLine("Shift-click: craft " .. self.crafts, 1, 1, 1)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    panel.rows[i] = row
  end
end

local tab
-- below the last shown side profession tab; fixed offset if Blizzard's tab list isn't there
local function AnchorTab()
  local last
  for _, t in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do if t:IsShown() then last = t end end
  tab:ClearAllPoints()
  if last then tab:SetPoint("TOP", last, "BOTTOM", 0, -12)
  else tab:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 8, -420) end -- ponytail: tune if the fallback is ever used
end

local function BuildTab()
  tab = CreateFrame("Button", "PPToggleTab", ProfessionsFrame)
  tab:SetSize(36, 36)
  tab.icon = tab:CreateTexture(nil, "ARTWORK"); tab.icon:SetAllPoints(); tab.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  tab:SetScript("OnClick", function() PP.db.panelOpen = not PP.db.panelOpen; PP.Refresh() end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(PP.db.panelOpen and "Hide Profession Planner" or "Show Profession Planner")
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", GameTooltip_Hide)
end

-- the tab shows whenever a supported profession window is open
function PP.RenderTab(shown)
  if not shown then if tab then tab:Hide() end return end
  if not tab then BuildTab() end
  AnchorTab()
  tab:Show()
end

local COLORS = { orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 }, green = { 0.25, 0.75, 0.25 }, grey = { 0.5, 0.5, 0.5 } }

-- view = { header = string, rows = { {icon, text, sub, color?} } }
function PP.RenderPanel(view)
  if not view then if panel then panel:Hide() end return end
  if not panel then Build() end
  panel.header:SetText(view.header)
  local n = math.min(#view.rows, MAX_ROWS)
  for i, row in ipairs(panel.rows) do
    local v = view.rows[i]
    row:SetShown(v ~= nil)
    if v then
      row.icon:SetTexture(v.icon or 134400)
      row.text:SetText(v.text)
      local c = COLORS[v.color] or { 1, 1, 1 }
      row.text:SetTextColor(c[1], c[2], c[3])
      row.sub:SetText(v.sub or "")
      row.recipeID, row.crafts = v.recipeID, v.crafts
      row.hl:SetShown(v.recipeID ~= nil)
    end
  end
  panel:SetHeight(74 + n * 30)
  panel:Show()
end

local function ItemName(id, onLoad)
  local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
  if not name then Item:CreateFromItemID(id):ContinueOnItemLoad(onLoad) end
  return name or ("item:" .. id), icon or C_Item.GetItemIconByID(id)
end

local function copy(t) local c = {}; for k, v in pairs(t) do c[k] = v end; return c end

-- scanned recipes annotated with seed data, in memory only (never saved)
local function View(prof, skill)
  local recipes, thresholds, seed = {}, {}, PP.SEED and PP.SEED.recipes or {}
  for id, r in pairs(PP.char.recipes[prof] or {}) do
    local v = copy(r)
    v.reagents = PP.MergeReagents(r.reagents, seed[id])
    local sd = seed[id]
    if sd then v.learnAt, v.taughtBy = sd.learnAt, sd.taughtBy end
    v.learnable = PP.Learnable(r, sd, skill)
    recipes[id] = v
    thresholds[id] = PP.MergeThresholds(PP.db.thresholds[id], seed[id])
  end
  return recipes, thresholds
end

-- per-refresh price table for every reagent in view; AH prices are read live, never saved
local function Prices(recipes)
  local prices, sources = {}, {}
  local function add(id)
    if sources[id] ~= nil then return end
    prices[id], sources[id] = PP.PickPrice(PP.db.prices[id], PP.AHPrice(id), PP.SEED and PP.SEED.price[id], PP.VendorFor(id) ~= nil)
    sources[id] = sources[id] or false
  end
  for _, r in pairs(recipes) do
    if r.learned or r.learnable then -- only what Plan can pick; unlearned-and-unreachable recipes cost no lookups
      for _, rg in ipairs(r.reagents) do add(rg.itemID) end
      for _, it in ipairs(r.learnable and r.taughtBy or {}) do add(it) end
    end
  end
  return prices, sources, add
end

local pending = false
local function Rerender() if not pending then pending = true; C_Timer.After(0.1, function() pending = false; PP.Refresh() end) end end

table.insert(PP.refreshers, function()
  local open = PP.current and ProfessionsFrame and ProfessionsFrame:IsShown()
  PP.RenderTab(open)
  if not open or not PP.db.panelOpen then return PP.RenderPanel(nil) end
  local s = PP.char.skill[PP.current]
  local target = PP.NextBracket(s.skill, s.max)
  local recipes, thresholds = View(PP.current, s.skill)
  local prices, sources = Prices(recipes)
  -- a pattern recipe is only plannable when one of its patterns has a price (vendor/AH/est.)
  for _, v in pairs(recipes) do
    if v.learnable and v.taughtBy then
      local bestItem
      for _, it in ipairs(v.taughtBy) do
        if prices[it] and (not bestItem or prices[it] < prices[bestItem]) then bestItem = it end
      end
      v.learnable, v.learnItem, v.learnCost = bestItem ~= nil, bestItem, bestItem and prices[bestItem]
    end
  end
  local have = PP.Have()
  local steps = PP.Plan({ skill = s.skill, target = target, recipes = recipes, have = have,
    prices = prices, thresholds = thresholds, unknownCost = PP.UNKNOWN_COST })
  local rows = {}
  for _, st in ipairs(steps) do
    -- * marks a step length taken from a learned threshold
    if st.learn then
      local learnName, learnIcon = "Trainer", nil
      if st.learn.item then learnName, learnIcon = ItemName(st.learn.item, Rerender) end
      local where = st.learn.item and PP.VendorFor(st.learn.item)
      rows[#rows + 1] = { icon = learnIcon or st.icon, text = "Learn: " .. learnName,
        sub = (where and (where.name .. (where.zone and (" (" .. where.zone .. ")") or "")))
          or (st.learn.source and st.learn.source:match("^[^\n]*")) or "" }
    end
    local goal = st.toSkill and ("-> " .. st.toSkill .. (st.toSkill < target and " *" or "")) or (st.untilColorChange and "(until color changes)") or ("-> " .. target)
    rows[#rows + 1] = { icon = st.icon, text = "x" .. st.crafts .. " " .. st.name, sub = goal .. "   " .. (st.estimated and "~" or "") .. PP.FormatMoney(st.cost), color = st.color,
      -- clickable only once actually learned (a planned learn step is not yet)
      recipeID = recipes[st.recipeID].learned and st.recipeID or nil, crafts = st.crafts }
  end
  if #steps == 0 then rows[#rows + 1] = { text = "No recipe gives skill-ups here", sub = "train new recipes" } end
  for _, it in ipairs(PP.ShoppingList(steps, recipes, have, prices, sources)) do
    local name, icon = ItemName(it.itemID, Rerender)
    local sub = it.have .. "/" .. it.need
    if it.buy > 0 then
      sub = sub .. "   buy " .. it.buy .. (it.unitPrice and (" @ " .. PP.FormatMoney(it.unitPrice) .. " " .. it.source) or "")
      local v = PP.VendorFor(it.itemID)
      if v then sub = sub .. " - " .. v.name .. (v.zone and (" (" .. v.zone .. ")") or "") end
    end
    rows[#rows + 1] = { icon = icon, text = name, sub = sub }
  end
  local known, atTrainer = 0, 0
  for id, v in pairs(recipes) do
    local th = PP.db.thresholds[id]
    if th and (th.yellow or th.green) then known = known + 1 end
    if not v.learned and not v.taughtBy then atTrainer = atTrainer + 1 end
  end
  PP.RenderPanel({ header = PP.PROFESSIONS[PP.current] .. "  " .. s.skill .. " -> " .. target
    .. "\n|cff999999" .. known .. " learned  |  " .. atTrainer .. " at trainer  |  seed "
    .. (PP.SEED and PP.SEED.build or "none") .. "|r", rows = rows })
end)
