# Design Discussion

`R:Qn` refers to sections of this folder's `research.md`. Code references are relative to `WarlockUtilityKit/`.

## Current State
- **v1 is on main.** It has:
  - the strip: armor, pet and five stone buttons, plus a soulstone line (`UI.lua:31-49`, `Prep.lua`);
  - a local summon queue (`Summon.lua`) and a healthstone trade helper (`Trade.lua`);
  - a settings window and minimap button (`Settings.lua`).
- **Nothing is sent between players.** The only outbound chat is a whisper reply (`Trade.lua:7`), and no `CHAT_MSG_ADDON` handler exists (R:Q1).
- **Wiring:**
  - one event dispatcher, `WUK.On` (`Core.lua:11-14`);
  - an init/refresher lifecycle gated to warlocks (`Core.lua:118-125`);
  - the `/wuk` handler, which Settings controls route through (`Core.lua:141-153`, `Settings.lua:6`).
- **Secure-button pattern:** a pool created once, with attributes rewritten only out of combat (`Summon.lua:49-50, 84-95`).
- **Tests:** only `Logic.lua` is tested, by `tests/run.lua`, under Lua 5.1 in CI.
- **Forever facts that shape v2:**
  - Banes (Agony and Doom) and Curses are separate per-warlock slots (R:Q3). Curse of Shadow's existence is contradictory.
  - Addon messages are limited to 255 characters and 10 per prefix (refilling 1/s). Trial accounts can't send, and an `AddOnMessageLockdown` result exists (R:Q2).
  - `SetRaidTarget` is protected, and `GetRaidTargetIndex` may return secrets (R:Q4).
  - Enemy-aura readability under secrets is undocumented (R:Q5).

## Desired End State
1. **Assignment board** (`/wuk board`, a strip-menu button in Settings, and right-click on the minimap button). Each warlock in the raid or party gets one row:
   - name;
   - utility **curse**: none, Elements, Recklessness, Tongues, Weakness, Exhaustion, or Shadow (Shadow listed only if the warlock knows it);
   - **banish mark**: none or 1–8, shown as raid icons;
   - **soulstone target**: none or any group member.

   The board also has **Take lead**, **Announce** and **Sync** buttons, plus a "Lead: <name>" line.
2. **Lead-authoritative sync over addon messages.**
   - Only the current lead can edit; everyone else sees the board read-only.
   - Lead edits broadcast at once.
   - A warlock who joins, logs in or reloads asks for the full board.
3. **My assignment.**
   - A new strip line shows it, e.g. `Elements · Banish {star} · SS: Healbot`.
   - When it changes, a chat line is printed.
   - The soulstone stone button uses an assigned target: `/use [@Name] item:ID` instead of target/self.
4. **Announce.**
   - The lead posts one line per warlock. The channel is RAID_WARNING if the lead is raid leader or assistant, otherwise RAID (PARTY outside a raid).
   - Marks render as `{rt1}`..`{rt8}`.
5. **`/wuk probe`.** Prints facts the open risks depend on, for the current target and situation:
   - instance/combat state;
   - `C_ChatInfo.InChatMessagingLockdown()`;
   - for each of the player's `HARMFUL|PLAYER` auras on the target: whether name, spellId and expirationTime are secret, and whether `C_UnitAuras.GetAuraDuration` returns an object;
   - `C_Secrets.GetSpellAuraSecrecy` for each known curse/bane name;
   - whether `GetRaidTargetIndex("target")` is secret.

   DoT timers are not built in v2; the probe results decide v3.

**Verification:**
- Two warlocks in a party running WUK:
  - A takes lead and sets B to Elements + banish star + SS on C. B's board and strip update within about a second.
  - B cannot edit.
  - B `/reload`s and the board comes back via sync.
  - A clicks Announce and party chat shows the lines.
- A trial-account or lockdown send failure prints one warning, and the board keeps working locally.
- `/wuk probe` prints without errors in the open world, in combat and in a dungeon.
- `tests/run.lua` covers the encode/decode, accept rules and announce lines.

## Patterns to Follow
- **Register with `WUK.On` inside an init**, warlock-only, like `Summon.lua:97-100`. Push a refresher for any strip text (`Core.lua:112-116`).
- **Pure logic goes in `Logic.lua`, tested via `tests/run.lua`** (R:Q1). That covers message encode/decode, accept/reject rules, announce lines and the curse/mark tables.
- **Window style:** copy `Settings.lua:15-55`, which is lazy-built, uses `BasicFrameTemplateWithInset`, `UISpecialFrames` and Sync on show. Use `WowStyle1DropdownTemplate` + `SetupMenu` dropdowns (`Settings.lua:36-44`). Board frames are insecure, so no combat gating is needed.
- **Secure attributes are updated out of combat only** (`UI.lua:64-66`). This applies to the soulstone macro target.
- **Group iteration:** `GroupUnits` and `UnitFull` (`Summon.lua:5-16`). Move both to Core so the board can share them. Classes come from `select(2, UnitClass(unit)) == "WARLOCK"` (classFilename is not secret, R:Q4).
- **Wire format modeled on GuildStock** (R:Q2):
  - pipe-delimited plain text with a leading protocol version;
  - one send every 0.5s from a small queue;
  - check the send result code.
- **Secret guard on every incoming argument** with `WUK.Secret` (`Core.lua:7`), as in `Summon.lua:70`.

**Do NOT:**
- call `SetRaidTarget` (protected, R:Q4);
- rely on `GetRaidTargetIndex` of enemies (SecretReturns). Marks are only numbers we assign.
- use GUILD as the sync channel: the board is group-scoped;
- use AceComm or any library (none present; native is enough, as GuildStock shows);
- send per-frame or per-keystroke updates.

## Design Decisions
1. **Sync model: lead-authoritative.**
   - Any warlock may take lead (button or `/wuk lead`). The claim is broadcast, and the latest claim wins.
   - Receivers accept board rows only from the current lead.
   - If the leader or an assistant is a warlock, the board suggests them, but anyone can claim.
   - Why: the Warlock Raid Leader model (R:Q6) has no merge conflicts.
2. **Protocol.**
   - Prefix `WUKB`, version `1`, channel `RAID` (falls back to PARTY when not in a raid, R:Q2). Messages:

     | Message | Meaning |
     |---|---|
     | `1\|L\|<rev>` | lead claim from the sender |
     | `1\|A\|<rev>\|<warlock>\|<curse>\|<mark>\|<ss>` | one row (curse key or `-`, mark 0–8, soulstone name or `-`) |
     | `1\|R` | request for a sync |
     | `1\|E\|<rev>` | end of a full sync |

   - `rev = math.max(time(), lastRev + 1)`.
   - Rows with an unknown version or older rev are ignored.
   - Each message stays under 200 bytes, so no chunking is needed.
3. **State: in memory, not saved.**
   - The board resets when the group disbands, and `/reload` re-syncs from the lead.
   - The lead keeps its own copy in `WUK.char.board`, so a lead `/reload` doesn't wipe the plan.
4. **Assignment model:** `{ curse = key|nil, mark = 0..8, ss = name|nil }` per warlock name.
   - Curse keys map to names in a Logic table (`elements = "Curse of the Elements"`, …).
   - Banes are deliberately not assigned (R:Q3: separate slot, a personal choice).
5. **Degradation.**
   - When a send result is not Success, the queue pauses: 2^n backoff capped at 30s, as in GuildStock.
   - Lockdown or trial failures print one warning per session. The board then works locally only.
   - Incoming args that are secret are dropped.
6. **Soulstone integration.** If my row has `ss`, the soulstone button macro becomes `/use [@<ss>] item:ID` (`StoneMacro` gains an optional target). Otherwise the v1 behavior stays.
7. **Probe output:** plain chat lines, one fact each. There is no persistence; the user pastes the output back for v3 planning.
8. **Files:**
   - new `Comm.lua` (prefix registration, send queue, receive dispatch);
   - new `Board.lua` (state, window, announce, strip line);
   - probe logic in `Board.lua` or `Core.lua`;
   - pure helpers added to `Logic.lua`;
   - TOC order: Logic, Core, UI, Prep, Summon, Trade, Comm, Board, Settings.

## What We're NOT Doing
- DoT/curse timer bars (deferred to v3, pending probe results).
- Assigning Banes; a per-curse cap or auto-assign; saved "grimoires" or per-boss plans.
- Setting raid marks, or reading enemy marks to auto-target.
- A curse cast button on the strip (could follow later).
- Guild-wide sync; compatibility with other addons' protocols (Warlock Curse Power etc.).
- Whispering each warlock their assignment. Announce plus the strip line cover it.
- Healer/Sheep/Kick/Shackle assignments (WMT-style).

## Open Risks
- **Addon messages in instances/encounters** may be locked down (R:Q2 open area). Mitigation: degrade locally, and probe reports `InChatMessagingLockdown`. The board is usually set up before the pull.
- **`CHAT_MSG_ADDON` sender format** (Name vs Name-Realm) is undocumented. Normalize with `Ambiguate(sender, "none")`, as v1 does.
- **Curse of Shadow** may not exist on Forever. List it only if the local spellbook has it, and accept unknown curse keys from the lead for display.
- **`@Name` in `/use` for soulstone** must resolve a group member, which requires the exact name with realm for cross-realm players. Verify in game.
- **Raid of 40 with 8+ warlocks:** a full sync is about 9 messages, under the 10-message burst limit, and pacing at 0.5s keeps it safe.
- **Lead race:** two people click Take lead at once. The latest received claim wins, and both boards converge once the claims arrive.
