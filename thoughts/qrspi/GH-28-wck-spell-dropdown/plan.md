# Implementation Plan

## Overview
Warlock Combat Kit's spell dropdowns list every active spell in the spellbook, grouped by tab (so Wrack appears), and rules work on any of them. A movable horizontal bar of round, secure spell buttons follows the rule list, with Fear and Banish appended at the end as emergency buttons:
- The bar's spell set changes out of combat only.
- The button for the suggested spell pulses purple.
- Shadow Bolt glows fel green during Nightfall.
- Spells that can't be cast right now are greyed out but always clickable.

Conventions for every phase:
- Tests run from the repo root: `lua WarlockCombatKit/tests/run.lua`. `lua5.1` is not on PATH, but `lua` works. Expect `all tests passed`.
- Deploy, exit codes 0-7 are OK:
  `robocopy "D:\Source\wow-addons\WarlockCombatKit" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WarlockCombatKit" /MIR /XD tests /NJH /NJS /NP /NDL`
- Code style matches the existing files: two-space indent, `local ADDON, WCK = ...` header, short `--` comments, and a `ponytail:` comment on any deliberate ceiling.

---

## Phase 1: Spellbook-driven dropdowns and rule state

### Changes

#### 1. Pure helpers
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify (append after `CopyRules`, around line 133)

```lua
-- spellbook rows {tab, name, itemType, isPassive} -> tabs {{name, spells={sorted}}} in book order, set {[name]=true}
-- itemType 1 = Enum.SpellBookItemType.Spell (FutureSpell/Flyout/PetAction dropped); passives dropped; first tab wins a duplicate
function WCK.BuildSpellTabs(entries)
  local tabs, set, byTab = {}, {}, {}
  for _, e in ipairs(entries) do
    if e.itemType == 1 and not e.isPassive and type(e.name) == "string" and e.name ~= "" and not set[e.name] then
      local t = byTab[e.tab]
      if not t then t = { name = e.tab, spells = {} }; byTab[e.tab] = t; tabs[#tabs + 1] = t end
      t.spells[#t.spells + 1] = e.name; set[e.name] = true
    end
  end
  for _, t in ipairs(tabs) do table.sort(t.spells) end
  return tabs, set
end

-- distinct non-empty rule spells, in rule order
function WCK.RuleSpells(rules)
  local out, seen = {}, {}
  for _, r in ipairs(rules or {}) do
    local s = r.spell
    if type(s) == "string" and s ~= "" and not seen[s] then seen[s] = true; out[#out + 1] = s end
  end
  return out
end
```

#### 2. Spellbook scan, rule state and cache
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify

- Above `function WCK.Known` (around line 153), add:

```lua
-- spellbook cache feeding the rule/slot dropdowns and rule state; rebuilt at login and on SPELLS_CHANGED
WCK.spellTabs, WCK.spellSet = {}, {}
function WCK.ScanSpellbook()
  local ok, entries = pcall(function()
    local out, bank = {}, Enum.SpellBookSpellBank.Player
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
      if line and not line.shouldHide then
        for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
          local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
          if info then out[#out + 1] = { tab = line.name, name = info.name, itemType = info.itemType, isPassive = info.isPassive } end
        end
      end
    end
    return out
  end)
  if not ok then return end -- keep the last good cache (secret reads or a missing API land here)
  local okB, tabs, set = pcall(WCK.BuildSpellTabs, entries)
  if okB then WCK.spellTabs, WCK.spellSet = tabs, set end
end
```

- `WCK.BuildRuleState` (line 158): replace the `for _, name in ipairs(WCK.DATA.rotation) do / if WCK.Known(name) then` header with the following. The body (cooldown and usable reads) stays the same, and the matching `end` stays.

```lua
  for _, name in ipairs(WCK.RuleSpells(WCK.char.rules)) do
    if WCK.spellSet[name] then
```

- Rule refresher (line 182): store the state.

```lua
table.insert(WCK.refreshers, function() -- file scope: runs after the proc refresher, before the panel's
  WCK.ruleState = WCK.BuildRuleState(GetTime())
  WCK.next = WCK.EvalRules(WCK.char.rules, WCK.ruleState)
end)
```

- In the init at line 195, after the `WCK.char.rules` line, add:

```lua
  WCK.ScanSpellbook()
  WCK.On("SPELLS_CHANGED", function() WCK.ScanSpellbook(); WCK.Refresh() end)
```

`WCK.Known` stays as is; the proc refresher still uses it.

#### 3. Dropdowns from the cache, grouped by tab
**File**: `WarlockCombatKit/Settings.lua`
**Action**: modify

- Replace `KnownSpells()` (lines 19-23) with:

```lua
-- one submenu per spellbook tab; radios inside
local function SpellMenu(root, isChecked, pick)
  for _, tab in ipairs(WCK.spellTabs) do
    local sub = root:CreateButton(tab.name)
    for _, name in ipairs(tab.spells) do
      sub:CreateRadio(name, function() return isChecked(name) end, function() pick(name) end)
    end
  end
end
```

- Rule dropdown `SetupMenu` (lines 35-40) becomes:

```lua
    r.spell:SetupMenu(function(_, root)
      SpellMenu(root, function(name) return WCK.char.rules[i] and WCK.char.rules[i].spell == name end,
        function(name) WCK.char.rules[i].spell = name; Changed() end)
    end)
```

- Slot dropdown `SetupMenu` (lines 106-111): keep the "(none)" radio, then `SpellMenu(root, function(name) return WCK.char.slots[i] == name end, Set)`.
- Fallback if the selected text is blank in game (see Manual): in `SyncRules` after `GenerateMenu()`, add `r.spell:SetDefaultText(rule.spell)`. In the slot sync, add `r.spell:SetDefaultText(WCK.char.slots[i] or "(none)")`. Only add this if the check fails.

#### 4. Data
**File**: `WarlockCombatKit/Data.lua`
**Action**: modify

- Delete `WCK.DATA.rotation` and its comment (lines 19-23).
- Add:

```lua
-- emergency spells, always at the end of the rotation bar when known
WCK.DATA.tail = { "Fear", "Banish" }
```

- Confirm nothing else references rotation: `grep -rn "DATA.rotation" WarlockCombatKit` should be empty.

#### 5. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: modify (add before `print("all tests passed")`)

```lua
-- GH-28 Phase 1
local tabs, set = WCK.BuildSpellTabs({
  { tab = "General", name = "Auto Attack", itemType = 1 },
  { tab = "Affliction", name = "Wrack", itemType = 1 },
  { tab = "Affliction", name = "Corruption", itemType = 1 },
  { tab = "Affliction", name = "Nightfall", itemType = 1, isPassive = true },
  { tab = "Affliction", name = "Haunt", itemType = 2 },      -- future spell
  { tab = "Demonology", name = "Summon Imp", itemType = 4 },  -- flyout: tab ends up empty
  { tab = "Destruction", name = "Corruption", itemType = 1 }, -- duplicate: first tab wins
})
eq(#tabs, 2, "empty tab dropped"); eq(tabs[1].name, "General", "book order")
eq(tabs[2].spells[1], "Corruption", "sorted"); eq(tabs[2].spells[2], "Wrack", "sorted 2"); eq(#tabs[2].spells, 2, "passive+future dropped")
eq(set.Wrack, true, "set"); eq(set.Nightfall, nil, "passive not in set")
local rs = WCK.RuleSpells({ { spell = "Corruption" }, { spell = "Shadow Bolt" }, { spell = "Corruption" }, { spell = "" }, {} })
eq(#rs, 2, "distinct"); eq(rs[1], "Corruption", "order"); eq(rs[2], "Shadow Bolt", "order 2")
eq(#WCK.RuleSpells(nil), 0, "nil rules")
```

#### 6. Changelog
**File**: `WarlockCombatKit/CHANGELOG.md`
**Action**: modify. Add above `## [0.1.0]`:

```markdown
## [0.2.0] — unreleased

### Fixed
- Rule and slot spell menus list every active spell in your spellbook, grouped by spellbook tab, instead of a fixed list. Wrack and other talent spells now appear. (#28)
```

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] `grep -rn "DATA.rotation\|KnownSpells" WarlockCombatKit` returns nothing
- [x] Deploy robocopy exits 0-7

#### Manual
- [x] `/reload` on a warlock. No Lua errors.
- [x] `/wck config`: rule spell dropdown shows tab submenus. Wrack is under Affliction. No passives.
- [x] Slot dropdown shows "(none)" plus the same submenus.
- [x] The selected spell's name shows on the dropdown button. If it's blank, apply the `SetDefaultText` fallback from change 3.
- [x] Add a rule `Wrack / off cooldown` at the top. The panel core shows Wrack.
- [x] Existing rules (Corruption, Shadow Bolt) still drive the core in combat.

---

## Phase 2: Rotation button bar (click and suggestion pulse)

### Changes

#### 1. Bar spell list
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify (append)

```lua
-- rotation bar order: rule spells, then emergency spells that are known and not already there
WCK.BAR_MAX = 12 -- 10 rules + Fear + Banish
function WCK.BarSpells(rules, emergency, known)
  local out, seen = {}, {}
  for _, s in ipairs(WCK.RuleSpells(rules)) do seen[s] = true; out[#out + 1] = { spell = s, emergency = false } end
  for _, s in ipairs(emergency) do
    if known[s] and not seen[s] then seen[s] = true; out[#out + 1] = { spell = s, emergency = true } end
  end
  return out
end
```

#### 2. Expose the round mask
**File**: `WarlockCombatKit/Panel.lua`
**Action**: modify. After `local function Round ... end` (around line 80), add `WCK.Round = Round`. This is a deviation from the structure: it's needed so `Rotation.lua` can reuse the round icon mask.

#### 3. The bar
**File**: `WarlockCombatKit/Rotation.lua`
**Action**: create

```lua
local ADDON, WCK = ...
-- rotation bar: one fixed-spell secure button per rule spell, then Fear/Banish. The spell set changes only out
-- of combat (secure attributes); highlights are plain textures, so they redraw in combat.
-- Own UIParent frame, never anchored to WCKPanel: protected children would lock the panel's resize in combat.
local SIZE, GAP, EGAP, PAD = 32, 4, 8, 6
local bar, buttons = nil, {}

table.insert(WCK.inits, function()
  bar = CreateFrame("Frame", "WCKRotationBar", UIParent)
  bar:SetSize(SIZE + PAD * 2, SIZE + PAD * 2); bar:SetFrameStrata("MEDIUM")
  local bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.03, 0, 0.06, 0.6)
  WCK.MakeMovable(bar, "bar", 260, -60) -- Shift+drag on the padding, out of combat only
  for i = 1, WCK.BAR_MAX do
    local b = CreateFrame("Button", "WCKRotation" .. i, bar, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE); b:RegisterForClicks("AnyUp", "AnyDown"); b:SetAttribute("type", "macro")
    b.rim = b:CreateTexture(nil, "BACKGROUND"); b.rim:SetPoint("CENTER"); b.rim:SetSize(SIZE + 4, SIZE + 4)
    b.rim:SetColorTexture(0.58, 0.51, 0.79, 0.8); WCK.Round(b, b.rim)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); WCK.Round(b, b.icon)
    WCK.AddGlow(b)
    b:SetScript("OnEnter", function(self)
      if not self.spell then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(self.spell); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:Hide(); buttons[i] = b
  end
end)

-- secure part: out of combat only; PLAYER_REGEN_ENABLED -> Refresh applies rule edits made in combat
table.insert(WCK.refreshers, function()
  if InCombatLockdown() or not bar then return end
  local list = WCK.BarSpells(WCK.char.rules, WCK.DATA.tail, WCK.spellSet)
  local x = PAD
  for i, b in ipairs(buttons) do
    local e = list[i]
    if e then
      if e.emergency and i > 1 and not list[i - 1].emergency then x = x + EGAP end
      b.spell = e.spell
      b:SetAttribute("macrotext", WCK.CastMacro(e.spell))
      b.icon:SetTexture(C_Spell.GetSpellTexture(e.spell) or 134400) -- 134400 = question mark
      b:ClearAllPoints(); b:SetPoint("LEFT", bar, "LEFT", x, 0); b:Show()
      x = x + SIZE + GAP
    else
      b.spell = nil; b:Hide()
    end
  end
  bar:SetWidth(math.max(x - GAP + PAD, SIZE + PAD * 2))
  bar:SetShown(WCK.db.shown and WCK.db.showBar and #list > 0)
end)

-- highlights: every refresh, in combat too (textures only)
table.insert(WCK.refreshers, function()
  for _, b in ipairs(buttons) do WCK.SetAlert(b, b.spell ~= nil and b.spell == WCK.next) end
end)
```

#### 4. TOC
**File**: `WarlockCombatKit/WarlockCombatKit.toc`
**Action**: modify. Put `Rotation.lua` after `Panel.lua`, before `Settings.lua`. This places its refreshers after the rule refresher (Core) and the panel. It deviates from the structure, which said "after Actions.lua": Rotation needs `WCK.Round` and should refresh after `WCK.next` is set.

#### 5. Default and toggle
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify. In `DEFAULTS` (line 22), add `showBar = true`.

**File**: `WarlockCombatKit/Settings.lua`
**Action**: modify. In `win.syncs` (line 133), insert after "Show panel":

```lua
    WCK.Check(win, "Show rotation buttons", -64, function() return WCK.db.showBar end,
      function(on) WCK.db.showBar = on; WCK.Refresh()
        if InCombatLockdown() then WCK.Print("rotation bar change applies after combat") end end),
```

Then shift the following checkboxes by -28 (Lock -92, Mark -120, Proc alerts -148, Proc sound -176) and the section start `local y = -184` to `-212`. The window height is computed from `y`, so it grows automatically.

#### 6. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: modify (append before the final print)

```lua
-- GH-28 Phase 2
local em = { "Fear", "Banish" }
local bs = WCK.BarSpells({ { spell = "Corruption" }, { spell = "Shadow Bolt" }, { spell = "Corruption" } }, em, { Fear = true, Banish = true })
eq(#bs, 4, "rules + emergency"); eq(bs[1].spell, "Corruption", "rule order"); eq(bs[2].emergency, false, "rule flag")
eq(bs[3].spell, "Fear", "fear after rules"); eq(bs[3].emergency, true, "emergency flag"); eq(bs[4].spell, "Banish", "banish last")
bs = WCK.BarSpells({ { spell = "Fear" } }, em, { Fear = true })
eq(#bs, 1, "fear not repeated, unknown banish skipped"); eq(bs[1].emergency, false, "fear keeps rule slot")
eq(#WCK.BarSpells({}, em, {}), 0, "nothing known")
```

#### 7. Docs
**File**: `WarlockCombatKit/README.md`
**Action**: modify
- In "Rotation helper" (line 51), replace the "A clickable core is not possible ..." sentence with: "The core itself can't be clicked (addons can't change a button's spell in combat). Use the rotation buttons below."
- Add a `## Rotation buttons` section before `## Mouseover cast slots`:
  - One round button per spell in your rules, then Fear and Banish after a gap (when known).
  - Clicking casts on the target.
  - The suggested spell pulses purple.
  - Shift+drag the bar's edge to move it.
  - Rule edits made in combat update the bar when combat ends.
  - Toggle with "Show rotation buttons".
- In "Settings window", mention the new checkbox.

**File**: `WarlockCombatKit/CHANGELOG.md`
**Action**: modify. Under `[0.2.0]`, add `### Added` with a "Rotation buttons" bullet, worded as in the README.

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] Deploy robocopy exits 0-7

#### Manual
- [ ] `/reload`. The bar appears at CENTER 260,-60, showing rule spells, a gap, then Fear and Banish.
- [ ] Clicking a button casts on the current target, both out of combat and in combat.
- [ ] In combat, the pulsing button follows the panel core.
- [ ] Shift+drag on the bar's padding moves it. The position survives `/reload`. "Reset positions" plus `/reload` restores the default.
- [ ] Unchecking "Show rotation buttons", `/wck hide` and right-clicking the minimap button each hide the bar out of combat.
- [ ] Editing a rule mid-combat leaves the bar unchanged until combat ends, then it updates.
- [ ] No "Interface action failed because of an AddOn" or blocked-action messages during a full fight.

---

## Phase 2 revision (user request, after Phase 2)
- The tail of the bar is `WCK.DATA.tail = { "Shadow Bolt", "Fear", "Banish" }` (Data.lua), with Shadow Bolt first.
- `BarSpells(rules, tail, known)` drops tail spells from the rule part and appends the known tail spells in tail order. The entry flag is `tail`.
- `BAR_MAX = 13`.
- Rotation.lua uses `e.tail`.
- Tests are updated. README and CHANGELOG are reworded.
- Phase 3 snippets below read `WCK.DATA.tail` in place of the old emergency list.
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] Deploy robocopy exits 0-7

## Phase 3: Nightfall glow and grey-out

### Changes

#### 1. Look helper
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify (append)

```lua
-- bar button look: dim = can't cast now (visual only, the button stays clickable); fel = a proc on this spell is up
function WCK.ButtonLook(spell, state, procs, procList)
  local dim = not state.known[spell] or state.ready[spell] == false or state.usable[spell] == false
  local fel = false
  for _, p in ipairs(procList) do if p.spell == spell and procs[p.key] then fel = true end end
  return { dim = dim, fel = fel }
end
```

`WCK.procs` is keyed by proc key (see `Panel.lua:201`, `WCK.procs[b.key]`).

#### 2. Rule state covers every bar spell
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify. In `BuildRuleState`, change the loop source from Phase 1 to:

```lua
  for _, e in ipairs(WCK.BarSpells(WCK.char.rules, WCK.DATA.tail, WCK.spellSet)) do
    local name = e.spell
    if WCK.spellSet[name] then
```

The body is unchanged. This adds ready and usable state for Fear and Banish, and `EvalRules` is unaffected.

#### 3. Fel glow and desaturation
**File**: `WarlockCombatKit/Rotation.lua`
**Action**: modify
- In init, after `WCK.AddGlow(b)`:

```lua
    b.fel = CreateFrame("Frame", nil, b); b.fel:SetSize(SIZE, SIZE); b.fel:SetPoint("CENTER")
    WCK.AddGlow(b.fel); b.fel.glow:SetVertexColor(0.45, 1, 0.3) -- fel green, as the Nightfall orb
```

- The highlight refresher becomes:

```lua
table.insert(WCK.refreshers, function()
  local st = WCK.ruleState
  for _, b in ipairs(buttons) do
    local look = b.spell and st and WCK.ButtonLook(b.spell, st, WCK.procs, WCK.DATA.procs) or { dim = false, fel = false }
    b.icon:SetDesaturated(look.dim) -- never Disable()/EnableMouse(false): grey buttons still cast
    WCK.SetAlert(b, b.spell ~= nil and b.spell == WCK.next)
    WCK.SetAlert(b.fel, look.fel and WCK.db.procAlerts)
  end
end)
```

#### 4. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: modify (append before the final print)

```lua
-- GH-28 Phase 3
local pl = { { key = "nightfall", spell = "Shadow Bolt" } }
local bst = { known = { ["Shadow Bolt"] = true, Fear = true }, ready = {}, usable = {} }
local lk = WCK.ButtonLook("Shadow Bolt", bst, {}, pl); eq(lk.dim, false, "ready not dim"); eq(lk.fel, false, "no proc")
eq(WCK.ButtonLook("Shadow Bolt", bst, { nightfall = true }, pl).fel, true, "nightfall glows bolt")
eq(WCK.ButtonLook("Fear", bst, { nightfall = true }, pl).fel, false, "nightfall not on fear")
bst.ready.Fear = false; eq(WCK.ButtonLook("Fear", bst, {}, pl).dim, true, "cooldown dims")
bst.ready.Fear = nil; bst.usable.Fear = false; eq(WCK.ButtonLook("Fear", bst, {}, pl).dim, true, "unusable dims")
eq(WCK.ButtonLook("Wrack", bst, {}, pl).dim, true, "unknown dims")
```

#### 5. Version and changelog
- `WarlockCombatKit/WarlockCombatKit.toc`: `## Version: 0.2.0`.
- `WarlockCombatKit/CHANGELOG.md`: under `[0.2.0]` Added, add the bullet "Shadow Bolt button glows fel green during Nightfall; buttons grey out when a spell is on cooldown, unusable or unknown, and stay clickable." Leave the heading as "unreleased"; the release date is set at PR or release time.
- `WarlockCombatKit/README.md`: add the same two behaviours to "Rotation buttons".

### Verification
#### Automated
- [ ] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [ ] Deploy robocopy exits 0-7

#### Manual
- [ ] On a Nightfall proc, the Shadow Bolt button glows green. The proc orb, pulse and sound still fire.
- [ ] Unchecking "Proc alerts" stops the green glow.
- [ ] After casting a spell with a cooldown (Death Coil or Howl of Terror in rules, or Fear/Banish while unusable), its button greys out. Clicking it still attempts the cast, and the game shows its own error.
- [ ] Out-of-mana or out-of-range spells grey out and return to colour when castable.
- [ ] A full fight produces no Lua errors or taint messages.
