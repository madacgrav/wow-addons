# Design Discussion

Working name: **BusinessCard** (folder `BusinessCard/`, prefix `BCARD`, slash `/bcard`). Rename freely before Structure.

## Current State
- **No Forever addon combines all three parts:**
  - A chat-ad board.
  - Addon-to-addon card exchange.
  - A player-set available/busy status.
- **Chat boards that exist:** Trade Hall, Hush Feed, SBB and Forever Profession Suite. Each covers the board part only (research Q1).
- **Recipe sync that exists:** Recipe Registry and ForeverCodex, both guild-only (research Q1).
- **No status:** nobody broadcasts a status (research Q1 (c)).
- **Repo chat parsing (WUK):**
  - Secret guard on text and sender, then `Ambiguate(sender,"none")`, then skip self, then a whole-token keyword match, then a `{name, at}` queue with a TTL (`WarlockUtilityKit/Summon.lua:58-62`, `Logic.lua:42-60`).
  - Whisper-back is in `Trade.lua:7`.
  - `CHAT_MSG_CHANNEL` is never used.
- **Repo addon comms:** `WarlockUtilityKit/Comm.lua:2-35` has a queue and backoff.
  - It sends to RAID/PARTY only.
  - It has no GUILD or WHISPER path and no chunking.
  - Its format is pipe-delimited with a version field (`Logic.lua:117-139`).
- **Recipe reads:**
  - ProfessionPlanner reads recipes only while the profession window is open (`ProfessionPlanner/Core.lua:28-86`).
  - Its whitelist covers 4 professions (`Logic.lua:12`).
  - `GetProfessions`/`GetProfessionInfo` give skill levels without an open window (`TackleBox/Core.lua:28-35`).
- **Platform limits:**
  - **Addon messages:** max 255 bytes. Each prefix has a bucket of 10 that refills at 1/s, but whispers outside instances are exempt.
  - **Trial accounts** cannot send addon messages. One wiki page says Veteran accounts can't either.
  - **Chat secrecy:** text and sender in `CHAT_MSG_CHANNEL` may be secret under chat lockdown (research Q3, Q4).
  - **`InChatMessagingLockdown`** does not exist on Forever (`warlock-utility-kit-v2/probe-results.md:5`).

## Desired End State
A standalone addon, for any class, with three parts.

**1. Ad log**
- Watches public channels (Trade, General, LookingForGroup, Services or TradeLocal if present) plus SAY, YELL and WHISPER.
- Classifies each ad by keyword into one of these categories:
  - A profession: Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, First Aid, Jewelcrafting if present.
  - Summon.
  - Portal, tagged by destination if parsed.
  - Other services (lockpicking, buffs) as "Other".
- Records the advertiser, category, the last ad text (truncated) and a timestamp.
- Persists the record per realm, so you can whisper the advertiser later.

**2. Card**
- Your own card holds:
  - Your professions with skill levels.
  - Your services (summon, which portals or teleports).
  - A status per entry: available, busy or off, plus one global status.
- Cards are exchanged silently over addon messages:
  - On request by whisper to strangers.
  - By broadcast to your guild on login and when your status changes.
- Opening someone's card can fetch their full recipe list for one profession on demand.

**3. Window**
- One movable window with two tabs:
  - **Seen**: the ad log. Category filter tabs, sorted by most recent. Each row shows name, category, age, status from the card if known, and an addon icon if they run BusinessCard.
  - **My card**: status toggles and a preview of your own card.
- Row actions:
  - Click whispers the person (opens a chat edit box with `/w name`).
  - Shift-click opens their card detail with the recipe list.
  - Right-click removes the row.

**Verify by:**
- Unit tests (`tests/run.lua`) for:
  - The classifier.
  - The encode/decode round trip.
  - Chunk reassembly.
  - Pruning.
- An in-game probe (slice 0) confirming the risky APIs before building on them.
- A two-account in-game test:
  - Card exchange over guild.
  - Card exchange over a whisper to a stranger.
  - A recipe fetch.
  - A status change propagating.
  - A trial account degrading cleanly.

## Patterns to Follow
- **Addon skeleton:** use the four-file split (`Core.lua`, `Logic.lua`, `Panel.lua`, `Settings`) as in WUK, WCK, TackleBox and ProfessionPlanner.
  - Pure functions go in `Logic.lua` so `tests/run.lua` can load them outside the client.
  - Init lives in `ADDON_LOADED` / `PLAYER_LOGIN` `inits` lists (WUK `Core.lua:147-152`).
- **Event helper:** copy the single-frame `X.On` (`WarlockUtilityKit/Core.lua:10-17`) and `X.Secret` (`Core.lua:7`). Repo convention is to copy these helpers, never share them (`GH-23-warlock-combat-kit/design.md:138`).
- **SavedVariables:** `BusinessCardDB` (account) and `BusinessCardCharDB` (character) with `MergeDefaults` (WUK `Core.lua:25-27`).
  - Must not error if the data resets (ForeverSVFix rule, `2026-10-19-warlock-utility-kit/design.md:108`).
- **Chat intake:**
  - Secret-guard text and sender, then `Ambiguate`, then skip self (`Summon.lua:59-61`).
  - Match whole tokens with `gmatch("%w+")` and a set lookup (`Logic.lua:42-46`). This keeps "portal" from matching "port" by accident; the classifier uses its own word sets per category.
- **Whisper send:** `(C_ChatInfo.SendChatMessage or SendChatMessage)(msg,"WHISPER",nil,to)` (`Trade.lua:7`).
- **Comm queue:**
  - Copy the ticker, queue, `result == 0 or true` check and exponential backoff (`Comm.lua:10-22`).
  - Extend it with a per-message channel and target, and with a one-time warning on failure (`Comm.lua:19`).
- **Wire format:** pipe-delimited, version first, `-` for nil, a per-kind field count in `Decode` (`Logic.lua:117-139`).
- **List UI:**
  - Fixed row pool shown with `SetShown` (`TackleBox/Panel.lua:113-138`). Tabs act as filters (`TackleBox/Panel.lua:142-176`).
  - Window template and drag from `WarlockUtilityKit/Board.lua:97-101`, with `UISpecialFrames` so Esc closes it.
  - Lock and reset slash commands as in `WarlockUtilityKit/Core.lua:231-232`.
- **Recipe scan:**
  - Model on `ProfessionPlanner/Core.lua:27-86`: the `IsTradeSkillReady` guard, the filter by `GetProfessionInfoByRecipeID`, and the empty-scan retry.
  - Store **IDs only**, not schematics.
- **Do NOT follow:**
  - The PP profession whitelist (`ProfessionPlanner/Logic.lua:12`). Read the profession from the API instead.
  - Wiping the WUK queue when there is no channel (`Comm.lua:13`). Whisper and guild targets differ per message.
  - The `InChatMessagingLockdown` assumption (`warlock-utility-kit/research.md:101`). Rely only on `issecretvalue`.

## Design Decisions
1. **Scope: full business card** (user choice). The ad log, cards and status all ship.
   - The ad log overlaps Trade Hall and SBB, which is accepted.
   - Its difference is that it persists across sessions and joins each advertiser to their card and status.
2. **Transport: whisper on demand plus guild broadcast** (user choice).
   - **GUILD:** broadcast your card (`C`) on login and on any status change, throttled to at most once every 10 s.
   - **WHISPER, to strangers:**
     - Send a card request (`Q`) to an advertiser the first time they are seen this session.
     - Send one when you shift-click a row.
     - The reply is their `C`.
     - Requests are paced at 1 per second through the queue and capped at once per name per session.
   - **Received cards** are cached on the Seen row by name, along with the card's `rev`.
3. **Card payload: professions, skill, services and status; recipes on request** (user choice).
   - **`C` (one message, ≤255 bytes):** `1|C|rev|gstatus|profs|svcs`
     - `profs` is `profID:skill:status,...`.
     - `svcs` is `S:status` for summon, and `P<dest>:status,...` for portals.
   - **`RQ` (recipe request):** `1|RQ|profID`.
   - **`RL` (recipe list chunk):** `1|RL|profID|seq|total|id,id,...`.
     - Recipe IDs are written in base 36.
     - Each chunk holds at most about 200 bytes of IDs.
     - The receiver reassembles by `sender+profID` and drops a partial set after 30 s.
4. **Recipe source:**
   - The card's professions and skill come from `GetProfessions`/`GetProfessionInfo`, which need no open window.
   - The recipe list comes from the last open-window scan, cached in CharDB as `recipes[profID] = {ids...}`.
   - If no cache exists, `RL` returns `total=0` and the detail view says "they haven't opened that profession yet".
5. **Services detection:**
   - Summon means Ritual of Summoning is known.
   - Portals and teleports mean the corresponding mage spells are known.
   - Spells are resolved by name, through `C_Spell.GetSpellInfo(name)` and then the player's spellbook, because the Forever spell IDs are unverified (research Q7). The slice-0 probe confirms the IDs, which then get hardcoded.
6. **Status model:**
   - Each profession or service carries `available`, `busy` or `off`. A global `busy` overrides all entries.
   - A status is set manually in the My card tab or with `/bcard busy|avail`.
   - No automatic status, and no auto-reply.
7. **Ad log persistence:**
   - `BusinessCardDB.seen[realm][name] = {cats={cat=lastSeen}, text, at, card}`.
   - Entries are pruned after 7 days without a new ad (a configurable setting).
   - The list is capped at 500 names, dropping the oldest first.
   - Pruning runs at login and on window open, never in combat (as at `Summon.lua:39`).
8. **Ad classifier:**
   - Keyword sets per category live in `Logic.lua` and are tested.
   - A request signal ("LF", "LFW", "WTB", "need") marks an ad as a request. Otherwise it is an offer.
   - The window shows offers by default, with a toggle to show requests.
   - Profession item and spell links in the text count as matches. Their IDs are extracted with the `|H(%a+):(%d+)` pattern.
9. **Channel selection:**
   - Channels are matched by `channelBaseName` (research Q3), never by number.
   - The default set is Trade, General, LookingForGroup, Services, TradeLocal, SAY, YELL and WHISPER. Each can be toggled in the settings.
10. **Degradation:**
    - **Secret text or sender:** the ad is ignored. The Seen list simply misses it.
    - **Send failure (trial, Veteran, lockdown):** print one warning, then disable outgoing comms for the session. The ad log and received cards keep working.
    - **Instances:** no outgoing card requests inside instances, to avoid the whisper throttle and lockdown.
11. **Standalone addon** (user choice): new folder `BusinessCard/`, interface 16001, with no dependency on the other addons.
    - Packaging follows the existing `.github/workflows/package-*.yml` pattern.

## What We're NOT Doing
- No posting to Trade, General or other public channels. `SendChatMessage` to a channel needs a hardware event (research Q3), and auto-advertising invites reports.
- No auto-reply to whispers, and no auto-invite or trade automation.
- No market prices, crafting-order queue or mats sourcing. Those are PRD Idea 5, a separate addon.
- No GuildStock integration and no shared inventory.
- No cross-realm or Battle.net transport. Same and connected realms only.
- No recipe source or learnability data, and no seed data from ProfessionPlanner.
- No minimap button in v1, only the slash command and a keybind.
- No custom public addon channel. It was rejected as too noisy and throttled.
- No sharing of the cached ad log between players. Only cards are exchanged.

## Open Risks
- **Chat secrecy (highest risk).** If `CHAT_MSG_CHANNEL` text or sender is secret in open-world Trade on Forever, the ad log is dead. Slice 0 probes this first, in a city.
- **Whisper addon messages to strangers.** Untested on Forever. If they fail with an unguilded target, card exchange drops to guild only. This is probed in slice 0, with two accounts.
- **Veteran-account restriction.** Many Forever players may be on Veteran accounts. Received cards still work, and that is the fallback.
- **Channel names.** Forever's Services/TradeLocal channel names are unknown. Slice 0 dumps `channelBaseName` values.
- **Spell IDs** for the ritual and the portals on Forever are unverified (research Q7). Name lookup is the fallback.
- **Classifier noise.** Phrasing is unknown (research Q7). The plan is to log raw ads in debug mode and tune the keyword sets after launch.
- **Burst on a busy Trade channel:** many new advertisers at once means many whisper `Q`s. The 1/s pacing, once-per-session cap and queue cap of 64 bound this.
- **Recipe IDs for LW/Alchemy** are unprobed (`profession-leveling-planner/probe-results.md:25`). This doesn't matter much, since only IDs are relayed and the receiver resolves names with `C_TradeSkillUI.GetRecipeInfo`. Whether that works for unknown recipes is a probe item.
