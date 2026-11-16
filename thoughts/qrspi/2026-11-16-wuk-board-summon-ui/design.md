# Design Discussion

## Current State

### Summon queue
- **Group check**:
  - `OnChat` queues every matching sender from party, raid, guild, say and whisper, with no membership check (`Summon.lua:58-63`, `:86-87`).
  - "Not in group" exists only as a red row label: `Context` sets no `inGroup`, so `SummonFailure` returns "not in group" (`Summon.lua:15-20`, `Logic.lua:70`).
  - Pruning drops entries by TTL only (`Summon.lua:41`).
- **Zone**: zone is raid-only (`Summon.lua:7-13`), so rows in a party always show "?".
- **Removal after a summon**:
  - The success handler removes `Ambiguate(WUK.lastCastTarget)` (`Summon.lua:89-93`).
  - `lastCastTarget` is overwritten by every player spell sent (`Core.lua:161-163`).
  - Failed or interrupted casts are not handled.
- **Panel**:
  - Flat black at 0.6 alpha with no edge (`Summon.lua:69`).
  - Long instructional title (`:71`).
  - Rows show `name  zone  failure` (`:49`).

### Board
- `BasicFrameTemplateWithInset`, 470x370, `CENTER`, `DIALOG` strata (`Board.lua:97-98`).
- Plain drag; no saved position.
- No column headers.
- Dropdowns are 120, 90 and 110 px wide (`Board.lua:114-131`). The template truncates the selected label, for example "No soulsto...".

### Settings
- The same template, 320x314, `CENTER`, `DIALOG` (`Settings.lua:18-19`).
- Opens directly over the board, because both use the same anchor and strata.
- Five unlabelled checkboxes, a pet dropdown and two buttons, with no sections (`Settings.lua:26-57`).

### Theme
- The purple palette exists only on the strip: rim, disc, swirl and glow (`UI.lua:96-125`), plus the chat prefix `|cff9482c9` (`Core.lua:8`).
- The dialog frames use stock Blizzard chrome.
- There are no media files.

## Desired End State

### All three frames
- Board, summon queue and settings share one warlock skin:
  - dark void-purple background
  - thin fel-green edge
  - purple title bar with a soul-shard icon
  - fel-green or lavender accents on headers
- Built from Blizzard textures only.

### Summon queue
- Only queues requesters who are in your party or raid, whatever channel the request came from.
- Drops entries when the person leaves the group.
- Removes the player you clicked when Ritual of Summoning succeeds.
- Has a short title ("Summons (n)"); the click help moves to a tooltip.
- Rows have class-coloured names.

### Board
- Column headers: Warlock / Curse / Banish / Soulstone.
- Dropdowns wide enough that the default labels fit.
- Remembered position.

### Settings
- Grouped into labelled sections: Strip & ring / Pet / Frames.
- Opens beside the board instead of on top of it, with a remembered position.

### Verification
- **Unit tests** (`tests/run.lua`):
  - new pure helper for group membership and pruning
  - new pure helper for picking the removal target
- **In-game, on Forever**:
  - Party: a guild member types "123" while out of the group, and nothing is queued. After the invite, typing "123" queues them.
  - Party: a queued member leaves the group, and their row disappears.
  - Click a row and the ritual succeeds: the row disappears. Cast another spell between clicking and the ritual finishing, and the correct row is still removed.
  - Interrupt the ritual (move): the row stays.
  - Open settings, then the board: no overlap. `/reload` keeps both positions. "Reset positions" plus `/reload` restores the defaults.
  - Board dropdown labels "No curse", "No banish" and "No soulstone" are not truncated.

## Patterns to Follow
- **Pure logic in `Logic.lua` with tests in `tests/run.lua`**: queue helpers follow the `QueueAdd`/`QueueRemove`/`QueuePrune` style (`Logic.lua:55-66`, `tests/run.lua:31-35`).
  - Membership checks take a plain name set or a predicate, so they are testable without WoW APIs.
- **Name normalization**: `Ambiguate(x, "none")` on both the sender and roster sides (`Summon.lua:60`, `Core.lua:124-128`).
  - Reuse `WUK.UnitFull` and `WUK.GroupUnits`; do not add a second roster walker.
- **Secret guards**: `WUK.Secret` on every name and text input (`Core.lua:7`, `Summon.lua:59`).
- **Secure rows**:
  - Change attributes only out of combat (`Summon.lua:39`) and replay them via `WUK.refreshers` on `PLAYER_REGEN_ENABLED` (`Summon.lua:95`, `Core.lua:156`).
  - Queue data may change in combat; the row display updates afterwards.
- **Saved positions**: `WUK.MakeMovable` with keys in `db.frames` (`UI.lua:13-26`).
  - Reset is `wipe(db.frames)` plus `/reload` (`Core.lua:251`).
- **Settings routing**: settings mutations keep going through `/wuk` via `Run()` (`Settings.lua:5`).
- **Palette**:
  - Purple `0.58,0.51,0.79` and near-black `0.04,0,0.07` from the strip (`UI.lua:119-120`).
  - Glow `0.7,0.3,1` (`UI.lua:99`).
  - Chat purple `9482c9` (`Core.lua:8`).
  - Add one fel green, about `0.45,0.85,0.3`, as the accent.

### Do NOT follow
- **`WUK.lastCastTarget`**: do not rely on it as the summon target (`Core.lua:161-163`). Any spell clobbers it.
- **Copied frame boilerplate**: do not copy the Board/Settings drag and template code a third time (`Board.lua:97-101`, `Settings.lua:18-22`). The skin helper replaces it.
- **Panel-shown-with-no-rows**: today an unknown ritual shows the panel with every row hidden (`Summon.lua:44-55`). The new panel must not inherit this.

## Design Decisions
1. **Group check: group-only, any channel.**
   - `OnChat` queues only if the sender is in `GroupUnits()`.
   - The prune predicate becomes "younger than TTL **and** still in the group".
   - Prune also runs on `GROUP_ROSTER_UPDATE`, which is already wired (`Summon.lua:88`).
   - Why: this was your choice. It keeps whisper and guild requests from groupmates, and the queue can no longer fill with people you can't summon.
   - The "not in group" failure label stays in `SummonFailure` as a safety net, but in practice it won't show.
2. **Removal target: the clicked row's name.**
   - A row `PreClick` (plain Lua, allowed in combat) records `pendingSummon = row.name` on a plain left-click.
   - `UNIT_SPELLCAST_SUCCEEDED` for the ritual removes `pendingSummon`, falling back to `lastCastTarget` for a manual `/cast`.
   - `UNIT_SPELLCAST_FAILED`/`_INTERRUPTED` for the ritual clear `pendingSummon`.
   - Why: you chose "on cast success". The clicked name is the true intent, and other spells can't clobber it.
3. **Shared skin helper in `UI.lua`.**
   - `WUK.Skin(frame, title)` turns a `BackdropTemplate` frame into the themed window: backdrop, fel edge, title bar plus shard icon, and a `UIPanelCloseButton` when the frame is a dialog.
   - Board, settings and summon panel all call it.
   - Buttons, checkboxes and dropdowns keep their Blizzard templates. They stay functional and familiar; only the label colours are tinted.
   - Why: one place for the look, no media files, and less code than the current per-frame boilerplate.
4. **Separate windows with saved positions.**
   - Board and settings both use `MakeMovable`, with keys `"board"` and `"settings"`.
   - `MakeMovable` gains an optional `free` flag so dialogs drag without Shift; the HUD frames keep Shift and lock.
   - Default positions sit side by side: board left of centre, settings right of centre, so they don't overlap on first open.
   - Why: this was your choice. It is the smallest change that ends the overlap and reuses the existing reset path.
5. **Board layout.**
   - About 560 px wide.
   - Columns: name ~110, curse ~140, banish ~120, soulstone ~150.
   - Header row of fel-green labels above row 1.
   - Lead line and buttons kept; buttons are re-spaced to the new width.
6. **Summon panel.**
   - Skinned, with the title "Summons (n)".
   - Hovering the title shows the click help (click summon / ctrl target / right remove).
   - Rows show a class-coloured name, grey zone and red failure reason.
   - Hidden when the queue is empty **or** the ritual is unknown.
7. **Settings sections.**
   - Fel-green section headers: "Strip & ring" (show, spin, collapse, dock), "Pet" (preferred pet), "Frames" (lock, reset, assignment board).
   - The window height grows to fit.
   - Routing is unchanged.

## What We're NOT Doing
- Tracking a summoned player's arrival, or a "pending" row state.
- Sharing or syncing the summon queue between warlocks.
- Party zone lookup (`RosterZone` stays raid-only, `Summon.lua:8`).
- Custom TGA art or fonts.
- Merging the board and settings into one tabbed window.
- Changing board sync, the wire protocol, or announce behaviour.
- Restyling the strip or ring, or the minimap button.
- Healthstone trade queue (`Trade.lua`).

## Open Risks
- **When the ritual's success event fires** (research Open Areas):
  - If `UNIT_SPELLCAST_SUCCEEDED` fires when the portal is placed, the row is removed before the summon actually completes, which is accepted with "on cast success".
  - If it does not fire at all on Forever, removal silently fails. Verify in-game in the first phase.
- **`PreClick` on secure buttons**: assigning `PreClick` out of combat is allowed. Confirm that it fires for the macro click and doesn't taint the secure action.
- **Overlay order**: if a `BackdropTemplate` dialog keeps `DIALOG` strata but drops `BasicFrameTemplate`, dropdown menus must still render above it. Confirm dropdown list strata.
- **Combat edge cases**:
  - Pruning in combat removes queue data while row attributes stay stale until `PLAYER_REGEN_ENABLED`.
  - A click in that window could still target the removed player. This is existing behaviour.
- **Moving the summon panel and old saved positions**: dialog sizes change, so a saved `db.frames.summon` position may sit partly off-screen. "Reset positions" covers this.
