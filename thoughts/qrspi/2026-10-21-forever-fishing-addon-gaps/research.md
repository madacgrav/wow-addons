# Research Findings

Date: 2026-10-21 (last beta day; launch 2026-11-04). Sources are mostly external web pages; download counts and dates are as shown on the pages that day. "BF" = BetterFishing local copy at `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\BetterFishing\`. "FB-fork" = Fishing Buddy fork cloned to scratchpad (`https://github.com/Coffiner666/FishingBuddy`, commit 301524c). CurseForge shows Forever as game version **1.60.1**; few pages state interface 16001 explicitly.

## Q1: Which fishing addons are published for WoW Forever?

### Findings
About 18 Forever-flagged addons, nearly all on CurseForge, almost all first published Sep–Oct 2026. Ordered by downloads:

| Addon (author) | DL | Updated | Flavors | Headline features |
|---|---|---|---|---|
| BetterFishing (Yuyuli) — curseforge.com/wow/addons/better-fishing | 6.0M (all flavors; one snippet said 17.6M, unresolved) | 10-18, v12.1.5 | Retail, Forever, MoP, Titan, Classic | soft-target single key, optional double-right-click, Enhanced Sound, gamepad |
| Fishing Buddy (Crusade) — /fishing-buddy-crusade | 33.7K | 10-01, "Fishing Buddy Forever 1.0.7" | Era/TBC/WotLK + Forever | outfits, lures, Fish Watcher, skill display |
| Fishing Mode (ambits) — /fishing-mode | 28.8K | 10-05, v1.8.0 | Retail 12.x + Forever | interact-key fishing via soft-target, gear set "Fishing", volume overrides |
| CFC Classic Fishing Companion (Relyk22) — /classic-fishing-companion | 23.0K | 10-19 | Era, TBC, Forever | double-click, swap keybind, gear, lure, splash boost, logs, rare/milestone alerts |
| FishFry - Fishing Forever (GildedVellum) — /fishfry-forever | 16.6K, 67 comments | 10-20, 1.5.1-16001 | Forever + TBC | HUD, 1-300 guides + TomTom, Tackle Swap, cast timer, Cook Fish, Campsite Assist (38 items), journal, compat API |
| Easy Fishing (ItsZiliya) — /easy-fishing | 9.9K | 10-18, 2.7.6 | Retail, Forever, Classic, TBC | one key cast+loot, journal, auto pole/lure, gold/hr |
| Forever Fishing (Hamish336) — /forever-fishing | 8.4K, 56 comments | 10-20, 0.9.2 | Forever only | one-button, gear/lure swap+restore, stats/goals, AH value, cooking+camp queues, 22 achievements, 1-300 Field Guide, Fast Auto Loot. v0.9.0 reset settings once |
| The Fishing Log (Boomflex) — /the-fishing-log | 5.3K | 10-20, v0.11.1 | Forever | catch log, spot records, bounties, realm leaderboard, events/signups, lure timers. Latest file title says CurseForge "randomly rolled it back" |
| ForeverPlusPlus (fishing module) — /foreverplusplus | 3.5K | 10-15, 0.9.0 | Forever | double-click, right-click lure, map zone skill |
| ForeverArtisan — /foreverartisan, Wago, GitHub v0.9.28 | ~964 (snippet) | 10-18 | Forever | tradeskill suite; fishing: controller keys, reel-in bobber search, per-char settings, skill-based lure, counts catches under auto-loot |
| Forever Angler (arkiebarky) — /forever-angler | 295 | 10-13, 1.1.3 | Forever | F key cast/reel, auto-loot, tackle box, vendor lure restock, escape rate per zone |
| Modern Fishing (kalol4696) — /modern-fishing | 254 | 10-19, 0.10.45 | Forever | HUD, audio cues IN RANGE / TOO FAR / CAUGHT, profession-window dashboard |
| Munin.SimpleFishing (Irinn) — /munin-simplefishing | 190 | 10-20 | Retail+Forever | one key, soft-target reel, no UI |
| Luredon (DonCoohd) — /luredon | 188 | 10-10, v1.4.1-forever | Forever | colored bobber at cursor, louder splash, atlas, camp + STV contest timers, shared totals, 9 languages |
| WoW Smart Fishing (SH_SEO) — /wowsmartfishing | 92 | 10-21, 2.0.4-forever | Forever (16001) | map spots, zone catch chances (Classic 1.12 data; new Forever zones absent), party/guild sharing |
| EzFishing Forever — /ezfishing-forever | 75 | 10-11 | Forever | one key, sound preset, pole swap, zone hint (enUS only, classic values) |
| Cooking&Fishing Helper — /cooking-fishing-helper | 63 | 10-15 | Forever | one key, XP-food buff tracking |
| Angler (GrandmasterBrosko) — /angler | 48 | 10-14 | Forever | auto fishing mode, lure timer, school pins learned (~30 yd accuracy), leveling route on Classic zone levels |
| Fishing's Fun (phsh) — /fishings-fun | 41 | 10-13 | Forever | sessions, journal, fish-to-recipe lookup |
| Quick Fish (nemeyeth) — eu.forums.blizzard.com/en/wow/t/636280/1 | forum only | 10-17, v0.7.0 | Forever | alerts (low lures, bags full, bobber out of reach, no bite), map tint by skill, 35 milestones, import/export |

- Not Forever: original Fishing Buddy (Sutorix, 16.4M DL, last build 2024-12-28 for 11.0.7); "Fishing Buddy - 12.0.7" fan fork (retail); FishingKit - Classic, SimpleFishing, Angler's Atlas, Fishing Friend (Classic/TBC only); Avid Angler (retail 12.1.5).
- Unverified Forever status: Angleur (claimed in the `timemir/wow-fish` spec, not found on CurseForge), Tweaks Forever, Wanderer, EllesmereUI "Forever Essentials", Wago "quick-fishing"/"fishing-ace", Advanced Soft Target (Interact).
- Unpublished: `github.com/timemir/wow-fish` ("Pagle") spec, issue #1. It lists beta probe results: no fishing toys found, in-combat weapon swap failed, pools identifiable only by localized tooltip text, Forever loot data not yet observed.
- Agents disagreed on whether any Fishing Buddy fork exists for Forever. The Crusade listing page itself shows a Forever 1.0.7 file, so that is taken as true.
- Comment text could not be retrieved from any page; only counts.

## Q2: What do established Classic-era and retail fishing addons do?

### Findings
Feature matrix (Y = on the listing page; - = not listed, which may not mean absent):

| Addon | dbl-click | key cast | gear swap | auto lure | auto-loot | sound | bobber visual | catch stats | pools/map | skill+zone | event timer | rare alert | quest fish | toys/raft | Edit Mode |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Fishing Buddy | Y | - | Y (outfits) | Y | - | Y (in code) | - | Y | plugin | Y | - | - | Y (`quest` field, FishingDatabase.lua:333-373) | Y (Rafts plan) | - |
| BetterFishing | Y | Y | - | - | - | Y | - | - | - | - | - | - | - | - | - |
| CFC | Y | Y | Y | Y | - | Y | - | Y | - | Y | - | Y | - | - | - |
| Angler | Y | Y | - | Y | Y | Y | - | Y | Y | Y | - | - | - | - | - |
| Forever Angler | - | Y | Y | Y | Y | Y | - | Y | - | Y | - | - | - | - | - |
| Modern Fishing | - | Y | - | Y | - | Y | audio range cue | Y | - | Y | - | - | - | - | - |
| Luredon | Y | - | Y | Y | - | Y | Y | Y | - | Y | Y | - | - | - | - |
| The Fishing Log | Y | - | Y | Y | - | - | - | Y | - | - | Y | Y? | - | - | - |
| Smart Fishing | - | Y | Y | Y | - | - | - | Y | Y | Y | - | - | - | - | - |
| Quick Fish | Y | Y | Y | Y | Y | - | pools brighter | Y | Y | Y | - | Y | - | - | - |
| FishingKit - Classic (Era only) | Y | Y | Y | Y | - | Y | - | Y | Y | Y | Y (STV) | Y | - | - | - |
| Avid Angler (retail) | Y | Y | Y | Y | Y | - | - | Y | Y? | Y | - | - | - | Y | - |

- No listing mentions Edit Mode support. Quest-fish tracking is documented by none of the listing pages; only Fishing Buddy's data model stores a `quest` flag.
- Event timers exist only in Luredon (Forever fishing camp + STV contest), The Fishing Log (scheduled player events) and FishingKit (STV, Classic only).
- Not found anywhere: Fishing Ace!, Fish!/FishFinder, Fishing Coach, Fishing Assistant (Fishing Ace survives only as archived Ascension source, see Q5).
- BF page: soft-target range "too short for fishing range in Classic and Forever Beta".

## Q3: How does fishing work mechanically in Classic Era vs Forever?

### Findings
- Classic Era (warcraft.wiki.gg/wiki/Fishing, a hybrid retail/Classic page): skill 1-300. Each zone has a minimum skill to cast and a cap above which every catch lands; below the cap, fish "get away" with no skill-up (removed on retail in 3.1). Channel 30s, then 20s (2.1), then 17s (3.1); Era's value unverified.
- Forever (third-party beta guides):
  - Apprentice needs no level. Trainers are in every starting zone and capital. Fishing is not in the spellbook; you drag it from the Professions window (wow-professions.com/forever/how-to-fish).
  - Journeyman needs Fishing 50 and level 10. Expert needs level 20 and Fishing 125 (Old Man Heming, Booty Bay). Artisan needs level 35 and Fishing 225 (Nat Pagle quest, Dustwallow; quest fish Feralas Ahi, Misty Reed Mahi Mahi, Sar'theris Striker, Savage Coast Blue Sailfin) (wow-professions.com/forever/fishing-leveling-guide).
  - Get-away chance is still in. Starting zones stop losing fish at skill 25; capitals at 75. Redridge allows no catch below 55 and loses fish until 150. Feralas and the 225-300 zones need Bright Baubles.
  - Zone bands: 1-75 starting zones. 75-150 capitals, Barrens, Darkshore, Loch Modan, Silverpine, Westfall. 150-225 Dustwallow, Alterac, Arathi, Desolace, STV, Swamp of Sorrows, Thousand Needles. 225-300 Felwood, Feralas, Hinterlands, Tanaris, Un'Goro, WPL.
  - Lures use Classic values (warcrafttavern.com/forever/guides/fishing): Shiny Bauble +25, Nightcrawlers +50, Aquadynamic Fish Lens +50, Bright Baubles +75, Flesh Eating Worm +75, Aquadynamic Fish Attractor +100. Durations are 10 min (Attractor 5 min), one lure at a time (snippet). The wiki's +3/+5/+7/+9 figures are retail-scaled and do not apply.
  - Poles: Strong +5, Blump Family +3, Big Iron +20, Nat Pagle FC-5000 +25, Arcanite +35. Gear: Lucky Fishing Hat +5, Extreme Anglin' Boots +5, Eternium Line +5, glove enchant +2. Water-walking from Surfer Shoes and Draught of Waterwalking. Buff foods range from +3 to +18.
  - New in Forever: Uncommon and Rare fish; a Chef's Knife for "Unique Fish"; a "Bait and Tackle" crafting menu for camp items. Fish Bowl gives a Kings-equivalent buff. Fishing Rack and Fishing Hut give buffs that allow Uncommon/Rare catches. Unlock skills conflict between sources (Rack ~140; Hut 300).
  - Legacy talents (account-wide Professions tree): Working Overtime, Luremaster (extra fish with a lure; "50%" unverified), Dedicated Study.
  - The Stranglethorn tournament allows multiple winners. Rewards are the Arcanite pole and the Extravagant Extravaganza Coin, which exchanges for rewards ("first 50" is unverified).
  - The skill cap appears to still be 300.
- Not found for either version: per-zone catch tables, pool names and contents, fishing spell IDs from a primary source. Icy Veins and wowvendor Forever fishing guides returned 403.

## Q4: Client APIs and events for fishing on Mainline 12.x / Forever

### Findings
- Patch 1.60.1 API notes (warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes) contain only secret-value entries: Midnight disarmament is active in Forever (09-15), and `GetFrameStrata` returns a secret value (Beta 4, 10-08). Nothing fishing-specific. The full API diff was only partly read (100k of 263k chars). It lists `C_AutoLoot.SetUseAutoLootToggle`, `C_LootFrame.TryAutoLoot`, `UnitHasLootInteraction`, `UnitIsInInteractRange` and `C_Item.GetWeaponEnchantInfo`.
- Secret predicates (wiki/Secret_Values):
  - `SecretWhenUnitSpellCastRestricted` makes cast info secret for units other than the player or pet.
  - `SecretWhenInCombat` makes values secret during combat.
  - `AllowedWhenUntainted` accepts secret arguments only from untainted code.
- `UNIT_SPELLCAST_CHANNEL_START` payload: unitTarget, castGUID, spellID, castBarID. It is tagged SecretWhenUnitSpellCastRestricted, which should not cover the player per the rule above. Unverified for the event specifically. BF uses it on Forever (BetterFishing.lua:329-335).
- Loot:
  - `LOOT_OPENED` (autoLoot, isFromItem) fires after `LOOT_READY`.
  - `IsFishingLoot()` is listed for Forever 1.60.1 and Vanilla 1.15.9. FB-fork replaces it locally because "Modern WoW removed IsFishingLoot()" (FishingBuddy.lua:1806-1816), so Forever and retail 12.x differ here.
  - `GetLootSlotInfo` has no documented secret predicates. `GetLootSourceInfo` returns guid/qty; GameObject GUIDs are possible.
- Skill:
  - `GetProfessions()` returns `prof1, prof2, archaeology, fishing, cooking`.
  - `C_TradeSkillUI.GetProfessionInfoBySkillLineID` is listed for Forever. It returns skillLevel, maxSkillLevel and skillModifier; `Enum.Profession.Fishing = 10`.
- Casting:
  - `SetOverrideBindingClick(owner, isPriority, key, buttonName[, mouseClick])` is #nocombat, never saved, and listed for Forever.
  - Both BF and FB-fork use a `SecureActionButtonTemplate` button plus `SetOverrideBindingClick` on BUTTON2 (BF :90-119, :313; FB-fork LibFishing:2249-2287, :2360-2366).
  - `UseItemByName` is protected, deprecated in 10.2.6, with its fallback removed in 12.1.5; Forever status unknown.
  - `C_Item.EquipItemByName(itemInfo[, dstSlot])` is AllowedWhenUntainted and listed for Forever. Fishing Mode's page and the wow-fish spec both report that weapon swap fails in combat on Forever.
- Bobber:
  - Soft-target CVars are undocumented (wiki 404/502). BF sets `SoftTargetInteract=3`, `SoftTargetInteractArc=2`, `SoftTargetInteractRange=60` and the icon CVars during the channel (BetterFishing.lua:233-242). A Dragonflight-era forum thread used Range 30.
  - Several Forever addon pages report that range is limited, and the interact key can grab an NPC or player instead of the bobber (EzFishing, Fishing Mode, Angler).
  - EzFishing Forever states "game doesn't report bites to addons".
- Sound: `Sound_*` CVar docs could not be fetched. BF and FB-fork write `Sound_MasterVolume`, `Sound_SFXVolume`, `Sound_MusicVolume`, `Sound_EnableAmbience`/`AmbienceVolume`, `Sound_EnableAllSound`, `Sound_EnableSFX`, `Sound_EnableSoundWhenGameIsInBG` on Forever without guards (BF :16-25, :374-399).

## Q5: How do the most-used fishing addons implement their core features?

### Findings
BetterFishing (local, ~640 lines):
- TOC `## Interface: 11509, 16001, 20506, 38002, 50504, 120100, 120105` (BetterFishing.toc:1). SV `BetterFishingDB` (:6). Load order: Settings.lua, then BetterFishing.lua (:24-25).
- `## X-Family: [Family]` / `## X-Game: [Game]` (BetterFishing.toc:8-9) are unsubstituted packager placeholders in the installed copy. `SetGameInfo` (BetterFishing.lua:271-290) keys `isForever`/`isClassicEra` off them. With placeholders, both stay false, so the installed copy runs the retail path: `GetFishingID` returns 131474 (:65-75) and the pole-equipped check is skipped (:161-170).
- Keybind: `Bindings.xml:2-4` defines `BETTERFISHINGKEY`, which calls `BetterFishing_Run` (:133-143). That function calls `SetOverrideBindingSpell(secureButton, true, key, fishingName)` with name from `C_Spell.GetSpellName(7620)`, falling back to 131474 (:77-81). It exits early if in combat, flying, the loot window is open, or the Lunker buff 392270 is active.
- Double-click: `GLOBAL_MOUSE_DOWN` (:298-323) checks a window of 0.04s to `doubleClickSpeed` (default 0.2, Settings.lua:6) with a 0.5s debounce, then `SetOverrideBindingClick(btn,true,"BUTTON2","BetterFishingButton")`. If already fishing, it binds BUTTON2 to `INTERACTTARGET`, cleared on mouse up (:324-328).
- Secure button (:90-119): `SecureActionButtonTemplate`, type=spell. A `SecureHandlerWrapScript` PostClick clears bindings, keyed to the `ActionButtonUseKeyDown` CVar (:83-88, :349-351).
- `AllowFishing` (:172-196) blocks fishing while moving, mounted (unless forced), flying, falling, stealthed, swimming or in a vehicle. `IsFishing` reads `UnitChannelInfo` (:145-151). The flying check is guarded by `C_Secrets.ShouldSpellAuraBeSecret` (:121-131).
- Bobber: on channel start, BF sets the soft-interact CVars and rebinds its key to `INTERACTTARGET`; Alt recasts (:249-269, :336-340). It restores the CVars on channel stop or logout (:244-247, :346-347). A `hooksecurefunc(C_CVar,"SetCVar")` cache tracks external changes (:206-220).
- Sound: snapshots 8 CVars into an in-memory cache, mutes music/ambience/pets and raises SFX/master. Restores on channel stop or logout (:374-399). The snapshot is not persisted, so a crash mid-channel leaves the changed values in place.
- Not present: gear/lure swap, catch logging (no LOOT_* events), any stats UI.
- Settings: canvas layout category (Settings.lua:11-15), checkboxes plus two sliders (:34-124), `/bf` and `/betterfishing` (:129-132). The SV is flat with no versioning.
- CHANGELOG: v63 "Forver support", v62 double-click fix when ActionButtonUseKeyDown=false, v44 soft-target range limited on classic.

Fishing Buddy fork (FB-fork; TOC 120100/120105, v1.27.2; SV `FishingBuddy_Info`, per-char `FishingBuddy_Player`; core in `Libs/LibFishing-1.0/LibFishing-1.0.lua`, 3054 lines):
- Double-click: `GLOBAL_MOUSE_DOWN` (FishingBuddy.lua:568) calls `FL:CheckForDoubleClick` (LibFishing:1717-1735, window 0.05-0.4s), then `CentralCasting` (FishingBuddy.lua:1462-1489). The mouse button is configurable (LibFishing:2289-2306).
- Lures: `PLANS:ExecutePlans()`, then `FL:InvokeLuring` with secure `type=item`, `target-slot=INVSLOT_FISHING_TOOL` (28, hardcoded LibFishing:979) or `type=toy` (:2386-2408). Lure presence comes from `GetWeaponEnchantInfo()` (FishingBuddy.lua:1404). Plan modules: `FishingPlans/` Lures, Baits, Bobbers, Pets, Rafts, Coins, Items.
- Outfits: Blizzard Equipment Manager via `C_EquipmentSet.*` / `EquipmentManager_EquipSet` (FishingGearManager.lua:11-40, :138-222). `LastGearSet` is stored for restore.
- Sound: `FBI:EnhanceFishingSounds` (FishingBuddy.lua:1741-1793) adjusts per-CVar settings, plus `graphicsParticleDensity` to make pools easier to see. The snapshot is persisted as `FishingBuddy_Player["ResetEnhance"]` for restore at next login. It also toggles `autoInteract` (:1543-1584).
- Catch log: `LOOT_READY` (:1861-1925) iterates loot slots. Data shape (FishingDatabase.lua): packed key `uiMapID*1000+subzoneIdx`; `SubZones`, `FishTotals[packed]`, `FishingHoles[packed][itemID]=qty`; `Fishies[itemID]={[locale]=name, texture, quality, quest, skill, ...}` (:233-450).
- Flavor split: `IsClassic = not IsRetail` via `WOW_PROJECT_ID` (LibFishing:39-56). Forever reports `WOW_PROJECT_ID = 18` (wow-fish spec), so it would take the "classic" branch. That branch finds the fishing spell by scanning spell IDs for the icon string "Interface\\Icons\\Trade_Fishing" (:192-212). The retail branch uses `GetProfessions`, slot 28 for pole/lure and `C_Minimap` tracking texture 133888 (:1606-1622).
- Older lineage: vanilla FB (github.com/aim2kill/FishingBuddy, Interface 11000) hooks `WorldFrame` OnMouseDown and uses `GetSkillLineInfo`, `UseContainerItem` + `PickupInventoryItem` for lures and nested-by-name SV. Fishing Ace (github.com/ThatGuyJon/FishingAce-Ascension, Ace2, 30300, archived) uses a secure CheckButton plus a `WorldFrame` hook and `GetTrackingTexture`. None of these Classic-only APIs exist on Mainline 12.x.

## Q6: What do players say they want from fishing addons on Forever?

### Findings
- Direct player text was not retrievable: CurseForge comment bodies would not load, Reddit was blocked, and no Wowhead threads were found. Everything below is inferred from author-documented limits and feature convergence, not player quotes.
- Friction that authors report on Forever:
  - Soft-target range is too short for far bobbers (BF page).
  - The interact key can grab an NPC, player or current target instead of the bobber (EzFishing, Fishing Mode, Angler).
  - There is no bite event, so addons compensate with splash-boost sound presets (Forever Angler, Angler, EzFishing, Luredon, Modern Fishing).
  - Weapons cannot be swapped in combat, so if you are attacked while fishing you must re-equip by hand from a backup set (Fishing Mode, wow-fish spec).
  - Built-in zone data is Classic 1.12 or enUS-only and misses new Forever fish and zones (Smart Fishing, EzFishing, Angler).
- Features that converge across the ~18 Forever addons: one-key cast/reel, lure automation and timers, 1-300 guides, AH-value stats, cooking and camp tie-ins, controller support (Forever Fishing, ForeverArtisan, BF), catch sharing and leaderboards (Fishing Log, Luredon, Smart Fishing).
- Policy: many pages state "not a bot". Every cast and hook needs player input under Midnight rules (icy-veins.com/wow-forever/news/addons-in-wow-forever-blizzard-devs-just-addressed-the-big-question/).

## Cross-Cutting Observations
- The Forever field is crowded but young. One established multi-flavor addon (BF) adds Forever as a flavor, and Fishing Buddy survives as the Crusade fork. About 15 new Forever-first addons each have 41 to 16.6K downloads and were updated within the past two weeks.
- Two mechanisms dominate core casting:
  - Double-right-click: a `SecureActionButtonTemplate` button plus `SetOverrideBindingClick(BUTTON2)`.
  - One key: `SetOverrideBindingSpell`, then `INTERACTTARGET` with the soft-interact CVars.
  - Both depend on soft-target behavior, whose CVars and range are undocumented on Forever.
- Flavor detection is fragile on Forever:
  - BF keys off TOC metadata that ships unsubstituted.
  - FB-fork keys off `WOW_PROJECT_ID` (18 on Forever), which routes it to a Classic branch.
  - Zone and skill data in several addons is Classic 1.12 or enUS-only.
- Restoring sound and CVar state differs: BF keeps it in memory only, while FB-fork persists it to SV and restores next login.
- Forever-specific content is covered by few addons:
  - Campsites, Fishing Rack/Hut, Uncommon/Rare fish: FishFry Campsite Assist, Forever Fishing camp crafting.
  - Legacy fishing talents: none found.
  - STV tournament: Luredon timer only.
  - Chef's Knife / Unique Fish: none found.

## Open Areas
- CurseForge comment bodies, Reddit and Wowhead player threads (Q6 is inference-only).
- Forever catch tables, pool names, exact lure durations, Fishing Rack/Hut unlock skills, Legacy point costs, fishing spell IDs from a primary source.
- SoftTarget* and Sound_* CVar docs and their Forever behavior (default range, max range).
- Whether `UNIT_SPELLCAST_CHANNEL_STOP` and loot APIs are ever secret-gated on Forever; `IsFishingLoot` presence conflicts between the wiki (listed for Forever) and the FB-fork comment (removed in modern WoW).
- Whether the BF CurseForge Forever file has the `X-Family`/`X-Game` placeholders substituted (only the installed copy was read).
- Angleur, Wago-only listings, and WoWInterface Forever builds were not verified. Angler (GrandmasterBrosko) source was not read.
