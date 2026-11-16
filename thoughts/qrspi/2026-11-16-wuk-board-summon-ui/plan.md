# Implementation Plan

## Overview
- **Summon queue**: holds only party/raid members, drops people who leave the group, and removes the row you clicked when Ritual of Summoning succeeds.
- **Shared warlock skin**: the summon panel, assignment board and settings window all use it (void purple, fel-green edge, purple title bar with a shard icon).
- **Placement**: board and settings get saved, side-by-side positions, and the board's dropdowns are readable.

Addon root is `WarlockUtilityKit/`. Run tests from the repo root:

```
lua5.1 WarlockUtilityKit/tests/run.lua
```

Deploy after each phase. Exit codes 0-7 mean success.

```
robocopy "D:\Source\wow-addons\WarlockUtilityKit" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WarlockUtilityKit" /MIR /XD tests /NJH /NJS /NP /NDL
```

---

## Phase 1: Summon queue: group-only + clicked-target removal

### Changes

#### 1. Pure helpers
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify. Add the helpers after `WUK.QueuePrune` (around line 66).

```lua
-- inGroup: set of group member names, or nil when membership is unknown (secret names) - then only TTL applies
function WUK.QueueKeep(r, now, ttl, inGroup)
  if now - (r.at or 0) >= ttl then return false end
  return inGroup == nil or inGroup[r.name] == true
end

-- the row the player clicked wins; a manual /cast falls back to the last spell target
function WUK.SummonTarget(pending, lastCast) return pending or lastCast end
```

#### 2. Tests
**File**: `WarlockUtilityKit/tests/run.lua`
**Action**: modify. Add the block before `print("all tests passed")`.

```lua
-- Board/summon UI: queue membership + removal target
local grp = { Ann = true }
eq(WUK.QueueKeep({ name = "Ann", at = 100 }, 150, 600, grp), true, "keep member")
eq(WUK.QueueKeep({ name = "Bob", at = 100 }, 150, 600, grp), false, "drop non-member")
eq(WUK.QueueKeep({ name = "Ann", at = 100 }, 700, 600, grp), false, "drop expired")
eq(WUK.QueueKeep({ name = "Bob", at = 100 }, 150, 600, nil), true, "unknown roster keeps")
eq(WUK.SummonTarget("Ann", "Bob"), "Ann", "clicked row wins")
eq(WUK.SummonTarget(nil, "Bob"), "Bob", "manual cast fallback")
eq(WUK.SummonTarget(nil, nil), nil, "no target")
```

#### 3. Summon wiring
**File**: `WarlockUtilityKit/Summon.lua`
**Action**: modify.

a. Add the state and roster set after line 5 (`local GroupUnits, UnitFull = ...`):

```lua
local pendingSummon -- name of the row last left-clicked; cleared when the ritual ends

-- set of group member names; nil if any name is secret (membership unknown - don't drop anyone)
local function GroupNames()
  local s = {}
  for _, u in ipairs(GroupUnits()) do
    local n = UnitFull(u)
    if not n then return nil end
    s[n] = true
  end
  return s
end
```

b. `OnChat`: after `if name == UnitName("player") then return end`, add:

```lua
  local group = GroupNames()
  if group and not group[name] then return end -- only queue party/raid members
```

c. In `WUK.UpdateSummonRows`:
   - Prune on every call, including in combat, because pruning touches data only.
   - Keep the lockdown return before any attribute write.
   - Hide the panel when the ritual is unknown.

Replace the function's first three lines with:

```lua
function WUK.UpdateSummonRows()
  local now, group = time(), GroupNames()
  WUK.QueuePrune(queue, function(r) return WUK.QueueKeep(r, now, TTL, group) end)
  if InCombatLockdown() then return end -- secure attributes: PLAYER_REGEN_ENABLED -> Refresh re-applies
```

Change the last line to:

```lua
  if queue[1] and WUK.known.ritual then panel:Show() else panel:Hide() end
```

d. In the row loop, after the `HookScript("OnClick", ...)`, add the PreClick. It is plain Lua and safe in combat:

```lua
    row:SetScript("PreClick", function(self, button)
      if button == "LeftButton" and not IsControlKeyDown() and self.name then pendingSummon = self.name end
    end)
```

e. Replace the `UNIT_SPELLCAST_SUCCEEDED` block (lines 89-93) with:

```lua
  local function IsRitual(unit, spellID)
    return unit == "player" and WUK.known.ritual and WUK.SpellName(spellID) == WUK.known.ritual
  end
  WUK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if not IsRitual(unit, spellID) then return end
    local t = WUK.SummonTarget(pendingSummon, WUK.lastCastTarget)
    pendingSummon = nil
    if t then WUK.QueueRemove(queue, Ambiguate(t, "none")); WUK.UpdateSummonRows() end
  end)
  for _, e in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
    WUK.On(e, function(unit, _, spellID) if IsRitual(unit, spellID) then pendingSummon = nil end end)
  end
```

### Verification
#### Automated
- [x] `lua5.1 WarlockUtilityKit/tests/run.lua` prints `all tests passed` (ran with installed `lua` 5.4; `luac -p` clean on all files)
- [x] Deploy with robocopy (exit code 0-7)

#### Manual (Forever, `/reload`)
- [ ] Out of the group, a guild member types "123": the summon panel does not appear.
- [ ] After you invite them, "123" in guild or whisper adds their row.
- [ ] The queued member leaves the group: their row disappears.
- [ ] Click a row, cast any other spell, then cast the ritual and let it succeed: the clicked row is removed and no other row is.
- [ ] Click a row and move to interrupt the ritual: the row stays.
- [ ] Record whether the row disappears when the portal is placed or when the summon completes. If it never disappears, the ritual's `UNIT_SPELLCAST_SUCCEEDED` does not fire on Forever. Report that before continuing.

---

## Phase 2: Shared skin + summon panel restyle

### Changes

#### 1. Theme, skin and header helpers
**File**: `WarlockUtilityKit/UI.lua`
**Action**: modify. Add after the `FALLBACK`/constant block (around line 11), before `WUK.MakeMovable`.

```lua
-- warlock window theme: void purple body, fel-green edge + accents, purple title bar (strip palette, UI rim/disc)
WUK.THEME = {
  bg = { 0.04, 0, 0.07, 0.92 }, edge = { 0.45, 0.85, 0.3, 0.9 },
  bar = { 0.25, 0.12, 0.38, 1 }, barEnd = { 0.08, 0.02, 0.12, 1 },
  accent = { 0.45, 0.85, 0.3 }, text = { 0.85, 0.8, 0.95 },
}

-- f must inherit BackdropTemplate; returns the title FontString
function WUK.Skin(f, title, opts)
  local T = WUK.THEME
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  f:SetBackdropColor(unpack(T.bg)); f:SetBackdropBorderColor(unpack(T.edge))
  local bar = f:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("TOPRIGHT", -1, -1); bar:SetHeight(22)
  bar:SetColorTexture(1, 1, 1, 1)
  if bar.SetGradient and CreateColor then
    bar:SetGradient("HORIZONTAL", CreateColor(unpack(T.bar)), CreateColor(unpack(T.barEnd)))
  else bar:SetVertexColor(unpack(T.bar)) end
  local icon = f:CreateTexture(nil, "OVERLAY")
  icon:SetSize(16, 16); icon:SetPoint("LEFT", bar, "LEFT", 4, 0)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02")
  local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("LEFT", icon, "RIGHT", 5, 0); text:SetTextColor(unpack(T.accent)); text:SetText(title)
  if opts and opts.close then
    local c = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    c:SetSize(24, 24); c:SetPoint("TOPRIGHT", 0, 0)
  end
  f.titleBar, f.titleText = bar, text
  return text
end

function WUK.Header(parent, text, x, y)
  local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  h:SetPoint("TOPLEFT", x, y); h:SetTextColor(unpack(WUK.THEME.accent)); h:SetText(text)
  return h
end
```

#### 2. Summon panel restyle
**File**: `WarlockUtilityKit/Summon.lua`
**Action**: modify.

a. **`Context`**: record the class for colouring. After `ctx.inGroup = true`, add:

```lua
  ctx.class = select(2, UnitClass(target)) -- classFilename is never secret (Core.lua GroupWarlocks)
```

b. **Panel build** in the init. Replace the `SetSize`, `SetBackdrop` and `title` lines (`:68-71`) with:

```lua
  panel:SetSize(300, 28 + MAX * 20)
  local title = WUK.Skin(panel, "Summons")
  -- title-bar hit area: tooltip with the click help, forwards drags to the panel (MakeMovable rules)
  local hit = CreateFrame("Frame", nil, panel)
  hit:SetAllPoints(panel.titleBar); hit:EnableMouse(true); hit:RegisterForDrag("LeftButton")
  hit:SetScript("OnDragStart", function() panel:GetScript("OnDragStart")(panel) end)
  hit:SetScript("OnDragStop", function() panel:GetScript("OnDragStop")(panel) end)
  hit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Summon queue")
    GameTooltip:AddLine("Click: summon   Ctrl-click: target   Right-click: remove", 1, 1, 1)
    GameTooltip:AddLine("Shift-drag: move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  hit:SetScript("OnLeave", GameTooltip_Hide)
```

   - `hit` must be created **after** `WUK.MakeMovable(panel, ...)`, so that `panel:GetScript("OnDragStart")` exists. Move the `MakeMovable` line above this block.
   - Store `panel.title = title`.

c. **Row anchor**: `row:SetPoint("TOPLEFT", 6, -26 - (i - 1) * 20)`. The rows start below the 22 px bar.

d. In `UpdateSummonRows`, in the row text line, colour the name by class:

```lua
      local c = ctx.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[ctx.class]
      local shown = c and ("|c" .. c.colorStr .. r.name .. "|r") or r.name
      row.text:SetText(shown .. "  |cffaaaaaa" .. (zone or "?") .. "|r  |cffff6060" .. (WUK.SummonFailure(ctx) or "") .. "|r")
```

e. At the end of `UpdateSummonRows`, before the show/hide line, add:

```lua
  panel.title:SetText("Summons (" .. #queue .. ")")
  panel:SetHeight(28 + math.max(1, math.min(#queue, MAX)) * 20)
```

### Verification
#### Automated
- [ ] `lua5.1 WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [ ] Deploy with robocopy

#### Manual
- [ ] With a groupmate queued, the panel has a dark purple body, a green 1 px edge, and a purple title bar with the shard icon reading "Summons (1)".
- [ ] The panel height fits the rows.
- [ ] Hovering the title bar shows the click-help tooltip.
- [ ] Names are class-coloured, the zone is grey and the failure reason is red.
- [ ] Shift-dragging the title bar or the body moves the panel, and `/wuk lock` prevents it.
- [ ] Click, ctrl-click and right-click still summon, target and remove.

---

## Phase 3: Assignment board restyle + layout

### Changes

#### 1. `MakeMovable` free mode
**File**: `WarlockUtilityKit/UI.lua`
**Action**: modify `WUK.MakeMovable` (line 13).

```lua
-- free = dialog window: plain drag, ignores the lock, clamped on screen
function WUK.MakeMovable(f, key, x, y, free)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  if free then f:SetClampedToScreen(true) end
  f:SetScript("OnDragStart", function(self)
    if free or (IsShiftKeyDown() and not WUK.db.locked and not InCombatLockdown()) then self:StartMoving() end
  end)
  -- OnDragStop and position restore unchanged
```

#### 2. Board build
**File**: `WarlockUtilityKit/Board.lua`
**Action**: modify `Build()` (lines 96-144).

- Frame:

```lua
  win = CreateFrame("Frame", "WUKBoard", UIParent, "BackdropTemplate")
  win:SetSize(560, 110 + MAX_ROWS * 28); win:SetFrameStrata("DIALOG")
  WUK.Skin(win, "Warlock Assignments", { close = true })
  WUK.MakeMovable(win, "board", -180, 0, true)
  tinsert(UISpecialFrames, "WUKBoard")
  win.leadText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  win.leadText:SetPoint("TOPLEFT", 14, -30); win.leadText:SetTextColor(unpack(WUK.THEME.text))
  WUK.Header(win, "Warlock", 14, -50); WUK.Header(win, "Curse", 124, -50)
  WUK.Header(win, "Banish", 270, -50); WUK.Header(win, "Soulstone", 396, -50)
```

- Remove:
  - the old `SetPoint("CENTER")`
  - the old `SetMovable`/`EnableMouse`/`RegisterForDrag`/drag scripts
  - the old title FontString, since `Skin` draws the title
- Rows: `row:SetSize(532, 26); row:SetPoint("TOPLEFT", 14, -66 - (i - 1) * 28)`, `row.name:SetWidth(106)`.
- Dropdowns: `Dropdown(row, 110, 140, ...)`, `Dropdown(row, 256, 120, ...)`, `Dropdown(row, 382, 150, ...)`. The column headers sit at `14 + x`.
- Buttons: `b:SetSize(120, 22)`. "Take lead" goes at x=14, "Sync" at 140 and "Announce" at 266.

### Verification
#### Automated
- [ ] `lua5.1 WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [ ] Deploy with robocopy

#### Manual
- [ ] Right-click the minimap button: the board shows the themed frame, with the green headers Warlock / Curse / Banish / Soulstone above their columns.
- [ ] "No curse", "No banish" and "No soulstone" show untruncated.
- [ ] Dropdown menus open on top of the board, and selections still sync to another WUK warlock.
- [ ] A plain drag moves the board. After `/reload` it reopens where it was left.
- [ ] Escape and the X button both close it.
- [ ] The Take lead / Sync / Announce buttons work and are evenly spaced.

---

## Phase 4: Settings restyle + sections + placement

### Changes

#### 1. Settings build
**File**: `WarlockUtilityKit/Settings.lua`
**Action**: modify.

a. **`Check` helper**: after `text:SetText(label)`, add `text:SetTextColor(unpack(WUK.THEME.text))`.

b. **`Build()` frame**: replace lines 18-24 with:

```lua
  win = CreateFrame("Frame", "WUKSettings", UIParent, "BackdropTemplate")
  win:SetSize(320, 336); win:SetFrameStrata("DIALOG")
  WUK.Skin(win, "Warlock Utility Kit", { close = true })
  WUK.MakeMovable(win, "settings", 280, 0, true) -- right of the board default (-180): no overlap
  tinsert(UISpecialFrames, "WUKSettings") -- Escape closes it
```

c. **Sections**: re-lay out the controls. The getters and setters stay the same.

```lua
  WUK.Header(win, "Strip & ring", 16, -32)
  local checks = {
    Check(win, "Show strip", -46, ...),                               -- same get/onClick as today
    Check(win, "Spin ring", -72, ...),
    Check(win, "Collapse ring until hover", -98, ...),
    Check(win, "Dock Blizzard cooldown timers under strip", -124, ...),
  }
  WUK.Header(win, "Pet", 16, -162)
  -- preferred pet dropdown: dd:SetPoint("TOPLEFT", 18, -178); remove the old "Preferred pet" label
  WUK.Header(win, "Frames", 16, -218)
  checks[#checks + 1] = Check(win, "Lock frames (no Shift+drag)", -232, ...)
```

   - The Reset positions and Assignment board buttons stay at `BOTTOMLEFT 16,16` and `BOTTOMRIGHT -16,16`.
   - `win:Sync` is unchanged, because it iterates `checks`.

#### 2. Version and changelog
**File**: `WarlockUtilityKit/WarlockUtilityKit.toc`
**Action**: modify. Set `## Version: 0.4.0`.

**File**: `WarlockUtilityKit/CHANGELOG.md`
**Action**: modify. Add above `## [0.3.3]`:

```markdown
## [0.4.0] — 2026-11-16

### Changed
- **Warlock look for the summon queue, assignment board and settings.** All three use one dark void-purple window with a fel-green edge and a purple title bar.
- **Summon queue panel.** Short "Summons (n)" title, click help on hover, class-coloured names, height fits the queue.
- **Assignment board.** Column headers, wider dropdowns so labels fit, remembers its position.
- **Settings.** Grouped into Strip & ring / Pet / Frames, opens beside the board instead of on top of it, remembers its position.

### Fixed
- **Summon queue only holds group members.** Requests from people outside your party or raid are ignored, and people who leave the group drop off the queue.
- **Successful summons leave the queue.** The row you clicked is removed when Ritual of Summoning succeeds, even if you cast something else in between; a failed or interrupted ritual keeps it.
```

### Verification
#### Automated
- [ ] `lua5.1 WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [ ] Deploy with robocopy

#### Manual
- [ ] Left-click the minimap button: settings shows the themed frame with the green sections Strip & ring / Pet / Frames.
- [ ] Each checkbox toggles its setting, with the matching chat message.
- [ ] The pet dropdown changes the preferred pet.
- [ ] Reset positions and Assignment board both work.
- [ ] Open settings, then the board (fresh positions): they sit side by side without overlapping.
- [ ] `/reload` keeps both positions.
- [ ] "Reset positions" plus `/reload` brings back the side-by-side defaults.
- [ ] The addon list shows version 0.4.0.
