local ADDON, PP = ...
local MAX_ROWS = 16
local panel

local function Build()
  panel = CreateFrame("Frame", "PPPanel", ProfessionsFrame, "BasicFrameTemplateWithInset")
  panel:SetWidth(260)
  panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 2, 0)
  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  panel.title:SetPoint("TOP", 0, -5); panel.title:SetText("Profession Planner")
  panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.header:SetPoint("TOPLEFT", 12, -30); panel.header:SetJustifyH("LEFT")
  panel.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(236, 28); row:SetPoint("TOPLEFT", 12, -50 - (i - 1) * 30)
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(24, 24); row.icon:SetPoint("LEFT")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0); row.text:SetWidth(200); row.text:SetJustifyH("LEFT")
    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2); row.sub:SetWidth(200); row.sub:SetJustifyH("LEFT")
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
  panel:SetHeight(60 + n * 30)
  panel:Show()
end

table.insert(PP.refreshers, function()
  if not PP.current or not (ProfessionsFrame and ProfessionsFrame:IsShown()) then return PP.RenderPanel(nil) end
  local s, rows = PP.char.skill[PP.current], {}
  for _, r in pairs(PP.char.recipes[PP.current]) do
    if r.learned and r.color ~= "grey" then rows[#rows + 1] = { icon = r.icon, text = r.name, sub = r.color, color = r.color } end
  end
  table.sort(rows, function(a, b) if a.color ~= b.color then return PP.RANK[a.color] < PP.RANK[b.color] end return a.text < b.text end)
  PP.RenderPanel({ header = PP.PROFESSIONS[PP.current] .. "  " .. s.skill .. " → " .. PP.NextBracket(s.skill, s.max), rows = rows })
end)
