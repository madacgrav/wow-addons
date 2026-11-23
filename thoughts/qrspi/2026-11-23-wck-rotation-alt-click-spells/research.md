# Research Findings

Scope: `WarlockCombatKit/` (1216 Lua lines) plus the wow-forever-addon skill references (`D:\Source\wowskill\skills\wow-forever-addon\references\`).

## Q1: How are rotation bar buttons created, populated and refreshed, and how does `Actions.lua` differ?

### Findings
- **Creation (once, at login init):** `Rotation.lua:10-54` runs inside `WCK.inits` (executed from `PLAYER_LOGIN` for warlocks only, `Core.lua:44-51`).
  - Container: `WCKRotationBar` plain `Frame` on `UIParent`, strata MEDIUM, level above the panel (`Rotation.lua:12-15`).
  - Core button: `WCKCoreCast`, `SecureActionButtonTemplate`, `RegisterForClicks("LeftButtonUp", "LeftButtonDown")`, `type=macro`, `macrotext="/cast Life Tap"` (`Rotation.lua:18-21`). Right-click is *not* registered with the secure handler; an insecure `OnMouseUp` script opens settings on `RightButton` (`Rotation.lua:31-32`). Tooltip advertises "Right-click: options" (`Rotation.lua:27`).
  - Bar buttons: `WCK.BAR_MAX` (13, `Logic.lua:177`) buttons named `WCKRotation1..13`, `SecureActionButtonTemplate`, `RegisterForClicks("AnyUp", "AnyDown")`, `SetAttribute("type", "macro")` (`Rotation.lua:38-40`). Each has `rim`, `icon` textures, a glow (`WCK.AddGlow`) and a child `fel` frame with its own glow (`Rotation.lua:41-46`). Tooltip `OnEnter` shows only `self.spell` (`Rotation.lua:47-50`). All start hidden.
  - Because `type` is set unsuffixed and clicks register `AnyUp/AnyDown`, every mouse button and modifier currently resolves to the same `type`/`macrotext` (see Q3).
- **Populate (secure refresher):** `Rotation.lua:57-77`, appended to `WCK.refreshers`.
  - Returns early if `InCombatLockdown()` or bar not built (`Rotation.lua:58`).
  - List = `WCK.BarSpells(char.rules, DATA.tail, spellSet, DATA.core)` when `db.showBar`, else `{}` (`Rotation.lua:59`).
  - For each button index `i`: entry `list[i]` sets `b.spell`, `macrotext = WCK.CastMacro(e.spell)`, icon texture, position; extra gap `EGAP` before first tail entry (`Rotation.lua:61-73`). Missing entry: `b.spell = nil; b:Hide()`.
  - Bar width, background, shown state set after loop (`Rotation.lua:74-76`).
- **Visual refresher (runs in combat too):** `Rotation.lua:80-89` — textures/alpha/glow only, no attributes.
- **Refresh scheduling:** `WCK.Refresh()` debounces 0.1 s via `C_Timer.After`, then runs every refresher in insertion order (`Core.lua:35-43`). Also fired on `PLAYER_REGEN_ENABLED` (`Core.lua:52`), so out-of-combat attribute writes catch up after combat. File-load order from TOC: `Data, Logic, Core, Actions, Panel, Rotation, Settings` (`WarlockCombatKit.toc`).
- **`Actions.lua` buttons:** `WCK.SLOTS` (6, `Logic.lua:207`) hidden buttons `WCKCast1..6` on a `WCKActionHolder` frame (`Actions.lua:7-14`), same template, same `RegisterForClicks("AnyUp","AnyDown")` and `type=macro`. No visuals, no `.spell` field. Refresher sets `macrotext = CastMacro(char.slots[i])` out of combat (`Actions.lua:17-20`). Triggered by key bindings `CLICK WCKCastN:LeftButton` (`Bindings.xml`, names at `Actions.lua:3-4`).
- Differences summary: Actions = fixed slot→spell from `char.slots`, keybind-driven, invisible; Rotation = slot→spell derived from rules each refresh, mouse-driven, visible, carries `b.spell` for visuals/tooltip.

## Q2: What does `CastMacro` produce, and how do `BarSpells`/`RuleSpells`/rules map spells to slots?

### Findings
- `WCK.CastMacro(spell)` returns `""` for non-string/empty, else `"/cast [@mouseover,harm,nodead][] " .. spell` (`Logic.lua:208-211`). Tested at `tests/run.lua:99-101`.
- `WCK.RuleSpells(rules)`: distinct non-empty `r.spell` values in rule order (`Logic.lua:167-174`); tests `tests/run.lua:116-118`.
- `WCK.BarSpells(rules, tail, known, core)` (`Logic.lua:178-188`): returns array of `{spell, tail}`:
  1. RuleSpells excluding any spell in `tail` and excluding `core` (`tail=false`);
  2. then each `tail` spell (`Shadow Bolt, Fear, Banish`, `Data.lua:20`) if `known[s]` (`tail=true`).
  - Note: rule spells are *not* filtered by `known`; tail spells are. Tests `tests/run.lua:123-130`.
- **Slot identity is positional and recomputed.** Button `i` receives `list[i]` on every secure refresh (`Rotation.lua:61-66`). Reordering rules (`WCK.MoveRule`, `Logic.lua:137-142`), removing (`Settings.lua:62`), editing a rule's spell (`Settings.lua:41`), dedup in RuleSpells, or a change to `spellSet` (on `SPELLS_CHANGED`, `Core.lua:256`) shifts which spell lands on which button index. The only stable key tying a button to content is the spell name (`b.spell`).
- Rule entries are `{spell, cond, n}` (`Logic.lua:147`, `Data.lua:23-27`); no other fields exist on a rule today. `CopyRules` copies exactly these three fields (`Logic.lua:145-149`).
- Duplicate rule spells (e.g. two Shadow Bolt rules in defaults, `Data.lua:26`) collapse to one bar button.

## Q3: How does `SecureActionButtonTemplate` resolve attributes per mouse button and modifier on Forever, and what combat constraints apply?

### Findings
- **Skill references:** `taint-and-secure.md:23` — buttons that cast must inherit `SecureActionButtonTemplate` and be configured with attributes **outside combat**; `taint-and-secure.md:24` — don't show/hide/move secure frames in combat; deferral pattern to `PLAYER_REGEN_ENABLED` at `taint-and-secure.md:15-20`. The references do **not** document modifier/button attribute resolution.
- **API index / std:** `SecureActionButtonTemplate`, `SecureActionButton_OnClick`, `SecureActionButton_ShouldUseOnKeyDown` are listed in the generated luacheck std (`templates/luacheck/forever-std.lua:16171-16173`). `IsShiftKeyDown`, `IsAltKeyDown`, `IsControlKeyDown`, `IsModifierKeyDown`, `GetMouseButtonClicked` are in `forever-api-index.md:1060`. `SecureButton_GetModifiedAttribute` does not appear in the index.
- **Resolution rules (reported from Retail FrameXML `SecureTemplates.lua`; unverified on Forever, no local copy of Blizzard source found under `D:\Source`):**
  - Attribute lookup is `SecureButton_GetModifiedAttribute(self, name, button)`: tries `<modifiers><name><suffix>` where modifiers prefix is built from held keys in order `alt-`, `ctrl-`, `shift-` (Retail also `meta-`), and suffix comes from the mouse button (`LeftButton`→`1`, `RightButton`→`2`, `MiddleButton`→`3`, `Button4/5`→`4/5`).
  - Fallback order tries combinations with `*` wildcards (e.g. `*name1`, `shift-name*`, `*name*`) then bare `name`. So bare `type`/`macrotext` (as WCK sets today) match every button/modifier; `type2`/`macrotext2` would apply only to right-click; `shift-type1`/`shift-macrotext1` only to shift+left.
  - `type="macro"` reads the (modified) `macrotext` attribute; a separate `macro` attribute selects a saved macro instead.
  - Which clicks reach the handler is gated by `RegisterForClicks`; WCK bar and Actions buttons register `AnyUp, AnyDown` (`Rotation.lua:40`, `Actions.lua:11`), the core only `LeftButtonUp/Down` (`Rotation.lua:20`). Whether up or down fires the action follows the `ActionButtonUseKeyDown` CVar via `SecureActionButton_ShouldUseOnKeyDown` (Retail behaviour, reported).
- **Combat:** `SetAttribute` on a protected frame is blocked during `InCombatLockdown()`; WCK guards every attribute write with `if InCombatLockdown() then return end` (`Rotation.lua:58`, `Actions.lua:18`) and re-runs refreshers on `PLAYER_REGEN_ENABLED` (`Core.lua:52`). Settings edits made in combat print "applies after combat" for slots and bar toggle (`Settings.lua:106`, `Settings.lua:137`). Modifier state itself is evaluated by the secure handler at click time, so modifier-keyed attributes set before combat work during combat (Retail behaviour, reported).
- Existing right-click use in the addon: core uses an insecure `OnMouseUp` for right-click → settings (`Rotation.lua:32`); minimap button uses `RegisterForClicks("LeftButtonUp","RightButtonUp")` + `OnClick(button)` (`Settings.lua:191-194`).

## Q4: How are saved variables structured, defaults merged, migrations handled; shapes of `char.rules` and `char.slots`?

### Findings
- TOC: `SavedVariables: WarlockCombatKitDB`, `SavedVariablesPerCharacter: WarlockCombatKitCharDB` (`WarlockCombatKit.toc`).
- Defaults (`Core.lua:23-25`):
  - account `DEFAULTS = { locked, shown, frames = {}, minimapAngle, plateMarker, procAlerts, procSound, showBar }`;
  - per-char `CHAR_DEFAULTS = { slots = {} }`.
- Merge at `ADDON_LOADED` for this addon (`Core.lua:27-33`): `WCK.MergeDefaults` (`Logic.lua:3-10`) recursively fills missing keys, replaces non-table values where a table default exists, keeps saved scalars. Then `WCK.db`, `WCK.char` alias the globals. Comment notes Forever beta loader can leave SVs nil (`Core.lua:29`).
- `char.rules`: **not** in `CHAR_DEFAULTS`; seeded in an init (`Core.lua:252-254`) with `CopyRules(DATA.defaultRules)` only when nil, explicitly to avoid merging list entries. Shape: array of `{ spell = string, cond = "ready"|"notRecent"|"proc"|"marked"|"usable", n = number|nil }` (`Data.lua:23-28`). Max 10 enforced by UI only (`Settings.lua:18`, `Settings.lua:85`).
- `char.slots`: sparse array indexed 1..`WCK.SLOTS` (6) of spell-name strings or nil (`Settings.lua:105`, `Actions.lua:19`).
- `db.frames`: positions keyed by frame id (used by `WCK.MakeMovable`, reset via `wipe(WCK.db.frames)` at `Settings.lua:153`).
- No versioned migration code exists; schema evolution relies on MergeDefaults filling new keys and the nil-check for rules. `db.lastProbe` written by the probe command (`Core.lua:317` comment).

## Q5: How does `Settings.lua` build rows and spell menus, and how do edits propagate?

### Findings
- Window `WCKSettings` (`BasicFrameTemplateWithInset`, DIALOG strata, movable, Escape-closable) built lazily on first `WCK.ToggleSettings()` (`Settings.lua:123-163`). Height computed from sections (`Settings.lua:147-149`).
- Top checkboxes via `WCK.Check(parent, label, y, get, onClick)` (`Settings.lua:6-14`, `132-146`); each has `.Sync`.
- Sections: `WCK.settingsSections` is an ordered list of `function(win, y) -> nextY` (`Settings.lua:4`), invoked in `Build` (`Settings.lua:148`). Each may push `{Sync=fn}` into `win.syncs`; `win:Sync()` runs all on `OnShow` (`Settings.lua:155-156`).
- `SpellMenu(root, isChecked, pick)` (`Settings.lua:20-27`): for each `WCK.spellTabs` entry creates a submenu button (`root:CreateButton(tab.name)`) with `CreateRadio(name, isChecked, pick)` children. `WCK.spellTabs`/`WCK.spellSet` come from `WCK.ScanSpellbook` → `WCK.BuildSpellTabs` (`Logic.lua:153-164`, `Core.lua:~170-175`), refreshed on `SPELLS_CHANGED` (`Core.lua:256`).
- Dropdowns: `CreateFrame("DropdownButton", nil, r, "WowStyle1DropdownTemplate")` + `:SetupMenu(function(_, root) ... end)`; `:GenerateMenu()` re-renders the selected text on sync (`Settings.lua:37-42`, `81`, `102-117`).
- **Rotation rules section** (`Settings.lua:29-89`): 10 pooled rows, each with spell dropdown, cond dropdown, numeric `n` EditBox (shown only for `notRecent`), and `x`/`v`/`^` buttons. All mutations write `WCK.char.rules` directly then call `Changed()` = `win:SyncRules(); WCK.Refresh()` (`Settings.lua:33`). "Add rule" / "Defaults" buttons (`Settings.lua:68-73`).
- **Mouseover slots section** (`Settings.lua:92-121`): 6 rows; label shows `GetBindingKey("CLICK WCKCastN:LeftButton")`; dropdown with `(none)` radio plus `SpellMenu`; `Set(name)` writes `char.slots[i]`, calls `WCK.Refresh()`, prints a notice if in combat.
- **Propagation:** settings write SV tables → `WCK.Refresh()` (debounced) → secure refreshers in Actions/Rotation re-apply `macrotext` when out of combat; otherwise deferred to `PLAYER_REGEN_ENABLED` refresh.
- Rows are indexed by rule position, not by bar button; there is no settings UI keyed to bar buttons or to `BarSpells` output.

## Q6: How do tooltips, glow/alert and cooldown-dim get their spell; what feeds cooldown tracking?

### Findings
- All visuals key off `b.spell` (set only in the secure refresher, `Rotation.lua:65`/`71`):
  - Tooltip: `GameTooltip:AddLine(self.spell)` (`Rotation.lua:47-50`).
  - Look: `WCK.ButtonLook(b.spell, WCK.onCD[b.spell], WCK.procs, WCK.DATA.procs)` → `{dim, fel}` (`Logic.lua:200-204`, used `Rotation.lua:84-87`). `dim` desaturates + alpha 0.6, never disables (`Rotation.lua:85`).
  - Suggested pulse: `WCK.SetAlert(b, b.spell == WCK.next)` (`Rotation.lua:86`); `WCK.next` = first passing rule from `WCK.EvalRules` (`Core.lua:207-210`, `Logic.lua:130-135`).
  - Proc glow: `WCK.SetAlert(b.fel, look.fel and db.procAlerts)` (`Rotation.lua:87`); procs from `DATA.procs` (`Data.lua:33-35`).
- **Cooldown tracking:** refresher at `Core.lua:231-241` builds the spell list from `BarSpells(...)` (same inputs as the bar), calls `WCK.BuildCooldowns` (`Core.lua:214-228`) → `WCK.onCD[name]=true` + earliest end; schedules one `C_Timer.After` redraw at the earliest end. Secret fields nil'd via `Clean` (`Core.lua:213`). `WCK.CooldownState` ignores GCD (`Logic.lua:192-197`).
- **Rule state** (`WCK.BuildRuleState`, `Core.lua:182-205`) covers only `RuleSpells(char.rules)` for known/ready/usable; tail spells not in rules get cooldowns but no rule state.
- Refresher order matters (comments `Core.lua:137`, `207`, `231`): procs → rule eval → cooldowns → Rotation highlight.
- Cast tracking for the cast map uses `UNIT_SPELLCAST_SENT/SUCCEEDED` filtered to `DATA.tracked` (`Core.lua:258-286`), independent of which button cast.

## Q7: What does the offline test harness cover; what stubs exist?

### Findings
- Single file `tests/run.lua` (152 lines), plain Lua: loads `Data.lua` and `Logic.lua` into a table and asserts with `eq`/`near` helpers (`tests/run.lua:1-11`). It does **not** use the skill's wowmock harness; there is no `tests/*_spec.lua`.
- Covered pure functions: `MergeDefaults` (`:14-17`), `EnemyKey`/`FallbackLabel`/`PickUnit`, cast-map functions, `IconAlpha`, `RowsView`, `ProcsUp`/`NewProcs`, `EvalRules`, `MoveRule`, `CopyRules` (`:96`), `CastMacro` (`:99-101`), `BuildSpellTabs`, `RuleSpells` (`:116-118`), `BarSpells` (`:123-130`), `CooldownState`, `ButtonLook` (`:135-139`).
- Not covered: `Core.lua`, `Rotation.lua`, `Actions.lua`, `Settings.lua`, `Panel.lua` — no frame, `SetAttribute`, `RegisterForClicks`, `InCombatLockdown`, or menu stubs exist in this addon's tests.
- Skill harness: `references/testing.md` documents the wowmock API (frames, events, `env:load_addon`, `env:update`) and states it cannot catch taint (`taint-and-secure.md` "Debugging taint"). Whether wowmock stubs `SetAttribute`/`GetAttribute` or `MenuUtil`-style `SetupMenu`/`CreateRadio` was not confirmed in this pass.

## Cross-Cutting Observations
- **Two-tier refresh pattern:** secure work (attributes, show/hide, position) only out of combat inside a refresher guarded by `InCombatLockdown()`; texture-only work every refresh. Combat edits catch up through `PLAYER_REGEN_ENABLED → WCK.Refresh` (`Core.lua:52`).
- **Registration lists:** features plug in via `WCK.inits`, `WCK.refreshers`, `WCK.settingsSections`, `win.syncs` — no module system, no libraries. No Ace3/LibStub anywhere in the addon.
- **Spell identity is by English name string** everywhere (rules, slots, bar, cooldowns, procs) (`Data.lua:3` ponytail note).
- **Pure logic lives in `Logic.lua`** and is the only tested layer; frame code is thin glue.
- `ponytail:` markers record known ceilings (`Data.lua:3`, `Settings.lua:17`).
- Right-click currently carries meaning on the core (options) and minimap (toggle panel), but bar buttons pass all mouse buttons to the secure handler with unsuffixed attributes.

## Open Areas
- Exact Forever behaviour of `SecureButton_GetModifiedAttribute` (modifier prefix order, `meta-`, wildcard fallback) and `ActionButtonUseKeyDown` is reported from Retail FrameXML only; no Forever source or reference in the skill confirms it.
- Whether the skill's wowmock implements `SetAttribute`/`GetAttribute`, modifier keys, or `DropdownButton:SetupMenu` was not verified (`references/testing.md` not read in full).
- `Panel.lua` interaction with bar buttons beyond anchoring (`Panel.lua:7`, `185`) not traced in detail.
