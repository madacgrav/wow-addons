local ADDON, PP = ...
local MAX_ROWS = 16
local panel

local function Build()
  panel = CreateFrame("Frame", "PPPanel", ProfessionsFrame, "BasicFrameTemplateWithInset")
  panel:SetWidth(360)
  -- Forever's profession window has a column of side tabs past its right edge; sit beyond them
  panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 60, 0)
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
    panel.rows[i] = row
  end
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
local function View(prof)
  local recipes, thresholds, seed = {}, {}, PP.SEED and PP.SEED.recipes or {}
  for id, r in pairs(PP.char.recipes[prof] or {}) do
    local v = copy(r)
    v.reagents = PP.MergeReagents(r.reagents, seed[id])
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
  for _, r in pairs(recipes) do for _, rg in ipairs(r.reagents) do add(rg.itemID) end end
  return prices, sources, add
end

local pending = false
local function Rerender() if not pending then pending = true; C_Timer.After(0.1, function() pending = false; PP.Refresh() end) end end

table.insert(PP.refreshers, function()
  if not PP.current or not (ProfessionsFrame and ProfessionsFrame:IsShown()) then return PP.RenderPanel(nil) end
  local s = PP.char.skill[PP.current]
  local target = PP.NextBracket(s.skill, s.max)
  local recipes, thresholds = View(PP.current)
  local prices, sources = Prices(recipes)
  local have = PP.Have()
  local steps = PP.Plan({ skill = s.skill, target = target, recipes = recipes, have = have,
    prices = prices, thresholds = thresholds, unknownCost = PP.UNKNOWN_COST })
  local rows = {}
  for _, st in ipairs(steps) do
    -- * marks a step length taken from a learned threshold
    local goal = st.toSkill and ("-> " .. st.toSkill .. (st.toSkill < target and " *" or "")) or (st.untilColorChange and "(until color changes)") or ("-> " .. target)
    rows[#rows + 1] = { icon = st.icon, text = "x" .. st.crafts .. " " .. st.name, sub = goal .. "   " .. (st.estimated and "~" or "") .. PP.FormatMoney(st.cost), color = st.color }
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
  local known = 0
  for id in pairs(recipes) do
    local th = PP.db.thresholds[id]
    if th and (th.yellow or th.green) then known = known + 1 end
  end
  PP.RenderPanel({ header = PP.PROFESSIONS[PP.current] .. "  " .. s.skill .. " -> " .. target
    .. "\n|cff999999" .. known .. " thresholds learned  |  seed " .. (PP.SEED and PP.SEED.build or "none") .. "|r", rows = rows })
end)
