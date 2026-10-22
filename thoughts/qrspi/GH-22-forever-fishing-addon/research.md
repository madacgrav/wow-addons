# Research Findings

Paths are relative to the repo root. PP means `ProfessionPlanner/` and WUK means `WarlockUtilityKit/`. Prior survey means `thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/research.md`, abbreviated `gaps/research.md`.

## Q1: How does an addon in this repo go from load to visible UI, and how are tests and packaging done?

### Findings

**TOC**
- PP: `ProfessionPlanner.toc:1-13`.
  - `## Interface: 16001`, Version 0.2.1, IconTexture.
  - SavedVariables `ProfessionPlannerDB`, SavedVariablesPerCharacter `ProfessionPlannerCharDB`.
  - OptionalDeps: Auctionator, QuestieDB.
  - File order (`:10-13`): Data, Logic, Core, Panel.
- WUK: `WarlockUtilityKit.toc:1-18`.
  - Interface 16001, Version 0.3.0.
  - SavedVariables `WarlockUtilityKitDB` / `WarlockUtilityKitCharDB`.
  - File order (`:9-18`): Logic, Core, UI, Prep, Summon, Trade, Comm, Board, Dock, Settings.
- Every file opens with `local ADDON, X = ...`. The private namespace table is the only thing shared across files (`Core.lua:1` in both).

**Core/Logic split**
- `Logic.lua` holds pure functions on the namespace table:
  - PP: `MergeDefaults` at `PP/Logic.lua:3-10`, plus Plan, NextBracket, ShoppingList and FormatMoney.
  - WUK: `MergeDefaults` at `WUK/Logic.lua:16`, plus ClassifyItem, FormatTime, and queue/summon helpers.
- Logic uses no WoW API. `PP/Logic.lua:165` keeps `FormatMoney` pure so it does not need `GetCoinTextureString`.
- PP `Data.lua` is generated and sets `PP.SEED` (`Data.lua:1-3`). It loads before Logic.
- `Core.lua` holds the WoW glue: the event frame, ADDON_LOADED / PLAYER_LOGIN handling, scans and the slash command.
- UI files hook in with `table.insert(X.inits, fn)` and `table.insert(X.refreshers, fn)`.

**Event dispatch (same pattern in both)**
- `X.inits, X.refreshers = {}, {}` (`PP/Core.lua:3`, `WUK/Core.lua:3`).
- `X.On(event, fn)` appends to `handlers[event]`. It registers the event on one hidden frame the first time the event is seen. The OnEvent handler loops over the handlers. See `PP/Core.lua:7-12` and `WUK/Core.lua:10-17`.
- `X.Refresh` runs every refresher.
  - PP: `PP/Core.lua:14`.
  - WUK: `WUK/Core.lua:137-141`. It returns early unless `WUK.active`, and rescans bags first.

**ADDON_LOADED**
- On ADDON_LOADED, `MergeDefaults(Global, defaults)` runs. The comment says this is nil-safe: "the Forever beta loader bug can leave these nil". See `PP/Core.lua:16-22` and `WUK/Core.lua:19-28`.
- `MergeDefaults` behaviour (`PP/Logic.lua:3-10`):
  - non-table input becomes `{}`
  - nested tables are merged recursively
  - scalars are filled only when nil
- PP defaults:
  - account: `{thresholds={}, prices={}, panelOpen=false}`
  - character: `{recipes={}, bank={}, skill={}}`
- WUK defaults:
  - account (`WUK/Core.lua:19`): `{locked, shown, frames={}, icons={}, minimapAngle=220, dockViewers, spin, collapse}`
  - character (`WUK/Core.lua:20`): `{pet="imp"}`

**PLAYER_LOGIN**
- PP (`PP/Core.lua:23`): runs `PP.inits`. These register the later events:
  - the Auctionator hook (`PP/Core.lua:176-179`)
  - bank, merchant and bag events (`PP/Core.lua:181-187`)
  - TRADE_SKILL_* events (`PP/Core.lua:189-194`)
- WUK (`WUK/Core.lua:143-150`): if the class is not WARLOCK, it returns and builds no UI. Otherwise it:
  - sets `WUK.active`
  - calls `ScanSpells`
  - runs the inits
  - calls Refresh

**Visible UI**
- PP builds its frames lazily on the first Refresh after TRADE_SKILL_SHOW (`PP/Core.lua:190-191`, `Panel.lua:5-6`, `Panel.lua:49-69`).
- WUK's inits build the frames directly, for example `WUKStrip` at `UI.lua:112`.

**Slash commands**
- PP `/pp` (`PP/Core.lua:273-299`):
  - lowercases the input and matches the first word
  - `probe` saves its output to `ProfessionPlannerDB.lastProbe` (`:197`)
  - also has `debug`
- WUK `/wuk` (`WUK/Core.lua:221-243`):
  - subcommands: show, hide, lock, reset, pet, config, probe, board, lead, dock, spin, collapse
  - several are blocked in combat
  - the Settings UI calls `SlashCmdList.WARLOCKUTILITYKIT` (`Settings.lua:6`)

**Tests**
- Location and runtime: `*/tests/run.lua`, run with plain `lua5.1`.
- How code is loaded:
  - The addon dir is derived from `arg[0]` (line 1).
  - `loadfile(dir.."/Logic.lua")("<Addon>", {})` passes the varargs by hand (PP `tests/run.lua:2-3`, WUK `tests/run.lua:2-3`).
  - PP also loads `Data.lua` the same way (`PP/tests/run.lua:65`).
- What is not covered:
  - No WoW globals are stubbed.
  - Core and the UI files are never loaded.
- Assertions:
  - A local `eq(got, want, label)` raises an error on mismatch.
  - Each run ends with "all tests passed" (PP `:107`, WUK `:98`).
  - Tests are grouped under "Phase N" comments.

**Packaging** (`.github/workflows/package-pp.yml`, `package-wuk.yml`)
- Trigger:
  - push to `main` with paths filter `<Addon>/**` plus the workflow file (`:3-7`)
  - `workflow_dispatch`
- Steps:
  1. Run the tests with lua5.1 (`:18-21`).
  2. Get the version with `sed` from TOC `## Version`. The step fails if it is empty (`package-pp.yml:26`).
  3. Zip with `zip -r <Addon>-<ver>.zip <Addon>` (`:31`):
     - PP excludes `tests/*` and `tools/*`
     - WUK excludes `tests/*`
- Release:
  - Tags are `pp-v<ver>` / `wuk-v<ver>`.
  - The workflow creates the tag itself with `gh release create --generate-notes`.
  - If the release already exists, it runs `gh release upload --clobber` instead (`:38-39`).

**Docs**
- Root `README.md` is one line, `# wow-addons`.
- Each addon has its own `README.md`. Sections: Install, feature sections, Slash commands, Notes, Development.
- Each addon has its own `CHANGELOG.md`:
  - entries look like `## [X.Y.Z] — YYYY-MM-DD`
  - sub-headings are `### Added` / `### Changed`
  - bullets start with bold lead-ins
- PP's `README.md:106-115` documents three things:
  - CI publishes on push
  - a version bump cuts a release
  - `Data.lua` is generated

## Q2: How do the addons read player state and refresh it? Which calls worked or misbehaved on Forever?

### Findings

**Auras**
- Only WUK reads auras.
- `WUK.ReadPlayerBuffs` (`WUK/Core.lua:95-104`):
  - loops `C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")` for i = 1..40, stopping at the first nil
  - keeps `a.name` only when it is not secret
- `Secret(v)` = `issecretvalue ~= nil and issecretvalue(v)` (`WUK/Core.lua:7`, copied at `PP/Core.lua:4`). It is applied to:
  - pet family (`:109`)
  - unit names (`:122`)
  - cast target and spellID (`:158`, `:161`)
  - chat text (`Summon.lua:59`)
  - `UnitInRange` (`Summon.lua:30`)
- Probe-only reads (`WUK/Core.lua:170-219`):
  - `C_Secrets.GetSpellAuraSecrecy`
  - `C_CooldownViewer`
  - `GetUnitAuras("target","HARMFUL|PLAYER")`, wrapped in pcall
  - `GetAuraDuration`

**Professions**
- `PP.ScanProfession` (`PP/Core.lua:27-89`) needs `C_TradeSkillUI.IsTradeSkillReady()`.
- It reads `GetBaseProfessionInfo()` (professionID, skillLevel, maxSkillLevel) into `PP.char.skill[prof]` (`:33`).
- It then walks `GetAllRecipeIDs`, `GetRecipeInfo`, `GetRecipeSchematic`, `GetRecipeRequirements` (pcall) and `GetRecipeSourceText`.
- Skill is read only while the tradeskill window is open. `GetProfessions` and `GetSkillLineInfo` are not called anywhere.
- WUK reads the spellbook via `C_SpellBook.GetNumSpellBookSkillLines`, with a `GetNumSpellTabs` fallback (`WUK/Core.lua:64-85`).

**Bags and bank**
- WUK `ScanBags` (`WUK/Core.lua:30-44`):
  - covers bags 0..`NUM_BAG_SLOTS or 4`
  - reads `C_Container.GetContainerItemInfo`
  - classifies items by name
- PP `ScanContainers` (`PP/Core.lua:91-99`) builds an itemID→count table.
  - `PP.Have` (`:101-105`) covers bags 0..`Enum.BagIndex.ReagentBag` plus the saved bank.
  - `ScanBank` (`:108-116`) runs only while the bank is open:
    - loops `Enum.BagIndex["CharacterBankTab_"..i]` for i = 1..9
    - persists the result to `PP.char.bank`
- `C_Item.GetItemCount` is used only in the probe (`PP/Core.lua:231`).

**Zone**
- `GetRealZoneText()` is used at `PP/Core.lua:156` and `WUK/Summon.lua:25`.
- `C_Map.GetAreaInfo` is used at `PP/Core.lua:144`.
- `GetSubZoneText` and `ZONE_CHANGED*` events are not used anywhere. The zone is read at refresh time.

**Refresh triggers**
- WUK events: BAG_UPDATE_DELAYED, PLAYER_REGEN_ENABLED, SPELLS_CHANGED, UNIT_AURA (player only), UNIT_PET and UNIT_SPELLCAST_SENT (`WUK/Core.lua:151-157`).
- WUK has no debounce. It runs tickers:
  - `C_Timer.NewTicker(1)` (`Prep.lua:48`)
  - `C_Timer.NewTicker(0.25)` (`Comm.lua:28`)
- PP events: BANKFRAME_*, PLAYERBANKSLOTS_CHANGED, BAG_UPDATE_DELAYED, MERCHANT_SHOW and TRADE_SKILL_* (`PP/Core.lua:182-193`).
- PP `Rerender` debounces with a pending flag plus `C_Timer.After(0.1)` (`Panel.lua:136-137`).
- PP `ScanProfession` retries `After(0.5)` up to 5 times (`PP/Core.lua:78-83`).

**Probe evidence for Forever**
- Worked (`2026-10-19-profession-leveling-planner/probe-results.md`):
  - `maxTrivialLevel` is populated (l.30).
  - Profession IDs confirmed: Tailoring 197, Enchanting 333, Cooking 185 (l.4). LW 165 and Alch 171 are not probed (l.26).
  - `GetItemCount(2996)` bags/bank 25/25 (l.14).
  - `CharacterBankTab_1`=6, 48 slots after the bank is opened, persisting after close (l.34).
  - `ReagentBag`=5 (l.35).
  - `C_Item.GetItemCount(id, true)` counts the bank (l.36).
- Unexpected (`2026-10-20-profession-planner-seed-data-auctionator/probe-results.md`):
  - Unlearned recipes give no learnability signal: `sourceType` = nil, `GetRecipeSourceText` = nil, `disabled` = false for all 431 (l.12-17).
  - `GetRecipeRequirements` returns crafting stations, not learn requirements (l.20).
  - `CharacterBankTab_1` reports 0 slots if the bank has not been opened this session (l.8).
- Secret or blocked (`2026-10-19-warlock-utility-kit-v2/probe-results.md`):
  - `C_ChatInfo.InChatMessagingLockdown` does not exist (l.5).
  - Every probed spell has aura secrecy 2 ("ContextuallySecret") (l.6-8).
  - In combat, `GetUnitAuras("target","HARMFUL|PLAYER")` errors with "Auras cannot be accessed when secret while tainted" (l.14, 24, 28).
  - `C_CooldownViewer` categories are readable in combat (l.18).
- No probe covers player-buff reads, `GetRealZoneText` or `UnitInRange` secrecy.

## Q3: How do the addons construct UI, handle combat lockdown and persist positions? What is reused vs duplicated?

### Findings

**Frames and rows**
- WUK `WUKStrip` (`UI.lua:112-152`):
  - five `SecureActionButtonTemplate` buttons (`type=macro`, `UI.lua:128-133`)
  - round mask via `Disc()` (`:53-59`)
  - glow and pulse animation groups (`:96-110`)
  - `LayoutRing` (`:33-50`)
  - a self-removing `OnUpdate` animator (`:68-85`)
- WUK Summon panel (`Summon.lua:66-94`):
  - `BackdropTemplate` with 10 secure rows
  - `macrotext1` is set in `UpdateSummonRows` (`:38-56`)
  - right-click is handled via `HookScript("OnClick")` (`:80-82`)
- WUK Board: draggable, and added to `UISpecialFrames` (`Board.lua:100-101`).
- PP `PPPanel` (`Panel.lua:5-37`):
  - `BasicFrameTemplateWithInset`, parented to `ProfessionsFrame` at TOPRIGHT x+60
  - 16 pre-built rows (icon, text, sub, highlight)
  - `RenderPanel(view)` shows or hides rows from a `{header, rows}` view and sets the height to `74+n*30` (`:74-94`)
  - rows react to `OnMouseUp`
- PP toggle tab `PPToggleTab` (`Panel.lua:41-69`): anchored under `ProfessionsFrame.rightProfessionTabs`.
- PP has no secure buttons. It calls `C_TradeSkillUI.CraftRecipe` from a click handler (`PP/Core.lua:163-174`).

**Minimap and settings (WUK only)**
- Minimap button (`Settings.lua:73-110`):
  - built by hand on `Minimap`, with no LibDBIcon
  - position from `minimapAngle`, using cos/sin at radius `Minimap:GetWidth()/2+8`
  - dragged via `OnUpdate` plus `GetCursorPosition`
  - left-click opens settings, right-click opens the board
- `WUKSettings` (`Settings.lua:18-71`):
  - `BasicFrameTemplateWithInset`
  - `UICheckButtonTemplate` through a `Check()` helper
  - `WowStyle1DropdownTemplate` with `SetupMenu` / `CreateRadio`
  - every control routes through `Run()`, which calls the slash command (`:6`)
  - `Sync` runs on OnShow
- PP has no minimap button and no settings window.

**Combat lockdown**
- WUK checks `InCombatLockdown()` at:
  - `UI.lua:16`, `UI.lua:35`, `UI.lua:69`, `UI.lua:84`, `UI.lua:166`
  - `Prep.lua:18`, `Prep.lua:38`
  - `Summon.lua:39`
  - `Dock.lua:7`
  - `Core.lua:225`, `Core.lua:236`, `Core.lua:241`
- No queue exists. `PLAYER_REGEN_ENABLED` triggers `WUK.Refresh` (`Core.lua:152`), which re-applies everything. `Summon.lua:63` comments on this.
- `PLAYER_REGEN_DISABLED` triggers `WUK.CombatFreeze` (`UI.lua:87-93,151`).
- Glow changes touch textures only, so they are allowed in combat (`UI.lua:95`).
- PP has no combat handling.

**Edit Mode**
- `WUK/Dock.lua` re-anchors `EssentialCooldownViewer` and `BuffIconCooldownViewer` under the strip.
- Triggers for re-applying:
  - `hooksecurefunc(v,"SetPoint")` → `C_Timer.After(0, ApplyDock)`, with an `applying` guard
  - `EDIT_MODE_LAYOUTS_UPDATED` (`Dock.lua:23`)
- Turning the dock off asks the user to `/reload` (`Core.lua:239`).

**Position persistence**
- `WUK.MakeMovable(f, key, x, y)` (`UI.lua:13-26`):
  - shift+drag, only while unlocked and out of combat
  - saves `{point, relPoint, x, y}` to `db.frames[key]`
  - used by the strip and the summon panel
  - `/wuk reset` wipes the saved positions
- Settings and Board windows are movable but their positions are not saved.
- PP's panel follows `ProfessionsFrame`. Only `panelOpen` is persisted (`Panel.lua:10,54`).

**Reuse**
- No shared library exists between the two addons.
- Copied with near-identical code:
  - `Secret`, `Print` and the `On` dispatcher (`WUK/Core.lua:7-17`, `PP/Core.lua:4-12`)
  - `inits`/`refreshers`
  - `MergeDefaults`
  - nil-safe ADDON_LOADED
  - `Probe` + `P()` (`WUK/Core.lua:170`, `PP/Core.lua:197`)
  - `BasicFrameTemplateWithInset` + `GameFontHighlight` title
  - GameTooltip OnEnter/`GameTooltip_Hide`
  - `ponytail:` comments
- Shared within one addon only:
  - WUK via `WUK.*`: `MakeMovable`, `AddGlow`/`SetAlert`, `GroupUnits`
  - PP via `PP.*`: `Have`, `AHPrice`, `VendorFor`

## Q4: What does the prior survey record about Forever fishing mechanics?

### Findings

All mechanics below come from third-party beta guides. No primary-source spell, item or quest IDs were found (`gaps/research.md:68,79,165`).

**Rack, Hut and camp**
- Campsite Fishing Rack / Fishing Hut give buffs that allow Uncommon/Rare catches (`gaps/research.md:75,158`).
- Bait and Tackle is the camp crafting menu.
- Fish Bowl gives a Kings-equivalent buff.
- Unlock skills conflict between sources: Rack ~140, Hut 300. UNVERIFIED (`:75,165`).
- No IDs or per-fact URL are recorded.
- Addons already covering camps:
  - FishFry Campsite Assist, 38 items (`:16`)
  - Forever Fishing camp crafting (`:18`)
  - Luredon camp timer (`:25`)

**Fish tiers and Chef's Knife**
- Uncommon and Rare fish are new in Forever. A Chef's Knife exists for "Unique Fish" (`:75`).
- No IDs, numbers or drop rates are recorded.
- Catch tables and pool contents were not found (`:79,165`).
- No addon covers this (`:161`).

**Legacy talents**
- They sit in an account-wide Professions tree (`:76`):
  - Luremaster: extra fish with a lure. The "50%" figure is UNVERIFIED.
  - Working Overtime: no effect recorded.
  - Dedicated Study: no effect recorded.
- Point costs were not found (`:165`).
- No addon covers them (`:159`).

**STV tournament**
- Multiple winners are possible (`:77`).
- Rewards: Arcanite pole and the Extravagant Extravaganza Coin, which is exchanged for rewards.
- "First 50" winners is UNVERIFIED.
- No schedule is recorded.
- Timers in other addons:
  - Luredon has a camp + STV timer (`:25,60,160`).
  - FishingKit has an STV timer, but only on Era (`:56`).
- Classic schedule from the web (Q5 agent): Sundays; SoD uses Sunday and Wednesday. Start is keyed to time zone, not realm time, and DST is not accounted for. UNVERIFIED for Forever.
  - https://warcraft.wiki.gg/wiki/Stranglethorn_Fishing_Extravaganza

**Artisan quest fish**
- Requirements: level 35, Fishing 225, a Nat Pagle quest in Dustwallow (`:70`).
- Fish: Feralas Ahi, Misty Reed Mahi Mahi, Sar'theris Striker, Savage Coast Blue Sailfin.
- No quest or item IDs recorded.
- Source: wow-professions.com/forever/fishing-leveling-guide.
- Fishing Buddy stores a `quest` flag per fish (`:46`).

**Water-walking**
- Surfer Shoes and Draught of Waterwalking (`:74`). No IDs, durations or sources recorded.

**Other recorded mechanics**
- Rank requirements (`:69-70`):
  - Journeyman: Fishing 50 / level 10
  - Expert: level 20 / Fishing 125 / Old Man Heming
- Fishing is dragged from the Professions window (`:69`).
- Skill cap appears to be 300 (`:78`).
- Get-away chance and zone bands (`:71-72`).
- Lure values (`:73`; warcrafttavern.com/forever/guides/fishing), Classic values:
  - Shiny Bauble +25
  - Nightcrawlers +50
  - Aquadynamic Fish Lens +50
  - Bright Baubles +75
  - Flesh Eating Worm +75
  - Aquadynamic Fish Attractor +100
- Lure durations are 10 min (Attractor 5 min). The exact durations are open (`:165`).
- Pole bonuses (`:74`): Strong +5, Blump +3, Big Iron +20, FC-5000 +25, Arcanite +35.
- Gear bonuses (`:74`): Hat +5, Boots +5, Eternium Line +5, glove enchant +2.

**API facts recorded by the prior survey**
- Fishing spell is 7620, read via `C_Spell.GetSpellName`, with 131474 as the fallback (`:113-114`). BetterFishing's TOC placeholders push it onto the retail path (`:113`).
- Lunker buff is 392270 (`:114`).
- `IsFishingLoot` conflicts between sources (`:92,167`):
  - the wiki lists it for 1.60.1
  - the FB fork's comment says it was removed
- Soft-target CVars are undocumented (`:103-104`):
  - BetterFishing sets `SoftTargetInteract=3`, `SoftTargetInteractRange=60`
  - range is reported too short on Forever (`:62,122`)
- No bite event is exposed to addons (`:105`).
- `WOW_PROJECT_ID = 18` (`:130`).
- "Midnight disarmament" is active in Forever (`:84-89`).

## Q5: Which client APIs and events expose fishing-related state on Mainline 12.x / Forever, and where are restrictions documented?

### Findings

All pages below list Forever 1.60.1. The wiki shows build 69913.

**Skill rank**
- `C_TradeSkillUI.GetProfessionInfoBySkillLineID(id)`:
  - returns ProfessionInfo: `profession` (`Enum.Profession.Fishing=10`), skillLevel, maxSkillLevel, skillModifier
  - predicate `AllowedWhenUntainted`
  - no secret predicate
  - https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI.GetProfessionInfoBySkillLineID
- `GetProfessions()` returns `prof1, prof2, archaeology, fishing, cooking`.
- `GetProfessionInfo(i)` returns name, icon, skillLevel, maxSkillLevel, …, skillLine, skillModifier.
  - https://warcraft.wiki.gg/wiki/API_GetProfessionInfo
- Fishing SkillLine is 356 in Forever data (Q6).
- Whether Classic skill lines populate these structs on Forever is unverified.

**Loot**
- `IsFishingLoot()` returns a boolean. No predicates; Forever is listed.
  - https://warcraft.wiki.gg/wiki/API_IsFishingLoot
  - This conflicts with the FB-fork comment (Q4).
- `LOOT_READY(autoloot)`:
  - SynchronousEvent
  - loot functions stay valid until LOOT_CLOSED
  - https://warcraft.wiki.gg/wiki/LOOT_READY
- `GetLootSlotInfo(slot)`:
  - returns icon, name, quantity, currencyID, quality, locked, isQuestItem, questID, isActive, isCoin
  - no secret predicates
  - https://warcraft.wiki.gg/wiki/API_GetLootSlotInfo
- `GetLootSlotLink` and `LOOT_OPENED` were not fetched.

**Channel**
- `UNIT_SPELLCAST_CHANNEL_START(unitTarget, castGUID, spellID, castBarID)`:
  - tagged `SecretWhenUnitSpellCastRestricted`, which applies to units other than the player or pet
  - the page gives no per-field secrecy for the player
  - https://warcraft.wiki.gg/wiki/UNIT_SPELLCAST_CHANNEL_START

**Auras**
- `C_UnitAuras.GetPlayerAuraBySpellID(id)`:
  - returns AuraData?
  - `RequiresNonSecretAura`, `SecretWhenUnitAuraRestricted`
  - https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetPlayerAuraBySpellID
- `C_UnitAuras.GetAuraDataBySpellName(unit, name, filter)`:
  - Forever intro 1.60.1
  - https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataBySpellName
- The two pages disagree on the taint predicate: `AllowedWhenTainted` vs `AllowedWhenUntainted`. Not cross-checked against Blizzard docs.
- Aura restrictions are listed for combat, encounter, M+ and PvP contexts only (Secret values article).
  - Forever-specific: WUK probe found secrecy=2 for every spell (Q2).

**Time and calendar**
- `GetServerTime()` returns Unix time.
- `C_DateAndTime.GetServerTimeLocal()` returns Unix time offset by the server timezone.
- `C_DateAndTime.GetCurrentCalendarTime()` returns realm time {monthDay, month, weekday, year, hour, minute}.
- `GetGameTime()` returns realm hour and minute.
- None of the time APIs have secret predicates.
  - https://warcraft.wiki.gg/wiki/API_C_DateAndTime.GetCurrentCalendarTime
- `C_Calendar.GetHolidayInfo(monthOffset 0|1, day, i)`:
  - returns {name, description, texture, startTime, endTime}
  - `MayReturnNothing`
  - https://warcraft.wiki.gg/wiki/API_C_Calendar.GetHolidayInfo
- Whether the STV tournament appears in the Forever calendar: NOT FOUND.
- The repo uses none of these time or calendar APIs (locator).

**Account progression**
- `GetAchievementCriteriaInfo[ByID]` returns 13 values: completed, quantity, reqQuantity, … No predicates.
  - https://warcraft.wiki.gg/wiki/API_GetAchievementCriteriaInfo
- Whether Forever has account-wide achievements, and any API for Legacy profession talents (C_Traits or other): NOT FOUND.

**Items**
- `C_Item.GetItemCount(item, includeBank, includeUses, includeReagentBank, includeAccountBank)`:
  - predicate `AllowedWhenUntainted`
  - https://warcraft.wiki.gg/wiki/API_C_Item.GetItemCount
- Reagent bank / account bank on Forever is unverified. PP probe: `ReagentBag`=5 exists (Q2).

**Restriction docs**
- https://warcraft.wiki.gg/wiki/Secret_values
- https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
- https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes
- Rule: tainted code may store and pass secrets, but arithmetic, comparison, length or indexing on one raises an error.
- Predicates:
  - SecretWhenInCombat
  - SecretWhenUnitAuraRestricted / SecretWhenAurasRestricted (12.1.0)
  - SecretWhenUnitSpellCastRestricted
  - SecretOnRestrictedMaps (12.0.5)
  - SecretWhenCooldownsRestricted
  - SecretInActivePvPMatch
  - SecretInChatMessagingLockdown
- Namespaces: `C_Secrets` (`GetSpellAuraSecrecy`, `ShouldSpellAuraBeSecret`, …) and `C_RestrictedActions` (`ADDON_RESTRICTION_STATE_CHANGED`).
- Of the APIs above, only the aura APIs and the cast event carry secret predicates.

## Q6: How is static game data produced for this repo, and which DB2 tables hold fishing-relevant data for Forever?

### Findings

**Generator**
- Script: `PP/tools/gen_seed.py`.
- Invocation: `python -I ProfessionPlanner/tools/gen_seed.py 1.60.1.70450 ProfessionPlanner/Data.lua` (docstring `:1-2`).
- Build is `sys.argv[1]` (`:68`).
- Fetch (`:8-12`):
  - URL: `https://wago.tools/db2/{name}/csv?build={build}`
  - a custom User-Agent is required, because the default one gets a 403 (`:10`)
  - parsed with `csv.DictReader`
- Tables read:
  - SkillLineAbility (`:17`)
  - SpellReagents (`:22`)
  - SpellEffect, `Effect==24` (`:27`)
  - ItemEffect, `TriggerType==6` (`:31`)
  - ItemXItemEffect (`:33`)
  - ItemSparse: RequiredSkill, RequiredSkillRank, BuyPrice (`:37`)
- Profession SkillLines are hard-coded as `{"197","333","165","171"}` (`:5`). These must match `PP.PROFESSIONS`.
- Output (`:50-64`), LF line endings:
  - header `-- Generated by tools/gen_seed.py from Forever build … Do not edit.`
  - then `local ADDON, PP = ...`
  - then `PP.SEED = { build=, recipes={[spell]={prof,yellow,green,grey,reagents,item,learnAt,taughtBy}}, price={} }`
  - this matches `Data.lua:1-4`
- CI zip excludes `tools/` (Q1).

**wago.tools tables confirmed for build 1.60.1.70450**
- ItemSparse:
  - has `OverallQualityID`, `RequiredSkill(Rank)`, `RequiredLevel`, `StartQuestID`, `SellPrice`, `Display_lang`, `Description_lang`
  - about 5.3 MB
- Item: `ID, ClassID, SubclassID`, … (17 columns).
- SkillLine:
  - First Aid 129, Cooking 185, Fishing 356
  - "Test Profession" children 2939/2942/2943 (parent 185/129/356, ParentTierIndex 4)
- SkillLineAbility: `SkillLine, Spell, MinSkillLineRank, TrivialSkillLineRankHigh/Low, NumSkillUps`, …
- SpellName: `ID, Name_lang` only.
- SpellMisc: `DurationIndex, CastingTimeIndex, SpellIconFileDataID, SpellID`, …
- AreaTable: zone hierarchy (`ParentAreaID`, `AreaName_lang`). No fishing-skill column.
- QuestV2: `ID, UniqueBitFlag, UiQuestDetailsThemeID` only. No names or objectives.
- QuestLine / QuestLineXQuest: questline names and ordered quest IDs.
- TraitTree:
  - 17 rows
  - `TraitTreeID` 0 and empty titles
  - examples: ID 1058 (system 0) and ID 1066 (system 10)
- TraitNode: rows exist (e.g. `103884,1058,…`).

**Tables that returned HTTP 400**
- `QuestObjective` and `ZoneFishing`. Whether that means the table is absent from the build or the name is unknown is undetermined.
- `FishingLoot` was not tested.

**Builds**
- Product code: none needed. `?build=1.60.1.70450` alone works.
- The wago builds list is JS-rendered and was not read.
- Other builds seen:
  - 70374 (CurseForge)
  - 69913 and 70291 (wiki)
- Column suffixes such as `Field_5_5_4_67090_*` and `Field_11_1_0_58221_*` show Forever data shares newer Classic/Mainline schemas.
- Fish item IDs, fishing quest IDs and fishing spell IDs were not enumerated. Only table headers were checked.

## Cross-Cutting Observations
- **Two-layer addon layout.** Both addons separate pure Lua in `Logic.lua` (and `Data.lua`), which is unit-tested under lua5.1 with no stubs, from WoW glue in `Core.lua` and the UI files, which are untested.
  - Core files hook in through `inits`, `refreshers` and `On()`.
- **Copied conventions.** `Secret()`, `On()`, nil-safe `MergeDefaults`, `/x probe` and `ponytail:` comments are copied per addon. No shared lib exists.
- **Probes before code.** Each prior run used an in-game `/x probe` that writes to SavedVariables, recorded in `probe-results.md`.
  - Forever repeatedly differed from the wiki: missing `InChatMessagingLockdown`, no recipe source data, aura secrecy erroring rather than returning secrets.
- **Wiki availability vs in-game behaviour.** The wiki marks APIs as present on 1.60.1 but does not show runtime behaviour. Probes found differences more than once.
- **Data pinned to one build.** Static data comes from wago.tools CSV pinned to build `1.60.1.70450`, generated offline, and ships as `Data.lua`.
- **Unverified fishing facts.** Forever-specific fishing mechanics (Rack/Hut, fish tiers, Legacy talents, tournament) exist only in third-party beta guides, with no IDs.

## Open Areas
- Forever IDs for:
  - fishing spells, Rack/Hut buffs and items
  - Uncommon/Rare/Unique fish and the Chef's Knife
  - Surfer Shoes / Draught of Waterwalking
  - Artisan quest and fish items
  - tournament coin and vendor
  - None were enumerated from DB2.
- `IsFishingLoot` existence on Forever: the wiki and the FB fork conflict.
- Taint predicate of the aura-by-spell APIs: the two wiki pages disagree.
- Player-buff read secrecy out of combat on Forever: not probed.
- STV tournament:
  - schedule on Forever
  - whether it appears in `C_Calendar`
- Legacy (account) profession talents: no API found. TraitTree rows exist but are untitled.
- Forever bank types: whether reagent bank and account bank exist.
- `QuestObjective` / `ZoneFishing` / `FishingLoot` availability on wago for this build.
- Pool and zone catch tables: not found from any source.
