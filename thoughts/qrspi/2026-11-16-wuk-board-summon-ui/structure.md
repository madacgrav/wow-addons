# Structure Outline

## Approach
Fix summon-queue behaviour first, since it is pure logic plus event wiring and testable without visuals. Then add one shared `WUK.Skin` helper and apply it frame by frame: summon panel, then board, then settings. Each frame gets its layout fixes in the same phase.

Test command (README.md:166): `lua5.1 WarlockUtilityKit/tests/run.lua`.
After each phase, deploy to `_forever_\Interface\AddOns` (robocopy) and test in game.

---

## Phase 1: Summon queue: group-only + clicked-target removal
The queue only holds group members. It drops people who leave the group. A successful ritual removes the row you clicked, even if another spell was cast in between. Failed and interrupted rituals leave the row alone.

**Files**: `Logic.lua`, `Summon.lua`, `tests/run.lua`

**Key changes**:
- `WUK.QueueKeep(r, now, ttl, inGroup: set<name>) -> bool` — new, pure. Keeps an entry only while it is younger than TTL **and** its name is in the `inGroup` set.
- `WUK.SummonTarget(pending: name?, lastCast: name?) -> name?` — new, pure. Returns `pending`, falling back to `lastCast`.
- `local GroupNames() -> set<name>` — new, in Summon.lua. Builds the set from `GroupUnits()` and `UnitFull()`.
- `OnChat` — modified. Returns early when `GroupNames()[name]` is false.
- `UpdateSummonRows` — modified. Prunes through `QueueKeep`, runs the prune even in combat (data only) and returns before the attribute writes. The panel is hidden when `not WUK.known.ritual`.
- Row `SetScript("PreClick", fn)` — new. On a plain left-click, sets the local `pendingSummon = self.name`.
- `UNIT_SPELLCAST_SUCCEEDED` handler — modified. Removes `Ambiguate(SummonTarget(pendingSummon, lastCastTarget))`, then clears `pendingSummon`.
- `UNIT_SPELLCAST_FAILED` / `UNIT_SPELLCAST_INTERRUPTED` — new handlers. For the player's ritual, they clear `pendingSummon`.

**Verify**:
- Tests pass, with new cases:
  - `QueueKeep` handles TTL expiry, a name not in the group, and a valid entry.
  - `SummonTarget` prefers `pending`, falls back to `lastCast`, and returns nil when both are nil.
- In game, on Forever:
  - A non-group guild member's "123" is ignored. After you invite them, "123" queues them.
  - When a queued member leaves the group, their row disappears.
  - Click a row, then cast another spell, then the ritual succeeds: the clicked row is removed.
  - Click a row and move to interrupt the ritual: the row stays.
  - **Record whether `UNIT_SPELLCAST_SUCCEEDED` fires for the ritual, and when.** This is the open risk from the design.

---

## Phase 2: Shared skin + summon panel restyle
Add the warlock window skin, then use it for the summon panel: short title, help in a tooltip, class-coloured names.

**Files**: `UI.lua`, `Summon.lua`

**Key changes**:
- `WUK.THEME = { bg, edge, title, accent }` — new colour table. It reuses the strip purples (`UI.lua:119-120`) and adds a fel green.
- `WUK.Skin(f, title: string, opts?: { close: bool }) -> titleFontString` — new. It applies to a `BackdropTemplate` frame:
  - backdrop and 1 px fel edge
  - purple title bar with the shard icon
  - an optional `UIPanelCloseButton`
- `WUK.Header(parent, text, x, y) -> FontString` — new. A fel-green section or column label, shared by phases 3 and 4.
- Summon panel — modified:
  - Call `WUK.Skin(panel, "Summons")`.
  - Title text becomes `"Summons (n)"`, updated in `UpdateSummonRows`.
  - `OnEnter` on the title bar shows a tooltip with the click help.
- Row text — modified: `ClassColor(name)` (via `C_ClassColor` / `RAID_CLASS_COLORS` from the unit's class), grey zone, red failure.

**Verify**:
- Tests still pass.
- In game:
  - The panel shows the themed frame, and the title count matches the number of rows.
  - Hovering the title shows the help.
  - Names show in class colours.
  - Shift+drag still moves the panel, and the lock setting still applies.

---

## Phase 3: Assignment board restyle + layout
The board uses the skin, has column headers and wider dropdowns, and remembers its position.

**Files**: `UI.lua`, `Board.lua`

**Key changes**:
- `WUK.MakeMovable(f, key, x, y, free?: bool)` — modified. With `free = true`, a plain drag moves the frame (no Shift, ignores the lock). Without it, the current behaviour is unchanged.
- `Build()` — modified:
  - The frame template becomes `BackdropTemplate` plus `WUK.Skin(win, "Warlock Assignments", { close = true })`.
  - Call `WUK.MakeMovable(win, "board", -170, 0, true)`.
  - Width is about 560.
  - Header row via `WUK.Header`: Warlock / Curse / Banish / Soulstone.
  - Dropdown x and width: curse ~140, banish ~120, soulstone ~150.
  - Buttons re-spaced.
- The `UISpecialFrames` entry and `DIALOG` strata are kept.

**Verify**:
- Tests still pass.
- In game:
  - "No curse", "No banish" and "No soulstone" are fully visible.
  - Headers line up with the columns.
  - A plain drag moves the board, and `/reload` keeps its position.
  - Dropdown menus open above the board.
  - Escape closes it, and the X button closes it.

---

## Phase 4: Settings restyle + sections + placement
Settings uses the skin, groups its controls into sections, and opens beside the board instead of on top of it.

**Files**: `Settings.lua`, `WarlockUtilityKit.toc`, `CHANGELOG.md`

**Key changes**:
- `Build()` — modified:
  - `BackdropTemplate` plus `WUK.Skin(win, "Warlock Utility Kit", { close = true })`.
  - Call `WUK.MakeMovable(win, "settings", 260, 0, true)`.
  - `WUK.Header` sections:
    - "Strip & ring": show, spin, collapse, dock.
    - "Pet": preferred pet.
    - "Frames": lock, reset, assignment board.
  - Height grows to fit.
- `Check(...)` — modified: the label is tinted to match the theme. The `Run()` routing is unchanged.
- Bump the TOC `## Version` to 0.4.0 and add a CHANGELOG entry.

**Verify**:
- Tests still pass.
- In game:
  - Open settings, then the board: they do not overlap.
  - Every checkbox, the dropdown and both buttons still work.
  - `/reload` keeps the positions.
  - "Reset positions" plus `/reload` brings back the side-by-side defaults.

---

## Testing Checkpoints
- **After phase 1**:
  - The queue holds only group members and removes the clicked player when the ritual succeeds.
  - The panel looks the same as before.
  - The ritual success timing is recorded.
- **After phase 2**: the summon panel is themed. `WUK.Skin`, `WUK.Header` and `WUK.THEME` exist for later phases.
- **After phase 3**: the board is themed and readable, with a saved position. Settings is still the old stock frame.
- **After phase 4**: all three frames are themed, nothing overlaps, and the version is 0.4.0.
