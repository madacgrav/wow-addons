# Structure Outline

## Approach
Self-contained addon in `WarlockUtilityKit/`: Mainline APIs only, names learned from the client (enUS), secure macro buttons rewritten out of combat. Pure logic sits in plain functions checked by `tests/run.lua` under stock Lua 5.1, and everything else is verified manually in the Forever client.

Shared namespace: `local _, WUK = ...` in every file. Pure functions hang off `WUK` so tests can load files with stub globals.

---

## Phase 1: Load, persist, count shards and stones
The addon loads on Forever and shows a movable strip with live shard/stone counts. Settings survive `/reload`.

**Files**: `WarlockUtilityKit/WarlockUtilityKit.toc`, `Core.lua`, `UI.lua`, `tests/run.lua`

**Key changes**:
- TOC: `## Interface: 16001`, `## SavedVariables: WarlockUtilityKitDB`, `## SavedVariablesPerCharacter: WarlockUtilityKitCharDB`, files listed in load order
- `WUK.ClassifyItem(name: string?): "shard"|"healthstone"|"soulstone"|"spellstone"|"firestone"|nil` (pure)
- `WUK.ScanBags(): Counts { shard, healthstone, soulstone, spellstone, firestone: number; slots: {[kind]: {bag, slot}} }`, which uses `C_Container.*`
- `WUK.MergeDefaults(sv: table?, defaults: table): table` (pure, nil-safe for the loader bug)
- `WUK.On(event, fn)`, a single event frame dispatcher
- Events: `ADDON_LOADED` (SV init), `PLAYER_LOGIN`, `BAG_UPDATE_DELAYED` (rescan + `WUK.Refresh()`)
- `WUK.Refresh()`: one entry point that UI and later phases hook into
- UI: strip frame with Shift+drag; position saved to `WarlockUtilityKitDB.frames.strip`
- `/wuk show|hide|lock|reset`
- Non-warlock characters: addon stays dormant after `PLAYER_LOGIN`

**Verify**: `lua tests/run.lua` passes (ClassifyItem, MergeDefaults). In game: the strip shows the correct counts, the counts update after looting or using a shard, and the position survives `/reload` and relog. No errors on a rogue alt.

---

## Phase 2: Spellbook scan + prep button
One secure button casts the next unsatisfied prep step per click. The border shows its state.

**Files**: `Core.lua` (spell scan), `Prep.lua`, `UI.lua`, `tests/run.lua`

**Key changes**:
- `WUK.ScanSpells(): Known { [key]: spellName }`, with keys `armor, detect, imp, voidwalker, succubus, felhunter, soullink, healthstone, soulstone, ritual`. Each key maps to the highest known rank by name. Forever spellbook API is probed here (Open Risk).
- `PrepState { known: Known, counts: Counts, buffs: {armor, detect, soullink, demonicSacrifice: bool}, pet: string?, preferredPet: string, soulstoneActive: bool, inCombat: bool }`
- `WUK.NextPrepStep(state: PrepState): Step? { key: string, macro: string }` (pure). Returns nil when fully prepped.
- `WUK.PrepRemaining(state): number` (pure, for the badge)
- `WUK.ReadPlayerBuffs(): buffs`, which uses `C_UnitAuras.GetPlayerAuraBySpellID` or name scan with an `issecretvalue` guard
- Secure button: `SecureActionButtonTemplate`, `type="macro"`, `RegisterForClicks("AnyUp","AnyDown")`
- `WUK.UpdatePrepButton()`: no-op under `InCombatLockdown()`, otherwise sets `macrotext` and border colour (yellow + count / green / red in combat)
- Events: `SPELLS_CHANGED`, `UNIT_AURA` (player), `UNIT_PET`, `PLAYER_REGEN_DISABLED/ENABLED`
- `/wuk pet <imp|voidwalker|succubus|felhunter>` writes `WarlockUtilityKitCharDB.pet`

**Verify**: `lua tests/run.lua` covers NextPrepStep's step order, skip rules, the no-shard fallback to Imp, and the nil-when-done case. In game, a naked warlock clicks through to green; mid-chain combat turns the border red and blocks the click; `/wuk pet` changes the summoned pet.

---

## Phase 3: Soulstone target + timer
The strip shows who holds the soulstone and the time remaining, and survives relog.

**Files**: `Prep.lua` (or `Core.lua`), `UI.lua`, `tests/run.lua`

**Key changes**:
- Event `UNIT_SPELLCAST_SUCCEEDED` (unit "player"): on a Soulstone Resurrection cast, record `{ target = UnitName("target") or player, expires = time() + 1800 }` in `WarlockUtilityKitCharDB.soulstone`
- `WUK.SoulstoneRemaining(record, now: number): number?` (pure; nil when expired or absent)
- 1-second `C_Timer.NewTicker` that updates the strip text only while a record is active
- Prep state `soulstoneActive` is fed from the record, so the prep chain skips "use soulstone"

**Verify**: tests cover SoulstoneRemaining edge cases (absent, expired, active). In game, the self-soulstone shows the name and a 30:00 countdown that persists across `/reload` and relog, and the prep button skips the use step while the record is active.

---

## Phase 4: Summon queue
Chat requests become rows. A click targets the requester and casts the ritual, and each row shows a failure reason.

**Files**: `Summon.lua`, `UI.lua`, `tests/run.lua`

**Key changes**:
- `WUK.IsSummonRequest(text: string): bool` (pure). Matches `123`, `sum`, `summon`, `port` as whole words, case-insensitive.
- `WUK.SummonQueue`: ordered list of `{ name: string, at: number }` with `Add(name)` (dedupe), `Remove(name)` and `Prune()` (drop anyone who has left the group).
- `WUK.SummonFailure(ctx: { inGroup, connected, dead, shards, zoneMatch: bool?, helpers: number? }): string?` (pure). Returns `"not in group"|"offline"|"dead"|"no shard"|"wrong zone"|"need 2 helpers"|nil`; an unknown (nil) zone or helpers value does not count as a failure.
- `WUK.BuildSummonContext(name): ctx`, which uses `UnitIsConnected`, `UnitIsDeadOrGhost`, `GetRaidRosterInfo` zone vs `GetRealZoneText()`, a `UnitInRange` count, and `issecretvalue` guards.
- Events: `CHAT_MSG_PARTY[_LEADER]`, `CHAT_MSG_RAID[_LEADER]`, `CHAT_MSG_GUILD`, `CHAT_MSG_SAY` and `CHAT_MSG_WHISPER` are matched on args 1–2 and skipped if secret. `GROUP_ROSTER_UPDATE` triggers `Prune`.
- UI: a pool of 10 secure row buttons. Left-click runs `macrotext` `/target <name>\n/cast <ritual>`, `ctrl-` runs `/target` only, and right-click removes the row through an insecure handler.
- Rows are rebuilt out of combat only; requests that arrive in combat are buffered until `PLAYER_REGEN_ENABLED`.

**Verify**: tests cover the IsSummonRequest matrix ("123" yes, "1234" no, "Summon pls" yes, "summoner" no) and each SummonFailure branch. In game, a party member types "123", a row appears with the correct reason (they go offline or die, or the warlock has 0 shards), the click starts the ritual on them, and right-click clears the row.

---

## Phase 5: Healthstone trade helper
A whisper keyword queues the requester and sends an auto-reply. Their trade gets a healthstone pre-placed.

**Files**: `Trade.lua`, `tests/run.lua`

**Key changes**:
- `WUK.IsHealthstoneRequest(text): bool` (pure). Matches `hs` and `healthstone` as whole words.
- `WUK.HSQueue`: `{ [name]: at }`, plus a whisper auto-reply through `C_ChatInfo.SendChatMessage` or `SendChatMessage` (WHISPER needs no hardware event; research Q5). Reply text is "no stone" when the count is 0.
- `TRADE_SHOW`: if the trade partner `UnitName("NPC")` is queued and `counts.slots.healthstone` exists, call `C_Container.PickupContainerItem(bag, slot)` then `ClickTradeButton(1)`. If `ClickTradeButton` is missing, print a hint and leave the stone on the cursor.
- `TRADE_ACCEPT_UPDATE` / `TRADE_CLOSED` dequeue after a completed trade; `AcceptTrade` is never called.

**Verify**: tests cover IsHealthstoneRequest. In game, an alt or friend whispers "hs", the auto-reply arrives, they open a trade, the healthstone appears in slot 1, and accepting removes them from the queue.

---

## Testing Checkpoints
- **After P1**: the addon loads on 16001 with no errors, the strip counts are correct, SavedVariables persist (or reset cleanly if the loader bug is present), and `tests/run.lua` is green.
- **After P2**: one-button prep works end to end, and the combat lock is respected.
- **After P3**: the soulstone record and countdown persist, and prep skips the use step.
- **After P4**: chat produces summon rows with failure reasons, and a click casts the ritual.
- **After P5**: whisper and trade put the healthstone in the slot.
- **Every phase**: `/console addonCombatRestrictionsForced 1` produces no Lua errors, because secrets are guarded.
