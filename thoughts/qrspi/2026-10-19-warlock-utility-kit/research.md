# Research Findings

Repository contains no addon source; all findings are external (warcraft.wiki.gg, CurseForge, GitHub), gathered 2026-10-19. URLs stand in for `file:line` references. **UNVERIFIED** = not directly seen on a fetched page.

Key shorthand:
- `NOTES` = https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes
- `SECRETS` = https://warcraft.wiki.gg/wiki/Secret_Values
- `API12` = https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes

## Q1: TOC layout, SavedVariables, ForeverSVFix

### Findings
- `NOTES` (Beta 4, 2026-10-08): "Forever" accepted as alias for "Camelot" in TOC suffixes (`MyAddon_Forever.toc`), `[Game]` variable and game-type folder lookup. Lua `require` renamed to `import`.
- TOC format (https://warcraft.wiki.gg/wiki/TOC_format):
  - `## Interface` single number or comma list (since 10.2.7), e.g. `## Interface: 120105, 50504, 11509`.
  - Game-type suffixes (`_Standard`, `_Forever`, `_Mists`) checked before family suffixes (`_Mainline`, `_Classic`); page prefers comma lists / inline directives over per-game TOCs.
  - `## SavedVariables` -> `WTF\<account>\SavedVariables\<Addon>.lua`; `## SavedVariablesPerCharacter` -> `WTF\<account>\<server>\<character>\SavedVariables\`.
  - Files load top to bottom; `Dependencies` / `OptionalDeps` load first; `## LoadSavedVariablesFirst: 1` loads SV files before addon scripts.
  - `## Category` = collapsible header in AddOn List; `## IconTexture` = texture path; `## AddonCompartmentFunc` = global function called from compartment dropdown. Forever behavior of these three UNVERIFIED.
- Real Forever TOCs:
  - GuildStock (https://raw.githubusercontent.com/luisjedev/wow-forever-addons/main/GuildStock/GuildStock.toc): `## Interface: 16001`, `## Title`, `## IconTexture: Interface\AddOns\GuildStock\Assets\Icon`, `## Version`, `## SavedVariablesPerCharacter: GuildStockDB`, then one Lua file per line (Locales, core, Bags, Sync, UI...). No suffix, no Category, no AddonCompartmentFunc. Same repo holds DeathMark, Revenge, TDL, Waymark, all 16001.
  - VuloForeverUI (https://github.com/mrvulo/VuloForeverUI, summarized not quoted): Interface 16001, `## Category: VuloUI`, SavedVariables + SavedVariablesPerCharacter, Libs (LibStub, CallbackHandler, LDB, LSM, LibDeflate) loaded first, `Core\Init.lua` last.
  - TacoTip lists interfaces 11509, 20506, 38002, 16001, 120100 on CurseForge (multi-client).
  - No `_Forever.toc` seen in any real addon. Hemlock Forever ships `HemlockForever.toc` (https://github.com/Hexx98/hemlock-forever), contents not read.
- SavedVariables bug:
  - ForeverSVBridge (https://github.com/KonigTX/ForeverSVBridge): beta client "writes addon saved variables at logout but doesn't read them back at login".
  - ForeverSVFix README (https://github.com/nobewayo/ForeverSVFix): same diagnosis; README states "It seems that Blizzard have fixed the issue." Fix build not confirmed.
  - ForeverSVFix mechanism (`forever_sv_fix.py`, fetch-tool summary): creates `ForeverSVFixData` directory link inside addon pointing at account `SavedVariables`; adds `ForeverSVFixData\<Addon>.lua` to addon TOC plus `## X-ForeverSVFix: 6`. Line placed before first file if `LoadSavedVariablesFirst: 1`, else appended at end. Per-character: generated `ForeverSVFixCharacter.lua` matches character via `UnitFullName`/`UnitName`, then `C_AddOns.LoadAddOn` on a generated LoadOnDemand helper `ForeverSVFixPC_<hex>`. Ambiguous match prints warning, restores nothing. Backups in `WTF/ForeverSVFix/backups/`.
  - Script does not reference `ADDON_LOADED` or `PLAYER_LOGIN`. SV globals are set when the injected TOC line executes, i.e. during file load (inference from TOC ordering). With end-of-TOC placement, addon files run before SV table exists.
  - ForeverSVBridge: separate `!`-prefixed addon loading first, TOC lists each addon's SV file via `SV` junction; Windows only, `setup.bat` + `/reload`.

## Q2: Secure action buttons; Forever click-to-cast patterns

### Findings
- SecureActionButtonTemplate (https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate):
  - `type` values: actionbar, action, pet, spell, toy, item, macro, flyout, glyph, worldmarker, cancelaura, stop, target, focus, assist, mainassist, maintank, click, attribute, togglemenu, destroytotem, multispell (deprecated). Unknown type -> checks `"_" .. type` attribute, then `rawget(button, type)`.
  - Modifier prefixes `alt-`, `ctrl-`, `shift-` (that order); `*` wildcard for modifier/button; `checkselfcast`/`checkfocuscast`.
  - Macro type: 255-char limit; cannot `/click` buttons that run other macros.
  - Template makes button and parents Protected; `SetAttribute` may fail in combat; create button out of combat. Non-left clicks require `RegisterForClicks()`.
- ActionButtonUseKeyDown (https://warcraft.wiki.gg/wiki/CVar_ActionButtonUseKeyDown): default 1 (fire on press), account-wide. Since 10.0, addon secure buttons react in CVar's direction even if registered both ways. Since 11.1.5, per-button `useOnKeyDown` attribute overrides CVar.
- SecureHandler snippets / WrapScript and protected-function list (CastSpellByName, UseContainerItem): pages not fetched, UNVERIFIED.
- `C_RestrictedActions.CheckAllowProtectedFunctions` exists (`API12`).
- Forever addons:
  - Hemlock Forever `Hemlock.lua` (https://raw.githubusercontent.com/Hexx98/hemlock-forever/main/Hemlock.lua): only `CastSpellByName(self.poisonSpellName)` as fallback when `C_TradeSkillUI.OpenTradeSkill` fails; no SecureActionButtonTemplate, SetAttribute, InCombatLockdown or issecretvalue. Vendor-window tool.
  - Easy Poisons (https://www.curseforge.com/wow/addons/easy-poisons): TBC Anniversary + Forever; modifier-click weapon icons apply highest-rank poison; page says it "works in combat"; auto-confirms replace-enchant popup. No source.
  - Wick's Poisons and Things (https://www.curseforge.com/wow/addons/wicks-poisons-and-things): MIT, needs WickCore; "Coating macros are rewritten out of combat as your bags change". No source found.
- Necrosis Classic secure pattern (https://raw.githubusercontent.com/kricklen/Necrosis-Classic/master/Helpers/SphereButtonHelper.lua): `type1`/`type3` = "macro", `type2` = "spell" for soulstone; `macrotext` lists all Soulstone item IDs; `shift-type*` = "spell" for Ritual of Summoning; Firestone/Spellstone flip `type1` between "spell" and "item" by bag contents; Healthstone `macrotext1` = `"/stopcasting\n"..useHealthstoneMacro`. Updated via `Update*Attribute` helpers called from `UpdateIcons()`; comment "Modifying the button use during combat is forbidden."

## Q3: Bag/item APIs, events, IDs

### Findings
- `NOTES` lists no container, item, trade or warlock API changes for 1.60.1.
- `C_Container.GetContainerItemInfo(bag, slot)` (https://warcraft.wiki.gg/wiki/API_C_Container.GetContainerItemInfo): returns `ContainerItemInfo` or nil; fields iconFileID, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink, isFiltered, hasNoValue, itemID, isBound, itemName. Predicates AllowedWhenUntainted, MayReturnNothing.
- `C_Container.GetContainerItemID(bag, slot)` (https://warcraft.wiki.gg/wiki/API_C_Container.GetContainerItemID): AllowedWhenUntainted; page has separate Forever bag-index table.
- `C_Container.GetContainerNumSlots`: not fetched, UNVERIFIED.
- `C_Item.GetItemCount(itemInfo[, includeBank[, includeUses[, includeReagentBank[, includeAccountBank]]]])` (https://warcraft.wiki.gg/wiki/API_C_Item.GetItemCount): AllowedWhenUntainted. `includeUses` counts charges. Forever honoring reagent/account bank args UNVERIFIED.
- `C_Item.GetItemInfoInstant` (https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfoInstant): no server query; returns itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID; names only resolve for items seen in bags/bank this session.
- `BAG_UPDATE_DELAYED` (https://warcraft.wiki.gg/wiki/BAG_UPDATE_DELAYED): no payload; fires after all BAG_UPDATEs for an action. BAG_UPDATE, ITEM_COUNT_CHANGED pages not fetched.
- No fetched page marks bag/item returns as secret.
- Item IDs (Classic data):
  - Soul Shard 6265 (https://www.wowhead.com/classic/spell=6201/create-healthstone).
  - Major Healthstone 9421 (lvl 48, 1200 HP). Healthstone page links 5512, rank unstated (https://warcraft.wiki.gg/wiki/Healthstone); pre-Wrath each rank separate item.
  - Soulstone 16893, rank unstated (https://warcraft.wiki.gg/wiki/Soulstone_(item)).
  - Other healthstone ranks/talent variants, other soulstone ranks, spellstone, firestone item IDs: NOT FOUND.
- Spell IDs:
  - Create Healthstone: 6201 (Minor), 11730 (Major) listed for Forever (https://warcraft.wiki.gg/wiki/Create_Healthstone); 5699 normal (https://classicdb.ch/?spell=5699). 6202, 11729 recollection only, UNVERIFIED.
  - Create Soulstone: 693 Minor (lvl 18), 20752 Lesser (30), 20755 normal (40), 20757 Major (60) (https://wowclassicdb.com/spell/693). Greater (20756?) UNVERIFIED.
  - Create Spellstone: 2362 (r1), 17728 (r3) (https://warcraft.wiki.gg/wiki/Create_Spellstone).
  - Create Firestone: 6366 (r1), 17953 (r4); Classic listed 17951 (https://warcraft.wiki.gg/wiki/Create_Firestone).
  - Summon Imp 688 (https://warcraft.wiki.gg/wiki/Summon_Imp). Voidwalker 697, Succubus 712, Felhunter 691 UNVERIFIED.
  - Demon Armor 706 (r1) .. 11735 (max), "remains in Classic and Forever" (https://warcraft.wiki.gg/wiki/Demon_Armor). Demon Skin 687 UNVERIFIED.
  - Detect Invisibility: Forever lists 132 and 11743 (likely Lesser and Greater); Classic 2970 (https://warcraft.wiki.gg/wiki/Detect_Invisibility).
  - Ritual of Summoning: learned lvl 20; ID 698 UNVERIFIED (https://warcraft.wiki.gg/wiki/Ritual_of_Summoning).
  - Soul Link, Soulstone Resurrection buff IDs: NOT FOUND.
- Forever warlock changes (https://accountshark.net/blog/wow-forever-rogue-warlock-changes-guide-mutilate-banes-talents, from BlizzCon 2026 demo / class deep dive): Drain Soul progressive shard chance per tick; Decimation can remove Soul Fire shard cost 10s; Curse of Agony/Doom become "Banes" (one per warlock per target); pets scale with warlock stats; capstones Wrack, Demonic Pact, Incinerate. Zockify says details may change (https://www.zockify.com/forever/warlock/). Shard stacking only a player proposal (https://us.forums.blizzard.com/en/wow/t/2368623). No healthstone changes found.

## Q4: Secrets restrictions on auras, spells, talents, pets

### Findings
- `NOTES` 2026-09-15: "The addon disarmament changes introduced in Midnight, including secrets, will also be active in Forever." 12.1.0 AuraContainer/AuraButton changes also present.
- `SECRETS`: secret values restrict operations on tainted paths; equal to normal values when unrestricted. Restriction states: combat, encounter, challenge mode, PvP match, restricted maps.
- Helpers (`API12`): issecretvalue, issecrettable, hasanysecretvalues, canaccessvalue, canaccessallvalues, canaccesssecrets, canaccesstable, dropsecretaccess, scrubsecretvalues, secretwrap, securecallmethod. `C_Secrets.HasSecretRestrictions`, `GetSpellAuraSecrecy`, `GetSpellCooldownSecrecy`, `ShouldAurasBeSecret`, etc. `C_RestrictedActions.GetAddOnRestrictionState`, `IsAddOnRestrictionActive`, event `ADDON_RESTRICTION_STATE_CHANGED`. CVar `addonCombatRestrictionsForced` simulates combat restrictions.
- New duration APIs: `C_UnitAuras.GetAuraDuration`, `GetAuraBaseDuration`, `GetUnitAuraInstanceIDs`, `C_Spell.GetSpellCooldownDuration`, `Cooldown:SetCooldownFromDurationObject`.
- `COMBAT_LOG_EVENT[_UNFILTERED]` "will error when trying to register them" (`API12`).
- Aura rules (`SECRETS`): `SecretWhenUnitAuraRestricted` under combat/encounter/challenge/PvP; per-spell never/always-secret flags override; `RequiresNonSecretAura` APIs return nothing instead of erroring. `SecretOnRestrictedMaps` (12.0.5): secret in dungeons/raids regardless of combat.
- `C_UnitAuras.GetPlayerAuraBySpellID` (https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetPlayerAuraBySpellID): AllowedWhenTainted, RequiresNonSecretAura, SecretWhenUnitAuraRestricted. NeverSecret fields: isFromPlayerOrPlayerPet, isHarmful, isHelpful, isNameplateOnly, isRaid.
- `C_UnitAuras.GetAuraDataByIndex` (https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex): AllowedWhenUntainted, RequiresUnitAuraAccess, SecretWhenUnitAuraRestricted; NeverSecret adds auraInstanceID. `NOT_CANCELABLE` filter removed (use `!CANCELABLE`).
- `C_UnitAuras.GetUnitAuras` (https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetUnitAuras): `ConditionalSecretContents`; name, spellId, duration, expirationTime, sourceUnit not NeverSecret. No group-member-specific rule documented.
- `UnitBuff` (https://warcraft.wiki.gg/wiki/API_UnitBuff): listed for Retail 12.1.5 and Forever 1.60.1 as alias of `C_UnitAuras.GetBuffDataByIndex`; deprecation notices conflict.
- `C_Spell.GetSpellCooldown` (https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCooldown): available in Forever; SecretWhenCooldownsRestricted; NeverSecret isEnabled, isActive, isOnGCD.
- `IsSpellKnown` (https://warcraft.wiki.gg/wiki/API_IsSpellKnown): deprecated 11.2.0, replacement `C_SpellBook.IsSpellInSpellBook`; removed Retail 11.2.0, Mists 5.5.1, TBC 2.5.5, Vanilla 1.15.8; Forever status UNVERIFIED. Passive spells: use `IsPlayerSpell`.
- `GetTalentInfo` (https://warcraft.wiki.gg/wiki/API_GetTalentInfo): deprecated 11.2.0 -> `C_SpecializationInfo.GetTalentInfo`; Forever not listed. `C_ClassTalents` in Forever UNVERIFIED.
- `UnitCreatureFamily` (https://warcraft.wiki.gg/wiki/API_UnitCreatureFamily): AllowedWhenUntainted, SecretWhenUnitIdentityRestricted (applies when unit not player-controlled or in party/raid); 11.1.5 added `id` return.
- `UnitName`: secret "if querying a non-player or pet unit while in combat". `UnitHealth`: combat may return secrets; max health secret when unit not player-controlled. Spell-cast info secret if unit not player or pet. `UnitExists("pet")` UNVERIFIED.
- `NOTES` Beta 5: pet/creature GUID server+spawn IDs obfuscated (stable in session).

## Q5: Chat events, group state, sending restrictions

### Findings
- `CHAT_MSG_PARTY` (https://warcraft.wiki.gg/wiki/CHAT_MSG_PARTY): args 1 text, 2 playerName, 3 languageName, 4 channelName, 5 playerName2, 6 specialFlags, 7 zoneChannelID, 8 channelIndex, 9 channelBaseName, 10 languageID, 11 lineID, 12 guid, 13 bnSenderID, 14 isMobile, 15 isSubtitle, 16 hideSenderInLetterbox, 17 suppressRaidIcons. text, playerName, playerName2, guid, bnSenderID not NeverSecret; event carries `SecretInChatMessagingLockdown` (secret during encounter, challenge mode, PvP match). RAID/GUILD/SAY/WHISPER pages not fetched, UNVERIFIED same predicate.
- `C_ChatInfo.InChatMessagingLockdown`, CVar `addonChatRestrictionsForced` (testing) exist (`API12`). `RestrictedForMacroChatMessages` applies only during instance encounters for macro-initiated messages (`SECRETS`).
- `UnitIsConnected`, `UnitIsDeadOrGhost` (https://warcraft.wiki.gg/wiki/API_UnitIsConnected, .../API_UnitIsDeadOrGhost): AllowedWhenUntainted, documented for Forever.
- `GetRaidRosterInfo` (https://warcraft.wiki.gg/wiki/API_GetRaidRosterInfo): returns name, rank, subgroup, level, class, fileName, zone (7th), online, isDead, role, isML, combatRole; offline zone = "Offline"; player zone may be nil until location change after reload.
- `C_Map.GetBestMapForUnit` (https://warcraft.wiki.gg/wiki/API_C_Map.GetBestMapForUnit): player and group members only.
- `UnitInRange` (https://warcraft.wiki.gg/wiki/API_UnitInRange): group only, `SecretReturns` predicate; returns inRange (40 yd), checkedRange.
- `CheckInteractDistance` (https://warcraft.wiki.gg/wiki/API_CheckInteractDistance): protected in combat for insecure code since 10.2.0 (enemy units re-allowed 10.2.0.52485).
- `UnitPosition` (https://warcraft.wiki.gg/wiki/API_UnitPosition): player/party/raid only; nil inside instances, battlegrounds, arenas since 7.1.0.
- `IsInRaid`, `IsInGroup`, `GetNumGroupMembers`: not fetched.
- `SendChatMessage` (https://warcraft.wiki.gg/wiki/API_SendChatMessage): deprecated 11.2.0 (to `C_ChatInfo`), 255-char truncation; SAY/YELL/CHANNEL need hardware event outdoors (8.2.5); WHISPER cross-realm in region. `NOTES` Beta 4: EMOTE now needs hardware event outside instances.
- `C_ChatInfo.SendAddonMessage` (https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage): 255 chars, 16-char prefix, recipient must `RegisterAddonMessagePrefix`; throttle 10 per prefix regenerating 1/sec, returns `AddonMessageThrottle`; result enum includes `AddOnMessageLockdown` (11), `TargetOffline` (12); `INSTANCE_CHAT` type for instance groups.
- `NOTES` Beta 4 (build 70291): "Trial accounts can no longer send addon messages."

## Q6: Trade window

### Findings
- `TRADE_SHOW` (https://warcraft.wiki.gg/wiki/TRADE_SHOW): no payload; fires when trade window appears.
- Related events (from https://warcraft.wiki.gg/wiki/API_AcceptTrade): TRADE_ACCEPT_UPDATE, TRADE_CLOSED, TRADE_MONEY_CHANGED, TRADE_PLAYER_ITEM_CHANGED, TRADE_REPLACE_ENCHANT, TRADE_REQUEST, TRADE_REQUEST_CANCEL. Payloads not fetched. TRADE_TARGET_ITEM_CHANGED UNVERIFIED.
- `AcceptTrade()`: restricted, `#hwevent` (keyboard/mouse input); listed for Forever.
- `InitiateTrade(unit)` (https://warcraft.wiki.gg/wiki/API_InitiateTrade): AllowedWhenUntainted; no hardware-event note.
- `C_Container.PickupContainerItem(bag, slot)` (https://warcraft.wiki.gg/wiki/API_C_Container.PickupContainerItem): AllowedWhenUntainted, Cursor API.
- `GetTradePlayerItemInfo(id)` (https://warcraft.wiki.gg/wiki/API_GetTradePlayerItemInfo): returns name, texture, numItems, quality, enchantment, canLoseTransmog; listed for Forever.
- `ClickTradeButton`, `ClickTargetTradeButton`: wiki URLs 404; `GetTradeTargetItemInfo` not fetched. UNVERIFIED.
- Necrosis uses `PickupContainerItem` + `CursorHasItem()` + `DeleteCursorItem()` for shard deletion (https://raw.githubusercontent.com/kricklen/Necrosis-Classic/master/Helpers/BagHelper.lua).

## Q7: Existing warlock addons; Forever UI conventions

### Findings
- **Necrosis Classic** (https://github.com/kricklen/Necrosis-Classic, GPL v2, archived 2026-01-23, TOC 20504):
  - Counting: `GetItemCount(ItemHelper.Soulshard_Item_Id)` in `_bh:GetStoneCounts()`; bag scan via `GetBagName`, `GetContainerNumSlots`, `select(6, GetItemInfo(bagName))` (subclass 1 = soul bag); stones via `GetContainerItemID` + `ItemHelper:IsSoulstone/IsHealthstone/IsSpellstone/IsFirestone` (`Helpers/BagHelper.lua`).
  - `GetContainerItemCooldown` for stone cooldowns; `UnitBuff`/`UnitDebuff` 1..40 loops in `UnitHasBuff`/`UnitHasEffect`; `GetSpellInfo` in `UNIT_SPELLCAST_SENT` handler and `Necrosis:SpellLocalize`; `GetSpellBookItemName(id, BOOKTYPE_SPELL)` in `SpellSetup()`; `GetSpellCooldown`, `GetSpellPowerCost`; `CHAT_MSG_ADDON` checked against `Necrosis.CurrentEnv.ChatPrefix` (`Necrosis.lua`, `Spells.lua`).
  - Summon request parsing not found in portion read.
- **Warlock Prep** (https://www.curseforge.com/wow/addons/warlock-prep, All Rights Reserved, no source): single button, each click casts next missing step: armor (Fel > Demon Armor > Demon Skin), Detect Invisibility, pet (default Imp; Imp if no shard), Soul Link, create Healthstone, create Soulstone, use Soulstone on self. Step skipped if buff active, item in bags, spell unknown, condition fails, or Demonic Sacrifice active. Border yellow + remaining-count badge / green when done / red in combat ("attributes are locked").
- **Logroño's Warlocks** (https://www.curseforge.com/wow/addons/logronos-warlocks, v2.0.0, Classic Era 1.15.9, MIT, no source link): parses "123", "sum", "summon me", "port" from party, raid, guild, say, whisper; one row per requester; click = target + Ritual of Summoning, Ctrl+click = target only, right-click = remove. Shared list across warlocks via addon messages, synced with RaidSummon, RaidSummonPlus, Capslock. Panel shows shard count and nearby helper count. Row flags: offline, dead, no shards, actual zone. Also soulstone 30-min timer, healthstone/spellstone handling.
- **WarlockTools** (https://github.com/afrugalpenguin/warlocktools, MIT, Interface 20505): shard/stone HUD, popup spell menu, healthstone economy panel, whisper queue with auto-reply that places healthstones into trades. Code not read.
- Other summon-queue addons: Delvers' Summon, Rituall, Summon Queue Assist, SteaSummonSOD (https://github.com/edualve/SteaSummonSOD, source public, not read).
- Classic-only vs Mainline:
  - `GetContainerItemInfo` global removed 10.0.2 -> `C_Container.GetContainerItemInfo` (https://warcraft.wiki.gg/wiki/API_GetContainerItemInfo). Other container globals on Forever UNVERIFIED.
  - `GetSpellInfo` deprecated 11.0 -> `C_Spell.GetSpellInfo` (https://warcraft.wiki.gg/wiki/Patch_11.0.2/API_changes).
  - `UnitBuff`/`UnitDebuff` status conflicting (see Q4). `GetTalentInfo` not listed for Forever (Q4). `GetSpellBookItemName` UNVERIFIED.
- UI conventions:
  - Settings API (https://warcraft.wiki.gg/wiki/Settings_API): `Settings.RegisterCanvasLayoutCategory(frame, name)`, `Settings.RegisterVerticalLayoutCategory(name)`, `Settings.RegisterAddOnCategory(category)`, `Settings.OpenToCategory(category[, scrollToElementName])`. Forum report: opening by self-assigned `cat.ID` broke after 12.0; `category:GetID()` suggested (https://wowinterface.com/forums/showthread.php?p=345275, UNVERIFIED).
  - Forever runs retail Edit Mode; `NOTES`: layouts saved separately per mouse/keyboard vs gamepad.
  - VuloForeverUI: own mover/"edit mode" system (`/vedit`, grid + snap), custom options window (`/vfui`); no `Settings.Register*` seen.
  - GuildStock: minimap button, slash command, own window with scale/move options.
  - Edit Mode Enhanced (https://www.curseforge.com/wow/addons/edit-mode-enhanced): warns Forever frame names may change between builds. Movable Windows Forever repositions Blizzard windows.
  - No Forever addon using LibEditMode or `RegisterCanvasLayoutCategory` found.

## Cross-Cutting Observations
- Forever = Mainline 12.x API surface + Classic-era content; 1.60.1 notes add only small deltas (TOC alias, trial addon-message block, EMOTE hwevent, GUID obfuscation, FrameStrata secret).
- Secrecy is state-driven (combat, encounter, challenge, PvP, restricted maps), not API-driven alone; dungeons/raids (`SecretOnRestrictedMaps`) restrict even out of combat. Chat payloads (sender, text) can be secret in chat lockdown.
- Combat lockdown blocks secure attribute changes; Classic warlock addons (Necrosis, Warlock Prep) and Forever Wick's all rewrite secure attributes/macros out of combat in response to bag changes.
- Forever-targeting addons observed use single `## Interface: 16001` TOCs without suffixes and their own frames/slash commands rather than Settings/Edit Mode integration.
- Classic warlock addon sources rely on globals (`GetContainerItemInfo`, `GetSpellInfo`, `UnitBuff`, `GetTalentInfo`) that are removed or deprecated on Mainline.

## Open Areas
- Complete item IDs (healthstone/soulstone/spellstone/firestone ranks), Soul Link, Ritual of Summoning, Soulstone Resurrection buff, pet summon IDs; whether Forever retains ranked stones.
- Talent query API on Forever (`C_ClassTalents` vs `GetTalentInfo` vs other); `IsSpellKnown` vs `C_SpellBook.IsSpellInSpellBook` availability.
- Whether group-member aura data (e.g. a raid member's soulstone buff, expirationTime) is readable out of combat in open world vs instances.
- Payloads/predicates of CHAT_MSG_RAID/GUILD/SAY/WHISPER and trade events; `ClickTradeButton` existence.
- SecureHandler/WrapScript behavior and protected-function list on 12.x.
- Whether Blizzard's SavedVariables loader fix ships in launch build.
- Source for Logroño's Warlocks, Warlock Prep, WarlockTools, Easy Poisons not read or not published.
