# Structure Outline

## Approach
Copy WUK's skin kit into a new `WarlockCombatKit/UI.lua`. Rebuild the settings window as a themed, fixed-size frame with four flat tabs fed by a `WCK.settingsTabs` registry. Then polish each page: icons, icon buttons, headers, hints and tooltips. DB fields and behavior stay unchanged, apart from one new `settingsTab` default.

## Phase 1: Themed tabbed shell
The window opens with the WUK look and four working tabs. The General tab is grouped under headers. The other three tabs hold the existing sections moved over as they are, on a per-page y cursor. Buttons become themed buttons. The window remembers its position and its last tab. After this phase the 1140px column is gone.

**Files**: `WarlockCombatKit/UI.lua` (new), `WarlockCombatKit/WarlockCombatKit.toc`, `WarlockCombatKit/Settings.lua`, `WarlockCombatKit/Core.lua`

**Key changes**:
- `UI.lua` copies these from `WarlockUtilityKit/UI.lua:13-147,277-282`, renamed to `WCK.*`. Fields read `WCK.db`.
  - `WCK.THEME`, local `Gradient`, local `Pulse`
  - `WCK.Skin(f, title, opts) -> titleFontString` (`opts.close`; swirl left out)
  - `WCK.Divider(parent, x, y, width)`, `WCK.Header(parent, text, x, y, width)`
  - `WCK.Button(parent, label, width, onClick) -> Button`
  - `WCK.MakeMovable(f, key, x, y, free)`
  - `WCK.AttachTooltip(b, fill)`
- TOC: add `UI.lua` after `Core.lua` and before `Actions.lua`.
- `Core.lua` DEFAULTS: add `settingsTab = 1`.
- `Settings.lua`:
  - `WCK.settingsSections` becomes `WCK.settingsTabs = { {title=string, hint=string, build=function(page) end} }`.
  - Page-local layout helper: `local function Cursor(page, y0) -> {y, Next(h)}`, or just a local `y` per build plus a `ROW = 26` constant. Pick the smaller one in the plan.
  - `WCK.Check(parent, label, y, get, onClick, tip?)` keeps the same signature with an optional `tip`, wired through `AttachTooltip`.
  - `Build()` makes:
    - `CreateFrame("Frame","WCKSettings",UIParent,"BackdropTemplate")`, size 440x520, `WCK.Skin(win,"Warlock Combat Kit",{close=true})`
    - `WCK.MakeMovable(win,"settings",0,0,true)`, UISpecialFrames
    - a tab strip, one page frame per tab, and a hint FontString per page
  - `local function SelectTab(i)` shows that page and hides the rest, sets the active underline, and saves `WCK.db.settingsTab`. An unknown value falls back to 1.
  - The `win.syncs` and `win:Sync()` OnShow model stays. Syncs run for every page, not just the visible one.
  - General tab headers: DISPLAY, NAMEPLATES, ALERTS. "Reset positions" moves to the General page and becomes a `WCK.Button`.
  - "Add rule" and "Defaults" become `WCK.Button`. Rule rows keep their text buttons for now (replaced in Phase 2).

**Verify**:
- `lua5.1 WarlockCombatKit/tests/run.lua` prints `all tests passed`, and `luac -p` is clean on all WCK files.
- `grep -c BasicFrameTemplateWithInset WarlockCombatKit/Settings.lua` = 0.
- Robocopy deploy, then check in-game:
  - Opens from `/wck config`, the minimap and a core right-click.
  - Skin matches WUK. Each tab fits 440x520.
  - All settings still edit and persist across `/reload`.
  - Drag position and last tab are remembered. Reset positions recentres the window. Escape closes it.
  - Dropdowns draw above the backdrop. No Lua errors.

---

## Phase 2: Rotation rule rows polish
Rule rows show the spell icon. Up, down and remove become textured icon buttons with tooltips, enabled by position. The N field gets an "s" suffix. A Rotation hint line is added. Footer reads "Add rule" and "Restore defaults".

**Files**: `WarlockCombatKit/Logic.lua`, `WarlockCombatKit/tests/run.lua`, `WarlockCombatKit/Settings.lua`, `WarlockCombatKit/UI.lua`

**Key changes**:
- `WCK.RowButtons(i, n) -> {up=bool, down=bool, remove=true}`: new pure helper in Logic.lua, with tests for first, middle, last and single row.
- `WCK.SpellIcon(name) -> texturePath|nil`: guarded `C_Spell.GetSpellTexture`. If it fails, show a question-mark icon or hide the icon.
- `WCK.IconButton(parent, texture, size, tip, onClick) -> Button` in UI.lua. It has a themed hover highlight and a disabled desaturate. If a texture is missing, it falls back to `WCK.Button` with a text glyph.
- `win:SyncRules()` also sets the row icon and calls `SetEnabled` on up/down from `RowButtons`.

**Verify**:
- Tests pass, including the new `RowButtons` cases. `luac -p` is clean.
- `grep -c UIPanelButtonTemplate WarlockCombatKit/Settings.lua` = 0.
- In-game:
  - Icons match the chosen spells.
  - Up is grey on row 1 and down is grey on the last row.
  - Reorder and remove work, and tooltips show.
  - The "s" suffix appears only for `notRecent`.
  - No condition label is cut off with "…".

---

## Phase 3: Cast slots + Alt clicks polish, tooltips everywhere
Both pages get hints, column headers and spell icons. Every checkbox and dropdown has a tooltip. An unbound key reads muted.

**Files**: `WarlockCombatKit/Settings.lua`

**Key changes**:
- Cast slots hint: the keybinding path, moved out of the in-section note. Each row: slot label (key in white, "unbound" muted), `SpellIcon` and dropdown. A dropdown tooltip names the slot and how to bind it.
- Alt clicks: hint text, plus `WCK.Header` column headers RIGHT-CLICK and SHIFT+CLICK aligned to the dropdown x. Each row: bar spell icon, name, two dropdowns, with tooltips.
- General checkbox tooltips, each a one-line effect. Examples: "Shift+drag disabled while locked"; "Plays a sound when Nightfall procs".

**Verify**:
- Tests pass and `luac -p` is clean.
- In-game:
  - Every control shows a tooltip.
  - The 13 alt rows fit, or the row pitch drops to 24.
  - The slot label updates after a keybind change and a reopen.
  - Alt rows follow rule reorders.
  - No Lua errors.

---

## Phase 4: Docs + release 0.4.0
The README describes the tabs, and the CHANGELOG has an entry. Version bumped, following the pattern of commit `049e86b`.

**Files**: `WarlockCombatKit/README.md`, `WarlockCombatKit/CHANGELOG.md`, `WarlockCombatKit/WarlockCombatKit.toc` (`## Version: 0.4.0`)

**Verify**:
- Tests pass.
- The addon list in-game shows 0.4.0.
- A final side-by-side look with WUK settings.

## Testing Checkpoints
- **After Phase 1**: themed, movable, four-tab window. All old settings work and persist. No stock frame template. Rule rows still use text buttons.
- **After Phase 2**: the Rotation tab is polished. `RowButtons` is tested. No `UIPanelButtonTemplate` remains in WCK.
- **After Phase 3**: every tab is polished, and every control has a tooltip.
- **After Phase 4**: docs and version 0.4.0 are shipped.
- Every phase: `lua5.1 WarlockCombatKit/tests/run.lua` and `luac -p`, then robocopy to `_forever_\Interface\AddOns` before the in-game check.
