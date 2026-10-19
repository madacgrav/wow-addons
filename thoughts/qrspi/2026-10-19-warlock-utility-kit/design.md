# Design Discussion

Refs point to `research.md` sections (`R:Qn`) and their source URLs; repo has no code to cite.

## Current State
- Repo has no addon code: README, LICENSE, .gitignore, PRD only. No shared core library to reuse.
- Forever = Mainline 12.x APIs + Classic-era content, TOC interface 16001 (R:Q1, GuildStock TOC).
- Midnight secrets are active. Aura, chat-sender/text, unit-identity and range values can be secret in combat, encounters, PvP and anywhere on restricted maps (dungeons/raids) (R:Q4, R:Q5, `SECRETS`).
- Secure button attributes cannot change in combat (R:Q2, SecureActionButtonTemplate).
- The beta SavedVariables loader may not restore data. Blizzard reportedly fixed it; the fix build is unconfirmed (R:Q1, ForeverSVFix README).
- No working Forever warlock addon exists. The Classic references (Necrosis, Warlock Prep, Logroño's) use removed globals or have no published source (R:Q7).

## Desired End State
A self-contained addon in `WarlockUtilityKit/` that loads on the Forever client and provides:

1. **Inventory strip**: shard count; healthstone / soulstone / spellstone / firestone on-hand counts; soulstone target name and remaining time.
2. **Prep button**: one secure button. Each click casts the next unsatisfied step: armor > Detect Invisibility > preferred pet (falls back to Imp if no shard) > Soul Link (if known) > create healthstone > create soulstone > use soulstone. Satisfied steps are skipped. The border shows state: yellow = steps left (with count), green = done, red = in combat/locked.
3. **Summon queue**: parses `123`, `sum`, `summon`, `port` (whole-word, case-insensitive) from party, raid, guild, say and whisper chat. One row per requester. Left-click targets them and casts Ritual of Summoning; right-click removes the row. Each row shows a failure reason: offline, dead, no shard, wrong zone, or fewer than 2 helpers in range.
4. **Healthstone trade helper**: a whisper keyword (`hs`, `healthstone`) queues the requester and auto-replies. When a queued requester opens a trade, the addon puts one healthstone in the trade slot. The player clicks Accept.
5. `/wuk` slash command. Frames move with Shift+drag; positions and options persist in SavedVariables.

**Verification**: on a Forever client, as a warlock:
- Shard count matches the bags after looting/using shards.
- The prep button goes yellow > green through the full chain with no manual casts besides clicks.
- A party member typing "123" appears as a row, and a click starts the ritual on them.
- A whisper of "hs" plus a trade results in a healthstone in the trade slot.
- Settings survive `/reload` and relog.
- No Lua errors with `addonCombatRestrictionsForced=1` (R:Q4).

## Patterns to Follow
- **TOC**: single `## Interface: 16001`, one Lua file per line, `## SavedVariables` (account) + `## SavedVariablesPerCharacter`, `## IconTexture`. No `_Forever` suffix, matching GuildStock (R:Q1).
- **Rewrite secure attributes out of combat on state change**. Necrosis `Update*Attribute` called from `UpdateIcons()` (R:Q2, `Helpers/SphereButtonHelper.lua`) and Wick's "macros rewritten out of combat as your bags change" (R:Q2) both do this. Recompute on `BAG_UPDATE_DELAYED`, `UNIT_AURA` (player), `UNIT_PET`, `SPELLS_CHANGED`, `PLAYER_REGEN_ENABLED`; skip while `InCombatLockdown()`.
- **Macro-type secure buttons** for multi-step casts (`type="macro"`, `macrotext` ≤255 chars, R:Q2). Necrosis's healthstone uses `"/stopcasting\n"..macro` (R:Q2).
- **Shift/modifier attributes** for alternate actions (`shift-type*`, R:Q2 Necrosis), and `RegisterForClicks("AnyUp","AnyDown")` given the ActionButtonUseKeyDown 10.0 behavior (R:Q2).
- **Mainline APIs only**:
  - Bags: `C_Container.GetContainerNumSlots/GetContainerItemInfo/GetContainerItemID/PickupContainerItem`, `C_Item.GetItemCount`.
  - Spells: `C_Spell.GetSpellInfo`.
  - Auras: `C_UnitAuras.GetPlayerAuraBySpellID` or `GetAuraDataByIndex` (R:Q3, R:Q4).
- **Warlock Prep step semantics**: skip a step if its buff is active, its item is in bags, its spell is unknown, or Demonic Sacrifice is active. Red border in combat (R:Q7).
- **Logroño's row interactions**: click = target + ritual, Ctrl+click = target only, right-click = remove, per-row failure flags (R:Q7).
- **Own frames + slash command**, as in GuildStock and VuloForeverUI (R:Q7).

**Do NOT follow**:
- Necrosis/Classic globals: `GetContainerItemInfo`, `GetSpellInfo`, `UnitBuff`/`UnitDebuff` 1..40 loops, `GetTalentInfo`, `GetSpellBookItemName(id, BOOKTYPE_SPELL)`. All are removed, deprecated or unlisted for Forever (R:Q7).
- `COMBAT_LOG_EVENT_UNFILTERED`: registering it errors (R:Q4).
- `UnitPosition`: returns nil in instances (R:Q5).
- `CheckInteractDistance`: protected in combat (R:Q5).
- Comparing or doing arithmetic on possibly-secret values without an `issecretvalue` guard (R:Q4).

## Design Decisions
1. **ID strategy: learn from client.**
   - At `PLAYER_LOGIN` and `SPELLS_CHANGED`, scan the spellbook and map spell names to IDs: Demon Armor/Skin, Detect Invisibility variants, Summon Imp/Voidwalker/Succubus/Felhunter, Soul Link, Create Healthstone/Soulstone, Ritual of Summoning.
   - Use the highest known rank for each.
   - Classify bag items by name substring ("Healthstone", "Soulstone", "Spellstone", "Firestone", "Soul Shard") via `C_Container.GetContainerItemInfo().itemName`.
   - Why: research found gaps in ID coverage and Forever may renumber ranks; this matches the PRD's no-static-table approach. Ceiling: enUS only; mark with a `ponytail:` comment. Upgrade path: a locale name table.
2. **Prep: single secure macro button.**
   - A pure Lua function `NextPrepStep(state)` returns the first unsatisfied step.
   - The button's `macrotext` is rewritten to that step out of combat.
   - "Use soulstone" step = `/use [@player] Soulstone-item`, which sets the soulstone on self.
   - Why: a click is required (hardware event); one button keeps it to the Warlock Prep model.
3. **Soulstone tracking from own casts.**
   - On `UNIT_SPELLCAST_SUCCEEDED` (unit "player"), detect Soulstone Resurrection (by name) and record the target name with `expires = GetTime() + 1800`.
   - Store it in per-character SV as `time()`-based expiry so it survives relog.
   - Why: player cast info is not secret (R:Q4), whereas reading a group member's aura is unverified.
4. **Summon queue: local only.**
   - No addon messages, so the trial-account block and throttle do not apply (R:Q5).
   - Rows come from a fixed pool of secure buttons (e.g. 10) created at load. Their `macrotext` is `/target <name>\n/cast Ritual of Summoning`, set out of combat.
   - New requests that arrive in combat are queued in Lua and applied on `PLAYER_REGEN_ENABLED`.
   - Chat text or sender for which `issecretvalue` is true is ignored.
5. **Failure checks** for each row, using only non-secret, group-scoped APIs (R:Q5):
   - Offline: `UnitIsConnected`.
   - Dead: `UnitIsDeadOrGhost`.
   - No shard: shard count is 0.
   - Wrong zone: `GetRaidRosterInfo` zone vs `GetRealZoneText()`.
   - Too few helpers: fewer than 2 group members with `UnitInRange` true, excluding self and target, with an `issecretvalue` guard. A secret value is treated as "unknown", not as a failure.
   - The requester must be in the group; non-group requesters get the reason "not in group".
6. **Trade helper: auto-fill.**
   - On `TRADE_SHOW`, if `TradeFrameRecipientNameText`/`UnitName("NPC")` matches a queued requester, find a healthstone slot and call `C_Container.PickupContainerItem` then `ClickTradeButton(1)`.
   - If `ClickTradeButton` is nil, leave the stone on the cursor and print a hint.
   - Remove the requester from the queue on `TRADE_CLOSED`, after a trade has completed.
   - Never call `AcceptTrade` (hwevent, R:Q6).
7. **SavedVariables**:
   - `WarlockUtilityKitDB` (account): frame positions, options.
   - `WarlockUtilityKitCharDB`: preferred pet, soulstone record.
   - Initialize with a defaults merge on `ADDON_LOADED`; nil-safe if the loader bug leaves them empty.
8. **Files**: `WarlockUtilityKit.toc`, `Core.lua` (events, SV, slash, spell/item scan), `Prep.lua`, `Summon.lua`, `Trade.lua`, `UI.lua` (strip + frames).
   - Pure logic (step selection, chat keyword matching, item classification) lives in plain functions.
   - Those functions are checked by one `tests/run.lua`, which uses stub globals and runs with stock Lua 5.1.
9. **Options via `/wuk`**: `show`/`hide`/`lock`, `pet <imp|voidwalker|succubus|felhunter>`, `reset`. No Blizzard Settings panel.

## What We're NOT Doing
- Curse/banish assignment board, DoT/curse timers, any v2 item.
- Addon-message sync between warlocks; RaidSummon/Capslock compatibility.
- Embedded shared core library (PRD build-order step 1). It is extracted later, when Idea 5 needs it.
- Localization beyond enUS.
- Blizzard Settings panel, Edit Mode integration, minimap button, LibDataBroker.
- Reading group members' auras (e.g. verifying a soulstone buff on others).
- Shard deletion/management, soul bag handling, pet action bars.
- Auto-accepting trades or any automation needing a hardware event.
- CurseForge packaging/release automation.

## Open Risks
- **Name matching on Forever**: stone and spell names may differ (renamed ranks, "Banes" rework affects curses but not stones; R:Q3). Must validate on the live client.
- **`ClickTradeButton`**: existence unverified (R:Q6). There is a fallback (stone left on cursor).
- **Restricted maps**: in dungeons/raids, chat sender/text and `UnitInRange` may be secret even out of combat (R:Q4, R:Q5). The summon queue may get no requests while inside instances; summons are mostly done outside, so this is acceptable.
- **Spellbook scan API**: on Forever (`C_SpellBook.GetNumSpellBookSkillLines` / `GetSpellBookItemInfo`) it is unverified (R:Q4 Open Areas). Must probe at implementation.
- **Soul Link / Demonic Sacrifice detection**: depends on talent-granted spell names appearing in the spellbook. The talent API itself is unknown on Forever (R:Q4).
- **SavedVariables loader bug**: may still be present at launch. Data then resets each session, but the addon must not error.
- **Macro length**: rows with long cross-realm names stay well under the 255-char limit.
- **No in-repo client**: all verification is manual in-game. Automated checks cover only the pure logic.
