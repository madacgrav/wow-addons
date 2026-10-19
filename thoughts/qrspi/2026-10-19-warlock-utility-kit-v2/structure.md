# Structure Outline

## Approach
- Add a local assignment board first: one warlock acts as their own lead, with no networking.
- Then layer lead-authoritative addon-message sync on top, then announce.
- A `/wuk probe` command ships first so in-game facts about secrets and lockdown arrive early.
- Pure rules (tables, encode/decode, accept, announce lines) live in `Logic.lua` and are tested by `tests/run.lua`.

---

## Phase 1: `/wuk probe`
Prints the in-game facts the open risks depend on. It has no UI and no state.

**Files**: `Core.lua`

**Key changes**:
- `WUK.Probe()`. It prints one chat line each for:
  - `IsInInstance()` type, `InCombatLockdown()`, `C_ChatInfo.InChatMessagingLockdown()`;
  - target exists / hostile, and whether `GetRaidTargetIndex("target")` is secret;
  - each `C_UnitAuras.GetUnitAuras("target", "HARMFUL|PLAYER")` entry: whether name, spellId and expirationTime are secret, and whether `C_UnitAuras.GetAuraDuration(target, auraInstanceID)` is non-nil;
  - `C_Secrets.GetSpellAuraSecrecy(name)` for known curse/bane spell names (calls are wrapped in `pcall`, since the API may be missing).
- `/wuk probe` branch in the slash handler.

**Verify**:
- `lua WarlockUtilityKit/tests/run.lua` passes.
- In game:
  - `/wuk probe` with no target, then with a cursed mob in the open world, in combat, and in a dungeon. No Lua errors.
  - The output is pasted back for v3.

---

## Phase 2: Local board + my assignment + soulstone target
A board window lists the group's warlocks with curse, banish-mark and soulstone dropdowns. You are lead by default, and your own row shows on the strip and drives the soulstone button.

**Files**: `Logic.lua`, `Core.lua` (move `GroupUnits`/`UnitFull` here from Summon.lua), `Summon.lua` (use the moved helpers), `Board.lua` (new), `UI.lua`, `Settings.lua`, `WarlockUtilityKit.toc`, `tests/run.lua`

**Key changes**:
- `WUK.CURSES`: ordered list of `{ key, name }`. The keys are `elements, recklessness, tongues, weakness, exhaustion, shadow` (pure).
- `WUK.MarkToken(mark: 0..8): string` returns `"{rt5}"`, or `""` for 0 (pure).
- `WUK.AssignmentText(row): string` returns e.g. `"Elements · Banish {rt1} · SS: Healbot"`, or `"No assignment"` (pure).
- `WUK.StoneMacro(kind, count, itemID, createSpell, ssTarget?)`: an optional target gives `/use [@ss] item:ID` for soulstone (pure, extended).
- `WUK.GroupUnits()` and `WUK.UnitFull(unit)` move to Core. `WUK.GroupWarlocks(): name[]` uses `select(2, UnitClass(u)) == "WARLOCK"` and includes the player.
- `WUK.board = { lead: name?, rev: number, rows: { [warlock]: { curse?, mark, ss? } } }`. It is in memory; the lead's copy is mirrored to `WUK.char.board`.
- `WUK.SetAssignment(warlock, field, value)`: edits are lead-only (the player is lead while solo or with no lead), they bump `rev`, and refresh.
- Board window `WUKBoard`:
  - a lazy `BasicFrameTemplateWithInset`;
  - one row per warlock, with name plus three `WowStyle1DropdownTemplate` menus (curse, mark with raid icons, ss from the group);
  - a "Lead: <name>" line;
  - dropdowns are disabled when you are not the lead.
- Opened by `/wuk board`, a Settings "Assignment board" button, and right-clicking the minimap button.
- Strip:
  - grows to 76 high;
  - gains a new `f.assign` FontString filled by a refresher;
  - prints a chat line when my row changes.
- The stone refresher passes `board.rows[me].ss` into `StoneMacro`.

**Verify**:
- Tests cover `MarkToken`, `AssignmentText` (none/partial/full) and `StoneMacro` with an ssTarget.
- In game, solo or in a party:
  - `/wuk board` lists you (and any party warlocks).
  - Setting curse, mark and SS updates the strip line.
  - Clicking soulstone with SS set to a party member soulstones them.
  - The assignment survives `/reload` (lead copy).
  - The summon queue still works after the helper move.

---

## Phase 3: Lead-authoritative sync
Other warlocks running WUK see the lead's board live, can't edit it, and re-sync after `/reload`.

**Files**: `Logic.lua`, `Comm.lua` (new), `Board.lua`, `WarlockUtilityKit.toc`, `tests/run.lua`

**Key changes**:
- `WUK.Encode(kind, ...): string` / `WUK.Decode(msg): { v, kind, ... }?` handle `1|L|rev`, `1|A|rev|warlock|curse|mark|ss`, `1|R` and `1|E|rev`. `-` encodes nil. They return nil on a bad version or shape (pure).
- `WUK.AcceptRow(board, sender, rev): bool`: true only if `sender == board.lead` and `rev >= board.rev` (pure).
- `WUK.AcceptLead(board, rev): bool`: the newest claim wins (pure).
- `Comm.lua`:
  - registers prefix `WUKB` at init;
  - `WUK.Send(msg)` queues a message, flushed one every 0.5s through `C_ChatInfo.SendAddonMessage(prefix, msg, IsInRaid() and "RAID" or "PARTY")`;
  - on a non-Success result, backs off 2^n (capped at 30s) and warns once per session;
  - dispatches `CHAT_MSG_ADDON`: filters prefix and secret args, `Ambiguate(sender, "none")`, ignores self, then calls `WUK.OnBoardMessage(sender, decoded)`.
- `Board.lua`:
  - Take lead button and `/wuk lead` send `L`;
  - lead edits send `A` for the changed row;
  - receiving `R` makes the lead send all `A` rows plus `E`;
  - `GROUP_ROSTER_UPDATE` (on joining) and login send `R`;
  - leaving the group clears the board.

**Verify**:
- Tests cover the Encode/Decode round-trip, rejection of bad versions and shapes, AcceptRow (non-lead / older rev / ok), and AcceptLead.
- In game, with two warlocks in a party:
  - A takes lead and edits B. B sees the change within about 1s, and B's dropdowns are disabled.
  - B `/reload`s and gets the board back.
  - B takes lead and A becomes read-only.
  - A trial or lockdown failure prints one warning, and nothing errors.

---

## Phase 4: Announce
The lead posts the plan to group chat.

**Files**: `Logic.lua`, `Board.lua`, `tests/run.lua`

**Key changes**:
- `WUK.AnnounceLines(board): string[]` returns one line per assigned warlock, `"WUK: Name - Curse of the Elements - Banish {rt1} - SS: Healbot"`, in sorted name order, skipping empty rows (pure).
- The Announce button (lead only) sends each line via `C_ChatInfo.SendChatMessage or SendChatMessage`. The channel is `RAID_WARNING` if `UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")` in a raid, otherwise `RAID`/`PARTY`. Lines are spaced with `C_Timer.After(i * 0.3)`.

**Verify**:
- Tests cover AnnounceLines ordering, empty-row skipping and mark tokens.
- In game, the party sees the lines with raid icons; in a raid as assistant, they appear as raid warnings.

---

## Testing Checkpoints
- **After P1:** `/wuk probe` runs cleanly in every context, and its output is captured for v3.
- **After P2:** the solo board, strip assignment line and soulstone-on-assigned-target work, and the v1 summon queue is unaffected.
- **After P3:** two clients converge on the lead's board, and non-leads are read-only. Send failures degrade to a local board with one warning.
- **After P4:** Announce posts the correct lines to the correct channel.
- **Every phase:** `lua WarlockUtilityKit/tests/run.lua` passes, and the CI package workflow stays green.
