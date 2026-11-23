# Research Findings

Refs: `Panel.lua` etc. are under `TackleBox/` unless prefixed. `idx` = `D:\Source\wowskill\skills\wow-forever-addon\references\forever-api-index.md`; `notes` = `forever-api-notes.md` in same folder. Web facts labelled **verified / reported / unverified** for Forever.

## Q1: How is the TackleBox panel built, and how does it compare to repo conventions and `widgets.md`?

### Findings
- **Constants** `Panel.lua:3-4`: WIDTH 320, ROW_W 296, TOP 146, TAB_H 34, HEAD 100, VISIBLE 10, LIST_W 276.
- **Theme** `TB.THEME` `Panel.lua:8-11` (RGBA): sea {.02,.09,.14,.94}, shallows {.08,.32,.45}, rope {.72,.58,.36}, sand {.95,.85,.6}, foam {.75,.9,1}, line {.15,.55,.8}.
- **Dock** `Panel.lua:18-26`: 1x1 movable `TBDock` on UIParent, position from `TB.db.frames.dock` else TOPLEFT/CENTER 140,150. `TB.DockDrag` `:29-40` Shift-drag, blocked when locked or in combat; saves `{p,rp,x,y}`.
- **Skin** `TB.Skin(f, edge)` `:43-48`: tooltip background + `UI-Tooltip-Border`, edgeSize default 16, insets 4, no tile, backdrop = sea, border = rope. Used by CastBar with edge 12 (`CastBar.lua:8`).
- **Fade** `:51-54`: white color texture + vertical `SetGradient`.
- **Build** `:56-135` (lazy, first `RenderPanel`): `TBPanel` BackdropTemplate, strata MEDIUM, width 320, anchored to dock.
  - Bottom glow BACKGROUND, h90, shallows fade (`:63-65`).
  - Close `UIPanelCloseButton` TOPRIGHT 2,2, hook sets `db.shown=false` (`:67-69`).
  - Portrait holder 62x62: 40x40 `Trade_Fishing` masked with `TempPortraitAlphaMask`, 106x106 `MiniMap-TrackingBorder` ring (`:72-80`; numbers are minimap button 31/20/53 x2).
  - Title `GameFontNormalLarge` "TackleBox" sand at 62,-14 (`:82-84`); random quip `GameFontDisableSmall` foam .7 from QUIPS (`:13-14,85-88`), re-rolled OnShow (`:134`).
  - Skill StatusBar h14 at 12,-58, `UI-StatusBar` texture, line colour, bg black .55, centered `GameFontHighlightSmall` text (`:91-96,103`).
  - "got away: N" text + 16px `INV_Misc_Fish_02` icon at -12,-65 (`:99-102,213`).
  - Expand toggle 16x16 at -12,-86 using `UI-MinusButton-Up`/`UI-PlusButton-Up` (`:106-113,219-220`).
  - Zone line at 12,-86 (`:115-117`); 1px rope .5 rule at y -138 (`:119-122`).
  - `UIPanelScrollFrameTemplate` scroll at 12,-146, 276 wide (`:129-133`); scrollbar shown only if rows > 10 (`:250`).
- **Rows** `GetRow` `:137-164`: pooled 276x24, pitch 26; 20px icon (texcoord .07-.93), text + sub line, 70x4 progress StatusBar, foam .08 highlight, alternating stripe (1,1,1,.03) (`:237`), item tooltip ANCHOR_LEFT. Greys {.6,.6,.6} for empty (`:233`); done colour (.25,.75,.25) at `:242` and `Logic.lua:38`.
- **Tabs** custom Buttons, no PanelTemplates. `MakeTab` `:166-184`: width `(296-(n-1)*4)/n`, h30 at y -100; Fade bg, 16px icon, label, count badge, 2px rope underline, foam .12 highlight; click sets `TB.db.tab` + `TB.Refresh`. `RenderTabs` `:187-200`: active = saturated icon, sand label, stronger fade, underline; inactive desaturated .6 alpha, grey label. Strip shown only when `db.expanded` (`:222`).
- **Sections**: `TB.sections` entries `{key,title,tab,icon,empty,build}` registered in order quest, where, camp, water, catch (`Panel.lua:257-316`). Refresher `:317-329` builds all (badges), picks via `TB.TabRows(secs, TB.db.tab)` (`Logic.lua:24-30`, falls back to first, inserts placeholder row when empty). Persistence: `TB.db.tab`, default `"where"` (`Core.lua:17`).
- **RenderPanel** `:203-255`: height expanded = TOP+10+vis*26 (vis = clamp(n,3,10)), collapsed = HEAD 100; scroll resets on tab change (`:251`).
- **Minimap button** `TBMinimapButton` `:331-368`: 31x31 on Minimap, strata MEDIUM level 8, `UI-Minimap-ZoomButton-Highlight`, 20px icon, 53px tracking border; angle `db.minimapAngle`, radius `Minimap:GetWidth()/2+8`; drag via unthrottled OnUpdate atan2; left = toggle panel, right = print skill; tooltip hint `:364`.
- **CastBar** `CastBar.lua:7-51`: `TBCastBar` 220x24 skinned edge 12, gradient bar, masked bobber at fill edge, anchored under panel (`:42`) else CENTER 0,-180 (`:44`); `TBFlash` fullscreen `LowHealth` texture, blue ADD pulse (`:25-33`).
- **Comparison**
  - BusinessCard tabs: `PanelTabButtonTemplate` + `PanelTemplates_TabResize/SetNumTabs/SetTab`, bottom-anchored (`BusinessCard/Panel.lua:42,113-124,156`); detail tabs in `BusinessCard/Card.lua:182-211`. TackleBox: top strip, custom buttons with icon+badge.
  - BusinessCard skin: `BC.Skin(f, kind, bg)` with dialog (Rock bg, DialogBox border, 24, inset 6) and tooltip (WHITE8x8, 12, inset 3) presets, tiled, gold border (`BusinessCard/Skin.lua:4-16`); title font MORPHEUS with fallback (`Skin.lua:96-97`). Close button at -4,-4 (`BusinessCard/Panel.lua:108`) vs TackleBox 2,2.
  - Minimap buttons in `WarlockCombatKit/Settings.lua:255-275` and `WarlockUtilityKit/Settings.lua:85-105` are line-for-line the same layout and drag code as TackleBox; only name, icon, db differ. `BusinessCard/Card.lua:27-33` reuses the 31/20/53 ratios for a portrait.
  - `widgets.md`: BackdropTemplate required for SetBackdrop (`:13`); lists templates BackdropTemplate/UIPanelButtonTemplate/UICheckButtonTemplate/SecureActionButtonTemplate (`:13`), fonts GameFontNormal/Highlight/NormalLarge/Disable (`:25`), draw layers (`:26`). No coverage of PanelTemplates tabs, minimap buttons, scroll templates, or skin helpers.
- **Observed literals**: QUIPS, "got away: " (`:213`), tooltip strings (`:110,364`), item IDs 279965/279966 (`:282`), FLAG_COLORS/ICONS (`:274-275`); y offsets -58/-65/-86/-100/-138 hand-placed vs TOP 146; 26 pitch repeated (`:140,248-249,253`); `3*26` initial scroll (`:130`); tab y -100 equals HEAD literal (`:169`); grey .6 not in THEME (`:195,233,327`); highlight alpha .08 rows vs .12 tabs; content padding 12, rule 10, glow 4, close 2.

## Q2: Data flow from `Data.lua` through `Logic.lua`/`Core.lua` into `TB.RenderPanel`; provenance rules

### Findings
- **Stored data** `Data.lua:3-50` (header `:2`: every ID must trace to `probe-results.md`):
  - `fishingSpells` 7620/7731/7732/18248 (`:6`); `castSeconds` 30 (`:7`).
  - `questFish` 4 Artisan fish with zone (`:9-14`).
  - `zones` 6 groups `{band,max,noLoss?,cast?,lure?,names[]}`, enUS names matched to `GetRealZoneText` (`:17-26`).
  - `lures` 6 `{id,name,bonus,req}` (`:28-36`); `fish = {}` empty, "Phase 3" (`:37`).
  - `campBuffs` Rack 1280341 / Hut 1280342 (`:39-42`, aura mapping unverified `:38`); `waterWalk` items/levels/auras (`:44-49`).
  - No coordinates, sub-zones, pool/object data, or per-zone fish lists anywhere in the addon. No `C_Map`, `C_Minimap`, tracking, or object code (only Minimap use is the button).
- **Zone read**: `GetRealZoneText()` in Where build (`Panel.lua:277`) and refresher (`:326`); catch zone string "Zone - SubZone" (`Core.lua:152-153`); `GetSubZoneText()` for camp rows (`Panel.lua:285`). Only `ZONE_CHANGED_NEW_AREA` registered, not `ZONE_CHANGED`/`ZONE_CHANGED_INDOORS` (`Core.lua:52-66`).
- **Skill read** `TB.ReadSkill` `Core.lua:29-39`: `GetProfessions()` 4th return, then `GetProfessionInfo` returns 3, 4, 8 = level, max, modifier; fallback `C_TradeSkillUI.GetProfessionInfoBySkillLineID(356)`. Effective = level+modifier, computed in `ZoneRow` (`Logic.lua:57`).
- **Refresh** `TB.Refresh` 0.1s debounce (`Core.lua:42-50`), triggers on login, skill, regen, bags, bank, zone, inventory, aura (`Core.lua:52-66,77`); runs every `TB.refreshers` entry.
- **Per-tab rows**:
  - Quest: `TB.QuestRows` (`Logic.lua:33-42`), counts via `C_Item.GetItemCount(id, true)` (`Core.lua:86-90`).
  - Where: `TB.WhereRows` (`Logic.lua:64-77`) lists zone names whose band contains base level; appends current zone if outside; `ZoneRow` flags "too low"/"outgrown"/"here", sub "no get-aways at N" or "skill a-b" plus lure need (`Logic.lua:49-61`). Status colouring `TB.ZoneStatus` (`Logic.lua:80-89`).
  - Camp: `TB.CampRows` (`Logic.lua:152-164`) via `TB.ReadAura` (`Core.lua:69-76`, pcall `C_UnitAuras.GetPlayerAuraBySpellID`, cached in combat); 1s ticker while timers run (`Core.lua:79-83`).
  - Water: reads `TB.waterActive`/`TB.actions.water` from Actions (`Panel.lua:291-299`).
  - Catch: `TB.CollectionView(DATA.fish, char.catches, …)` (`Logic.lua:109-127`), tier from quality (`:107`); catches written on `LOOT_READY` when `IsFishingCatch` (`Logic.lua:91-94`) via `TB.RecordCatch` storing `{n, first, last, q, zones{}}` (`Logic.lua:98-105`, `Core.lua:145-161`). Tooltip shows top 3 zones (`Panel.lua:301-316`).
- **Provenance** `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md`: IDs from wago.tools DB2 build 1.60.1.70450 (`:58-60`); third-party guide data flagged; unverified mappings marked "needs in-game check" (`:107`). Zone bands came from third-party Forever guides (`Data.lua:15-16`, fishing-gaps `research.md:70-73`).
- **Probe results relevant here**: `IsFishingLoot` exists (`probe-results.md:10`); auras not secret out of combat (`:11`); channel 30000 ms, not secret (`:19-20`); `LOOT_READY` ~10 ms after channel stop (`:43`); loot-slot quality works (`:41,79-80`); Rack/Hut are game objects + area triggers (`:101`). **No probe of map position, `C_Map`, tracking, tooltips, or soft-interact.**
- fishing-gaps `research.md`: Fishing Buddy keys catches by `uiMapID*1000+subzoneIdx` (`:129`); FB-fork retail uses `C_Minimap` tracking texture 133888 (`:130`); pools identified only via localized tooltip text (`:35`); object GUID via `GetLootSourceInfo` (`:91`); soft-target CVars undocumented (`:103`); other addons claim map spots / school pins (`:25,26,31`) — listing claims only. Open areas `:163-169`.

## Q3: What fishing location data exists for Classic-era / Forever content, and where?

### Findings
- **Classic pool types** ([warcraft.wiki.gg Fishing Pool](https://warcraft.wiki.gg/wiki/Fishing_Pool), zones only, no coordinates/skill): Oily Blackmouth School (coastal: Arathi, Ashenvale, Azshara, Blasted Lands, Darkshore, Desolace, Hillsbrad, Swamp of Sorrows, Tanaris, Wetlands); Firefin Snapper School (coastal, "various"); Mixed Ocean School (STV); Stonescale Eel Swarm (Blasted Lands, Swamp, Tanaris, Thousand Needles); Sagefish School (Ashenvale, Duskwood, Silverpine, STV, Wetlands); Greater Sagefish School (E/W Plaguelands); School of Deviate Fish (N. Barrens); Floating Debris (Azshara, Darkshore, Duskwood, Barrens, Redridge, Silverpine, Westfall); Floating Wreckage / Bloodsail Wreckage (STV, Mithril Bound Trunk); Waterlogged Wreckage (Desolace, Dustwallow, Feralas, WPL); Schooner Wreckage (Ashenvale, Hillsbrad, Stonetalon, Wetlands). Page states pools never yield junk. No Lightning Eel pool; "Oil Spill"/"Patch of Elemental Water" not on page.
- **Per-zone catches** ([WarcraftTavern Classic loot list](https://warcrafttavern.com/wow-classic/guides/fishing-loot-list), ~86% read, no skill numbers): e.g. Darkshore Grouper; Deviate Fish (Barrens oasis); Oil Covered Fish (Sludge Fen, Windshear Crag); Firefin via Oil Spill (Stonetalon); quest fish strands (Sar'theris, Misty Reed, Verdantis River, Savage Coast); Lightning Eel and Plated Armorfish in high zones; Darkclaw Lobster (Azshara Bay of Storms). Winter Squid, Summer Bass, Redgill, Glossy Mightfish, Nightfin, Sunscale/Whitescale zones not confirmed from this source.
- **Skill thresholds** (Blizzard Watch, search summary only): Stonescale 205/300, Firefin 55/150, Oily Blackmouth 1/75; Stonescale best at night. [Fishing skill wiki](https://warcraft.wiki.gg/wiki/Fishing_skill): per-zone min-cast and 100%-catch caps exist; fresh vs salt water yield differs; no numbers.
- **Coordinates: none obtained.** Wowhead Classic/Forever object pages (e.g. `classic/object=180682`, `forever/object=180682`) returned "location unknown" to the fetcher (map is JS-rendered, so absence unconfirmed). wago.tools returned 403. Coordinate system of Wowhead (assumed zone-local 0-100) unverified.
- **Datasets**: MaNGOS/Trinity/AzerothCore schema has `gameobject` (map-local world x/y/z) + `pool_gameobject` ([AzerothCore wiki](https://www.azerothcore.org/wiki/pool_gameobject)) — verified schema, not zone percentages; vmangos (GPL-2.0) publishes a DB dump, spawn content unverified. Wowhead/wago terms not found; data-mining redistribution restrictions only secondhand ([Data mine](https://warcraft.wiki.gg/wiki/Data_mine)).
- **Forever-specific** (all **reported**, fan/news sites Oct–Nov 2026; [wiki.gg Forever fishing](https://warcraft.wiki.gg/wiki/Forever_fishing_techniques), [Gfinity](https://www.gfinityesports.com/article/world-of-warcraft-forever-fishing-guide-1-300-leveling-trainers), WarcraftTavern Forever):
  - Fishing 1-300; once at zone's required skill all catches succeed; some fish need >300 via poles/lures; 7 poles incl. new Ravaged Fishing Pole; 6 Classic lures kept; cooked foods give fishing skill; legacy perks.
  - Pools exist; Floating Wreckage may hold locked trunks.
  - Fishing Rack (140, Gelihast BFD) / Fishing Hut (300, Jammal'an ST) camp items; Gfinity lists other camp items (Fish Bowl 20, Simple Fish Drying Rack 50, Fisher's Bait Table 175, Grand Angler's Basin 300).
  - New zones: Zephras Isle, Valanaar, The Riverglades, Shen'Dralas, Mount Hyjal.
  - Gfinity tiers: 1-55 starters/capitals/Zephras Isle; 55-135 Westfall, Loch Modan, Darkshore, Barrens, Silverpine, Redridge; 135-205 Wetlands, Ashenvale, Hillsbrad, Stonetalon, Duskwood, Riverglades; 205-275 STV, Arathi, Desolace, Dustwallow, Feralas, Hinterlands, Shen'Dralas; 275-300+ Tanaris, Azshara, Felwood, Un'Goro, Winterspring, Plaguelands, Hyjal. Fish per tier listed (Smallfish/Mud Snapper → Catfish/Oily → Trout/Firefin → Redgill/Nightfin → Stonescale/Sunscale/Armorfish/Lobster).
  - These tiers differ from the bands in `Data.lua:18-26` (e.g. Darkshore 75-150 there vs 55-135; STV 150-225 vs 205-275; Gfinity includes Forever-only zones absent from Data.lua).
  - "Unique Fish" + Chef's Knife, new uncommon/rare fish (WarcraftTavern, unnamed).
  - No Forever pool coordinates or pool-to-zone mapping found. Unchecked sources: Icy Veins, Method, Mobalytics, wow-professions Forever fishing pages; "Forever Fishing" CurseForge addon.

## Q4: Which Forever APIs/frameworks draw markers on the world map and minimap?

### Findings
- **Present in idx**:
  - `C_Map` (`idx:721`): GetBestMapForUnit, GetPlayerMapPosition, GetMapInfo, GetMapInfoAtPosition, GetMapChildrenInfo, GetMapRectOnMap, GetMapWorldSize, GetWorldPosFromMapPos, GetMapPosFromWorldPos, SetUserWaypoint/ClearUserWaypoint/GetUserWaypoint/HasUserWaypoint/CanSetUserWaypointOnMap, OpenWorldMap, GetFallbackWorldMapID, …
  - `C_Minimap` (`idx:730`): GetUiMapID, GetViewRadius, IsRotateMinimapIgnored/SetIgnoreRotateMinimap, tracking functions, POI helpers.
  - `C_SuperTrack` (`idx:931`): SetSuperTrackedUserWaypoint, SetSuperTrackedMapPin, ClearAllSuperTracked, …
  - Globals (`idx:1060`): UnitPosition, GetPlayerFacing, GetMinimapZoneText; GetCVar (`idx:358`).
  - Related: C_VignetteInfo (`idx:1017`), C_MapExplorationInfo (`idx:724`).
  - Events: MINIMAP_UPDATE_TRACKING/ZOOM/PING (`idx:2083-2085`), PLAYER_MAP_CHANGED (`:2278`), NEW_WMO_CHUNK (`:2124`), USER_WAYPOINT_UPDATED (`:2787`), SUPER_TRACKING_CHANGED (`:2548`), WORLD_MAP_OPEN (`:2875`), ZONE_CHANGED* (`:2881-2883`).
- **Absent from idx/refs**: MapCanvasMixin, MapCanvasDataProviderMixin, MapCanvasPinMixin, WorldMapFrame, AddDataProvider, AcquirePin, `rotateMinimap` CVar, Minimap widget methods (index has no widget section; FrameXML globals only in lint std, `idx:1062`). None on never-emit list (`notes:49-67`). Secret-values caveat verified for unit health/power/aura only (`notes:41`, `taint-and-secure.md:10`); map/position scope unmapped.
- **Web**:
  - `C_Map.GetPlayerMapPosition` / `UnitPosition`: outdoors only, nil in instances; AllowedWhenUntainted (**reported**; [wiki](https://warcraft.wiki.gg/wiki/API_C_Map.GetPlayerMapPosition), [wiki](https://warcraft.wiki.gg/wiki/API_UnitPosition)).
  - **HereBeDragons-2.0** (MINOR 35; needs LibStub + CallbackHandler): has explicit Forever/Camelot flag, walks map tree from 947 for Classic/Forever; coordinate API (GetPlayerZonePosition, GetWorldCoordinatesFromZone, TranslateZoneCoordinates, GetZoneDistance, …); 1s polling in micro dungeons (**reported**, lib source).
  - **HereBeDragons-Pins-2.0** (MINOR 17): world map pins via a `MapCanvasDataProviderMixin` provider registered with `WorldMapFrame:AddDataProvider`, Lua-created frames in its own pin pool; minimap pins with floatOnEdge; handles `rotateMinimap` via GetCVar + GetPlayerFacing; uses `C_Minimap.GetViewRadius` when present (it is, `idx:730`); OnUpdate skipped when minimap hidden, full update ≤1/s (**reported**, lib source). License not found in files; size not obtained.
  - Taint from WorldMapFrame pins, Forever existence of MapCanvas mixins: **unverified** (Gethe `forever` UI source not fetched).

## Q5: Can an addon detect nearby game objects (e.g. pools) at runtime?

### Findings
- **No API found that lists nearby objects, exposes object coordinates, minimap blips, or fires "object appeared".** Detection paths found are all one object at a time, needing user interaction.
- **In idx**:
  - `UnitIsGameObject`, `UnitGUID`, `UnitName`, `UnitTokenFromGUID`, `GetMouseFoci` (`idx:1060`).
  - Events: `PLAYER_SOFT_INTERACT_CHANGED` (`idx:2294`), `UPDATE_MOUSEOVER_UNIT` (`:2770`), `CURSOR_CHANGED` (`:1585`), `UNIT_SPELLCAST_CHANNEL_*` (`:2723-2725`), `UNIT_SPELLCAST_SUCCEEDED` (`:2740`), `LOOT_OPENED/READY/CLOSED/SLOT_CLEARED` (`:2036-2049`).
  - `C_TooltipInfo.GetWorldLootObject`, `GetWorldCursor`, `GetMinimapMouseover` (`idx:963-964`).
  - `C_NamePlate.*` + `NAME_PLATE_UNIT_ADDED/REMOVED` (`idx:744-748, 2099-2102`); whether objects get plates: unknown.
  - `C_Minimap` tracking `GetNumTrackingTypes/GetTrackingInfo/SetTracking` (`idx:729-730`) — no blip-position reader.
  - `C_VignetteInfo` + `VIGNETTES_UPDATED`/`VIGNETTE_MINIMAP_UPDATED` (`idx:1017, 2805-2806`); whether pools are vignettes: unverified.
- **Not in idx but confirmed in-game**: `IsFishingLoot` (`probe-results.md:10`), loot slot info (`:41`). Not in idx: `GetLootSourceInfo`, `softinteract` token, SoftTarget CVar names.
- **Web**:
  - `softinteract` unit token covers "a game object like a mailbox or a gathering node", added 10.0.0 ([UnitId](https://warcraft.wiki.gg/wiki/UnitId); **reported**).
  - `PLAYER_SOFT_INTERACT_CHANGED(oldTarget, newTarget)`, SecretWhenUnitIdentityRestricted (**reported**).
  - `UnitIsGameObject` lists Forever 1.60.1 (**reported**). `C_TooltipInfo.GetWorldLootObject` lists Forever 1.60.1 (**reported**).
  - SoftTarget CVar behaviour/defaults: **unverified** (wiki 404).
  - **Find Fish**: from Weather-Beaten Journal in TBC (item 34109, spell 43308), not in vanilla (**reported**, forums/changelog); presence in Forever **unverified**; tracking blip data not exposed to addons (no source says otherwise).
  - **GatherMate2** `Collector.lua` ([source](https://raw.githubusercontent.com/Nevcairiel/GatherMate2/master/Collector.lua), Retail-family code): on `UNIT_SPELLCAST_SENT/STOP/FAILED/INTERRUPTED` + `CURSOR_CHANGED`, reads `GameTooltipTextLeft1:GetText()` (skips secret values), matches known node names, takes position from `HBD:GetPlayerZonePosition()`, offsets fishing nodes 15 yd along `GetPlayerFacing()`. Wowace comments (**reported**): addons only record *potential* spots; "no in game api to detect the node has spawned"; fishing node logging needs hovering the pool when casting.
- fishing-gaps `research.md:105`: "game doesn't report bites to addons"; `:91` pool GUID obtainable from `GetLootSourceInfo`.

## Q6: SavedVariables, events/load order, OnUpdate, and test harness

### Findings
- **TOC** `TackleBox.toc`: Interface 16001 (`:1`), Version 1.1.0 (`:4`), `SavedVariables: TackleBoxDB` (`:6`), `SavedVariablesPerCharacter: TackleBoxCharDB` (`:7`); load order Data, Logic, Core, Actions, Panel, CastBar (`:9-14`).
- **SV shape**: account `DEFAULTS = {locked, shown, frames={}, minimapAngle=200, tab="where", flash, expanded}` (`Core.lua:17`); char `{catches={}}` (`:18`). Runtime-only keys: `db.castKey`, `db.cvarBackup` (`Actions.lua:48-65`), `db.lastProbe` (`Core.lua:167`), `char.weapons` (`Actions.lua:155`). No version/schema field.
- **Merge**: on `ADDON_LOADED` (name match) `TB.MergeDefaults` both DBs, set `TB.db`/`TB.char` (`Core.lua:20-26`); MergeDefaults recursive, fills nil only (`Logic.lua:3-10`).
- **Events**: `TB.On` single frame, one handler table (`Core.lua:9-12`). `PLAYER_LOGIN` sets `TB.active`, runs `TB.inits` (1s ticker `Core.lua:79`, Actions `:76`, minimap button `Panel.lua:331`), then Refresh (`Core.lua:52-56`). Refreshers run in file order (Actions before Panel). `PLAYER_LOGOUT` restores CVars (`:61`).
- **OnUpdate**: CastBar per-frame while casting, unthrottled (`CastBar.lua:47-53`); minimap drag only while dragging (`Panel.lua:348-355`). Other timing via `C_Timer` (`Core.lua:45,80,134`).
- **Tests** `tests/run.lua`: plain `lua tests/run.lua`; loads only Data.lua + Logic.lua via `loadfile(...)("TackleBox", TB)` (`:1-4`); stubs no WoW globals (pure functions); `eq(got,want,label)` helper (`:6-8`); covers MergeDefaults, FormatTime, SkillText, TabRows, QuestRows, WhereRows (real DATA `:39`), ZoneStatus, IsFishingCatch, RecordCatch, CollectionView, TopZones, CastProgress, IsMiss, CampRows, WaterWalkPick, PickPole, PickLure, FindWeapon, WeaponsMacro, NormalizeKey; prints "all tests passed" (`:116`). No frame/panel render tests. The repo's other addons follow the same `tests/run.lua` convention.

## Cross-Cutting Observations
- Architecture split: pure logic in `Logic.lua` (unit-tested), WoW calls in `Core.lua`/`Actions.lua`, UI in `Panel.lua`; new tabs are entries in `TB.sections` with a `build` returning rows.
- Data rule: `Data.lua` IDs must trace to `probe-results.md`; third-party guide numbers allowed but flagged in comments.
- All five repo addons are lib-free and hand-roll minimap buttons with identical code; no world-map pins or LibStub anywhere.
- Zone identity throughout TackleBox is the enUS zone *name* string, not uiMapID.
- Position/map APIs, soft-interact, and tooltip-on-object paths have never been probed in Forever; existing probes cover skill, channel, loot, auras.

## Open Areas
- No pool spawn coordinates obtained for any version; Wowhead (JS) and wago.tools (403) not readable by fetcher. Forever pool placement vs Classic unknown.
- Whether MapCanvas mixins / `WorldMapFrame:AddDataProvider` exist and are taint-safe in Forever (Gethe `forever` source not checked).
- HereBeDragons license and size.
- Secret-value behaviour of `C_Map` position, tooltip text of objects, and soft-interact GUIDs in Forever.
- Whether Find Fish tracking exists in Forever; whether pools surface as vignettes or nameplates.
- Authoritative Forever per-zone skill bands (Gfinity tiers conflict with `Data.lua` bands).
