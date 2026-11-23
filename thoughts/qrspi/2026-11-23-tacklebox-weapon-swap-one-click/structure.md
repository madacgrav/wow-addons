# Structure Outline

## Approach
Five slices, safest first: two panel-only slices (no secure code), then weapon memory, then the one-key cast and reel, then docs and release.
- Pure decisions go in `Logic.lua`, tested in `tests/run.lua`.
- WoW glue goes in Panel/Actions/Core.
- Secure attributes, bindings and CVars change only outside combat (design "Patterns to Follow").

**Every phase verifies with:**
- `<skill>/scripts/lint.sh TackleBox` (clean).
- `lua5.1 TackleBox/tests/run.lua` (prints `all tests passed`).
- Deploy with robocopy into `_forever_\Interface\AddOns\TackleBox`, then in game `/reload` with no Lua errors, plus the phase's manual checks.

---

## Phase 1: Collapsible panel + zone line
The header always shows the current zone's fishing status, and a chevron hides or shows the tab strip and rows, with the state remembered.

**Files**: `TackleBox/Logic.lua`, `TackleBox/Panel.lua`, `TackleBox/Core.lua`, `TackleBox/tests/run.lua`
**Key changes**:
- `TB.ZoneStatus(zones, lures, skill, zone) -> {text, sub, flag} | nil` (new, Logic):
  - Shares the per-zone row builder with `TB.WhereRows` (`Logic.lua:49-71`), so both produce the same flags.
  - Returns `{text="<zone>: no fishing data"}` for an unknown zone and `nil` with no skill.
- `DEFAULTS.expanded = false` (`Core.lua:17`).
- `TB.RenderPanel(rows, skill, misses, tabs, active, zone)` (modified): sets the zone line text and color using `FLAG_COLORS` (`Panel.lua:234`), toggles the tabs and rows with `TB.db.expanded`, and sets the height from that state.
- New header widgets in `Build()`: `panel.zone` (FontString, truncated) and `panel.expand` (chevron Button, `OnClick` flips `TB.db.expanded` then `TB.Refresh()`).
- `TOP` becomes header + zone line. The tab strip and rows move down by one line.

**Verify**:
- Tests: `ZoneStatus` returns `here`, `too low`, `outgrown`, unknown zone and no skill. `WhereRows` tests (`tests/run.lua:27-39`) still pass.
- In game: the line reads correctly in Orgrimmar and in an unknown zone, and changes after crossing a zone border.
- In game: collapse, expand and `/reload` keep the state, and toggling works in combat.

---

## Phase 2: Scrollable rows
Rows scroll inside a box at most 10 rows tall, for every tab. The Catch list is no longer cut off at 30 rows.

**Files**: `TackleBox/Panel.lua`
**Key changes**:
- `panel.scroll` (ScrollFrame, `UIPanelScrollFrameTemplate` if present in `refs/forever-api-index.md` / `refs/widgets.md`, else a bare ScrollFrame with `OnMouseWheel`) and `panel.content` (scroll child).
- Rows are re-parented to `panel.content` and created lazily by `GetRow(i)`, replacing the fixed `MAX_ROWS` loop (`Panel.lua:3, 112-138`). The ponytail comment at `:2` is removed.
- Height: `content` = `#rows * 26`; visible = `min(max(#rows,3),10) * 26`.
- Scroll resets to 0 when `active` changes.

**Verify**:
- No new pure logic, so the existing tests just have to stay green.
- In game: a Catch list with more than 10 rows scrolls with the wheel, and its tooltips still show.
- In game: short tabs don't show an empty scroll box, a tab switch resets to the top, and collapse still hides it all.

---

## Phase 3: Weapon memory + re-equip button
While the main hand holds a non-pole, the main-hand and off-hand weapons are remembered per character. With a pole equipped, the pole slot becomes "Equip weapons".

**Files**: `TackleBox/Logic.lua`, `TackleBox/Actions.lua`, `TackleBox/tests/run.lua`
**Key changes**:
- `BagItems() -> { {id, classID, subID, bag, slot, link} }` (modified, `Actions.lua:79-91`). `TB.PickPole` is unchanged.
- `TB.FindWeapon(items, want{id, link}) -> item | nil` (new, Logic): an exact link match first, then an ID match.
- `TB.WeaponsMacro(mhLoc, ohLoc) -> string | nil` (new, Logic): builds `/equipslot 16 b s` plus an optional `\n/equipslot 17 b s`. Returns nil when the main hand is missing.
- `TB.char.weapons = { mh={id,link}, oh={id,link}|nil }` (new SV key). It is written in the Actions refresher whenever slot 16 is not a pole, and not written while a pole is equipped.
- `A.pole` (modified):
  - When a pole is equipped and `TB.char.weapons` exists, it is `{weapons=true, macro=..., icon=mh icon, usable, need="<name> not in bags"}`.
  - `Apply()` pole branch: `macrotext = a.macro` for the weapons variant. The tooltip says "Equip weapons".

**Verify**:
- Tests:
  - `FindWeapon` prefers the link, falls back to the ID, and returns nil when the weapon is missing.
  - `WeaponsMacro` handles MH only, MH+OH and a missing MH.
- In game:
  - Equip a pole; the slot shows your weapon icon, and clicking it restores MH (+OH). Repeat with a two-hander.
  - Bank the weapon; the button greys out with the red text.
  - `/reload` with the pole on; the snapshot survives.

---

## Phase 4: One-key cast + reel
`/tb bind <KEY>` gives one key that casts Fishing, then reels in with Interact while the line is out. Soft-target CVars are raised during the channel and restored afterwards.

**Files**: `TackleBox/Actions.lua`, `TackleBox/Core.lua`, `TackleBox/Logic.lua`, `TackleBox/tests/run.lua`
**Key changes**:
- `TB.db.castKey` (string | nil) and `TB.db.cvarBackup` ({SoftTargetInteract, SoftTargetInteractRange} | nil): new SV keys.
- `TB.NormalizeKey(s) -> string | nil` (new, Logic): trims and upper-cases the key; nil for empty input.
- An owner frame in Actions provides:
  - `TB.BindCast()`, which out of combat clears overrides and then calls `SetOverrideBindingClick(owner, true, key, "TBAction_cast")`.
  - `TB.ReelMode(on: boolean)`:
    - `on`, out of combat with a key bound: back up the CVars, set `3` / larger range, then `SetOverrideBinding(owner, true, key, "INTERACTTARGET")`.
    - `off`: restore the CVars, clear the backup and call `BindCast()`.
- Core wiring:
  - a fishing `CHANNEL_START` calls `ReelMode(true)`, and `CHANNEL_STOP` calls `ReelMode(false)`, both next to `Core.lua:110-136`
  - `PLAYER_REGEN_ENABLED` calls `ReelMode(false)` if needed
  - `PLAYER_LOGIN` restores any leftover backup and then calls `BindCast()`
  - `PLAYER_LOGOUT` restores the CVars
- Slash commands: `/tb bind <KEY>` and `/tb unbind`, added to the help line (`Core.lua:236-247`).
- The Cast button keeps its attributes while hidden. If the key fires twice in game (once on press, once on release), register the button for the down edge only (design risk).

**Verify**:
- Tests: `NormalizeKey` handles `" f "` to `"F"`, empty input to nil and `"SHIFT-F"` (unchanged).
- In game:
  - `/tb bind F` with the panel closed: F casts, F reels in the bobber, and F casts again. Do it five times.
  - `/reload` mid-cast, then check the CVars are back (`/dump GetCVar("SoftTargetInteract")`).
  - Start a channel in combat: no errors, and F casts again after combat.
  - `/tb unbind` frees the key.

---

## Phase 5: Docs + release
Document the new behaviour and ship it as 1.1.0.

**Files**: `TackleBox/README.md`, `TackleBox/CHANGELOG.md`, `TackleBox/TackleBox.toc`
**Key changes**:
- README:
  - The new slash commands, "Enable Interact Key" and soft-target notes.
  - Known limits: interact may grab an NPC or player, far bobbers may not reel in, no swap in combat.
- Collapse, zone line and scroll in the panel section.
- CHANGELOG 1.1.0 and `## Version: 1.1.0`.
- `docs/index.html`'s ADDONS entry only if the description changes.

**Verify**: lint and tests green. The README commands match `/tb` help output.

## Testing Checkpoints
- **After Phase 1:** the header shows the zone status, and the tabs collapse and remember their state. Secure code is untouched.
- **After Phase 2:** every tab scrolls at up to 10 rows, and the Catch list is complete.
- **After Phase 3:** `TB.char.weapons` is tracked, and the pole slot toggles between pole and weapons. Logic tests cover the lookup and macro.
- **After Phase 4:** the bound key casts and reels, CVars are always restored, and nothing errors in combat.
- **After Phase 5:** docs and version are at 1.1.0, ready for `/qrspi-plan-toolkit:8-pr`.
- Phases 1-2 and 3-4 are independent pairs. If Phase 4 fails in game, Phases 1-3 still ship.
