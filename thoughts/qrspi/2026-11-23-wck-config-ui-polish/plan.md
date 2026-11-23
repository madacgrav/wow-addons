# Implementation Plan

## Overview
- The WCK settings window (`/wck config`, minimap left-click, rotation core right-click) becomes a themed, fixed-size window, about 460x520, in WarlockUtilityKit's purple and fel look.
- It has four flat tabs: General, Rotation, Cast slots, Alt clicks.
- It remembers its position and its last tab.
- Rule rows get spell icons and icon buttons. Every control gets a tooltip, and each tab gets a hint line.
- DB fields and behavior stay the same, apart from one new default, `settingsTab`.

**Conventions (all phases)**
- Tests: run `lua WarlockCombatKit/tests/run.lua` from the repo root. It must print `all tests passed`.
- Syntax: run `luac -p WarlockCombatKit/*.lua`. It must print nothing.
- Lint: run `luacheck WarlockCombatKit --globals WCK` if it runs cleanly before your change. Treat only new warnings as failures.
- Deploy after each phase, before asking for an in-game check (exit codes 0-7 are success):
  `robocopy "D:\Source\wow-addons\WarlockCombatKit" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WarlockCombatKit" /MIR /XD tests /NJH /NJS /NP /NDL`
- Keep these as they are:
  - the `win.syncs` / `win:Sync()` OnShow model;
  - every DB write, `WCK.Refresh()` call and "applies after combat" print in the current `Settings.lua`;
  - the minimap button block (`Settings.lua:211-248`).
- No Ace3, no new libraries, no edits to WarlockUtilityKit.

**Layout constants (Settings.lua)**
- `W, H = 460, 520`. Title bar 22px, from `WCK.Skin`.
- Tab strip at y=-28, tabs 22px high. Page frames span TOPLEFT `0,-56` to BOTTOMRIGHT `0,0`.
- Inside a page: hint at `16,-4`, content cursor starts at `y = -22`, `ROW = 26`, row frames are `428x24` at `x = 14`.
- **Deviation from the design**: width is 460, not 440. A rule row needs number, icon, spell 120, condition 150, N box with "s", then three 18px buttons.

---

## Phase 1: Themed tabbed shell

### Changes

#### 1. Skin kit
**File**: `WarlockCombatKit/UI.lua`
**Action**: create

Copy these verbatim from `WarlockUtilityKit/UI.lua`, then replace `WUK` with `WCK`:
- `WHITE` and `WUK.THEME` (:13-19)
- `Gradient` and `Pulse` (:21-33)
- `WUK.Skin` (:35-93), with the `opts.swirl` block (:45-57) **removed**
- `Divider` (:95-102), `Header` (:104-111), `Button` (:113-130), `MakeMovable` (:132-147)

Start the file with `local ADDON, WCK = ...`.

`AttachTooltip` deliberately uses `HookScript`, not WUK's `SetScript`. Blizzard dropdown and checkbox templates and `WCK.Button` already set their own OnEnter/OnLeave, and those must keep working.

```lua
-- fill(self) adds lines; hooks so template/Button hover visuals keep working
function WCK.AttachTooltip(b, fill)
  b:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); fill(self); GameTooltip:Show()
  end)
  b:HookScript("OnLeave", GameTooltip_Hide)
end
-- one-line tooltip shorthand
function WCK.Tip(b, title, line)
  WCK.AttachTooltip(b, function()
    GameTooltip:AddLine(title)
    if line then GameTooltip:AddLine(line, 1, 1, 1, true) end
  end)
end
```

#### 2. TOC
**File**: `WarlockCombatKit/WarlockCombatKit.toc`
**Action**: modify. Insert `UI.lua` on its own line after `Core.lua`, before `Actions.lua`.

#### 3. Default for last tab
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify `DEFAULTS` (:23-24) to add `settingsTab = 1`:

```lua
local DEFAULTS = { locked = false, shown = true, frames = {}, minimapAngle = 240, plateMarker = false,
  procAlerts = true, procSound = true, showBar = true, settingsTab = 1 }
```

#### 4. Tabbed window
**File**: `WarlockCombatKit/Settings.lua`
**Action**: modify. Leave the minimap block (:211-248) and `SpellMenu` (:20-27) untouched.

- Replace `WCK.settingsSections = {}` (:4) with:
  ```lua
  WCK.settingsTabs = {} -- { title, hint, build = function(page, win) }; build pushes its syncs into win.syncs
  local ROW = 26
  ```
- `WCK.Check` gains an optional `tip` as the last argument. Positioning is unchanged; it stays relative to `parent`.
  ```lua
  function WCK.Check(parent, label, y, get, onClick, tip)
    -- ...existing body...
    if tip then WCK.Tip(cb, label, tip) end
    return cb
  end
  ```
- **General tab**: a new first tab. It moves the six checks out of `Build()` (:179-191) and the reset button out of (:197-199).
  ```lua
  table.insert(WCK.settingsTabs, { title = "General", hint = "Panel, nameplate and alert options.", build = function(page, win)
    local y = -22
    local function Group(name) WCK.Header(page, name, 16, y, 428); y = y - 20 end
    local function Add(label, get, set, tip)
      table.insert(win.syncs, WCK.Check(page, label, y, get, set, tip)); y = y - ROW
    end
    Group("DISPLAY")
    Add("Show panel", function() return WCK.db.shown end, function(on) WCK.db.shown = on; WCK.Refresh() end)
    Add("Show rotation buttons", ...same get/set as :181-183...)
    Add("Lock panel (no Shift+drag)", ...:184-185...)
    y = y - 8; Group("NAMEPLATES")
    Add("Mark CC'd mobs on nameplates (open world)", ...:186-187...)
    y = y - 8; Group("ALERTS")
    Add("Proc alerts (Nightfall)", ...:188-189...)
    Add("Proc sound", ...:190-191...)
    local reset = WCK.Button(page, "Reset positions", 130, function()
      wipe(WCK.db.frames); WCK.Print("positions reset - /reload to apply") end)
    reset:SetPoint("BOTTOMLEFT", 16, 16)
  end })
  ```
  Insert this entry **first**. Put it above the Rotation entry in the file, or use `table.insert(WCK.settingsTabs, 1, ...)`.
- **Rotation, Cast slots and Alt clicks**: convert each existing `table.insert(WCK.settingsSections, function(win, y) ... end)` into an entry with this mechanical rewrite:
  - The signature becomes `build = function(page, win)` with `local y = -22` at the top.
  - Every `win:CreateFontString`, every `CreateFrame(..., win, ...)` and every `SetPoint("TOPLEFT", ...)` for content uses `page` as the parent. `win:Sync()` and `win.syncs` stay on `win`.
  - Remove the trailing `return ...` lines.
  - Titles and hints:
    - Rotation: `title = "Rotation"`, `hint = "First matching rule lights the core button."`. Drop the old long header text (:30-31).
    - Cast slots: `title = "Cast slots"`, `hint = "Bind keys: Esc > Options > Keybindings > AddOns > Warlock Combat Kit"`. Delete the old head and note (:93-96). Rows start at `y - 0` instead of `y - 34`.
    - Alt clicks: `title = "Alt clicks"`, `hint = "Extra spells on the rotation bar buttons."`. Delete the head FontString (:125-126). The column captions stay at `y - 2` for now and rows start at `y - 18`.
  - Row frames become `SetSize(428, 24)`.
  - "Add rule" and "Defaults" become `WCK.Button(page, "Add rule", 100, fn)` and `WCK.Button(page, "Defaults", 100, fn)`, anchored the same way (:68-73).
  - The rule row's `^`/`v`/`x` `Btn` helper stays on `UIPanelButtonTemplate` in this phase.
- **Replace `Build()`** (:169-204):
  ```lua
  local function Build()
    win = CreateFrame("Frame", "WCKSettings", UIParent, "BackdropTemplate")
    win:SetSize(460, 520); win:SetFrameStrata("DIALOG")
    WCK.Skin(win, "Warlock Combat Kit", { close = true })
    WCK.MakeMovable(win, "settings", 0, 0, true)
    tinsert(UISpecialFrames, "WCKSettings") -- Escape closes it
    win.syncs = {}
    local tabs, pages, n = {}, {}, #WCK.settingsTabs
    local tw = (460 - 24 - (n - 1) * 4) / n
    local function Select(i)
      if not pages[i] then i = 1 end
      for j, p in ipairs(pages) do
        p:SetShown(j == i); tabs[j].line:SetShown(j == i)
        tabs[j]:GetFontString():SetTextColor(unpack(j == i and WCK.THEME.accent or WCK.THEME.text))
      end
      WCK.db.settingsTab = i
    end
    for i, t in ipairs(WCK.settingsTabs) do
      local b = WCK.Button(win, t.title, tw, function() Select(i) end)
      b:SetPoint("TOPLEFT", 12 + (i - 1) * (tw + 4), -28)
      b.line = b:CreateTexture(nil, "OVERLAY"); b.line:SetColorTexture(unpack(WCK.THEME.accent))
      b.line:SetPoint("BOTTOMLEFT", 1, 1); b.line:SetPoint("BOTTOMRIGHT", -1, 1); b.line:SetHeight(2)
      local p = CreateFrame("Frame", nil, win)
      p:SetPoint("TOPLEFT", 0, -56); p:SetPoint("BOTTOMRIGHT", 0, 0)
      local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      hint:SetPoint("TOPLEFT", 16, -4); hint:SetPoint("RIGHT", -16, 0); hint:SetJustifyH("LEFT"); hint:SetText(t.hint)
      t.build(p, win)
      tabs[i], pages[i] = b, p
    end
    function win:Sync() for _, s in ipairs(self.syncs) do s:Sync() end end
    win:SetScript("OnShow", win.Sync)
    Select(WCK.db.settingsTab)
    win:Hide()
  end
  ```
  `WCK.Button`'s OnLeave resets the text colour to `T.text`, which would clear the active tab's accent colour. Add an `OnLeave` hook after the button is created that re-applies the accent when `b.line:IsShown()`:
  ```lua
  b:HookScript("OnLeave", function(self) if self.line:IsShown() then self:GetFontString():SetTextColor(unpack(WCK.THEME.accent)) end end)
  ```
- Update the header comment on line 2 to say "tabs via WCK.settingsTabs".

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] `luac -p WarlockCombatKit/*.lua` is silent
- [x] `grep -c "BasicFrameTemplateWithInset\|settingsSections" WarlockCombatKit/Settings.lua` prints `0`
- [x] `luacheck WarlockCombatKit --globals WCK` shows no new warnings
- [x] Robocopy deploy exits 0-7

#### Manual (in-game, Forever)
- [ ] `/wck config`, a minimap left-click and a right-click on the Life Tap core each toggle the window
- [ ] Purple and fel skin with a shard icon and close button; the look matches WUK settings
- [ ] Four tabs switch pages. The active tab has a fel underline and green text, and keeps them after mouse-out
- [ ] Every page fits 460x520, including Alt clicks with a full bar
- [ ] Each checkbox, rule edit, slot pick and alt pick still works and persists across `/reload`
- [ ] Drag the window, then `/reload`: position is kept. Last tab is kept. Reset positions + `/reload` recentres it
- [ ] Escape closes the window. Dropdown menus draw above it. No Lua errors (BugSack)

---

## Phase 2: Rotation rule rows polish

### Changes

#### 1. Row button rule
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify. Add after `WCK.MoveRule` (:137-142):
```lua
-- which reorder buttons a rule row may use
function WCK.RowButtons(i, n) return { up = i > 1, down = i < n } end
```

#### 2. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: modify. Insert before `print("all tests passed")`:
```lua
-- settings rule row buttons
local rb = WCK.RowButtons(1, 3); eq(rb.up, false, "first: no up"); eq(rb.down, true, "first: down")
rb = WCK.RowButtons(2, 3); eq(rb.up, true, "mid: up"); eq(rb.down, true, "mid: down")
rb = WCK.RowButtons(3, 3); eq(rb.up, true, "last: up"); eq(rb.down, false, "last: no down")
rb = WCK.RowButtons(1, 1); eq(rb.up, false, "single: no up"); eq(rb.down, false, "single: no down")
```

#### 3. Icon helpers
**File**: `WarlockCombatKit/UI.lua`
**Action**: modify. Append:
```lua
-- built-in art; set an entry to nil to fall back to the glyph if it renders blank/green on Forever
local ICONS = {
  up = "Interface\\Buttons\\Arrow-Up-Up", down = "Interface\\Buttons\\Arrow-Down-Up",
  remove = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
local GLYPH = { up = "^", down = "v", remove = "x" }

function WCK.SpellIcon(name)
  if not (name and C_Spell and C_Spell.GetSpellTexture) then return nil end
  local ok, tex = pcall(C_Spell.GetSpellTexture, name)
  return ok and tex or nil
end

-- kind = "up" | "down" | "remove"; dims when disabled
function WCK.IconButton(parent, kind, size, title, line, onClick)
  local b
  if ICONS[kind] then
    b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexture(ICONS[kind])
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(unpack(WCK.THEME.accent)); hl:SetAlpha(0.25)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnable", function(self) self.icon:SetDesaturated(false); self:SetAlpha(1) end)
    b:SetScript("OnDisable", function(self) self.icon:SetDesaturated(true); self:SetAlpha(0.35) end)
  else
    b = WCK.Button(parent, GLYPH[kind], size, onClick); b:SetHeight(size)
    b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    b:SetScript("OnDisable", function(self) self:SetAlpha(0.35) end)
  end
  WCK.Tip(b, title, line)
  return b
end
```

#### 4. Rule rows
**File**: `WarlockCombatKit/Settings.lua`
**Action**: modify the Rotation tab build.
- Row layout from left to right, all anchored `LEFT` inside the 428px row:
  - `r.num` at 0
  - `r.icon`: 20x20 texture at x=14, `SetTexCoord(0.08, 0.92, 0.08, 0.92)`
  - `r.spell` w120 at x=38
  - `r.cond` w150, `LEFT` of `r.spell` `RIGHT` +4
  - `r.n` 26x20 at `r.cond` `RIGHT` +8
  - `r.sfx`: FontString `GameFontDisableSmall` "s" at `r.n` `RIGHT` +2
- Replace the `Btn` helper and its three calls (:58-64) with:
  ```lua
  r.del  = WCK.IconButton(r, "remove", 18, "Remove rule", nil, function() table.remove(WCK.char.rules, i); Changed() end)
  r.down = WCK.IconButton(r, "down", 18, "Move down", "Lower priority", function() WCK.MoveRule(WCK.char.rules, i, 1); Changed() end)
  r.up   = WCK.IconButton(r, "up", 18, "Move up", "Higher priority", function() WCK.MoveRule(WCK.char.rules, i, -1); Changed() end)
  r.del:SetPoint("RIGHT", 0, 0); r.down:SetPoint("RIGHT", -20, 0); r.up:SetPoint("RIGHT", -40, 0)
  ```
- Rename the "Defaults" button label to "Restore defaults" and set its width to 120.
- In `win:SyncRules()`, inside `if rule then`, add:
  ```lua
  r.icon:SetTexture(WCK.SpellIcon(rule.spell) or "Interface\\Icons\\INV_Misc_QuestionMark")
  local rb = WCK.RowButtons(i, #rules); r.up:SetEnabled(rb.up); r.down:SetEnabled(rb.down)
  r.sfx:SetShown(rule.cond == "notRecent")
  ```
  This sits next to the existing `r.n:SetShown(...)`.

### Verification
#### Automated
- [ ] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`, including the new RowButtons asserts
- [ ] `luac -p WarlockCombatKit/*.lua` is silent
- [ ] `grep -c UIPanelButtonTemplate WarlockCombatKit/Settings.lua` prints `0`
- [ ] `luacheck WarlockCombatKit --globals WCK` shows no new warnings
- [ ] Robocopy deploy exits 0-7

#### Manual
- [ ] Each rule row shows the icon of its spell, and the icon updates when you pick a different spell
- [ ] Up is greyed out on row 1, down is greyed out on the last row, and a single rule has both greyed out
- [ ] Up, down and remove reorder and delete correctly. Their tooltips read "Move up", "Move down" and "Remove rule"
- [ ] The arrow and remove art renders. If it is blank or green, set that `ICONS` entry to nil, redeploy, and check the glyph fallback
- [ ] The N box and "s" appear only for "not cast on target in N s", and that label is not cut off with "…"
- [ ] "Restore defaults" restores the six starter rules

---

## Phase 3: Cast slots + Alt clicks polish, tooltips everywhere

### Changes

#### 1. General tooltips
**File**: `WarlockCombatKit/Settings.lua`
**Action**: modify. Pass `tip` to each `Add(...)` in the General tab:
- Show panel: "Summoning-circle panel with your enemy bands."
- Show rotation buttons: "Spell buttons docked right of the panel. Applies after combat."
- Lock panel: "Stops Shift+drag moving the panel and bar."
- Mark CC'd mobs: "Fear icon above the nameplate of each mob you CC'd. Open world only."
- Proc alerts: "Flash when Nightfall makes Shadow Bolt instant."
- Proc sound: "Play a sound with the proc alert."

Also add a tooltip to the Reset positions button: `WCK.Tip(reset, "Reset positions", "Recentre panel, bar and this window. /reload to apply.")`.

#### 2. Rotation dropdown tooltips
In the Rotation build:
- `WCK.Tip(r.spell, "Spell", "Cast when this rule's condition is met.")`
- `WCK.Tip(r.cond, "Condition")`
- `WCK.Tip(r.n, "Seconds", "Rule fires when you have not cast it on the target this long.")`

#### 3. Cast slots rows
- Add `r.icon`, a 20x20 texture at x=124. Move the `r.spell` dropdown to x=148 and make it w200.
- In the sync, change the label to colour the key:
  ```lua
  local key = GetBindingKey("CLICK WCKCast" .. i .. ":LeftButton")
  r.key:SetText("Slot " .. i .. "  " .. (key and ("|cffffffff" .. key .. "|r") or "|cff808080unbound|r"))
  local s = WCK.char.slots[i]
  r.icon:SetShown(s ~= nil); if s then r.icon:SetTexture(WCK.SpellIcon(s) or "Interface\\Icons\\INV_Misc_QuestionMark") end
  ```
- Each slot's `Set(name)` already calls `WCK.Refresh()` but not the window sync. Add `win:Sync()` to `Set` so the icon updates right away.
- `WCK.Tip(r.spell, "Slot " .. i, "Casts on the hostile mob under your mouse, else your target.")`

#### 4. Alt clicks rows
- Replace the two caption FontStrings (:127-129) with headers aligned to the dropdown x positions:
  - `WCK.Header(page, "RIGHT-CLICK", 14 + 148, y - 2)`
  - `WCK.Header(page, "SHIFT+CLICK", 14 + 148 + 134, y - 2)`
- Rows: `r.icon` 20x20 at x=4. `r.label` moves to x=28 with width 112. `r.right` w130 at x=148. `r.shift` w130 at `r.right` `RIGHT` +4.
- In the sync, inside `if e then`, add `r.icon:SetTexture(WCK.SpellIcon(e.spell) or "Interface\\Icons\\INV_Misc_QuestionMark")`.
- Tooltips:
  - `WCK.Tip(r.right, "Right-click", "Spell cast when you right-click this bar button.")`
  - `WCK.Tip(r.shift, "Shift+click", "Spell cast when you Shift+click this bar button.")`
- Fit check: `-22 - 18 - 13*26 = -378`, which is inside the 464px page. No pitch change needed.

### Verification
#### Automated
- [ ] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [ ] `luac -p WarlockCombatKit/*.lua` is silent
- [ ] `luacheck WarlockCombatKit --globals WCK` shows no new warnings
- [ ] Robocopy deploy exits 0-7

#### Manual
- [ ] Every checkbox, dropdown, icon button and the Reset button shows a tooltip, and dropdown hover highlight still works
- [ ] Slot rows: the bound key shows in white and unbound in grey. After binding a key and reopening, the label updates. The icon follows the pick immediately
- [ ] Alt rows: the RIGHT-CLICK and SHIFT+CLICK headers line up over their dropdowns. Icons match the bar spells. Rows follow a rule reorder
- [ ] All 13 alt rows fit (with Shadow Bolt, Fear and Banish known and 10 rules). No Lua errors

---

## Phase 4: Docs + release 0.4.0

### Changes

#### 1. README
**File**: `WarlockCombatKit/README.md`
**Action**: modify
- Replace the "## Settings window" body (:99-102) with:
  - "`/wck config`, a left-click on the minimap button or a right-click on the Life Tap core opens the settings window. It remembers where you put it and which tab you were on. Tabs:"
  - **General:** Show panel, Show rotation buttons, Lock panel, Mark CC'd mobs on nameplates, Proc alerts, Proc sound, and the Reset positions button.
  - **Rotation:** the rule editor.
  - **Cast slots:** the mouseover cast slots.
  - **Alt clicks:** right-click and Shift+click spells for each bar button.
  - "Hover any control for a tip."
- Line 63: "reorder with ^ and v, delete with x" becomes "reorder with the arrow buttons, delete with the red X".
- Line 64: "Defaults" becomes "Restore defaults".
- Line 75: `/wck config` > "Alt clicks" becomes `/wck config` > Alt clicks tab.
- Line 86: `/wck config` > Mouseover cast slots becomes `/wck config` > Cast slots tab.

#### 2. CHANGELOG
**File**: `WarlockCombatKit/CHANGELOG.md`
**Action**: modify. Insert above `## [0.3.0]`:
```markdown
## [0.4.0] — 2026-11-23

### Changed
- Settings window redesigned: themed to match Warlock Utility Kit, split into General, Rotation, Cast slots and Alt clicks tabs, and it remembers its position and last tab.
- Rotation rules show spell icons and use arrow and remove buttons; every setting has a hover tip.
```

#### 3. Version
**File**: `WarlockCombatKit/WarlockCombatKit.toc`
**Action**: modify `## Version: 0.3.0` to `## Version: 0.4.0`.

### Verification
#### Automated
- [ ] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [ ] `grep -n "Version: 0.4.0" WarlockCombatKit/WarlockCombatKit.toc` matches
- [ ] Robocopy deploy exits 0-7

#### Manual
- [ ] The addon list shows Warlock Combat Kit 0.4.0
- [ ] Final side-by-side look with `/wuk config`: both windows read as one family
