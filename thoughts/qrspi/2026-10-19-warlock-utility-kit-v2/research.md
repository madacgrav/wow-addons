# Research Findings

Codebase paths are relative to `WarlockUtilityKit/`; external findings cite URLs. **UNVERIFIED** means not seen on a fetched page. Gathered 2026-10-19. Earlier research is in `thoughts/qrspi/2026-10-19-warlock-utility-kit/research.md` and is not repeated here.

URL shorthand:
- `SECRETS` = https://warcraft.wiki.gg/wiki/Secret_Values
- `API12` = https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
- `NOTES` = https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes

## Q1: Addon wiring (events, lifecycle, slash/settings, secure rows, tests)

### Findings
- **TOC** (`WarlockUtilityKit.toc`)
  - Interface 16001 is declared at `:1`.
  - SavedVariables: `WarlockUtilityKitDB` (`:6`) and per-character `WarlockUtilityKitCharDB` (`:7`).
  - Load order (`:9-15`): Logic, Core, UI, Prep, Summon, Trade, Settings. Every file opens with `local ADDON, WUK = ...`.
- **Defaults**
  - `Core.lua:19`: `DEFAULTS = { locked, shown, frames, icons, minimapAngle=220 }`. `Core.lua:20`: `CHAR_DEFAULTS = { pet="imp" }`.
  - On `ADDON_LOADED` (`Core.lua:22-28`), `WUK.MergeDefaults` (`Logic.lua:16-23`) fills these in and sets `WUK.db` and `WUK.char`.
  - `WUK.char.soulstone` is written at `Prep.lua:40` but is not in `CHAR_DEFAULTS`.
- **Event dispatch**
  - `WUK.On(event, fn)` (`Core.lua:11-14`) lazily registers the event on one shared frame (`:10`) and appends the handler.
  - `OnEvent` (`:15-17`) calls every handler with the event arguments, minus the event name.
- **Lifecycle**
  - `WUK.inits` and `WUK.refreshers` are arrays (`Core.lua:3`).
  - `PLAYER_LOGIN` (`Core.lua:118-125`):
    - stops unless the class is `WARLOCK` (`:120`);
    - otherwise sets `WUK.active`, runs `ScanSpells()`, runs every init in order, then calls `Refresh()`.
  - `WUK.Refresh` (`Core.lua:112-116`) rescans bags and then calls every refresher. Refresher order:
    1. stone buttons (`UI.lua:55`)
    2. armor (`Prep.lua:12`)
    3. pet (`Prep.lua:29`)
    4. summon rows (`Summon.lua:106`)
  - `Refresh` is called from:
    - the `BAG_UPDATE_DELAYED`, `PLAYER_REGEN_ENABLED`, `SPELLS_CHANGED`, `UNIT_AURA` (player) and `UNIT_PET` (player) handlers (`Core.lua:126-130`);
    - `/wuk pet` (`:150`);
    - a successful soulstone cast (`Prep.lua:41`).
  - Module-specific events are registered inside inits, so only on warlocks: `Prep.lua:38`, `Summon.lua:97-100`, `Trade.lua:10,17,27,30`.
- **Helpers**
  - `SPELLS` (`Core.lua:48-61`), with ranked names listed highest first: `armor, detect, imp, voidwalker, succubus, felhunter, soullink, ritual, healthstone, soulstone, spellstone, firestone`.
    - `detect` and `soullink` are scanned but no code reads them.
  - Spellbook scan: `SpellbookNames` (`:63-84`) uses `C_SpellBook` skill lines, with a Classic-style fallback.
  - `ReadPlayerBuffs` (`:94-103`) returns a set of HELPFUL aura names on the player, skipping secret names.
  - Other helpers: `PetFamily` (`:105-110`), `WUK.Secret` (`:7`), `WUK.SpellName` (`:135-139`).
  - `WUK.lastCastTarget` is captured from `UNIT_SPELLCAST_SENT` (`:132-134`).
- **`/wuk`** (`Core.lua:141-153`)
  - Commands: `show`, `hide` (refused in combat, `:145`), `lock` (toggle), `reset`, `pet <name>`, and `config` (`WUK.ToggleSettings`, `:151`). Anything else prints usage.
  - `Settings.lua:6` `Run(cmd)` calls `SlashCmdList.WARLOCKUTILITYKIT(cmd)`. The window controls route through it:
    - Show checkbox (`:28`)
    - Lock checkbox (`:29-30`)
    - `WowStyle1DropdownTemplate` pet radio menu (`:36-44`)
    - Reset button (`:46-48`)
  - The window is built lazily (`:58-61`), is listed in `UISpecialFrames` (`:19-23`), and syncs its controls on show (`:50-54`).
  - The minimap button is created in an init (`Settings.lua:63-97`). It sits at `db.minimapAngle`, drags with `atan2`, and calls `ToggleSettings` on click.
- **Summon secure rows** (`Summon.lua`)
  - `MAX=10` and `TTL=600` (`:2`).
  - Panel `WUKSummon` (`:78-83`) is movable under key `"summon"`.
  - 10 `SecureActionButtonTemplate` rows (`:84-95`). Fixed attributes: `type1` and `ctrl-type1` = `"macro"` (`:88`). A right-click `HookScript` removes the row (`:91-93`).
  - `UpdateSummonRows` (`:49-67`):
    - returns immediately while `InCombatLockdown()` (`:50`);
    - sets `macrotext1` / `ctrl-macrotext1` (`:57-58`);
    - shows the panel only when the queue is non-empty (`:66`).
  - Combat catch-up runs through the `PLAYER_REGEN_ENABLED` refresh.
  - Chat events `CHAT_MSG_PARTY/_LEADER/RAID/_LEADER/GUILD/SAY/WHISPER` feed `OnChat` (`:69-75`, registered at `:97-98`).
  - Group helpers: units from `GroupUnits` (`:5-10`), names from `UnitFull` (`:12-16`), zones from `RosterZone`, raid only (`:18-24`).
- **Layout** (`UI.lua`)
  - Strip `WUKStrip` is 284x62 (`UI.lua:31-35`), with 36px buttons at y=-4:
    - armor x=4 (`Prep.lua:6`), pet x=44 (`Prep.lua:23`)
    - stones x=84..244 (`UI.lua:39`)
  - Soulstone text at BOTTOMLEFT (6,6) (`UI.lua:48-49`), driven by a 1s ticker (`Prep.lua:44-47`).
  - `MakeMovable` (`UI.lua:11-24`) moves frames with Shift-drag, never when locked or in combat, and saves positions to `db.frames[key]`.
- **Pure logic and tests**
  - `Logic.lua` exports: `ClassifyItem` (`:9`), `MergeDefaults` (`:16`), `StoneMacro` (`:26`), `FormatTime` (`:35`), `HasWord` (`:39/:44`), `IsSummonRequest` (`:47`), `IsHealthstoneRequest` (`:50`), `QueueAdd/Remove/Prune` (`:52/:58/:61`), `SummonFailure` (`:66`), `SoulstoneRemaining` (`:76`).
  - `tests/run.lua:1-3` loads only `Logic.lua` into an empty table. `eq` helper at `:5-7`; sections are marked by comments; the run ends with `print("all tests passed")` (`:59`).
- **Shared whisper:** `Trade.lua:10` and `Summon.lua:97` both handle `CHAT_MSG_WHISPER`.

## Q2: Addon messaging on Forever / Mainline 12.x

### Findings
- **`C_ChatInfo.RegisterAddonMessagePrefix(prefix)`** (https://warcraft.wiki.gg/wiki/API_C_ChatInfo.RegisterAddonMessagePrefix)
  - The prefix is at most 16 characters.
  - Result codes: 0 Success, 1 DuplicatePrefix, 2 InvalidPrefix, 3 MaxPrefixes. The numeric cap is UNVERIFIED.
  - Registration does not persist across `/reload`.
- **`C_ChatInfo.SendAddonMessage(prefix, msg [, chatType [, target]])`** (https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage)
  - Messages are up to 255 characters; NUL is not allowed. `chatType` defaults to PARTY.
  - Chat types: PARTY, RAID (falls back to PARTY when not in a raid), INSTANCE_CHAT, GUILD, OFFICER and WHISPER work everywhere. CHANNEL is Retail-only; SAY and YELL are Classic-only.
  - Throttle: 10 messages per prefix, regenerating 1 per second; whispers outside instances are exempt. The page recommends ChatThrottleLib/AceComm.
  - `Enum.SendAddonMessageResult`: 0 Success, 1 InvalidPrefix, 2 InvalidMessage, 3 AddonMessageThrottle, 4 InvalidChatType, 5 NotInGroup, 6 TargetRequired, 7 InvalidChannel, 8 ChannelThrottle, 9 GeneralError, 10 NotInGuild, 11 AddOnMessageLockdown, 12 TargetOffline.
    - Sources disagree on whether value 11 was added in 11.1.0 or 12.0.0.
    - Success means the message was queued, not delivered.
- **`SendAddonMessageLogged`** is for user-generated plain text. Receivers get `CHAT_MSG_ADDON_LOGGED`. Unsupported characters fail silently.
- **`CHAT_MSG_ADDON`** payload (https://warcraft.wiki.gg/wiki/CHAT_MSG_ADDON):
  - order: `prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID`;
  - `channel` holds the chat type;
  - the sender's Name-Realm format and any secret predicates are UNVERIFIED (the page states neither).
- **Lockdown**
  - `C_ChatInfo.InChatMessagingLockdown()` returns `isRestricted` (https://warcraft.wiki.gg/wiki/API_C_ChatInfo.InChatMessagingLockdown). The `lockdownReason` return was removed in 12.0.5.
  - `SECRETS` `SecretInChatMessagingLockdown`: guarded values are secret during encounter, challenge mode or PvP restrictions, and on communication-restricted maps (dungeons and raids).
  - Testing CVars: `addonChatRestrictionsForced`, `addonEncounterRestrictionsForced`, `addonMapRestrictionsForced`.
  - Secondary sources say encounters set lockdown and incoming chat becomes secret. JumpBoss falls back across INSTANCE_CHAT, RAID and PARTY (https://www.curseforge.com/wow/addons/jumpboss/files/7849320). Whether addon messages are blocked in instances is UNVERIFIED officially.
- **Trial accounts:** `NOTES` (Beta 4) says "Trial accounts can no longer send addon messages."
- **GuildStock `Sync.lua`** (https://raw.githubusercontent.com/luisjedev/wow-forever-addons/main/GuildStock/Sync.lua, read via a fetch summary)
  - Prefix and channel:
    - prefix `"GuildStockS2"`, registered at `PLAYER_LOGIN`;
    - GUILD channel only, for both sending and receiving.
  - Wire format:
    - pipe-delimited text `2|<kind>|<session>|...`, where the leading `2` is the protocol version;
    - kinds `H`, `O`, `P`, `Q`, `A`, `S`; the old kinds `D`, `R`, `T` are ignored.
  - Payload details:
    - 240-byte cap on messages;
    - entries are `itemID,count,bound` joined by `;`;
    - tokens match `^%d+%-%d+$`.
  - Chunking: `i|total` parts.
  - Pacing:
    - one send every 0.5s;
    - the queue holds at most 128 entries, each expiring after 180s;
    - failures back off `min(30, 2^n)` seconds, and after 3 failures the queue is cleared and the addon waits 60s;
    - at most one reply per peer every 5s.
  - Revision: `math.max(time(), rev+1)`.
  - It uses native `C_ChatInfo` only, with no AceComm.

## Q3: Forever warlock curses, Banes and crowd control

### Findings
- **Blizzard deep dive, 2026-10-07**, via https://www.warcrafttavern.com/forever/news/poison-pets-rogue-warlock-deep-dive-for-wow-forever/:
  - "Curse of Agony and Curse of Doom are now Banes." "Only one Bane can be active per Warlock on a single target."
  - "All effects that interacted with Curses now also interact with Banes."
  - Curse of the Elements now applies to all magic damage. Curse of Shadows is removed.
  - Curse of Exhaustion is the 16-point gold-medal talent and slows by 30%.
- **Banes and Curses are separate slots.** Zockify (https://www.zockify.com/forever/warlock/) and AccountShark (https://accountshark.net/blog/wow-forever-rogue-warlock-changes-guide-mutilate-banes-talents) both say one Bane and one Curse per warlock can be on the same target. Zockify calls them "Bane of Agony/Doom", and says Shatter Curse removes both. Retail precedent: https://warcraft.wiki.gg/wiki/Bane_(spell).
- **Conflict:** https://warcraft.wiki.gg/wiki/Curse_of_Shadow says Curse of Shadow "remains in Classic and Forever" (Classic IDs 17862 and 17937). The deep-dive sources say it was removed.
- **Spell data from warcraft.wiki.gg pages**

| Spell | Classic | Forever |
|---|---|---|
| Curse of the Elements | IDs 1490–11722 | 4 ranks; IDs 440892 (R1) to 1311680 (R4); level 20; −30 magic resistance; +4% magic damage taken; 5 min |
| Curse of Recklessness | IDs 704–11717 | IDs 704 and 11717; −175 armor; no AP bonus listed |
| Curse of Weakness | IDs 702–11708 | IDs 702 and 11708; −4 physical damage |
| Curse of Agony | IDs 980–11713 | Forever data UNVERIFIED |
| Curse of Doom | ID 603 | Forever data UNVERIFIED |
| Curse of Tongues | IDs 1714 and 11719 | Forever data UNVERIFIED |
| Banish | IDs 710 and 18647; Demon/Aberration/Elemental; up to 20s | Forever data UNVERIFIED |

- **Fear and Enslave Demon:** no data found. A player post (not official) says Fear range is capped at 20 yd (https://us.forums.blizzard.com/en/wow/t/2375390).
- **Debuff caps:** nothing found on 16/40 debuff-cap or raid-debuff-limit changes.

## Q4: Raid targets, GUIDs and group roles

### Findings
- **`GetRaidTargetIndex(unit)`** (https://warcraft.wiki.gg/wiki/API_GetRaidTargetIndex)
  - Returns 1–8 (1 = star … 8 = skull) or nil.
  - Predicates: AllowedWhenUntainted and **SecretReturns**.
  - May return arbitrary values for units that don't exist.
- **`SetRaidTarget(unit, index)`** (https://warcraft.wiki.gg/wiki/API_SetRaidTarget)
  - In a party anyone can mark; in a raid, only the leader and assistants.
  - "This can only be called from secure code"; it has been protected since 12.0.0.
  - `API12` also lists `SetRaidTargetProtected` and `IsRaidMarkerSystemEnabled`.
- **`RAID_TARGET_UPDATE`** (https://warcraft.wiki.gg/wiki/RAID_TARGET_UPDATE) has no payload. It fires when marks change or roster membership changes, not when a marked mob dies.
- **`UnitGUID`** (https://warcraft.wiki.gg/wiki/API_UnitGUID)
  - Predicate: `SecretWhenUnitIdentityRestricted`, meaning secret when the unit is neither player-controlled nor in the party or raid (`SECRETS`).
  - `NOTES` Beta 5: creature, pet, vehicle and object GUIDs have obfuscated server and spawn IDs. They stay consistent within a session, and the string format is unchanged.
- **Leader and assistant**
  - `UnitIsGroupLeader(unit[, category])` (https://warcraft.wiki.gg/wiki/API_UnitIsGroupLeader) and `UnitIsGroupAssistant(unit)` (https://warcraft.wiki.gg/wiki/API_UnitIsGroupAssistant) carry `SecretWhenUnitIdentityRestricted`.
  - `UnitIsGroupAssistant` returns false for the leader.
  - The `IsEveryoneAssistant` page returned 404 (UNVERIFIED).
- **Class**
  - `UnitClass` (https://warcraft.wiki.gg/wiki/API_UnitClass): `className` is ConditionalSecret; `classFilename` and `classId` are not marked secret.
  - `GetRaidRosterInfo` (https://warcraft.wiki.gg/wiki/API_GetRaidRosterInfo): `fileName` is the English upper-case class token. `rank` is 2 for leader, 1 for assistant, 0 otherwise. No secret notes.

## Q5: Reading player-cast debuffs on enemies; timers under secrets

### Findings
- **Forever applies Midnight secrets.** `NOTES` (2026-09-15) says Midnight secrets are active, and the 12.1.0 AuraContainer/AuraButton changes ship too.
- **Predicates** (`SECRETS`)
  - `SecretWhenUnitAuraRestricted` (12.0.0) and `SecretWhenAurasRestricted` (12.1.0) apply under combat, encounter, challenge mode and PvP restrictions. Per-spell never/always-secret flags take priority over both.
  - `SecretOnRestrictedMaps` (12.0.5) covers dungeons and raids. The page does not tie it to auras explicitly.
  - Other predicates: `RequiresUnitAuraAccess` (errors), and `RequiresNonSecretAura` / `RequiresValidUnitAuraInstance`, which return nothing.
  - Testing CVars: `addonCombatRestrictionsForced`, `addonEncounterRestrictionsForced`, `secretMapRestrictionsForced` / `addonMapRestrictionsForced` (https://warcraft.wiki.gg/wiki/Patch_12.0.5/API_changes).
- **Aura reads**
  - `C_UnitAuras.GetUnitAuras(unit, filter, ...)` (https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetUnitAuras): the `HARMFUL|PLAYER` filter is supported. Predicate: RequiresUnitAuraAccess. Some AuraData fields are "potentially secret".
  - `GetAuraDataByAuraInstanceID` (https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByAuraInstanceID): returns secret data when restricted. NeverSecret fields: auraInstanceID, isHelpful, isHarmful, isRaid, isFromPlayerOrPlayerPet.
  - 12.0.5 dropped NeverSecret from the `unit` argument of `GetAuraDataByIndex` and related functions. It also added `AddBlockedAura`, `SwitchAuraDataProvider` and events `UNIT_AURA_BLOCKED` and `AURA_DATA_PROVIDER_SWITCH`.
- **`UNIT_AURA`** (https://warcraft.wiki.gg/wiki/UNIT_AURA)
  - `updateInfo` contains `isFullUpdate`, `addedAuras`, `updatedAuraInstanceIDs`, `removedAuraInstanceIDs`.
  - 12.1.0 (2026-08-11): "fully secret payload while auras are secret". This conflicts with the NeverSecret field list on the same page.
- **Spell secrecy**
  - `C_Secrets.GetSpellAuraSecrecy(spell)` returns `Enum.SecrecyLevel`: 0 NeverSecret, 1 AlwaysSecret, 2 ContextuallySecret (https://warcraft.wiki.gg/wiki/API_C_Secrets.GetSpellAuraSecrecy).
  - `C_Secrets.ShouldUnitAuraIndexBeSecret(unit, index[, filter])` returns a boolean.
  - Which warlock debuffs are flagged never-secret is UNVERIFIED.
- **Duration sinks**
  - `C_UnitAuras.GetAuraDuration(unit, auraInstanceID)` returns a DurationObject and is listed for Forever 1.60.1 (https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDuration).
  - `StatusBar:SetTimerDuration(duration[, interp[, direction]])` is AllowedWhenUntainted (https://warcraft.wiki.gg/wiki/API_StatusBar_SetTimerDuration). `SECRETS` says duration objects "can be passed to StatusBar:SetTimerDuration()".
  - `Cooldown:SetCooldownFromDurationObject` is marked IsProtectedFunction and "can be called only from untainted code" (https://warcraft.wiki.gg/wiki/API_Cooldown_SetCooldownFromDurationObject). Whether tainted addons can drive either sink is unresolved.
  - `FontString:SetText` accepts secrets (AllowedWhenTainted, adds a Text secret aspect) (https://warcraft.wiki.gg/wiki/API_FontString_SetText).
  - DurationObject `Format*Duration` methods were added in 12.0.5. Whether their output is secret is UNVERIFIED.
- **How existing addons cope**
  - WeakAuras retail will not support Midnight (https://www.icy-veins.com/wow/news/weakauras-to-end-support-in-midnight/).
  - DreadPlagueTracker relies on `auraInstanceID` plus fallbacks and is correct "~95%" of the time (https://www.curseforge.com/wow/addons/dreadplaguetracker).
  - DodoNameplate (12.0.7–12.1.5) shows "mine" debuffs as `HARMFUL|PLAYER` intersected with Blizzard's curated nameplate category set (https://www.curseforge.com/wow/addons/dodonameplate/files/8321906).
  - No Forever DoT-timer addon was found on CurseForge.

## Q6: Existing curse/banish assignment addons

### Findings
All findings are from CurseForge descriptions only. No source code or wire formats were found, and every addon targets TBC or Classic; none lists Forever.

- **Warlock Curse Power** (https://www.curseforge.com/wow/addons/warlock-curse-power)
  - State: each warlock gets a Curse, a Banish, both, or none. No raid mark.
  - Sync: shared with other users of the addon "almost immediately"; "only one Warlock needs the addon". The mechanism is unstated.
  - UI: click-to-assign list; `/wcp`, plus a movable summary at `/wcps`.
  - Announce: a Notify button posts to group or raid chat.
- **Warlock Raid Leader** (https://www.curseforge.com/wow/addons/warlock-raid-leader, TBC 20506, All Rights Reserved)
  - State: curses, banish (one of 8 raid marks per warlock), soulstones, and saved "Grimoires" (setups).
  - Sync: lead-authoritative. Any warlock can take or release the lead; members get a read-only view. Every change broadcasts via addon messages, and members can request a full sync.
  - UI: tabs with dropdowns, a summary matrix, a personal overlay, and a minimap button.
  - Announce: selectable Raid Warning, Raid, Party or Say, plus a whisper to each warlock.
- **WMT Assignments** (https://www.curseforge.com/wow/addons/wmt-assignments)
  - State: curse plan capped at 1–4 warlocks per curse; banish is by marker, one warlock per marker.
  - UI: 8 marker rows and auto-assign.
  - Announce: multi-line posts to RAID or PARTY with `{rt5}` tokens, plus a per-row confirmation whisper.
  - Network sharing is UNVERIFIED.
- **TBC Anniversary Warlock Assignments** (https://www.curseforge.com/wow/addons/tbc-anniversary-warlock-assignments)
  - State: curses and soulstones; it tracks assigned warlocks going offline.
  - UI: Auto Assign that doesn't overwrite manual choices; closes itself in combat.
  - Announce: batches of 9 lines with 1.5s gaps; unassigned warlocks are whispered.
- **Others**
  - Fel Union: "curse panel syncs between addon users" (https://www.curseforge.com/wow/addons/fel-union).
  - Necrosis: personal curse menu, no sharing.
  - Angry Assignments: per-boss assignments with multiple editors; resyncs from the raid leader after reload (https://www.wowace.com/projects/angry-assignments).
  - CT_RaidAssist: no curse-assignment feature seen.
  - Not fetched: ClassicRaidAssist, RaidSummon/Plus, Exorsus Raid Tools.
- **RAID_WARNING:** the leader/assist requirement is general knowledge, not confirmed on a fetched page.

## Cross-Cutting Observations
- **Messaging and the codebase**
  - The addon currently sends no addon messages. Its only outbound chat is the whisper auto-reply (`Trade.lua:7`).
  - Its existing `WUK.On` dispatcher and `inits` would host `CHAT_MSG_ADDON` the same way as other events (`Core.lua:11-14`).
- **Shared state in existing addons:** they keep it small and keyed by warlock, holding curse/bane, banish mark and soulstone. Two sync models appear:
  - lead-authoritative with full-sync on request (Warlock Raid Leader, Angry Assignments);
  - "anyone edits, broadcast immediately" (Warlock Curse Power).
- **Marks:** setting them is protected (`SetRaidTarget`), and reading them can return secrets (`GetRaidTargetIndex` SecretReturns). Assignments can still be expressed as mark indexes 1–8 without reading the units.
- **Same restriction triggers everywhere:** encounter, restricted map and combat restrictions govern auras, chat payloads, and possibly addon messages. Testing CVars exist for each.
- **Forever curse model:** Bane and Curse are separate per-warlock slots. Curse of Shadow's status is conflicting, and Elements now covers all magic schools.

## Open Areas
- Whether `CHAT_MSG_ADDON` arguments become secret, or sends return `AddOnMessageLockdown`, inside Forever dungeons and raids or during encounters. Not documented.
- The `CHAT_MSG_ADDON` sender name format.
- Forever spell names and IDs for Agony/Doom as Banes, Tongues, Exhaustion, Banish, Fear and Enslave; and whether Curse of Shadow exists.
- Which warlock debuffs (if any) are never-secret, and whether tainted code can call `StatusBar:SetTimerDuration` or `Cooldown:SetCooldownFromDurationObject` with an aura DurationObject.
- Whether `GetRaidTargetIndex` returns secrets for enemy units in practice.
- `IsEveryoneAssistant` and the `RegisterAddonMessagePrefix` cap.
- Source code or message formats for any curse-assignment addon (none are public).
