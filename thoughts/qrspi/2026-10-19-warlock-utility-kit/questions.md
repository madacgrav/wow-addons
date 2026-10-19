# Research Questions

## Context
The repository contains no addon source yet (only README, LICENSE, .gitignore and a planning document), so research is primarily external: the WoW Forever client (interface 1.60.x / 16001, built on Mainline 12.x APIs), Warcraft Wiki API docs, and the source of existing addons on CurseForge/GitHub. Focus on Forever/Mainline behavior; note wherever Classic-era behavior differs.

## Questions
1. What is the required file layout and `.toc` format for an addon loaded by the WoW Forever client (interface number, `## SavedVariables` / `SavedVariablesPerCharacter`, load order, `## Category`/`IconTexture` fields), and how does the ForeverSVFix workaround change when and how SavedVariables become available (ADDON_LOADED vs PLAYER_LOGIN)?

2. How do secure action buttons work under Mainline 12.x / Forever's restrictions: `SecureActionButtonTemplate` attribute types (`spell`, `item`, `macro`, `target`), `SecureHandler` snippets, the `ActionButtonUseKeyDown` CVar behavior, and which attribute changes are blocked in combat (`InCombatLockdown`)? How have Forever-compatible addons (e.g. Hemlock Forever, Easy Poisons, Wick's Poisons and Things) structured click-to-cast or click-to-use-item buttons?

3. Which APIs return bag contents and item counts on Forever (`C_Container.GetContainerNumSlots`, `C_Container.GetContainerItemInfo`, `C_Item.GetItemCount`), which events signal bag changes (`BAG_UPDATE`, `BAG_UPDATE_DELAYED`), and what are the Forever item IDs / spell IDs for Soul Shard, all healthstone/soulstone/spellstone/firestone ranks, and the warlock spells that create or consume them (Create Healthstone/Soulstone, Ritual of Summoning, Soul Link, Demon/Fel Armor, Detect Invisibility, summon-demon spells)?

4. Which unit, aura and spell queries are restricted by Midnight "secrets" on Forever: can an addon read the player's own buffs (`C_UnitAuras.GetAuraDataByIndex` / `GetPlayerAuraBySpellID`), a group member's Soulstone Resurrection aura and its expiration, spell-known/talent state (`IsSpellKnown`, `C_SpellBook`, talent APIs), and pet existence/family (`UnitExists("pet")`, `UnitCreatureFamily`) — both in and out of combat?

5. How are chat messages received and how is group/guild state queried on Forever: `CHAT_MSG_PARTY`/`RAID`/`GUILD`/`SAY`/`WHISPER` event payloads (including any secret-wrapped sender/text fields), and the APIs for a group member's online/dead/connected state, zone, and range (`UnitIsConnected`, `UnitIsDeadOrGhost`, `GetRaidRosterInfo`, `C_Map.GetBestMapForUnit`, `UnitInRange`/`CheckInteractDistance`)? What restrictions apply to `SendChatMessage` and `C_ChatInfo.SendAddonMessage` (rate limits, hardware-event requirements, trial accounts)?

6. How does the trade window work programmatically on Mainline/Forever: events (`TRADE_SHOW`, `TRADE_PLAYER_ITEM_CHANGED`, `TRADE_ACCEPT_UPDATE`, `TRADE_CLOSED`), `InitiateTrade`, placing an item from bags into a trade slot (`C_Container.PickupContainerItem` + `ClickTradeButton`), and which of these are protected or require a hardware event?

7. How do existing warlock addons (Necrosis, Warlock Prep, Logroño's Warlocks, WarlockTools) implement shard/stone tracking, multi-step buff/prep sequencing across clicks, summon-request parsing and queueing, and what API calls in their source would not exist or behave differently on Mainline/Forever? Also, what UI conventions do Forever-compatible addons use for movable frames and settings (Edit Mode integration, `Settings.RegisterCanvasLayoutCategory` / `Settings.RegisterVerticalLayoutCategory`)?
