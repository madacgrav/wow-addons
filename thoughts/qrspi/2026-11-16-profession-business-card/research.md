# Research Findings

Sources: repo code (paths relative to repo root), `thoughts/qrspi/*` docs, root PRD, and web pages (CurseForge, Warcraft Wiki, Warcraft Tavern), read 2026-11-16. The web research covered only CurseForge, not Wago, GitHub or WoWInterface, and read no addon TOC files.

## Q1: Existing community addons (chat-ad scanning, recipe/service broadcast, available/busy)

### Findings
No single addon was found that does all three of the following: (a) scan public chat into a list of advertisers, (b) broadcast your own recipes or services addon-to-addon, and (c) set an available/busy status. Each behaviour exists separately.

**(a) Public-chat ad scanners with Forever builds (CurseForge tag 1.60.1)**
- **Wick's Trade Hall** — https://www.curseforge.com/wow/addons/trade-hall
  - Board with one line per person per subject, in the categories selling, buying, enchanting, crafting and travel.
  - Filter by category, search by player, entries expire after about 20 min, right-click whispers the poster.
  - Read-only and needs WickCore. The page says posting is restricted on this client.
  - Forever v0.9.3. Updated Nov 15, 2026.
- **Allemano Hush Feed** — https://www.curseforge.com/wow/addons/allemano-hush-feed
  - Sorts General, Trade, TradeLocal, Services, LookingForGroup and custom channels into LFG, Trade, Services, Guilds and Other.
  - Merges repeat posts by the same player. Whisper and Invite actions, keyword "watches" with a sound.
  - Labelled Alpha, needs Allemano Hush. Forever only ("interface 16001"). Updated Sep 30, 2026.
- **Services Bulletin Board (SBB)** — https://www.curseforge.com/wow/addons/services-bulletin-board-sbb
  - Parses the Services and Trade channels into a board with categories that include Summons and Crafting.
  - One-click whisper and invite, search, Trade Ledger.
  - Builds for Forever, Retail and the Classic flavors. Updated Nov 8, 2026.
- **Forever Profession Suite** — https://www.curseforge.com/wow/addons/forever-profession-suite
  - Its Trade Board watches trade chat and yells for WTB/WTS posts and alerts on matches.
  - Its Profession Master shows guild professions.
  - Forever v1.0.0. Updated Oct 25, 2026.

**(a) Not on Forever**
- **CraftScan** (Retail 12.1.5 only, MIT, source on GitHub) — https://www.curseforge.com/wow/addons/craftscan
  - Matches chat crafting requests against your characters' recipes, including item links, and offers a one-click whisper.
  - Customer rows last 10 min.
- **Calgs Portals** (Classic 1.15.9) — https://www.curseforge.com/wow/addons/calgs-portals
  - Queues portal requests from Trade chat, filters out other mages' adverts, and parses destination abbreviations.
- **Other portal addons, not opened:** MageMart, Portal Service, Portal Pro, InviteSniper.
- **Warlock summons:** no summon-specific addon was found.

**(b) Recipe broadcast, all guild-scoped**
- **Recipe Registry** (Forever v0.1.8, 2519 recipes across 12 professions; updated Nov 14) — https://www.curseforge.com/wow/addons/recipe-registry
  - A guild crafting directory filled when you open your professions, with online crafters listed first.
  - Can share results to guild, party, raid, say or whisper, and has a tab listing guildmates who run the addon.
  - No chat scanning and no status.
- **ForeverCodex** (Forever v1.0.32; updated Oct 16) — https://www.curseforge.com/wow/addons/forevercodex
  - Guild recipe sync with a revision handshake. Relays cached data for offline crafters. No chat scanning.
- **CraftLink** (TBC Classic only) — https://www.curseforge.com/wow/addons/craftlink
  - Addon-to-addon recipe sharing with clickable chat links, plus a composer that posts crafts to trade chat.
- **Guild-only, Classic flavors:** GuildCraftSync, Ultimate Profession Master (hash-then-fetch sync), GuildWorkshop, Who Can Craft.
- **PRD's own list (`WoW Forever Addon Ideas — PRD.md:129-143`):** GuildStock (guild material sharing, Forever) and Guild Self Forever 2.0 (crafting requests within the GSF ruleset).

**(c) Available/busy**
- None of the pages read describes a player-set status that is broadcast to others.
- The nearest is CraftScan's per-crafter enable/disable, which is local and only controls alerts.
- "Online first" in Recipe Registry comes from online status, not from a status the player sets.

**Unverified:** no page says how its addon handles Midnight chat secrets.

## Q2: How WUK `Summon.lua` / `Trade.lua` parse chat and whisper back

### Findings
**Events**
- Registered at `WarlockUtilityKit/Summon.lua:86-87`: `CHAT_MSG_PARTY`, `_PARTY_LEADER`, `_RAID`, `_RAID_LEADER`, `_GUILD`, `_SAY`, `_WHISPER`. All go to `OnChat(text, sender)` at `Summon.lua:58`.
- Summon's inits run only for the WARLOCK class (`WarlockUtilityKit/Core.lua:147-152`).

**Guards**
- `OnChat` returns early if `WUK.Secret(text)` or `WUK.Secret(sender)` (`Summon.lua:59`).
- `WUK.Secret` is `issecretvalue ~= nil and issecretvalue(v)` (`Core.lua:7`).

**Matching**
- `WUK.IsSummonRequest` is `HasWord(text, SUMMON_WORDS)` (`WarlockUtilityKit/Logic.lua:49-50`), with words `123`, `sum`, `summon`, `port`.
- `HasWord` (`Logic.lua:42-46`) lowercases the text, tokenizes it with `gmatch("%w+")`, and looks each whole token up in a set. There is no substring matching: the tests at `tests/run.lua:29-30` reject "summoner", "portal" and "1234".

**Sender names**
- `Ambiguate(sender, "none")` (`Summon.lua:60`) strips the realm for same-realm players.
- Messages from the player themself are skipped (`Summon.lua:61`).
- `WUK.UnitFull(unit)` (`Core.lua:124-128`) builds the same name form from a unit and returns nil if the name is secret.

**Store and expiry**
- Module-local `queue` with `MAX=10` and `TTL=600` (`Summon.lua:2-3`).
- `WUK.QueueAdd` (`Logic.lua:55-60`) dedupes by name, caps the list and appends `{name, at}`. `at = time()` is set at `Summon.lua:62`.
- `QueuePrune` (`Logic.lua:64-66`) only runs when rows refresh, and refresh is skipped in combat (`Summon.lua:39-41`).
- Entries are also removed on a right-click (`Summon.lua:81`) and on a successful ritual cast (`Summon.lua:89-93`).
- Rows are SecureActionButtons whose macro is `/target name` + `/cast` (`Summon.lua:46-47`).

**Whispers in `Trade.lua`**
- On `CHAT_MSG_WHISPER` (`WarlockUtilityKit/Trade.lua:10`), the same secret guards run (`Trade.lua:11`), then `IsHealthstoneRequest` (`Logic.lua:52-53`).
- A per-name timestamp table with a 600 s cooldown blocks repeat replies (`Trade.lua:2`, `Trade.lua:13`).
- Replies use `(C_ChatInfo.SendChatMessage or SendChatMessage)(msg, "WHISPER", nil, to)` (`Trade.lua:7`) and are sent to the raw `sender`.
- Reply strings deliberately contain no trigger words (`Trade.lua:4-5`).
- The `TRADE_SHOW` auto-fill is at `Trade.lua:17-30`.

**Chat announce in `Board.lua`**
- `WUK.Announce` (`WarlockUtilityKit/Board.lua:72-81`) sends to RAID_WARNING, RAID or PARTY only, with lines spaced 0.3 s apart.

## Q3: Public channel chat on the Forever client

### Findings
**What the repo records**
- No code, probe result or PRD entry mentions `CHAT_MSG_CHANNEL` or public channels.
- No probe has tested whether chat text or sender names are secret.
- The repo's chat events are only those listed in Q2, plus `CHAT_MSG_ADDON` (`WarlockUtilityKit/Comm.lua:29`).

**`CHAT_MSG_CHANNEL` arguments** (https://warcraft.wiki.gg/wiki/CHAT_MSG_CHANNEL)
- The 18 arguments, in order: text, playerName, languageName, channelName (includes the number), playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, suppressRaidIcons, discordInfo.

**Secret values**
- Marked NeverSecret: languageName, channelName, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, and the booleans.
- Not marked NeverSecret, so they can be secret: text, playerName, playerName2, guid, bnSenderID, discordInfo.
- The event lists the predicate `SecretInChatMessagingLockdown`. Per https://warcraft.wiki.gg/wiki/Secret_Values, that lockdown applies during encounters, challenge modes and PvP matches, and on communication-restricted maps such as dungeons and raids.
- No source says public channel text is secret outside lockdown.
- The 1.60.1 notes confirm the Midnight secrets system is active on Forever (https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes).

**Lockdown API: conflicting records**
- `thoughts/qrspi/2026-10-19-warlock-utility-kit/research.md:101` and the Patch 12.0.0 wiki say `C_ChatInfo.InChatMessagingLockdown` exists.
- The Forever probe says it does not exist on this client (`thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md:5`), and `GH-23-warlock-combat-kit/research.md:107` repeats that.
- The probe is the client-observed fact. `Core.lua:180` probes for the API defensively.

**Sending**
- SAY, YELL and CHANNEL need a hardware event since 8.2.5. Sources: `thoughts/qrspi/2026-10-19-warlock-utility-kit/research.md:109`, and the secondary source Calg's addon pages.
- EMOTE needs a hardware event on Forever from 1.60.1 (PRD `:21`, 1.60.1 notes).
- WHISPER, PARTY, RAID and GUILD do not need one, per the same secondary source.
- `RestrictedForMacroChatMessages` (12.0.1) applies only to macro-initiated chat during instance encounters.
- No whisper-specific throttle was found for 12.x or Forever.

**Channels** (https://support.blizzard.com/en/article/9738)
- General, Trade, LocalDefense and LookingForGroup, plus "Trade (Services)", joined with `/join services`.
- Retail's Services channel is off by default.
- Channel numbers depend on join order. `channelBaseName` and `channelIndex` identify the channel.
- Forever's actual channel list, including whether Services exists, is unverified. Allemano Hush Feed's page lists Services and TradeLocal for its Forever build.

## Q4: WUK `Comm.lua` addon messages; trial and WHISPER limits

### Findings
**`Comm.lua`**
- Prefix `"WUKB"` (`WarlockUtilityKit/Comm.lua:2`), registered at `Comm.lua:27`.
- `Channel()` returns RAID, PARTY or nil (`Comm.lua:5-7`). There is no GUILD or WHISPER path.
- `WUK.Send` enqueues only when a channel exists and the queue holds fewer than 64 messages (`Comm.lua:3`, `Comm.lua:24`).
- A `C_Timer.NewTicker(0.25, Flush)` drives sending (`Comm.lua:28`).
- `Flush` (`Comm.lua:10-22`):
  - Success is `result == 0 or result == true`. It then sets `nextSend = now + 0.5`.
  - Failure backs off `min(30, 2^failures)` seconds and prints a one-time warning with the code.
  - After 3 failures the queue is wiped. The queue is also wiped when there is no channel.
- No size check and no chunking.

**Message format** (`Logic.lua:117-139`)
- `PROTO="1"`, pipe-delimited, with `-` for nil.
- Kinds: L, A, R and E. `Decode` validates each kind's field count and numeric fields.

**Receive**
- `CHAT_MSG_ADDON` handler at `Comm.lua:29-35`: checks prefix, secret guards, `Ambiguate`, skips self, decodes, then calls `WUK.OnBoardMessage` (`Board.lua:56-70`).
- `WUK.On` (`Core.lua:10-17`) uses one frame and a per-event handler list, with no unregister and no pcall.

**API facts** (https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage)
- Prefix at most 16 characters, message at most 255 bytes, no NUL.
- `Enum.SendAddonMessageResult`:
  - 0 Success (queued only)
  - 3 AddonMessageThrottle
  - 5 NotInGroup
  - 8 ChannelThrottle
  - 10 NotInGuild
  - 11 AddOnMessageLockdown
  - 12 TargetOffline (12.0)
- Throttle: each prefix has a bucket of 10 that refills at 1/s. Whispers outside instances are exempt. Sending too much across several prefixes can disconnect the client.
- WHISPER goes to a player on the same or a connected realm. The page states no guild or group requirement. This is untested on Forever.
- `SendAddonMessageLogged` (`CHAT_MSG_ADDON_LOGGED`) exists for user-generated text.
- The wiki recommends ChatThrottleLib or AceComm. Neither is used in this repo, and neither is verified on Forever.

**Trial and Veteran accounts**
- "Trial accounts can no longer send addon messages", per Beta 4 notes (`thoughts/qrspi/2026-10-19-warlock-utility-kit/research.md:111`, PRD `:21`).
- The SendAddonMessage wiki page adds Veteran accounts, on Forever from 1.60.1. Only that page says so.
- Trial-account testing is deferred (`thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/plan.md:461`).
- The design keeps the board local when a send fails (`2026-10-19-warlock-utility-kit-v2/design.md:57`).
- Open PRD question: `:199`.

## Q5: ProfessionPlanner recipe reading

### Findings
**When data is read**
- Only while the profession window is open and ready: `ScanProfession` returns when `not C_TradeSkillUI.IsTradeSkillReady()` (`ProfessionPlanner/Core.lua:28`).
- Triggered by `TRADE_SKILL_SHOW` and `TRADE_SKILL_LIST_UPDATE`. `TRADE_SKILL_CLOSE` clears the current profession (`Core.lua:189-194`).

**Calls**
- `GetBaseProfessionInfo` gives professionID, skillLevel and maxSkillLevel (`Core.lua:29`).
- A whitelist `PP.PROFESSIONS = {197 Tailoring, 333 Enchanting, 165 Leatherworking, 171 Alchemy}` (`ProfessionPlanner/Logic.lua:12`) is checked at `Core.lua:31`.
- `GetAllRecipeIDs` is filtered by `GetProfessionInfoByRecipeID` professionID or parentProfessionID (`Core.lua:37-40`). The comment notes a stale list can follow a profession switch.
- Per recipe: `GetRecipeInfo`, `GetRecipeSchematic` (Basic reagents), `GetRecipeRequirements` via pcall for stations, and `GetRecipeSourceText` for unlearned recipes (`Core.lua:44-73`).
- An empty scan keeps the old cache and retries 5 times, 0.5 s apart (`Core.lua:78-84`).

**Data shape**
- `PP.char.recipes[professionID][recipeID] = {name, icon, reagents={{itemID,qty}}, qtyMin, stations, learned, color, maxTrivial, source}` (`Core.lua:86`).
- `PP.char.skill[prof] = {skill, max}` (`Core.lua:33`).

**SavedVariables**
- `ProfessionPlannerDB` = `{thresholds, prices, panelOpen, lastProbe}`.
- `ProfessionPlannerCharDB` = `{recipes, bank, skill}`.
- Set at `Core.lua:19-20` and `ProfessionPlanner.toc:6-7`.

**Other profession reads**
- `GetProfessions`/`GetProfessionInfo` appear only in TackleBox (`TackleBox/Core.lua:28-35`, event `SKILL_LINES_CHANGED` at `TackleBox/Core.lua:57`), and they need no open window.
- Fallback: `GetProfessionInfoBySkillLineID(356)`.

**Probe facts**
- From `thoughts/qrspi/2026-10-19-profession-leveling-planner/probe-results.md`:
  - Tailoring is 197 with 471 recipes, 40 learned (`:4`). Enchanting is 333 with 261 recipes (`:15`).
  - Leatherworking 165 and Alchemy 171 are unprobed (`:25`).
  - `maxTrivialLevel` is populated (`:30`).
- From `2026-10-20-profession-planner-seed-data-auctionator/probe-results.md`:
  - Unlearned recipes give no source or learnability signal (`:11-14`).
  - Forever-only station recipes show as unlearned (`:31`).

**Compact recipe encoding**
- None exists for a player's recipe list.
- `ProfessionPlanner/tools/gen_seed.py:50-64` generates the static `PP.SEED` table at build time.
- WUK `Encode`/`Decode` (`Logic.lua:117-139`) is the only wire format.
- No base64, serialize or compress code exists in any `.lua` file.

## Q6: State storage and list-style UI

### Findings
**SavedVariables**
- Every addon declares `XDB` (account) and `XCharDB` (character) at `.toc:6-7`.
- Each addon has its own copy of a nil-safe `MergeDefaults`: WUK `Core.lua:25-27`, WCK `Core.lua:29-30`, TackleBox `Core.lua:23-24`, ProfessionPlanner `Core.lua:19-21`.
- No shared library. The addons do not depend on each other (`thoughts/qrspi/GH-23-warlock-combat-kit/design.md:138`).

**ForeverSVFix**
- PRD `:20`, `:178` and `:197` cover it (open question: fixed at launch?).
- Code comments: `ProfessionPlanner/Core.lua:18`, `WarlockUtilityKit/Core.lua:24`.
- Design rule: data may reset each session, but the addon must not error (`thoughts/qrspi/2026-10-19-warlock-utility-kit/design.md:108`).
- SavedVariables were observed persisting (`2026-10-20-profession-planner-seed-data-auctionator/research.md:167`).

**List UI**
- No addon uses a ScrollFrame or ScrollBox. All use fixed row pools built once and shown per refresh with `SetShown`.
- **ProfessionPlanner `Panel.lua`:**
  - `MAX_ROWS=16` (`:2`), panel docked to `ProfessionsFrame` (`:6-9`).
  - Clicking a row runs `PP.SelectRecipe`, shift-click crafts (`:26`). Tooltip at `:27-33`.
  - Not movable, no filters.
- **TackleBox `Panel.lua`:**
  - `MAX_ROWS=30` (`:2`, comment "add a ScrollBox if that bites").
  - Tabs act as filters (`:142-176`).
  - Shift-drag moves the dock when unlocked and out of combat (`:18-40`). Position is saved in `db.frames`.
- **WUK `Board.lua`:**
  - `BasicFrameTemplateWithInset` window, dragged with plain `StartMoving` and added to `UISpecialFrames` (`:97-101`).
  - Row pool with `WowStyle1DropdownTemplate` dropdowns (`:108-134`). Action buttons at `:136-144`.
- **Lock and reset:** `/wuk lock` and `reset` (`WarlockUtilityKit/Core.lua:231-232`).

## Q7: Summon and travel spells on Forever; ad phrasing

### Findings
**Ritual of Summoning**
- Classic: spell 698, 1 Soul Shard, level 20, needs 2 more party members to click (https://wowclassicdb.com/spell/698, https://warcraft.wiki.gg/wiki/Summoning_Portal).
- The Forever spell ID is unverified, and Metaforge blocked the fetch (403).
- The repo resolves the ritual through `WUK.known.ritual` (`Summon.lua:46-47`). Its spell data lives in WUK's Logic and Core files and was not re-traced for this question.

**Mage travel** (https://www.warcrafttavern.com/forever/guides/mage-portals/)
- Teleports:
  - Level 20: Stormwind, Ironforge, Orgrimmar, Undercity.
  - Level 30: Darnassus, Thunder Bluff.
- Portals:
  - Level 40: Stormwind, Ironforge, Orgrimmar, Undercity.
  - Level 50: Darnassus, Thunder Bluff.
  - A portal lasts 60 s.
- Reagents: Rune of Teleportation 10s, Rune of Portals 20s.
- Learning: taught by Portal Trainers in each of your faction's cities.
- The Legacy talent "Reagent Economy" removes the reagent cost.
- No Forever-only destinations are listed, and no spell IDs were found.

**Meeting Stones**
- Classic: the ritual summons at the stone, and summoning is not allowed in battlegrounds (https://warcraft.wiki.gg/wiki/Meeting_Stone).
- No Forever-specific behavior or travel services (such as campsites) were found.

**Ad phrasing**
- No source quoting real ad strings was found.
- Indirect sources:
  - Advice to link the item, or ask the crafter to link their profession, rather than typing plain text (engadget 2009).
  - Calg's Enchanter reacts to "LF enchanter"-style requests.
  - Tipping mages is customary (blizzardwatch).
  - Portals, summons and buffs belong in the Services channel (Wowhead headline).
- Observed in repo code: WUK triggers on `123`, `sum`, `summon` and `port` (`Logic.lua:49-50`), and on `hs` and `healthstone` (`Logic.lua:52-53`).
- Observed in the addons above:
  - Calgs Portals parses abbreviated destinations.
  - Allemano Hush Feed's page says its sorting may miss new phrasings.

## Cross-Cutting Observations
- **Shared patterns, copied into each addon rather than shared:**
  - The `X.On` single event frame (WUK `Core.lua:10-17`).
  - The `X.Secret` wrapper (WUK `Core.lua:7`, ProfessionPlanner `Core.lua:4`).
  - `MergeDefaults`.
  - Fixed row pools.
  - The `inits` list run at PLAYER_LOGIN.
- **Chat handling** follows one shape: guard text and sender with `Secret`, normalize with `Ambiguate(sender,"none")`, skip self, match whole tokens, store `{name, at}` with a TTL, prune on refresh, and whisper back through `C_ChatInfo.SendChatMessage or SendChatMessage`.
- **Addon comms in the repo** use group channels only (RAID/PARTY). No GUILD or WHISPER transport exists, and there is no chunking above 255 bytes.
- **Forever facts in this area** come from three source types:
  - Client probes: authoritative, but they cover auras, spells and units only.
  - PRD and research docs.
  - Retail wiki pages: these sometimes conflict with the probes, as with `InChatMessagingLockdown`.
- **Several CurseForge addons with Forever builds** already scan Trade and Services chat into boards with one-click whisper: Trade Hall, Hush Feed, SBB, and Forever Profession Suite. Several sync recipes in the guild: Recipe Registry and ForeverCodex.

## Open Areas
- Whether public `CHAT_MSG_CHANNEL` text and sender are secret on Forever outside instances. No probe covers this.
- Forever's channel list (Services? TradeLocal?) and channel numbers.
- Whether WHISPER addon messages to unguilded, ungrouped players work on Forever, and the Veteran-account restriction.
- The Forever Ritual of Summoning spell ID, and mage Teleport/Portal spell IDs.
- Recipe IDs for Leatherworking and Alchemy (165/171 unprobed). Recipe data is readable only with the profession window open, via `C_TradeSkillUI`.
- Verbatim trade-chat ad phrasing on Forever.
- Wago, GitHub and WoWInterface were not searched. Also not checked: TSM, Skillet and BadBoy for Forever, the CurseForge pages that were not opened (Fabrikao, Forever Profession Master, Craft Catcher Suite, CraftRadar, RecipeVault, MageMart), and every addon's TOC interface number.
