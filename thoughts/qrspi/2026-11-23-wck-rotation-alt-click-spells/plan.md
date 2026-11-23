# Implementation Plan

## Overview
- Each WCK rotation bar button can carry two optional situational spells: one on right-click, one on Shift+left-click. Both cover rule spells and the Shadow Bolt/Fear/Banish tail.
- Alternates are stored per character, keyed by the main spell's name (`WCK.char.alts[spell] = { right, shift }`), and edited in a new "Alt clicks" settings section.
- An unset alternate falls back to the main spell.
- The Life Tap core keeps right-click = options.

**Conventions (all phases)**
- Tests: run `lua WarlockCombatKit/tests/run.lua` from the repo root. It must print `all tests passed`.
- Lint: run `luacheck WarlockCombatKit --globals WCK` if it runs cleanly before your change. Treat only new warnings as failures.
- Deploy after each phase, before asking for an in-game check (exit codes 0-7 are success):
  `robocopy "D:\Source\wow-addons\WarlockCombatKit" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WarlockCombatKit" /MIR /XD tests /NJH /NJS /NP /NDL`
- Secure attributes are written only inside the existing `InCombatLockdown()`-guarded Rotation refresher (`Rotation.lua:57-58`). Combat edits catch up through `PLAYER_REGEN_ENABLED → WCK.Refresh` (`Core.lua:52`).
- Never key anything by bar button index: button→spell is recomputed by position (`Rotation.lua:61-66`).
- No Ace3 and no new libraries.

---

## Phase 1: Right-click alternate, end to end

### Changes

#### 1. Pure helper
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify. Append after `WCK.CastMacro` (`Logic.lua:208-211`).

```lua
-- rotation bar click variants: attribute name per alternate; an unset alternate stays nil so the secure
-- template falls back to the plain macrotext (the button's own spell)
WCK.ALT_ATTRS = { right = "macrotext2" }
function WCK.AltAttrs(spell, alt)
  local out = { macrotext = WCK.CastMacro(spell) }
  if type(alt) == "table" then
    for key, attr in pairs(WCK.ALT_ATTRS) do
      local m = WCK.CastMacro(alt[key])
      if m ~= "" then out[attr] = m end
    end
  end
  return out
end
```

#### 2. Saved-variable default
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify line 25.

```lua
local CHAR_DEFAULTS = { slots = {}, alts = {} }
```
`MergeDefaults` (`Logic.lua:3-10`) adds the empty map on existing characters. A map is safe to merge, unlike the rules list (`Core.lua:253`).

#### 3. Apply attributes and show tooltip line
**File**: `WarlockCombatKit/Rotation.lua`
**Action**: modify.

- Tooltip (`Rotation.lua:47-50`):
```lua
b:SetScript("OnEnter", function(self)
  if not self.spell then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(self.spell)
  local alt = WCK.char.alts[self.spell]
  if alt and alt.right then GameTooltip:AddLine("Right-click: " .. alt.right, 1, 1, 1) end
  GameTooltip:Show()
end)
```
- Secure refresher (`Rotation.lua:65-71`): replace `b:SetAttribute("macrotext", WCK.CastMacro(e.spell))` with:
```lua
local attrs = WCK.AltAttrs(e.spell, WCK.char.alts[e.spell])
b:SetAttribute("macrotext", attrs.macrotext)
for _, attr in pairs(WCK.ALT_ATTRS) do b:SetAttribute(attr, attrs[attr]) end -- nil clears a removed alternate
```
- In the `else` branch (hidden button), also clear the alternates:
```lua
b.spell = nil; b:Hide()
for _, attr in pairs(WCK.ALT_ATTRS) do b:SetAttribute(attr, nil) end
```
- `type = "macro"` stays unsuffixed (`Rotation.lua:40`). Leave `RegisterForClicks("AnyUp", "AnyDown")` as it is.

#### 4. "Alt clicks" settings section
**File**: `WarlockCombatKit/Settings.lua`
**Action**: modify.

- Rules section `Changed` (`Settings.lua:33`) must also refresh the alt rows, since bar spells derive from rules:
```lua
local function Changed() win:Sync(); WCK.Refresh() end
```
  `win:Sync` is defined in `Build` (`Settings.lua:155`) after the sections run, but `Changed` only runs later, on click.
- Append a new section after the mouseover-slots section (after `Settings.lua:121`, before `local function Build`):
```lua
-- Alt clicks: a situational spell per bar spell; keyed by spell name so it follows rule reorders
table.insert(WCK.settingsSections, function(win, y)
  local head = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  head:SetPoint("TOPLEFT", 20, y); head:SetText("Alt clicks (right-click casts instead)")
  local rows = {}
  local function Set(spell, key, name)
    local a = WCK.char.alts[spell] or {}
    a[key] = name
    WCK.char.alts[spell] = next(a) and a or nil
    WCK.Refresh()
    if InCombatLockdown() then WCK.Print("alt click change applies after combat") end
  end
  local function AltMenu(dd, key)
    dd:SetupMenu(function(_, root)
      local spell = dd:GetParent().spell
      if not spell then return end
      local function cur() local a = WCK.char.alts[spell]; return a and a[key] end
      root:CreateRadio("(none)", function() return cur() == nil end, function() Set(spell, key, nil) end)
      SpellMenu(root, function(name) return cur() == name end, function(name) Set(spell, key, name) end)
    end)
  end
  for i = 1, WCK.BAR_MAX do
    local r = CreateFrame("Frame", nil, win); r:SetSize(348, 24); r:SetPoint("TOPLEFT", 14, y - 18 - (i - 1) * 26)
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.label:SetPoint("LEFT", 4, 0)
    r.label:SetWidth(110); r.label:SetJustifyH("LEFT")
    r.right = CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")
    r.right:SetWidth(110); r.right:SetPoint("LEFT", 120, 0); AltMenu(r.right, "right")
    rows[i] = r
  end
  table.insert(win.syncs, { Sync = function()
    local list = WCK.BarSpells(WCK.char.rules, WCK.DATA.tail, WCK.spellSet, WCK.DATA.core)
    for i, r in ipairs(rows) do
      local e = list[i]
      r.spell = e and e.spell
      r:SetShown(e ~= nil)
      if e then r.label:SetText(e.spell); r.right:GenerateMenu() end
    end
  end })
  return y - 18 - WCK.BAR_MAX * 26 - 8
end)
```
- Window height grows automatically (`Settings.lua:149`). Row space is reserved for all 13 rows, the same fixed-pool approach the rules section uses (`Settings.lua:34-35`).

#### 5. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: modify. Insert before `print("all tests passed")`.

```lua
-- alt clicks
local aa = WCK.AltAttrs("Corruption", nil)
eq(aa.macrotext, WCK.CastMacro("Corruption"), "main macro"); eq(aa.macrotext2, nil, "no right alt")
eq(WCK.AltAttrs("Corruption", {}).macrotext2, nil, "empty alt table")
eq(WCK.AltAttrs("Corruption", { right = "Fear" }).macrotext2, WCK.CastMacro("Fear"), "right alt")
eq(WCK.AltAttrs("Corruption", { right = "" }).macrotext2, nil, "empty right ignored")
eq(WCK.AltAttrs(nil, { right = "Fear" }).macrotext, "", "no main spell")
eq(WCK.AltAttrs("Fear", { right = "Fear" }).macrotext2, WCK.CastMacro("Fear"), "alt may equal main")
```

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] `luacheck WarlockCombatKit --globals WCK` shows no new warnings
- [x] robocopy deploy exits 0-7

#### Manual (in-game, `/reload`)
- [ ] No Lua errors on login; `/dump WarlockCombatKitCharDB.alts` shows a table
- [ ] `/wck config` shows the "Alt clicks" section with one row per bar spell
- [ ] Set Right on Corruption to Fear: left-click Corruption casts Corruption, right-click casts Fear
- [ ] Right-click on a button with no alternate casts its own spell
- [ ] Tooltip on Corruption shows "Right-click: Fear"
- [ ] Reorder rules so Corruption moves: the alternate follows Corruption, and the alt rows update while the window is open
- [ ] Change an alternate in combat: chat says "applies after combat", no `ADDON_ACTION_BLOCKED`, and it works after combat
- [ ] Set Right back to "(none)": right-click casts the main spell again
- [ ] Right-click on the Life Tap core still opens options

**If right-click still casts the main spell** (so Forever ignores `macrotext2`): add `b:SetAttribute("type2", "macro")` next to `type` in `Rotation.lua:40`, redeploy and retest. If that also fails, stop: record the result here and return to `/qrspi-plan-toolkit:3-design`.

---

## Phase 2: Shift+left alternate

### Changes

#### 1. Helper
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify.

```lua
WCK.ALT_ATTRS = { right = "macrotext2", shift = "shift-macrotext1" }
```
`AltAttrs` needs no other change. Shift+right resolves to `macrotext2`, then to `macrotext`, through the template's own fallback.

#### 2. Tooltip
**File**: `WarlockCombatKit/Rotation.lua`
**Action**: modify. Add a line in `OnEnter` after the right-click line.

```lua
if alt and alt.shift then GameTooltip:AddLine("Shift-click: " .. alt.shift, 1, 1, 1) end
```

#### 3. Settings Shift dropdown
**File**: `WarlockCombatKit/Settings.lua`
**Action**: modify the "Alt clicks" section.

- Header: `head:SetText("Alt clicks (right-click / Shift+click cast instead)")`
- In the row loop, after `r.right`:
```lua
r.shift = CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")
r.shift:SetWidth(110); r.shift:SetPoint("LEFT", r.right, "RIGHT", 4, 0); AltMenu(r.shift, "shift")
```
  Layout check: 120 + 110 + 4 + 110 = 344 px, which fits the 348 px row.
- In sync: `if e then r.label:SetText(e.spell); r.right:GenerateMenu(); r.shift:GenerateMenu() end`
- Add small column headers above the rows if the dropdown text doesn't make Right vs Shift clear. Two `GameFontDisableSmall` strings at x=134 and x=248 on the header line, reading "Right" and "Shift".

#### 4. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: modify. Append to the alt-clicks block.

```lua
local both = WCK.AltAttrs("Corruption", { right = "Fear", shift = "Banish" })
eq(both.macrotext2, WCK.CastMacro("Fear"), "both: right"); eq(both["shift-macrotext1"], WCK.CastMacro("Banish"), "both: shift")
local so = WCK.AltAttrs("Corruption", { shift = "Banish" })
eq(so.macrotext2, nil, "shift only: no right"); eq(so["shift-macrotext1"], WCK.CastMacro("Banish"), "shift only")
```

### Verification
#### Automated
- [ ] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [ ] `luacheck WarlockCombatKit --globals WCK` shows no new warnings
- [ ] robocopy deploy exits 0-7

#### Manual (in-game, `/reload`)
- [ ] Set Shift on Corruption to Banish: Shift+left casts Banish
- [ ] With Right=Fear and Shift=Banish: Shift+right casts Fear; with Right unset, Shift+right casts Corruption
- [ ] Plain left- and right-click are unchanged
- [ ] The tooltip shows both lines
- [ ] Shift+drag from the bar background or the circle still moves the kit and casts nothing
- [ ] Shift+drag starting on a button: record whether it casts, and note it for the README in Phase 3

---

## Phase 3: Docs and release

### Changes

#### 1. README
**File**: `WarlockCombatKit/README.md`
**Action**: modify the "Rotation buttons" list (`README.md:72-80`). After "Click a button to cast its spell on your target.", add:

```markdown
- **Right-click** or **Shift+click** a button to cast a situational spell instead. Pick them per spell in `/wck config` > "Alt clicks". With none picked, the button casts its own spell. Alternates follow the spell when you reorder rules and also work on Shadow Bolt, Fear and Banish. A change made in combat applies when combat ends.
```
If Phase 2 found that a Shift+drag starting on a button casts, add: "Start Shift+drag from the bar's edge or the circle, not from a button."

#### 2. CHANGELOG
**File**: `WarlockCombatKit/CHANGELOG.md`
**Action**: modify. Insert above `## [0.2.2]`.

```markdown
## [0.3.0] — <date of release>

### Added
- Rotation bar buttons can cast a situational spell on right-click and another on Shift+click, chosen per spell in the new "Alt clicks" settings section. Unset clicks cast the button's own spell.
```

#### 3. Version
**File**: `WarlockCombatKit/WarlockCombatKit.toc`
**Action**: modify. `## Version: 0.2.2` → `## Version: 0.3.0`

### Verification
#### Automated
- [ ] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [ ] `luacheck WarlockCombatKit --globals WCK` shows no new warnings
- [ ] robocopy deploy exits 0-7

#### Manual
- [ ] The AddOns list in-game shows Warlock Combat Kit 0.3.0
- [ ] The README text matches the behaviour seen in Phases 1-2
