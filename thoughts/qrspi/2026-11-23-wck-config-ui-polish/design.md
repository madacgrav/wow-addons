# Design Discussion

## Current State
- `WarlockCombatKit/Settings.lua` builds one stock window, `BasicFrameTemplateWithInset` 380 wide (`Settings.lua:170-171`). Its height is set from the sections (`:195`) and works out to about 1140px. There is no scroll frame.
- Top of the window: six checkboxes with no group header. Each sits at a hardcoded y in 28px steps (`:179-191`).
- Below them, three sections run one after another through `WCK.settingsSections`, a running y cursor (`:4,193-194`):
  - Rotation: 10 pooled rows (`:29-89`).
  - Mouseover cast slots: 6 rows (`:92-121`).
  - Alt clicks: 13 rows (`:124-167`).
- Section headers are plain `GameFontNormal` FontStrings (`:30,93,125`).
- Buttons are `UIPanelButtonTemplate` (`:59,68,71,197`). This is the last use of that template in the repo. Rule rows use text buttons labelled "x", "v" and "^" (`:62-64`).
- The N-seconds field is a bare `InputBoxTemplate` with no unit (`:53-54`).
- No control has a tooltip. The window does not save its position (`:171-173`). Its title is centred in the stock bar (`:175-176`).
- Data flow works and stays as it is:
  - The `win.syncs` and OnShow `Sync` pattern (`:178,201-202`).
  - The `get`/`onClick` closures in `WCK.Check` (`:6-14`).
  - `SpellMenu` submenus (`:20-27`).
  - The `Changed()` → `win:Sync(); WCK.Refresh()` path (`:33`).
- WarlockUtilityKit, the sibling Warlock addon, has a skin kit in `WarlockUtilityKit/UI.lua`:
  - `WUK.THEME` (`:14-19`)
  - `Skin` (`:36-93`), `Divider` (`:96`), `Header` (`:105-111`), `Button` (`:114-130`)
  - `MakeMovable` (`:133-147`), `AttachTooltip` (`:277-282`)
- Its settings window groups controls under `WUK.Header` sections (`WarlockUtilityKit/Settings.lua:32,43,63`).
- Tests cover only Data and Logic (`WarlockCombatKit/tests/run.lua:1-4`). No test touches frames.

## Desired End State
`/wck config`, a minimap click or a right-click on the rotation core opens a themed WCK window. It matches WUK's purple and fel look. It has four tabs, and each page fits without scrolling.

```
+-[shard] Warlock Combat Kit -------------- x +
| General   Rotation   Cast slots   Alt clicks |   <- flat tabs, fel underline on active
|----------------------------------------------|
| muted one-line hint for this tab             |
| DISPLAY ___________________________________  |
| [x] Show panel                               |
| ...                                          |
|                         [Reset positions]    |
+----------------------------------------------+
```

- **Window**: about 440 wide and a fixed height of about 520, sized to the tallest page (Alt clicks, 13 rows). It is themed with a copy of `WUK.Skin` and has a close button. It remembers its position in `WCK.db.frames.settings`, and `/wck reset` / Reset positions clear it like the other frames. Escape still closes it.
- **General tab**: three headed groups.
  - DISPLAY: Show panel, Show rotation buttons, Lock panel.
  - NAMEPLATES: Mark CC'd mobs.
  - ALERTS: Proc alerts, Proc sound.
  - "Reset positions" button at the bottom.
- **Rotation tab**:
  - Hint: "Top to bottom: the first rule whose condition is met lights the core button."
  - 10 rows. Each row has a priority number, the **spell icon**, the spell dropdown and the condition dropdown. The N box shows an "s" suffix and appears only for `notRecent`.
  - Each row ends with **up, down and remove icon buttons** with tooltips. Up is disabled on the first row and down on the last.
  - Footer buttons: "Add rule" and "Restore defaults".
- **Cast slots tab**: the hint holds the keybinding path. Six rows: the slot label shows the bound key or "unbound" in muted text, the spell icon and the dropdown.
- **Alt clicks tab**: hint "Extra spells on the rotation bar buttons." Column headers RIGHT-CLICK and SHIFT+CLICK are drawn with `Header`. Each row: bar spell icon, name, then two dropdowns.
- **Tooltips**: every checkbox, icon button and dropdown has a short tooltip, attached with an `AttachTooltip` copy.
- **Behavior is identical**: the same DB fields, defaults, combat prints and Refresh calls. The minimap button, slash command and rotation right-click are unchanged. Opening the window still re-syncs every page.

**Verification**:
- `lua5.1 WarlockCombatKit/tests/run.lua` passes, plus a new test for any pure helper this adds (for example, row button enable state).
- `luac -p` is clean on all files.
- `grep -c "UIPanelButtonTemplate\|BasicFrameTemplateWithInset" WarlockCombatKit/Settings.lua` returns 0.
- Deploy with robocopy to `_forever_\Interface\AddOns`, then check in-game:
  - each tab fits and switches;
  - edits persist across `/reload`;
  - the position is remembered and Reset positions clears it;
  - tooltips show, icons render, dropdowns draw above the backdrop;
  - no Lua errors;
  - the look matches WUK side by side.

## Patterns to Follow
- **Copy the WUK skin kit into a new `WarlockCombatKit/UI.lua`**, loaded before `Settings.lua` in the TOC (`WarlockCombatKit.toc:9-15`). Copy `THEME`, `Gradient`, `Pulse`, `Skin`, `Divider`, `Header`, `Button`, `MakeMovable` and `AttachTooltip` from `WarlockUtilityKit/UI.lua:13-147,277-282`, renamed to `WCK.*`. This is the same copy-per-addon convention the BC redesign used (`2026-11-16-business-card-ui-redesign/design.md:85,116`). Every addon stays self-contained.
- **`MakeMovable(f, "settings", x, y, true)`** in free mode with `db.frames[key]` persistence (`WarlockUtilityKit/UI.lua:133-147`). This matches the repo-wide `db.frames` convention and the existing reset paths (`Core.lua` `/wck reset`, `Settings.lua:199`).
- **Keep Blizzard checkbox and dropdown templates** (`UICheckButtonTemplate`, `WowStyle1DropdownTemplate` + `SetupMenu`), as the WUK redesign did (`2026-11-16-wuk-board-summon-ui/design.md:109-113`).
- **Keep the sync model**: `win.syncs` and `win:Sync()` on show (`Settings.lua:178,201-202`), `WCK.Check`'s get/set closures (`:6-14`), pooled rows with `SetShown` plus `GenerateMenu()` (`:75-86`). These work and are what the tests' Logic helpers assume.
- **Custom flat tabs**, built like TackleBox's icon tabs (`TackleBox/Panel.lua:142-160`) and styled with the copied `Button` look. Do not use `PanelTabButtonTemplate` (`BusinessCard/Panel.lua:116`): its gold Blizzard art clashes with the WUK skin.
- **Header and divider per group**: `Header(parent, text, x, y, width)` (`WarlockUtilityKit/UI.lua:105-111`), as in WUK Settings (`Settings.lua:32,43,63`).
- **Hint text** in muted `GameFontDisableSmall`, as WCK already does for the keybind note (`Settings.lua:95-96`).
- **Guard optional APIs**: use a nil-check or pcall for `C_Spell.GetSpellTexture`, `SetGradient` and similar, as the BC redesign did (`design.md:118`; `UI.lua:24` already falls back).

**Do NOT follow:**
- Hardcoded absolute y for every control (`Settings.lua:179-191`). Use a per-page y cursor with one row-height constant.
- `UIPanelButtonTemplate` red buttons and `InputBoxTemplate` without a unit label (`:53,59,68,71,197`).
- Text glyph buttons "x", "v", "^" (`:62-64`).
- A height computed from content that grows without bound (`:195`).
- Copying WUK's `opts.swirl` animated background. It is noisy behind a dense form, so leave it off.

## Design Decisions
1. **Layout: four tabs** (General, Rotation, Cast slots, Alt clicks), chosen by the user. This removes the 1140px column without adding a scroll frame. Each tab is a child frame of `win`, and only the active one is shown.
2. **Skin: copy WUK's theme into WCK `UI.lua`**, chosen by the user. Both Warlock addons get the same look. A copy rather than a shared library, because the repo has no shared module and each addon ships alone.
3. **Section registry becomes a tab registry**. `WCK.settingsSections` (`function(win, y)`) becomes `WCK.settingsTabs = { {title, hint, build = function(page) end}, ... }`. Every section lives in `Settings.lua`; the grep found no other callers, so it changes freely.
4. **Rule rows: icons plus icon buttons**, chosen by the user.
   - The spell icon is a 20px texture left of the dropdown, set on sync from the spell name.
   - Up, down and remove are 18px textured buttons using built-in art: arrow textures for up/down and a red X/close texture for remove. All are guarded.
   - Up is disabled on the first row and down on the last.
5. **Help: tooltips plus one hint line per tab**, chosen by the user. Tooltip text lives next to each control's creation, with no separate strings table.
6. **Fixed window size of about 440x520**. All pages share it. The Alt clicks page (13×26 + header) sets the height. If it overflows at 26px rows, drop the row pitch to 24 before adding a scroll frame.
7. **Remember the last tab** in `WCK.db.settingsTab`, a new DEFAULTS field (`Core.lua:23-24`) that MergeDefaults fills. It is a convenience only; an unknown value falls back to 1.
8. **Pure helpers go to `Logic.lua` and get tests**, for example `WCK.RowButtons(i, n)` returning `{up=bool, down=bool}`. This is the repo's way of testing UI decisions without frames (BC redesign `design.md` verification; `tests/run.lua:134-139` `ButtonLook`).

## What We're NOT Doing
- No Blizzard `Settings` panel registration, no Ace3, no `MenuUtil` port. None is verified on Forever (research Open Areas).
- No drag-to-reorder rows, no scroll frames, no raising `MAX_RULES`, `SLOTS` or `BAR_MAX`.
- No changes to the panel, the rotation bar, the minimap button behavior, slash commands, key bindings or DB fields. The one exception is the new `settingsTab` default.
- No extraction of a shared cross-addon UI library, and no edits to WUK.
- No restyle of the WCK in-combat panel or rotation bar. This is the settings window only.
- No frame-level tests and no vendoring of wowmock (it lacks dropdown and checkbox support).

## Open Risks
- **Icon textures**: the up/down/remove art paths (for example `Interface\Buttons\Arrow-Up-Up`, `UI-GroupLoot-Pass-Up`) are not verified on Forever 16001. Use `/dump`, or fall back to the copied `Button` with "↑"/"↓"/"×" text if they are missing.
- **Spell icon lookup**: `C_Spell.GetSpellTexture(name)` by name is not verified. Fallback is a question-mark icon or hiding the icon.
- **Dropdown strata**: the menu must draw above a BackdropTemplate dialog. WUK listed this as a risk, and WUK Board does it in practice (`WarlockUtilityKit/Board.lua:90`).
- **Dropdown width**: the longest condition label, "not cast on target in N s", may truncate at 110px. The wider window gives room, so check in-game for "…" truncation, which WUK hit before.
- **Fixed height fit**: 13 alt rows plus header, tabs and hint must fit about 520px. Measure in-game.
- **Saved position off-screen** after a resolution change. Free-mode `SetClampedToScreen` (`UI.lua:135`) covers it.
