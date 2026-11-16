# Research Questions

## Context
Focus on the WarlockUtilityKit addon (`WarlockUtilityKit/`): `Board.lua`, `Summon.lua`, `Settings.lua`, `UI.lua`, `Core.lua`, `Logic.lua`, `Comm.lua`, `Prep.lua`, and `tests/run.lua`. Prior design docs for this addon live under `thoughts/qrspi/2026-10-19-warlock-utility-kit*`, `thoughts/qrspi/2026-10-20-wuk-button-layout`, and `thoughts/qrspi/2026-11-16-wuk-*`.

## Questions
1. How is the `WUKBoard` frame built in `Board.lua`? Cover:
   - template, size and anchoring
   - row layout and column x-offsets
   - header labels
   - dropdown widths and default text
   - how rows are rebuilt when the roster or board data changes
   - where it sits relative to `WUKSettings` and other WUK frames when they are open together
2. How is the `WUKSettings` frame built in `Settings.lua`? Cover:
   - each control: checkboxes, the preferred-pet dropdown, buttons
   - their positions and grouping
   - what saved setting each control reads and writes
   - how the minimap button opens it
3. How is the `WUKSummon` panel in `Summon.lua` constructed and laid out? Cover:
   - backdrop, title and row pool
   - the row count limit
   - secure button attributes and the click/ctrl/right-click behaviours
   - what each row displays
   - when the panel is shown, hidden or refreshed, including combat-lockdown constraints
4. How does the summon queue decide whether a requester is in the player's party or raid? Trace `OnChat`, `RosterZone`, `Context`, `IsSummonRequest`, `QueueAdd` and `QueuePrune`:
   - which chat channels are accepted
   - how sender names are normalized (realm suffixes, case)
   - which roster APIs are queried (`UnitInParty`, `UnitInRaid`, `GetRaidRosterInfo`, `IsInGroup`, and so on)
   - which events trigger re-pruning when the roster changes
5. Trace a summon end to end: chat request, queue entry, row click, `UNIT_SPELLCAST_SENT` in `Core.lua`, then the `UNIT_SPELLCAST_SUCCEEDED` handler in `Summon.lua`. What target information is recorded at each step? What does the success handler currently do? What do `QueueRemove` and `SummonFailure` do, and who calls them? Which events or APIs signal that a ritual completed, failed, was interrupted or was accepted, and which ones does the codebase already use or probe for (see `Core.lua` `Probe` and `probe-results.md` in the v2 qrspi folder)?
6. What visual styling exists across WUK frames? Cover:
   - templates (`BasicFrameTemplateWithInset`, `BackdropTemplate`, `WowStyle1DropdownTemplate`)
   - backdrop and border textures
   - colors, fonts, glows (`AddGlow`) and any bundled media files
   - Blizzard warlock-related textures or atlases referenced anywhere in the repo
   - the conventions in `UI.lua`: `MakeMovable`, saved positions, frame lock, "Reset positions"
   - the local `Dropdown`/`Check`/button helpers in `Board.lua` and `Settings.lua`
7. How is board and queue state stored and synced? Cover:
   - the SavedVariables structure
   - `SendRow`, `SendFullBoard` and `OnBoardMessage`
   - `Encode` and `Decode`
   - whether the summon queue is local-only or shared between warlocks
   - what test coverage `tests/run.lua` has for board, roster and queue logic, and how the tests are run
