local ADDON, WUK = ...
local MAX_ROWS = 10
local MARKS = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local me, win, lastText

WUK.board = { lead = nil, rev = 0, rows = {} }

local function MarkIcon(m) return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. m .. ":0|t" end

function WUK.IsLead() return WUK.board.lead == nil or WUK.board.lead == me end
function WUK.MySoulstoneTarget() local r = WUK.board.rows[me]; return r and r.ss end

local function SaveIfLead()
  local b = WUK.board
  if b.lead == me then WUK.char.board = { rev = b.rev, rows = b.rows } end
end

function WUK.BoardChanged()
  if win and win:IsShown() then win:Sync() end
  WUK.Refresh() -- strip line + soulstone macro
end

function WUK.ClaimLead()
  local b = WUK.board
  b.lead, b.rev = me, WUK.NextRev(b.rev, time())
  if WUK.SendFullBoard then WUK.SendFullBoard() end
  SaveIfLead(); WUK.BoardChanged()
end

function WUK.SetAssignment(warlock, field, value)
  local b = WUK.board
  if not warlock or not WUK.IsLead() then return end
  if b.lead == nil then WUK.ClaimLead() end -- first edit claims lead so others accept the rows
  local row = b.rows[warlock] or { mark = 0 }
  row[field] = value
  b.rows[warlock] = row
  b.rev = WUK.NextRev(b.rev, time())
  if WUK.SendRow then WUK.SendRow(warlock) end
  SaveIfLead(); WUK.BoardChanged()
end

function WUK.SendRow(warlock)
  local b, r = WUK.board, WUK.board.rows[warlock]
  WUK.Send(WUK.Encode("A", b.rev, warlock, r.curse, r.mark or 0, r.ss))
end

function WUK.SendFullBoard()
  local b = WUK.board
  WUK.Send(WUK.Encode("L", b.rev))
  for w in pairs(b.rows) do WUK.SendRow(w) end
  WUK.Send(WUK.Encode("E", b.rev))
end

function WUK.RequestSync() WUK.Send(WUK.Encode("R")) end

function WUK.OnBoardMessage(sender, m)
  local b = WUK.board
  -- same lead re-sending its claim at an equal rev (full sync) is accepted too
  if m.kind == "L" and (sender == b.lead or WUK.AcceptLead(b, m.rev)) then
    b.lead, b.rev = sender, m.rev
    WUK.char.board = nil -- someone else leads now
    WUK.BoardChanged()
  elseif m.kind == "A" and WUK.AcceptRow(b, sender, m.rev) then
    b.rows[m.warlock] = { curse = m.curse, mark = m.mark, ss = m.ss }
    b.rev = m.rev
    WUK.BoardChanged()
  elseif m.kind == "R" and b.lead == me then
    WUK.SendFullBoard()
  end
end

function WUK.Announce()
  if not WUK.IsLead() then return WUK.Print("only the lead can announce") end
  local lines = WUK.AnnounceLines(WUK.board)
  if #lines == 0 then return WUK.Print("nothing to announce") end
  local ch = (IsInRaid() and ((UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) and "RAID_WARNING" or "RAID"))
    or (IsInGroup() and "PARTY") or nil
  if not ch then for _, l in ipairs(lines) do WUK.Print(l) end return end
  local send = C_ChatInfo.SendChatMessage or SendChatMessage
  for i, l in ipairs(lines) do C_Timer.After((i - 1) * 0.3, function() send(l, ch) end) end
end

local function Radio(root, label, row, field, val)
  root:CreateRadio(label,
    function() local r = WUK.board.rows[row.warlock]; return (r and r[field]) == val end,
    function() WUK.SetAssignment(row.warlock, field, val) end)
end

local function Dropdown(row, x, width, build)
  local dd = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
  dd:SetWidth(width); dd:SetPoint("LEFT", x, 0)
  dd:SetupMenu(function(_, root) build(root) end)
  return dd
end

local function Build()
  win = CreateFrame("Frame", "WUKBoard", UIParent, "BackdropTemplate")
  win:SetSize(560, 110 + MAX_ROWS * 28); win:SetFrameStrata("DIALOG")
  WUK.Skin(win, "Warlock Assignments", { close = true, swirl = true })
  WUK.MakeMovable(win, "board", -180, 0, true)
  tinsert(UISpecialFrames, "WUKBoard")
  win.leadText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  win.leadText:SetPoint("TOPLEFT", 14, -30); win.leadText:SetTextColor(unpack(WUK.THEME.text))
  WUK.Header(win, "Warlock", 14, -50); WUK.Header(win, "Curse", 124, -50)
  WUK.Header(win, "Banish", 270, -50); WUK.Header(win, "Soulstone", 396, -50)
  WUK.Divider(win, 14, -63, 532)

  win.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, win)
    row:SetSize(532, 26); row:SetPoint("TOPLEFT", 14, -66 - (i - 1) * 28)
    if i % 2 == 0 then -- faint lavender stripe on every other row
      local s = row:CreateTexture(nil, "BACKGROUND"); s:SetAllPoints(); s:SetColorTexture(0.58, 0.51, 0.79, 0.07)
    end
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 4, 0); row.name:SetWidth(102); row.name:SetJustifyH("LEFT")
    row.dds = {
      Dropdown(row, 110, 140, function(root)
        Radio(root, "No curse", row, "curse", nil)
        for _, c in ipairs(WUK.CURSES) do
          if c.key ~= "shadow" or WUK.known.curseshadow then Radio(root, c.short, row, "curse", c.key) end
        end
      end),
      Dropdown(row, 256, 120, function(root)
        Radio(root, "No banish", row, "mark", 0)
        for m, label in ipairs(MARKS) do Radio(root, MarkIcon(m) .. " " .. label, row, "mark", m) end
      end),
      Dropdown(row, 382, 150, function(root)
        Radio(root, "No soulstone", row, "ss", nil)
        Radio(root, me, row, "ss", me)
        for _, u in ipairs(WUK.GroupUnits()) do
          local n = WUK.UnitFull(u)
          if n and n ~= me then Radio(root, n, row, "ss", n) end
        end
      end),
    }
    win.rows[i] = row
  end

  local function Button(label, x, onClick)
    local b = WUK.Button(win, label, 120, onClick)
    b:SetPoint("BOTTOMLEFT", x, 14)
    return b
  end
  win.leadBtn = Button("Take lead", 14, WUK.ClaimLead)
  Button("Sync", 140, WUK.RequestSync)
  win.announceBtn = Button("Announce", 266, WUK.Announce)

  function win:Sync()
    local list = WUK.GroupWarlocks()
    for i, row in ipairs(self.rows) do
      row.warlock = list[i]
      row:SetShown(row.warlock ~= nil)
      if row.warlock then
        -- you in fel green, other warlocks in warlock purple
        row.name:SetText(row.warlock)
        if row.warlock == me then row.name:SetTextColor(unpack(WUK.THEME.accent)) else row.name:SetTextColor(0.58, 0.51, 0.79) end
        for _, dd in ipairs(row.dds) do dd:GenerateMenu(); dd:SetEnabled(WUK.IsLead()) end
      end
    end
    self.leadText:SetText("|TInterface\\GroupFrame\\UI-Group-LeaderIcon:0|t Lead: " .. (WUK.board.lead or (me .. " (local)")))
    self.leadBtn:SetShown(WUK.board.lead ~= me)
    self.announceBtn:SetShown(WUK.IsLead())
  end
  win:HookScript("OnShow", win.Sync) -- HookScript: keeps the skin's fade-in
  win:Hide()
end

function WUK.ToggleBoard()
  if not win then Build() end
  win:SetShown(not win:IsShown())
end

table.insert(WUK.inits, function()
  me = UnitName("player")
  local saved = WUK.char.board -- restore my own plan if I was lead before /reload
  if saved and IsInGroup() then WUK.board.lead, WUK.board.rev, WUK.board.rows = me, saved.rev or 0, saved.rows or {} end
  if IsInGroup() then WUK.RequestSync() end
  local wasInGroup = IsInGroup()
  WUK.On("GROUP_ROSTER_UPDATE", function()
    local inGroup = IsInGroup()
    if wasInGroup and not inGroup then
      WUK.board = { lead = nil, rev = 0, rows = {} }; WUK.char.board = nil; WUK.BoardChanged()
    elseif inGroup and not wasInGroup and WUK.RequestSync then WUK.RequestSync()
    elseif win and win:IsShown() then win:Sync() end
    wasInGroup = inGroup
  end)
end)

table.insert(WUK.refreshers, function()
  local text = WUK.AssignmentText(WUK.board.rows[me], MarkIcon)
  WUK.strip.assign:SetText(text)
  if lastText and text ~= lastText then WUK.Print("Your assignment: " .. text) end
  lastText = text
end)
