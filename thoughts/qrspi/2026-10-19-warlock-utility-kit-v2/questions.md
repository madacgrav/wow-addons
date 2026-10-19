# Research Questions

## Context
The work has two parts:
- **The existing addon in `WarlockUtilityKit/`**: Core.lua, Logic.lua, UI.lua, Prep.lua, Summon.lua, Trade.lua, Settings.lua, and tests/run.lua.
- **External WoW Forever client APIs**: interface 16001, a Mainline 12.x API base with Midnight "secret values" restrictions and Classic-era warlock content.

Use warcraft.wiki.gg, CurseForge and GitHub for the external parts. Prior research for this addon is in `thoughts/qrspi/2026-10-19-warlock-utility-kit/research.md`. Extend it; do not repeat it.

## Questions
1. In `WarlockUtilityKit/`, trace how the addon is wired:
   - event registration and dispatch (`WUK.On`), the `WUK.inits` / `WUK.refreshers` lifecycle, and SavedVariables defaults;
   - the `/wuk` slash handler and how Settings.lua routes its controls through it;
   - how Summon.lua builds and updates its pool of secure row buttons in and out of combat;
   - how Logic.lua functions are tested by tests/run.lua.

   Give file:line references.
2. How does addon-to-addon messaging work on Forever/Mainline 12.x?
   - `C_ChatInfo.RegisterAddonMessagePrefix`, `SendAddonMessage` vs `SendAddonMessageLogged`, chat types RAID, PARTY, GUILD, WHISPER and INSTANCE_CHAT;
   - the `CHAT_MSG_ADDON` payload, including the sender name format;
   - throttles and return codes (`Enum.SendAddonMessageResult`), the 255-byte limit, and behavior during encounter/instance lockdown (`AddOnMessageLockdown`);
   - the Forever trial-account restriction.

   Which Forever-compatible addons sync shared state this way (e.g. GuildStock's Sync.lua, AceComm/ChatThrottleLib ports), and what message formats and versioning do they use?
3. What are the Forever warlock curse and crowd-control spells?
   - names, ranks and IDs for Curse of Agony, Doom, Recklessness, the Elements, Shadow, Tongues, Weakness and Exhaustion, plus Banish, Fear and Enslave Demon;
   - which curses Forever turned into "Banes", and the "one per warlock per target" rules.

   Cite sources dated October 2026 where possible.
4. How are raid targets identified on Forever?
   - `GetRaidTargetIndex` / `SetRaidTarget` (permissions, in-combat behavior, whether results are secret) and the `RAID_TARGET_UPDATE` event;
   - unit GUID secrecy and the Beta 5 GUID obfuscation;
   - leader/assistant detection (`UnitIsGroupLeader`, `UnitIsGroupAssistant`, `IsEveryoneAssistant`) and raid roster class queries (`UnitClass`, `GetRaidRosterInfo` class fields) for finding the other warlocks in a raid.
5. Can debuffs the player casts on enemies be read on Forever, in and out of combat and in open world vs dungeons/raids? Cover:
   - `C_UnitAuras.GetAuraDataByIndex` / `GetUnitAuras` on `target`, `focus` and `nameplateN` with `HARMFUL|PLAYER` filters;
   - `UNIT_AURA` `updateInfo`, `C_UnitAuras.GetAuraDuration` duration objects, and `C_Secrets.GetSpellAuraSecrecy` / per-spell never-secret flags;
   - whether Cooldown/StatusBar widgets accept secret durations (`SetCooldownFromDurationObject`, `SetTimerDuration`) so an addon can display a timer it cannot read.

   How do Forever or Midnight-compatible timer addons (e.g. any DoT-timer or nameplate-aura addons listed for 1.60.x or 12.x) handle this?
6. How do existing curse/banish assignment addons work?
   - Warlock Curse Power, CT_RaidAssist, ClassicRaidAssist, RaidSummon's sync, and Necrosis's curse menu.
   - What state do they share (assignee, curse, raid mark), and how is it synchronized and conflict-resolved (leader-authoritative vs last-write-wins)?
   - What UI do they use for assigning and displaying, and how do they announce assignments (`SendChatMessage` RAID_WARNING/RAID restrictions)?
