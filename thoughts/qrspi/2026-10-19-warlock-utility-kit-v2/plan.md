# Implementation Plan

## Overview
Add the v2 features to `WarlockUtilityKit/`:
- a `/wuk probe` command for in-game secrecy and lockdown facts;
- a curse / banish-mark / soulstone-target assignment board, with your own row shown on the strip and driving the soulstone button;
- lead-authoritative sync over addon messages;
- an Announce button.

DoT timers are deferred until the probe results are in.

## Conventions
- **Namespace:** every file starts `local ADDON, WUK = ...`.
- **Pure code:** only in `Logic.lua`, tested by `tests/run.lua`.
- **Lua compatibility:** code must run under both 5.1 and 5.4.
- **Where to register:** events go through `WUK.On` inside `WUK.inits`, so they only run for warlocks. Strip and stone updates go in `WUK.refreshers`.
- **Secure attributes:** set only out of combat. Board frames are insecure, so they need no combat gating.
- **Test command (repo root):** `lua WarlockUtilityKit/tests/run.lua` must print `all tests passed`. Lua is at `C:\Users\madac\AppData\Local\Programs\Lua\bin`, so add it to PATH in PowerShell.
- **Syntax check:** `lua -e "assert(loadfile([[<file>]]))"` for every `.lua` file.
- **Deploy after every phase (implementer does it, before handing over for manual checks):**
  ```powershell
  robocopy "D:\Source\wow-addons\WarlockUtilityKit" "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\WarlockUtilityKit" /MIR /XD tests /NJH /NJS /NP /NDL
  ```
  Robocopy exit codes 0-7 mean success. The user then runs `/reload` in game.
- **Branch:** work on `wuk-v2` (create it from `main`), with one commit per phase.

---

## Phase 1: `/wuk probe`

### Changes

#### 1. Probe command
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify. Add the function after `WUK.SpellName`, and a slash branch before `config`.

```lua
local PROBE_SPELLS = { "Curse of Agony", "Curse of Doom", "Bane of Agony", "Bane of Doom", "Corruption", "Immolate",
  "Curse of the Elements", "Curse of Recklessness", "Curse of Shadow", "Banish" }

-- prints in-game facts about secrets/lockdown; output gets pasted back for v3 timer planning
function WUK.Probe()
  local function P(k, v) WUK.Print(k .. ": " .. tostring(v)) end
  local function S(v) if WUK.Secret(v) then return "SECRET" end return tostring(v) end
  local inInst, kind = IsInInstance()
  P("instance", tostring(inInst) .. " " .. tostring(kind))
  P("combat", InCombatLockdown())
  P("chat lockdown", C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or "n/a")
  for _, n in ipairs(PROBE_SPELLS) do
    local ok, lvl = pcall(C_Secrets.GetSpellAuraSecrecy, n)
    P("secrecy " .. n, ok and S(lvl) or "n/a")
  end
  if not UnitExists("target") then return P("target", "none") end
  P("target hostile", UnitCanAttack("player", "target"))
  P("raid mark", S(GetRaidTargetIndex("target")))
  local ok, auras = pcall(C_UnitAuras.GetUnitAuras, "target", "HARMFUL|PLAYER")
  if not ok then return P("GetUnitAuras error", auras) end
  if not auras or WUK.Secret(auras) then return P("my debuffs", auras and "SECRET table" or "nil") end
  P("my debuffs", #auras)
  for _, a in ipairs(auras) do
    local okD, dur = pcall(C_UnitAuras.GetAuraDuration, "target", a.auraInstanceID)
    P("  aura", S(a.name) .. " id=" .. S(a.spellId) .. " exp=" .. S(a.expirationTime)
      .. " durationObj=" .. tostring(okD and dur ~= nil))
  end
end
```
Slash branch: `elseif cmd == "probe" then WUK.Probe()`. Add `probe` to the usage string.

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [x] Every `.lua` file passes the syntax check

#### Manual
- [x] Deployed to AddOns (Phase 1 was copied by the user)
- [x] `/wuk probe` with no target prints the instance/combat/lockdown/secrecy lines and "target: none", with no Lua errors
- [x] With a mob you've cursed in the open world, out of combat and then in combat, it lists your debuffs (or SECRET)
- [ ] (skipped: not needed after the in-combat result, see probe-results.md) Inside a dungeon it runs without errors
- [x] Paste the output into `thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md` for v3

---

## Phase 2: Local board, my assignment, soulstone target

### Changes

#### 1. Pure helpers
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify (append, and extend `StoneMacro`)

```lua
WUK.CURSES = {
  { key = "elements", name = "Curse of the Elements", short = "Elements" },
  { key = "recklessness", name = "Curse of Recklessness", short = "Recklessness" },
  { key = "tongues", name = "Curse of Tongues", short = "Tongues" },
  { key = "weakness", name = "Curse of Weakness", short = "Weakness" },
  { key = "exhaustion", name = "Curse of Exhaustion", short = "Exhaustion" },
  { key = "shadow", name = "Curse of Shadow", short = "Shadow" }, -- may not exist on Forever; board lists it only if known
}
local CURSE_BY_KEY = {}
for _, c in ipairs(WUK.CURSES) do CURSE_BY_KEY[c.key] = c end
function WUK.CurseInfo(key) return CURSE_BY_KEY[key] end

function WUK.MarkToken(mark)
  if type(mark) == "number" and mark >= 1 and mark <= 8 then return "{rt" .. mark .. "}" end
  return ""
end

-- markFmt: MarkToken for chat, a texture-escape function for FontStrings
function WUK.AssignmentText(row, markFmt)
  if not row then return "No assignment" end
  markFmt = markFmt or WUK.MarkToken
  local parts = {}
  if row.curse then local c = CURSE_BY_KEY[row.curse]; parts[#parts + 1] = c and c.short or row.curse end
  if (row.mark or 0) > 0 then parts[#parts + 1] = "Banish " .. markFmt(row.mark) end
  if row.ss then parts[#parts + 1] = "SS: " .. row.ss end
  if #parts == 0 then return "No assignment" end
  return table.concat(parts, "  ")
end

function WUK.NextRev(rev, now) return math.max(now, (rev or 0) + 1) end
```
`StoneMacro` gets a 5th parameter `ssTarget`. Change the soulstone line to:
```lua
if kind == "soulstone" then
  if ssTarget then return "/use [@" .. ssTarget .. "] item:" .. itemID end
  return "/use [help] item:" .. itemID .. "; [@player] item:" .. itemID
end
```

#### 2. Shared group helpers
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify. Move `GroupUnits` and `UnitFull` here from Summon.lua as `WUK.GroupUnits` / `WUK.UnitFull` (same bodies), and add:
```lua
function WUK.GroupWarlocks()
  local me = UnitName("player")
  local list = { me }
  for _, u in ipairs(WUK.GroupUnits()) do
    local n, class = WUK.UnitFull(u), select(2, UnitClass(u)) -- classFilename is never secret
    if n and n ~= me and class == "WARLOCK" then list[#list + 1] = n end
  end
  table.sort(list)
  return list
end
```
Add `curseshadow = { "Curse of Shadow" }` to `SPELLS`. Slash branches:
- `elseif cmd == "board" then WUK.ToggleBoard()`
- `elseif cmd == "lead" then WUK.ClaimLead()`

Add both to the usage string.

**File**: `WarlockUtilityKit/Summon.lua`
**Action**: modify. Delete the local `GroupUnits` / `UnitFull` definitions (lines 5-16) and replace them with `local GroupUnits, UnitFull = WUK.GroupUnits, WUK.UnitFull`. Core loads first, so the names already exist.

#### 3. Board state + window + strip line
**File**: `WarlockUtilityKit/Board.lua`
**Action**: create

```lua
local ADDON, WUK = ...
local MAX_ROWS = 10
local MARKS = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local me, win, rows, lastText

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
  if WUK.SendFullBoard then WUK.SendFullBoard() end -- Phase 3
  SaveIfLead(); WUK.BoardChanged()
end

function WUK.SetAssignment(warlock, field, value)
  local b = WUK.board
  if not WUK.IsLead() then return end
  if b.lead == nil then b.lead = me end
  local row = b.rows[warlock] or { mark = 0 }
  row[field] = value
  b.rows[warlock] = row
  b.rev = WUK.NextRev(b.rev, time())
  if WUK.SendRow then WUK.SendRow(warlock) end -- Phase 3
  SaveIfLead(); WUK.BoardChanged()
end
```

Window: lazy-built, modeled on `Settings.lua` `Build()`.
- Frame: `"WUKBoard"`, `BasicFrameTemplateWithInset`, 470 x (90 + MAX_ROWS*28), DIALOG strata, draggable, in `UISpecialFrames`.
- Title "Warlock Assignments". `win.leadText` FontString at TOPLEFT (16,-30).
- Each of `MAX_ROWS` rows has:
  - a name FontString (width 100);
  - three `WowStyle1DropdownTemplate` dropdowns at x = 120 / 250 / 350, widths 120 / 90 / 110.

  Dropdown menus resolve `row.warlock` when they open:
```lua
local function Radio(root, label, get, val, warlock, field)
  root:CreateRadio(label, function() return get() == val end, function() WUK.SetAssignment(warlock(), field, val) end)
end
-- curse
dd:SetupMenu(function(_, root)
  local w = function() return row.warlock end
  local get = function() local r = WUK.board.rows[row.warlock]; return r and r.curse end
  Radio(root, "None", get, nil, w, "curse")
  for _, c in ipairs(WUK.CURSES) do
    if c.key ~= "shadow" or WUK.known.curseshadow then Radio(root, c.short, get, c.key, w, "curse") end
  end
end)
-- mark: "None" -> 0, then MarkIcon(i) .. " " .. MARKS[i] -> i
-- ss: "None" -> nil, then UnitName("player") and each WUK.UnitFull(u) for u in WUK.GroupUnits()
```
`CreateRadio` with a nil value: `get() == nil` is selected for "None", which is the intended behavior.

- `win:Sync()`:
  - `list = WUK.GroupWarlocks()`;
  - for each row i, set `row.warlock = list[i]`, show or hide the row, and set the name text;
  - for each dropdown: `dd:GenerateMenu()` and `dd:SetEnabled(WUK.IsLead())`;
  - `win.leadText:SetText("Lead: " .. (WUK.board.lead or (me .. " (local)")))`.
- Bottom buttons (`UIPanelButtonTemplate`):
  - "Take lead" calls `WUK.ClaimLead()` and is hidden when you are already lead;
  - Phase 3 adds "Sync" and Phase 4 adds "Announce".
- `win:SetScript("OnShow", win.Sync)`. `WUK.ToggleBoard()` builds the window lazily and toggles it.

Init + refresher:
```lua
table.insert(WUK.inits, function()
  me = UnitName("player")
  local saved = WUK.char.board -- restore my own plan if I was lead before /reload
  if saved and IsInGroup() then WUK.board.lead, WUK.board.rev, WUK.board.rows = me, saved.rev or 0, saved.rows or {} end
  local wasInGroup = IsInGroup()
  WUK.On("GROUP_ROSTER_UPDATE", function()
    local inGroup = IsInGroup()
    if wasInGroup and not inGroup then
      WUK.board = { lead = nil, rev = 0, rows = {} }; WUK.char.board = nil; WUK.BoardChanged()
    elseif inGroup and not wasInGroup and WUK.RequestSync then WUK.RequestSync() -- Phase 3
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
```
Note: when solo (not in a group), the saved board is not restored, which avoids a stale plan. Solo edits still work and are kept for the session.

#### 4. Strip layout + soulstone target
**File**: `WarlockUtilityKit/UI.lua`
**Action**: modify
- Strip height 62 becomes 76: `f:SetSize(4 + 7 * 40, 76)`.
- `f.stone` moves to `BOTTOMLEFT, 6, 20`.
- Add `f.assign = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.assign:SetPoint("BOTTOMLEFT", 6, 6)`.
- Change the refresher's macro line to:
  ```lua
  b:SetAttribute("macrotext", WUK.StoneMacro(kind, c[kind], id, WUK.known[kind], kind == "soulstone" and WUK.MySoulstoneTarget() or nil) or "")
  ```

#### 5. Settings access
**File**: `WarlockUtilityKit/Settings.lua`
**Action**: modify
- Add an "Assignment board" button (`UIPanelButtonTemplate`, 130x22, `BOTTOMRIGHT, -16, 16`) that runs `Run("board")`.
- Minimap button: add `b:RegisterForClicks("LeftButtonUp", "RightButtonUp")`, and change the click handler to `b:SetScript("OnClick", function(_, button) if button == "RightButton" then WUK.ToggleBoard() else WUK.ToggleSettings() end end)`.
- Tooltip line: `"Click: settings   Right-click: board   Drag: move"`.

#### 6. TOC
**File**: `WarlockUtilityKit/WarlockUtilityKit.toc`
**Action**: modify. Insert `Board.lua` after `Trade.lua` and before `Settings.lua`, and bump `## Version: 0.2.0` so CI publishes a new release.

#### 7. Tests
**File**: `WarlockUtilityKit/tests/run.lua`
**Action**: modify. Insert before `print`:
```lua
-- v2 Phase 2
eq(WUK.MarkToken(1), "{rt1}", "mark 1"); eq(WUK.MarkToken(8), "{rt8}", "mark 8"); eq(WUK.MarkToken(0), "", "mark none")
eq(WUK.AssignmentText(nil), "No assignment", "no row")
eq(WUK.AssignmentText({ mark = 0 }), "No assignment", "empty row")
eq(WUK.AssignmentText({ curse = "elements", mark = 1, ss = "Healbot" }), "Elements  Banish {rt1}  SS: Healbot", "full row")
eq(WUK.AssignmentText({ curse = "mystery", mark = 0 }), "mystery", "unknown curse key shown raw")
eq(WUK.StoneMacro("soulstone", 1, 16893, nil, "Healbot"), "/use [@Healbot] item:16893", "ss on assigned target")
eq(WUK.NextRev(5, 3), 6, "rev bumps"); eq(WUK.NextRev(5, 100), 100, "rev uses clock")
```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [x] Every `.lua` file passes the syntax check

#### Manual
- [x] Deployed to AddOns with robocopy
- [x] `/wuk board`, the Settings button and right-clicking the minimap button all open the board; you are listed (plus any party warlocks)
- [x] Setting curse, mark and SS on your row updates the strip line (raid icon shown) and prints "Your assignment: ..."
- [x] With SS set to a party member, the soulstone icon click soulstones them
- [x] In a party, the board survives `/reload` (lead copy); after leaving the group it clears
- [x] The summon queue still works ("123" from a party member makes a row), confirming the helper move

---

## Phase 3: Lead-authoritative sync

### Changes

#### 1. Protocol (pure)
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify (append)
```lua
local PROTO = "1"
local function enc(v) if v == nil or v == "" then return "-" end return tostring(v) end
local function dec(s) if s == "-" then return nil end return s end

-- 1|L|rev  1|A|rev|warlock|curse|mark|ss  1|R  1|E|rev ; "-" = nil
function WUK.Encode(kind, ...)
  local parts = { PROTO, kind }
  for i = 1, select("#", ...) do parts[#parts + 1] = enc((select(i, ...))) end
  return table.concat(parts, "|")
end

function WUK.Decode(msg)
  if type(msg) ~= "string" then return nil end
  local f = {}
  for p in (msg .. "|"):gmatch("(.-)|") do f[#f + 1] = p end
  if f[1] ~= PROTO then return nil end
  local kind = f[2]
  if kind == "R" and #f == 2 then return { kind = "R" } end
  if (kind == "L" or kind == "E") and #f == 3 and tonumber(f[3]) then return { kind = kind, rev = tonumber(f[3]) } end
  if kind == "A" and #f == 7 and tonumber(f[3]) and tonumber(f[6]) and dec(f[4]) then
    return { kind = "A", rev = tonumber(f[3]), warlock = f[4], curse = dec(f[5]), mark = tonumber(f[6]), ss = dec(f[7]) }
  end
  return nil
end

function WUK.AcceptLead(board, rev) return rev > (board.rev or 0) end
function WUK.AcceptRow(board, sender, rev) return sender == board.lead and rev >= (board.rev or 0) end
```

#### 2. Transport
**File**: `WarlockUtilityKit/Comm.lua`
**Action**: create
```lua
local ADDON, WUK = ...
local PREFIX = "WUKB"
local queue, nextSend, failures, warned = {}, 0, 0, false

local function Channel()
  if IsInRaid() then return "RAID" elseif IsInGroup() then return "PARTY" end
end

-- ponytail: one shared 0.5s pace (GuildStock-style); a per-prefix token bucket if boards grow past ~20 rows
local function Flush()
  if #queue == 0 or GetTime() < nextSend then return end
  local ch = Channel()
  if not ch then wipe(queue); return end
  local result = C_ChatInfo.SendAddonMessage(PREFIX, queue[1], ch)
  if result == 0 or result == true then
    table.remove(queue, 1); failures = 0; nextSend = GetTime() + 0.5
  else -- throttle, lockdown (11), trial account, ...
    failures = failures + 1; nextSend = GetTime() + math.min(30, 2 ^ failures)
    if not warned then warned = true; WUK.Print("board sync unavailable (code " .. tostring(result) .. "); board works locally") end
    if failures >= 3 then wipe(queue); failures = 0 end
  end
end

function WUK.Send(msg) if Channel() and #queue < 64 then queue[#queue + 1] = msg end end

table.insert(WUK.inits, function()
  C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  C_Timer.NewTicker(0.25, Flush)
  WUK.On("CHAT_MSG_ADDON", function(prefix, text, _, sender)
    if prefix ~= PREFIX or WUK.Secret(text) or WUK.Secret(sender) then return end
    local name = Ambiguate(sender, "none")
    if name == UnitName("player") then return end
    local m = WUK.Decode(text)
    if m and WUK.OnBoardMessage then WUK.OnBoardMessage(name, m) end
  end)
end)
```
TOC: insert `Comm.lua` after `Trade.lua`, so the order is Trade, Comm, Board, Settings.

#### 3. Board wiring
**File**: `WarlockUtilityKit/Board.lua`
**Action**: modify (append)
```lua
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
```
- **Login:** in the Board init, after the restore, call `if IsInGroup() then WUK.RequestSync() end`.
- **Sync button:** add a "Sync" bottom button that calls `WUK.RequestSync()`.

#### 4. Tests
Append to `tests/run.lua`:
```lua
-- v2 Phase 3
local m = WUK.Decode(WUK.Encode("A", 12, "Lockone", "elements", 3, nil))
eq(m.kind, "A", "decode A"); eq(m.rev, 12, "rev"); eq(m.warlock, "Lockone", "warlock")
eq(m.curse, "elements", "curse"); eq(m.mark, 3, "mark"); eq(m.ss, nil, "ss nil")
eq(WUK.Encode("A", 12, "Lockone", nil, 0, nil), "1|A|12|Lockone|-|0|-", "encode nils")
eq(WUK.Decode(WUK.Encode("R")).kind, "R", "decode R")
eq(WUK.Decode(WUK.Encode("L", 7)).rev, 7, "decode L")
eq(WUK.Decode("2|L|7"), nil, "bad version"); eq(WUK.Decode("1|A|x|a|b|0|-"), nil, "bad rev")
eq(WUK.Decode("1|A|5|-|b|0|-"), nil, "no warlock"); eq(WUK.Decode(nil), nil, "nil msg")
local brd = { lead = "Lead", rev = 10, rows = {} }
eq(WUK.AcceptRow(brd, "Other", 11), false, "non-lead row"); eq(WUK.AcceptRow(brd, "Lead", 9), false, "old row")
eq(WUK.AcceptRow(brd, "Lead", 10), true, "same rev ok")
eq(WUK.AcceptLead(brd, 10), false, "stale claim"); eq(WUK.AcceptLead(brd, 11), true, "newer claim")
```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [x] Every `.lua` file passes the syntax check

#### Manual (two warlocks in a party, both running WUK)
> **DEFERRED (2026-10-19):** needs a second warlock running WUK; verify before release.
- [x] Deployed to AddOns with robocopy
- [ ] (deferred) A clicks Take lead; B's board shows "Lead: A" and B's dropdowns are disabled
- [ ] (deferred) A sets B to Elements + Star + SS on A; within ~1s B's board and strip update and B gets the chat line
- [ ] (deferred) B `/reload`s; the board comes back after login, via R and full sync
- [ ] (deferred) B takes lead; A's dropdowns disable, and B's edits reach A
- [ ] (deferred) On a trial account, or with `/console addonChatRestrictionsForced 1`: at most one "board sync unavailable" warning, no Lua errors, and the local board still edits

---

## Phase 4: Announce

### Changes

#### 1. Lines (pure)
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify (append)
```lua
function WUK.AnnounceLines(board)
  local names = {}
  for n, r in pairs(board.rows) do
    if r.curse or (r.mark or 0) > 0 or r.ss then names[#names + 1] = n end
  end
  table.sort(names)
  local out = {}
  for _, n in ipairs(names) do
    local r, parts = board.rows[n], { "WUK: " .. n }
    if r.curse then local c = CURSE_BY_KEY[r.curse]; parts[#parts + 1] = c and c.name or r.curse end
    if (r.mark or 0) > 0 then parts[#parts + 1] = "Banish " .. WUK.MarkToken(r.mark) end
    if r.ss then parts[#parts + 1] = "SS: " .. r.ss end
    out[#out + 1] = table.concat(parts, " - ")
  end
  return out
end
```

#### 2. Announce button
**File**: `WarlockUtilityKit/Board.lua`
**Action**: modify
```lua
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
```
Add an "Announce" bottom button, shown only when `WUK.IsLead()` (its visibility is updated in `win:Sync`).

#### 3. Tests
```lua
-- v2 Phase 4
local lines = WUK.AnnounceLines({ rows = {
  Zed = { curse = "tongues", mark = 0 }, Abe = { curse = "elements", mark = 1, ss = "Healbot" }, Mia = { mark = 0 } } })
eq(#lines, 2, "skips empty"); eq(lines[1], "WUK: Abe - Curse of the Elements - Banish {rt1} - SS: Healbot", "abe line")
eq(lines[2], "WUK: Zed - Curse of Tongues", "zed line")
```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [x] Every `.lua` file passes the syntax check

#### Manual
- [x] Deployed to AddOns with robocopy
- [ ] In a party, the lead's Announce posts one line per assigned warlock in party chat, with raid icons
- [ ] In a raid as leader or assistant, the lines appear as raid warnings; as a plain member, in raid chat
- [ ] Non-leads see no Announce button
- [ ] Solo, Announce prints the lines locally

---

## Phase 5: Dock Blizzard Cooldown Manager under the strip (added after the probe; see probe-results.md)
The addon cannot read DoT or curse timers in combat. Blizzard's Cooldown Manager draws them, though, and its frames are reachable. This phase anchors those frames to the WUK strip.

### Changes
- **`Core.lua`**: add `dockViewers = false` to `DEFAULTS`. The `/wuk dock` slash command toggles it (refused in combat).
- **New `Dock.lua`** (TOC: after Board.lua):
```lua
local ADDON, WUK = ...
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
```
- **Undocking** needs `/reload` so that Edit Mode restores its own layout. The command prints this.
- **`Settings.lua`**: add a "Dock Blizzard cooldown timers under strip" checkbox that runs `Run("dock")`.

### Verification
#### Automated
- [ ] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [ ] Every `.lua` file passes the syntax check

#### Manual
- [ ] Deployed to AddOns with robocopy
- [ ] With the Cooldown Manager on, `/wuk dock` puts the Essential viewer (Corruption, Immolate, Curses) and the Buff viewer under the strip; moving the strip moves them
- [ ] In combat the docked timers count down and there is no "Lua Taint: WarlockUtilityKit" error
- [ ] Opening and closing Edit Mode doesn't leave them stuck elsewhere
- [ ] `/wuk dock` again, then `/reload`, restores the Edit Mode position

---

## Final checks
- [ ] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [ ] `git status` shows changes only under `WarlockUtilityKit/` and `thoughts/`
- [ ] Open a PR from `wuk-v2`; after merge, CI publishes release `wuk-v0.2.0`
