# Research Findings

Paths are relative to `D:\Source\wow-addons\` unless noted. `AH-ADDON\` = `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\Auctionator\` (locally installed copy, version 340). wago.tools data pulled 2026-10-20 into the session scratchpad.

## Q1: How PP.ScanProfession reads and stores recipes, and how it flows into Plan/ShoppingList

### Findings
- Triggers: `TRADE_SKILL_SHOW` and `TRADE_SKILL_LIST_UPDATE` call `PP.ScanProfession()` then `PP.Refresh()` (`ProfessionPlanner/Core.lua:124-129`). Registered inside a `PP.inits` function that runs on `PLAYER_LOGIN` (`Core.lua:23`). `TRADE_SKILL_CLOSE` only clears `PP.current` (`Core.lua:128`).
- Guards: returns if `C_TradeSkillUI.IsTradeSkillReady()` is false (`Core.lua:28`). Profession from `C_TradeSkillUI.GetBaseProfessionInfo().professionID` (`Core.lua:29-30`). Only IDs in `PP.PROFESSIONS = {[197]=Tailoring,[333]=Enchanting,[165]=Leatherworking,[171]=Alchemy}` are scanned (`Logic.lua:12`, `Core.lua:31`).
- Skill: `PP.char.skill[prof] = {skill=info.skillLevel, max=info.maxSkillLevel}` (`Core.lua:33`).
- Loop over `C_TradeSkillUI.GetAllRecipeIDs()` (`Core.lua:37`):
  - `GetRecipeInfo(id)` (`:38`).
  - Profession filter via `GetProfessionInfoByRecipeID(id)`, matching `professionID` or `parentProfessionID` (`:40-41`).
  - Keeps only `ri.learned` recipes (`:42`).
- Record build (first time only; reused from previous scan otherwise, `Core.lua:43-56`):
  - `GetRecipeSchematic(id, false)` gives `qtyMin = sch.quantityMin` (`:48`).
  - For each `reagentSlotSchematics` slot where `reagentType == BASIC` (`Enum.CraftingReagentType.Basic` or 1, `:25`), stores the first reagent option: `{itemID = slot.reagents[1].itemID, qty = slot.quantityRequired}` (`:49-53`).
- Every scan updates (`Core.lua:57-62`): `learned = true`, `color = PP.COLOR[ri.relativeDifficulty] or "grey"`, `maxTrivial = ri.maxTrivialLevel`.
- Stored shape, `ProfessionPlannerCharDB.recipes[professionID][recipeID]`:
  `{ name, icon, qtyMin, reagents = { {itemID, qty}, ... }, learned = true, color, maxTrivial }`.
  - Key is the recipeID from `GetAllRecipeIDs` (same as the crafting spellID; e.g. 3755 = Linen Bag per wago SpellName).
  - Output itemID is not stored or referenced anywhere in ProfessionPlanner.
  - Unlearned recipes are never stored.
- Empty result (profession-switch race) retries via `C_Timer.After(0.5)` up to 5 times without overwriting (`Core.lua:67-73`). Otherwise the per-profession table is replaced wholesale (`Core.lua:75`).
- Consumers: the Panel refresher (`Panel.lua:60-87`):
  - `target = PP.NextBracket(s.skill, s.max)`. Brackets are `{75,150,225,300}` (`Logic.lua:17-24`).
  - Calls `PP.Plan{skill, target, recipes, have = PP.Have(), prices = PP.db.prices, thresholds = PP.db.thresholds, unknownCost = 10000}` (`Panel.lua:63-66`).
- `PP.Plan(s)` (`Logic.lua:63-89`) returns up to 3 steps: `{recipeID, name, icon, color, crafts, toSkill?, untilColorChange?, cost}`.
- `PP.ShoppingList(steps, recipes, have, prices)` (`Logic.lua:91-103`) returns `{itemID, need, have, buy, unitPrice?}`, sorted by `buy` desc then itemID.
- Probe results (`thoughts/qrspi/2026-10-19-profession-leveling-planner/probe-results.md`):
  - Tailoring 197 has 471 recipe IDs, 40 learned.
  - Every reagent slot reports type=1 (Basic).
  - `numSkillUps` is 1 everywhere.
  - Leatherworking 165 and Alchemy 171 IDs were not probed in game.

## Q2: Color thresholds — representation, learning, storage, consumption

### Findings
- Tables:
  - `PP.COLOR = {[0]=orange,[1]=yellow,[2]=green,[3]=grey}`.
  - `PP.RANK` is the inverse map.
  - `PP.CHANCE = {orange=1, yellow=0.6, green=0.25, grey=0}`, commented as guessed odds (`Logic.lua:13-16`).
- Storage: `ProfessionPlannerDB.thresholds[recipeID] = {yellow?, green?, grey?}`.
  - Account-wide, flat by recipeID, not nested by profession (`Core.lua:19`).
  - Values are the skill at which the recipe becomes that color.
  - There is no `orange` key.
- `PP.LearnThresholds(th, prev, cur, skill)` (`Logic.lua:117-127`):
  - When a recipe's color rank increases between scans, sets `th[id][newColor] = skill`, keeping the lowest observation.
  - First sighting (no `prev`) is skipped.
  - Called with the scan-time `info.skillLevel` (`Core.lua:76`).
- `PP.LearnGrey(th, id, maxTrivial)` (`Logic.lua:130-136`) sets `th[id].grey` from `ri.maxTrivialLevel` when > 0, keeping the lowest. Called for every cached recipe (`Core.lua:77`).
- Probe: `maxTrivialLevel` is populated on Forever and equals the grey threshold, e.g. Woolen Bag green at 93, maxTrivial 110 (`probe-results.md`).
- `PP.ProjectColor(th, curColor, curSkill, skill)` (`Logic.lua:29-39`):
  - Returns `curColor` when `skill == curSkill`; nil when `th` is nil.
  - Otherwise walks the worse colors in order and returns nil as soon as a needed threshold is missing.
- `PP.NextThreshold(th, color, skill)` (`Logic.lua:42-47`) returns the next worse color's threshold only if known and greater than `skill`; else nil.
- In `PP.Plan`:
  - Eligibility is `r.learned and ProjectColor(...)`. Recipes with unknown thresholds are still eligible at the current skill (`Logic.lua:69`).
  - When `nextT` is nil, crafts are computed to `target` and the step gets `untilColorChange = true`. Planning stops after that step (`Logic.lua:79-85`).
- Panel shows `-> toSkill *`, `(until color changes)` or `-> target` (`Panel.lua:70`). The footer counts recipes with `th.yellow or th.green` as "color thresholds learned" (`Panel.lua:80-86`).

## Q3: Item prices end to end

### Findings
- Only writer is `ScanMerchant` (`Core.lua:107-114`), run on `MERCHANT_SHOW` (`Core.lua:121`).
  - Writes `PP.db.prices[itemID] = info.price / max(1, info.stackCount)`: copper per unit, possibly fractional.
  - Skips zero/nil prices and `hasExtendedCost` items.
  - Last merchant seen wins. No source/time metadata. Nothing is ever deleted.
- `PP.db.prices` lives in account-wide `ProfessionPlannerDB` (`Core.lua:19`).
- `CraftCost(r, crafts, have, prices, unknownCost)` (`Logic.lua:50-59`):
  - Owned reagents (from `have`) are free and consumed (mutates `have`).
  - The rest cost `prices[itemID] or unknownCost`.
- Ranking score is one-craft cost / `CHANCE[color]`, lowest wins, ties to the lower recipeID (`Logic.lua:71-72`). Ranking uses `copy(have)`. Step cost consumes a running `have` copy across steps (`Logic.lua:64,84`).
- `UNKNOWN_COST = 10000` (1g) is defined only in `Panel.lua:50`.
  - Unpriced reagents inflate both score and step cost.
  - Steps carry no "estimated" flag.
- `ShoppingList` does not apply the fallback: `unitPrice = prices[id]` may be nil (`Logic.lua:99`). Panel prints `buy N @ price` only when `unitPrice` is set (`Panel.lua:77`). No total cost row.
- `PP.FormatMoney(copper)` (`Logic.lua:106-114`) floors the value and emits colored `Ng Ns Nc` parts, with `0c` when empty. It is pure Lua.
- `PP.Have()` (`Core.lua:90-94`):
  - Sums bag containers 0 through `Enum.BagIndex.ReagentBag`, plus cached `PP.char.bank`.
  - Recomputed on every refresh (`Panel.lua:64`).
- `ScanBank` (`Core.lua:97-105`):
  - Scans `Enum.BagIndex.CharacterBankTab_1..9` only while the bank is open.
  - Triggered by `BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED` and `BAG_UPDATE_DELAYED` (`Core.lua:117-120`).

## Q4: SavedVariables defaults, load order, cross-addon patterns

### Findings
- `PP.MergeDefaults(sv, defaults)` (`Logic.lua:3-10`):
  - Non-table `sv` becomes `{}`.
  - Table defaults recurse.
  - Scalars are applied only when nil.
- Applied in `ADDON_LOADED` for own name only (`Core.lua:16-22`):
  - DB: `{thresholds, prices}`.
  - CharDB: `{recipes, bank, skill}`.
  - The comment notes a Forever beta loader bug can leave SVs nil (`Core.lua:18`).
- WarlockUtilityKit uses the same pattern with named `DEFAULTS` / `CHAR_DEFAULTS` tables (`WarlockUtilityKit/Core.lua:19-28`, `WarlockUtilityKit/Logic.lua:16-19`).
- `ProfessionPlanner/ProfessionPlanner.toc`:
  - Interface 16001, v0.1.0.
  - SVs `ProfessionPlannerDB` / `ProfessionPlannerCharDB`.
  - Load order Logic.lua, Core.lua, Panel.lua.
- `WarlockUtilityKit/WarlockUtilityKit.toc`: Interface 16001, 10 files.
- Neither .toc has `OptionalDeps`, `Dependencies` or `RequiredDeps`.
- No `IsAddOnLoaded` / `C_AddOns` calls in the repo (grep).
- No calls into another addon's API. Only Blizzard globals are touched:
  - `ProfessionsFrame` (`Panel.lua:6,61`).
  - `_G[name]` lookups of Blizzard cooldown viewer frames, nil-checked before use (`WarlockUtilityKit/Dock.lua:11,19`; `WarlockUtilityKit/Core.lua:204`).
- Namespace: every file starts `local ADDON, PP = ...`, a shared private table.
- Events: `PP.On(event, fn)` lazily registers each event on one hidden frame, runs handlers in order, and has no unregister (`Core.lua:7-12`).
- Hooks: `PP.inits` run on `PLAYER_LOGIN` (`Core.lua:23`). `PP.refreshers` run on `PP.Refresh()` (`Core.lua:14`).
- Interface 16001 corresponds to wago.tools product `wow_classic_beta` version `1.60.1.x` (latest seen 1.60.1.70450).

## Q5: tests/run.lua

### Findings
- Plain Lua script, run with `lua ProfessionPlanner/tests/run.lua`.
  - Locates the addon dir from `arg[0]` (`tests/run.lua:1`).
  - Loads only Logic.lua via `loadfile(dir.."/Logic.lua")("ProfessionPlanner", PP)` (`:3`).
  - No WoW API stubs.
- Assertion: a single `eq(got, want, label)` that calls `error(...,2)` on `~=` (`:5-7`). Prints `all tests passed` (`:55`).
- Fixtures:
  - `R` has 3 learned recipes (orange item 10, yellow item 11, green item 12, qty 1 each) (`:20-24`).
  - `S(o)` builds the Plan input with `skill=50, target=75, prices={[10]=1000,[11]=100,[12]=1}, thresholds={}, unknownCost=10000`, overridable (`:25-26`).
  - Threshold fixtures are `{[2]={green=60,grey=70}}` (`:33`) and `th3` (`:51`).
- Covered:
  - MergeDefaults; NextBracket edges.
  - Plan: cheapest-per-point, stop on unknown threshold, owned reagents free, green fallback, at-target, threshold-bounded step, multi-step.
  - ProjectColor, NextThreshold, ShoppingList, FormatMoney, LearnThresholds, LearnGrey (`:10-53`).
- Not covered: the `unknownCost` path (every fixture reagent is priced) and anything in Core.lua / Panel.lua.

## Q6: Auctionator public API (verified against installed source)

### Findings
- Installed copy: `AH-ADDON\Auctionator.toc:1-3`.
  - `## Interface: 120100, 16001, 50504, 38000, 20506, 11508, 11509`, Version 340, so it explicitly lists 16001 (Forever).
  - The folder/addon name is `Auctionator`.
  - Its own SavedVariables include `AUCTIONATOR_PRICE_DATABASE` and `AUCTIONATOR_VENDOR_PRICE_CACHE` (`Auctionator.toc:23`).
- License: "All Rights Reserved, Copyright (c) 2020-2025 plusmouse, borjamacare" (`AH-ADDON\LICENSE:1-3`).
- caller check: `Auctionator.API.InternalVerifyID(callerID)` errors `"Invalid callerID. Use the name of your add-on."` unless callerID is a non-empty string (`AH-ADDON\Source\API\Internal.lua:9-13`).
- Wrong argument types call `ComposeError`, which raises `error("Contact the maintainer of <callerID> to resolve this problem. Details: <usage>")` (`Internal.lua:1-6`).
- `Auctionator.API.v1.GetAuctionPriceByItemID(callerID, itemID:number)` (`AH-ADDON\Source\API\v1\GetAuctionPrice.lua:1-16`):
  - Returns nil if `Auctionator.Database == nil`.
  - Otherwise returns `Database:GetPrice(tostring(itemID))`, the last seen minimum buyout `.m`, or nil if the item was never seen (`AH-ADDON\Source\Database\Mixin.lua:82-88`).
  - Units: the copper buyout stored by `SetPrice(dbKey, buyoutPrice, ...)` (`Mixin.lua:15-27`).
- `GetAuctionPriceByItemLink(callerID, itemLink:string)` resolves DB keys from the link, item-level aware, and falls back to a basic key (`GetAuctionPrice.lua:18-46`).
- `GetAuctionAgeByItemID` / `ByItemLink` return the number of days since the item was last seen, nil if more than 21 days or never seen (`GetAuctionAge.lua:1-3` comment, `Mixin.lua:183-195`).
- `GetVendorPriceByItemID(callerID, itemID)` returns `AUCTIONATOR_VENDOR_PRICE_CACHE[tostring(itemID)]`, which can be nil (`GetVendorPrice.lua:1-11`). There is also a ByItemLink variant.
- `IsAuctionDataExactByItemID` / `ByItemLink` (`IsAuctionDataExact.lua`).
- Other v1 files: `GetDisenchantPrice.lua`, `MultiSearch.lua`, `ShoppingLists.lua` (`AH-ADDON\Source\API\v1\`, not read in detail).
- `RegisterForDBUpdate(callerID, callback:function)`:
  - Exists separately in `Source_ModernAH\API\v1\RegisterForDBUpdate.lua` and `Source_LegacyAH\API\v1\RegisterForDBUpdate.lua`.
  - The ModernAH version fires `callback()` with no arguments on `IncrementalScan.Events.PricesProcessed` and `FullScan.Events.ScanComplete` (`Source_ModernAH\...\RegisterForDBUpdate.lua:11-18`).
  - Auctionator's own crafting UI uses it (`Source_Mainline\CraftingInfo\Mixins\Professions.lua:27`, `Source_Classic\CraftingInfo\Mixins\Frame.lua:25`).
- Database lifecycle:
  - `Auctionator.Database` is created in `Variables.InitializeDatabase()` (`AH-ADDON\Source\Variables\Main.lua:83,200-205`).
  - That runs from `InitializeLate()` on Auctionator's `PLAYER_LOGIN` handler (`Variables\Main.lua:23-24`, `Source\Initialize\Main.lua:20-21`). Before that the API returns nil.
  - Data is per connected-realm root key (`Variables\Main.lua:110`).
  - Per-day low/high/available history `l/h/a`, pruned by the `PRICE_HISTORY_DAYS` config (`Mixin.lua:10-23`).
  - With the `NO_PRICE_DATABASE` option the DB is an empty table (`Variables\Main.lua:201-202`).
- Game-type gating in the .toc:
  - Shared `Source\Manifest.xml` loads for all clients.
  - `Source_ModernAH` loads for `cata, mists, mainline`; `Source_LegacyAH` for `vanilla, tbc, wrath`.
  - `Source_Forever\Constants.lua` loads for `[AllowLoadGameType camelot][ExcludeLoadGameType classic, standard]` and only overrides `Constants.Durations` (`Auctionator.toc:41-51`).
- Live data on this machine: `_classic_beta_\WTF\Account\*\SavedVariables\Auctionator.lua` (174 KB, 2026-10-20 08:19).
  - Contains `AUCTIONATOR_PRICE_DATABASE = { ["__dbversion"] = 8, ["PvE"] = <CBOR-serialized string> }`.
  - Also contains a populated `AUCTIONATOR_VENDOR_PRICE_CACHE`.
  - The `ProfessionPlanner.lua` SV file sits beside it (2.6 KB), so SavedVariables persist on this client.
- Legacy globals (`Atr_GetAuctionBuyout`, `GetAuctionBuyout`) are from an old unofficial mirror (github.com/Clancey/AddOns); not found in a grep of the installed copy's v1 API dir.
- External consumers call `Auctionator.API.v1.*` with the addon name and treat errors and nil as "no price": guild-bank-ledger (github.com/RussellFeinstein/guild-bank-ledger/issues/196) and CraftWise, which wraps calls in `pcall` (github.com/velibkolay/CraftWise/issues/2).
- skillup-forever (github.com/cjber/skillup-forever/issues/1) is a Forever-specific profession addon that also proposed Auctionator as a price source.

## Q7: Classic 1-300 leveling guides and machine-readable data

### Findings — guide sites (editorial)
- Common format: rows of skill range, one recipe, craft count, reagents. Then a totals shopping list. Recipe source noted inline (trainer / vendor book / quest).
- wow-professions.com First Aid (https://www.wow-professions.com/classic/first-aid-leveling-guide-classic-wow) runs from "1-40: 50 Linen Bandage" to "290-300: 15 Heavy Runecloth Bandage". Books are named with vendor NPCs.
- wow-professions.com Blacksmithing (…/blacksmithing-leveling-guide-classic-wow) has the same shape.
- Others found, not fetched:
  - Wowhead Classic guides (patch 1.15.8 era).
  - Warcraft Tavern (warcrafttavern.com/wow-classic/guides/…).
  - Zockify (zockify.com/classic/professions/…).
  - wowisclassic.com.
- Guides do not publish per-recipe color thresholds. Ranges are editorial choices.
- Copyright: wow-professions.com footer "© 2026 WoW-Professions.com", no license. Wowhead terms page not located (404s).

### Findings — client game data (wago.tools DB2 mirror, CSV export `https://wago.tools/db2/<Table>/csv?build=<ver>` or `?product=<product>`)
- `SkillLineAbility` for Forever build `1.60.1.70450`.
  - Header: `AbilityVerb_lang,AbilityAllVerb_lang,ID,SkillLine,Spell,MinSkillLineRank,ClassMask,SupercedesSpell,AcquireMethod,TrivialSkillLineRankHigh,TrivialSkillLineRankLow,Flags,NumSkillUps,UniqueBit,TradeSkillCategoryID,SkillupSkillLineID,...`
  - Sample rows (Spell, High, Low):

    | Spell | Name | High | Low |
    |---|---|---|---|
    | 3275 | Linen Bandage | 60 | 30 |
    | 2963 | Bolt of Linen Cloth | 50 | 25 |
    | 2964 | Bolt of Woolen Cloth | 85 | 70 |
    | 3755 | Linen Bag | 65 | 30 |
    | 3757 | Woolen Bag | 110 | 75 |

  - `SkillupSkillLineID = 2948` for Tailoring rows.
  - SkillLine table has both 197 and 2948 named "Tailoring".
  - Row counts per SkillLine: 197 = 486, 333 = 272, 165 = 616, 171 = 212.
- The `TrivialSkillLineRankHigh` values match the in-game probe's `maxTrivialLevel` exactly (Bolt of Woolen 85, Linen Bag 65, Woolen Bag 110, Bolt of Linen 50).
- The Classic Era / Anniversary products (`wow_classic_era`, `wow_anniversary`) carry different numbers for the same spells:
  - Bolt of Woolen High=105 / Low=90.
  - Linen Bag 105/70.
  - Woolen Bag 140/105.
  - Bolt of Linen 50/25 (unchanged).
  - So Forever thresholds differ from Era data for some recipes.
- Era header lacks the `_lang` columns and `SkillupSkillLineID`.
- `TrivialSkillLineRankLow` lines up with the yellow threshold in Era data (Linen Bag Low 70 vs commonly cited yellow 70). This is inferred, not verified in game on Forever.
- Green threshold is not a DB2 column. One Forever data point: Woolen Bag is green at skill 93 with Low=75 and High=110, consistent with green = midpoint (92.5). Single sample.
- `MinSkillLineRank` is 1 for all sampled rows, including Woolen Bag. The skill required to learn (orange start) is not in this column for these rows. Trainer requirements live in server data (emulator `npc_trainer.ReqSkillRank`, per azerothcore.org/wiki/npc_trainer), not the client DB2.
- `AcquireMethod`:
  - 1 on auto-learned rows (Bolt of Linen, Linen Bandage, Linen Bag).
  - 0 on others (Bolt of Woolen, Woolen Bag).
  - Meaning per wowdev.wiki/DB/SkillLineAbility: 0 = trainer, 1 = on skill gain, 2 = racial.
- `SpellReagents` (build 1.60.1.70450) columns: `ID,SpellID,Reagent_0..7,ReagentCount_0..7,ReagentReCraftCount_0..7,ReagentSource`.
  - Example: spell 3755 has reagents 2996×3 and 2320×3.
  - Era example: spell 2963 has 2589×2.
- `SpellEffect` (3.8 MB CSV) gives the output item.
  - Columns: `Effect` (col 5), `EffectItemType` (col 12), `SpellID` (col 37).
  - Example: spell 3755 has Effect 24 (create item) with EffectItemType 4238.
- `SpellName` CSV maps spellID to name (e.g. `3755,"Linen Bag"`).
- License: Blizzard client data. wago.tools is a viewer/mirror with no open license stated.
- Addon databases:
  - CraftLib (curseforge.com/wow/addons/craftlib) covers recipes, reagents, skill levels and sources (trainer/vendor/drop/quest/rep) for Classic Era 1.15.8 and TBC 2.5.5. License not found.
  - TradeSkillInfo `Data.lua` is generated by github.com/Ravendwyr/TradeSkillInfo_DataMiner, which scrapes Wowhead/WoWdb. No LICENSE file.
  - Emulator DBs: mangos-classic DB is GPL v3, CMaNGOS TBC-DB is GPL v2. VMaNGOS license not found.
  - LibPeriodicTable, Ackis Recipe List and Icy Veins were not checked.

## Cross-Cutting Observations
- One ID space links everything. recipeID (ProfessionPlanner key) = DB2 `SkillLineAbility.Spell` = `SpellReagents.SpellID` = `SpellEffect.SpellID`. Reagent itemIDs match between the in-game schematic and `SpellReagents` (e.g. 3755 → 2996; the probe only printed slot 1).
- ProfessionPlanner holds three kinds of runtime-learned data, all keyed by numeric IDs:
  - Account-wide `thresholds[recipeID]` and `prices[itemID]`.
  - Per-character `recipes[profID][recipeID]`, `skill[profID]` and `bank[itemID]`.
- Every price consumer treats a missing price as `nil`. Plan substitutes `unknownCost`; ShoppingList and Panel display nothing.
- Auctionator follows the same convention (nil when unknown, copper units, string-keyed itemIDs internally).
- Initialization ordering:
  - ProfessionPlanner registers its scan events in `PLAYER_LOGIN` inits.
  - Auctionator builds `Auctionator.Database` in its own `PLAYER_LOGIN` handler.
  - The relative order of the two handlers depends on addon load order. Neither addon declares the other as a dependency.
- Forever (Interface 16001, wago `wow_classic_beta` 1.60.1) is a Classic-content client with Mainline-style APIs:
  - `C_TradeSkillUI.GetRecipeSchematic`, `Enum.BagIndex.CharacterBankTab_*`, `ProfessionsFrame`.
  - Mainline-style DB2 columns (`SkillupSkillLineID`, child skill line 2948).
  - Auctionator tags it with game type `camelot`.

## Follow-up Research (open areas, round 2)

### Thresholds verified against learned in-game data
- Source: the user's live `ProfessionPlannerDB.thresholds`. It is the account SavedVariables file `_classic_beta_\WTF\Account\<acct>\SavedVariables\ProfessionPlanner.lua` and has 70 values learned in game.
- Compared to Forever `SkillLineAbility` (build 1.60.1.70450):
  - grey: 66 of 66 learned values equal `TrivialSkillLineRankHigh`.
  - yellow: 3 of 3 equal `TrivialSkillLineRankLow`. Spells 2401 and 6521 (Tailoring) are 95 = Low 95; spell 7788 (Enchanting) is 120 = Low 120.
  - green: 1 of 1 equals `(Low + High) / 2`. Spell 7457 is 120 = (100 + 140) / 2. The probe's Woolen Bag (green at 93; Low 75, High 110, midpoint 92.5) is consistent.
- Learned values are the skill at scan time when the color change was seen (`Core.lua:76`), so they are upper bounds. All four non-grey samples hit the DB2-derived value exactly.
- Learned IDs include Forever-only spells, e.g. 1229504, 1230643, 1245320, 1257368. Their grey values also match DB2.
- 259 spells in SkillLines 197 and 333 exist in the Forever DB2 but not in the Era DB2.

### Learn-at skill and recipe sources (client DB2)
- `SkillLineAbility.MinSkillLineRank` is 1 on every Tailoring row in both the Forever (486 rows) and Era (296 rows) builds. It carries no learn-at skill.
- Recipe items (patterns, formulas, plans) link to recipe spells through `ItemEffect` rows with `TriggerType = 6` and `SpellID = <recipe spell>`. `ItemXItemEffect(ItemEffectID → ItemID)` joins the effect to the item.
  - For SkillLines 197/333/165/171 (1,585 recipe spells), 1,230 are taught by at least one item and 355 have no teaching item (trainer or auto-learned).
  - Rows with `TriggerType = 0` referencing a recipe spell are on-use items such as enchant scrolls, not teachers.
- `ItemSparse` columns `RequiredSkill` (col 84) and `RequiredSkillRank` (col 83) on a recipe item give the skill line and the skill needed to learn it. Examples:
  - Pattern: Green Winter Clothes: 197 / 250, Low 250.
  - Formula: Scroll of Spatial Mending: 333 / 120, Low 120.
  - Pattern: Scarlet Augur's Hood: 197 / 280, Low 285.
- `Low − RequiredSkillRank` across item-taught recipes ranges over 0–30. Histogram: 20 (429), 5 (193), 15 (193), 25 (115), 10 (75), 0 (54), 30 (25). The learn-at skill is therefore not derivable from Low.
- Trainer-taught recipes have no learn-at skill or trainer reference in the client tables checked. In emulators these live server-side (`npc_trainer.ReqSkillRank`).
- `ItemSparse.BuyPrice` (col 53), `SellPrice` (col 52) and `VendorStackCount` (col 54) carry base vendor prices. They compare to ProfessionPlanner's merchant-scanned `prices` as follows:

  | Item | BuyPrice | PP scanned |
  |---|---|---|
  | Coarse Thread 2320 | 10 | 9 |
  | Fine Thread 2321 | 100 | 90 |
  | Red Dye 2604 | 50 | 45 |
  | Gray Dye 4340 | 350 | 315 |
  | Black Dye 2325 | 1000 | 900 |

  Every scanned price is exactly 90% of BuyPrice (a consistent 10% discount, cause not identified).
- `ItemSparse.BuyPrice` is nonzero for many non-vendor items too (e.g. the patterns above, buy 5000). BuyPrice alone does not indicate that a vendor sells the item.

### Recipe count reconciliation
- Forever `SkillLineAbility` has 486 distinct spells for SkillLine 197.
- 14 have `High = 0 / Low = 0`. The named ones are "Tailoring" rank spells (3908, 3909, 3910, 12180, 1240953, 1240964, 1240976, 1240988), not recipes.
- 486 − 14 = 472, against 471 recipe IDs in game (probe). One-row difference remains unexplained.

### Auctionator branch on Forever
- `Source_ModernAH\Variables\Main.lua:1-16`: when `RegionalUniqueNamesEnabled()` is true, the DB key is the ruleset name `PvP` / `RP` / `HC` / `PvE`, chosen with `C_GameRules.IsGameRuleActive`. `Source_LegacyAH\Variables\Main.lua:3` defines a different `GetConnectedRealmRoot`.
- The local DB key is `PvE`, so the ModernAH branch is the one loaded on this client. Its `RegisterForDBUpdate` fires on `IncrementalScan.Events.PricesProcessed` and `FullScan.Events.ScanComplete`.
- `AH-ADDON\Source\Constants\Main.lua:56-57`: `IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` ("temporary fix assigning retail to mainline"); `IsForever = build >= 16000 and build < 20000`.
- `Libs_ModernAH\LibAHTab\LibAHTab.lua:8` accepts `WOW_PROJECT_CAMELOT`.
- `AH-ADDON\CHANGELOG.md:3-8`: release 340 (2026-10-02) includes "Forever: Separate PvE, PvP, HC and RP auction houses".

### Other installed addons with profession/source data (Forever client)
- **QuestieDB 1.0.5** (`AddOns\QuestieDB\QuestieDB_Forever.toc`, Interface 16001, generated by `lua generate.lua Forever`):
  - Exposes the global `_G.LibQuestieDB` (`QuestieDB\src\api.lua:8,164`).
  - `LibQuestieDB.Item` has `vendors(id) → NpcId[]?`, `npcDrops(id)`, `objectDrops(id)`, `teachesSpell(id) → spellID?`, `questRewards(id)` and `name(id)` (`QuestieDB\Types\Item.t.lua:3-25`).
  - `LibQuestieDB.Npc` has `name`, `subName` (e.g. trainer titles) and `npcFlags` (`Types\Npc.t.lua:4-27`).
  - It also has a contract check, `RequireContract(n)` / `contractVersion` (`Types\LibQuestieDB.t.lua`).
  - No LICENSE file in `QuestieDB\`.
- **AtlasLootContinued_Crafting**:
  - `AtlasLootContinued_Crafting_Camelot.toc` covers Interface 16000/16001/120100. `data-forever.lua` has `data["TailoringForever"]` (`:1043`).
  - Entries are `{ slot, recipeSpellID }`, grouped by category, with a trailing comment such as `--Woolen Bag / 15 / 105` (`:1325`).
  - The comment numbers do not match Forever DB2 (Woolen Bag Low 75 / High 110), so they are not Forever thresholds.
  - GPL v2 (`AtlasLootContinued\LICENSE`).
- Also installed: Questie, GuildStock, Leatrix_Maps/Plus, BetterFishing, GearQuestForever, DBM modules (not inspected).

## Follow-up Research (round 3)

### Trainer-taught recipes: learn-at skill and source
- **Client DB2:** no learn-at skill or trainer reference for the 355 recipes without a teaching item (round 2).
- **Forever in-game API** (Blizzard UI source, github.com/Gethe/wow-ui-source, branch `forever`):
  - `TradeSkillUITypesDocumentation.lua`: `TradeSkillRecipeInfo` has these fields, among others:
    - `sourceType` (number, nilable)
    - `learned`
    - `disabled`
    - `disabledReason`
    - `skillLineAbilityID`
    - `nextRecipeID`
    - `maxTrivialLevel`
    - `relativeDifficulty`
  - `TradeSkillUIDocumentation.lua:738-751`: `C_TradeSkillUI.GetRecipeRequirements(recipeID)` returns `{ {name, met, type: RecipeRequirementType}, ... }`.
  - `Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeSchematicForm.lua:635-641`: for unlearned recipes the Forever UI calls `C_TradeSkillUI.GetRecipeSourceText(recipeID)` (or `nextRecipeID` for the next rank) and shows it under `TRADESKILL_UNLEARNED_RECIPE_HEADER`.
  - `GetRecipeSourceText` is called by Blizzard code but is absent from the generated API doc.
  - The returned text's format on Forever (trainer name / required skill / cost) was not observed.
- **Unlearned recipes in game:** `GetAllRecipeIDs()` returns unlearned recipes too (Tailoring: 471 total, 40 learned; probe). `PP.ScanProfession` currently skips them (`Core.lua:42`).
- **QuestieDB** identifies trainers but not what they teach:
  - NPC field 15 is `npcFlags`, where `TRAINER = 16` and `VENDOR = 4` (`QuestieDB\src\corrections\enum\expansions.lua:59-66`).
  - NPC field 14 is `subName`, e.g. "Journeyman Tailor" / "Artisan Tailor" with flags 17.
  - The Forever DB has 52 NPCs with "Tailor" in their subName, 28,399 NPC rows and 37,553 item rows.
  - There is no per-trainer spell list. No item carries field 16 `teachesSpell` in the Forever baked DB.
- **Emulator DBs** (`npc_trainer.ReqSkillRank`): Era data; round 1 found Forever thresholds differ from Era for some recipes.

### Vendor price gap (10%)
- Five reagents and two patterns all scanned at exactly 90% of `ItemSparse.BuyPrice`:

  | Item | BuyPrice | PP scanned |
  |---|---|---|
  | Pattern: Red Woolen Bag 5772 | 500 | 450 |
  | Pattern: Blue Overalls 6274 | 400 | 360 |

  The other five are the reagents listed in round 2.
- Reputation discount rules (warcraft.wiki.gg/wiki/Reputation):
  - Retail/TBC+: Friendly 5%, Honored 10%, Revered 15%, Exalted 20%.
  - Pre-2.3.0: "a flat 10% discount starting at honored". Icy Veins' Classic reputation guide also gives Honored as 10%.
- No documented Forever-wide vendor discount was found. warcraft.wiki.gg Patch 1.60 / 1.60.1 pages don't mention one; the only reported vendor price rule is a 50g cap on Black Lotus / Arcane Crystal from one NPC (gamewave.fr, 2026-09-30).
- The pattern is consistent with Honored reputation at the vendors visited. This is not confirmed: the character's standings and which vendors were scanned are unknown.
- `C_MerchantFrame.GetItemInfo(i).price` (used at `Core.lua:109`) returns the price the character actually pays. `ItemSparse.BuyPrice` is the undiscounted base.

### QuestieDB vendor data (verified by decoding the Forever baked DB)
- Storage:
  - `QuestieDB_Forever.toc` (113,429 lines) holds data as `## X-<Kind>-<id>-<field>: <base64 CBOR>` metadata lines (`## X-Mode: baked`, `## X-Flavor: Forever`, `## X-Contract-Version: 3`).
  - `-S` lines pack small scalar fields.
  - Field numbers come from `QuestieDB\src\corrections\enum\fieldKeys.lua:47-82`: item `vendors = 14`, `npcDrops = 2`, `objectDrops = 3`, `teachesSpell = 16`; npc `name = 1`, `zoneID = 9`, `factionID = 12`, `friendlyToFaction = 13`, `subName = 14`, `npcFlags = 15`.
- Runtime access: `_G.LibQuestieDB.Item.vendors(itemID)` / `.npcDrops` / `.name`, and `LibQuestieDB.Npc.name / subName / npcFlags / zoneID` (`Types\Item.t.lua`, `Types\Npc.t.lua`).
- Decoded examples (vendor counts):

  | Item | Vendors | First NPCs |
  |---|---|---|
  | Coarse Thread 2320 | 122 | 66 Tharynn Bouden "Trade Supplies" (A); 777 Amy Davenport "Tradeswoman" (A); 989 Banalash "Trade Goods" (H) |
  | Red Dye 2604 | 101 | |
  | Empty Vial 3371 | 115 | |
  | Pattern: Red Woolen Bag 5772 | 11 | |
  | Pattern: Red Linen Bag 5771 | 4 | |
  | Pattern: Blue Overalls 6274 | 4 | |

- Crafted items (Bolt of Linen Cloth 2996, Linen Bag 4238) have no vendors field. Bolt of Linen Cloth has drop fields 2/3/4.
- NPC `friendlyToFaction` is `"A"` / `"H"`, so vendors can be filtered by player faction.
- Vendor-sold patterns pair with `ItemSparse.RequiredSkillRank` for learn-at skill (5771: 197/50, 5772: 197/90, 6274: 197/75).

### Licenses / reuse terms
- **Questie:** CurseForge lists "GNU General Public License version 3 (GPLv3)" (curseforge.com/wow/addons/questie).
  - The GitHub API reports no license file for `Questie/Questie` or `Questie/QuestieDB`.
  - QuestieDB has a `PROVENANCE.md`, which contains no license/GPL/copyright text.
  - Questline's CurseForge page describes the data as "QuestieDB (GPL-3.0)" (secondhand).
- **CraftLib:** `LICENSE` reads "All Rights Reserved. Copyright (c) 2026 Bogdan Osinnyi (kAldown)" (github.com/kaldown/CraftLib).
  - Its README says its data comes from DB2 tables, with "Wowhead-verified difficulty thresholds".
  - It targets Classic 1.15.8 / TBC 2.5.5, not Forever.
- **Wowhead:** terms are the "Fanbyte/ZAM Terms of Service" (wowhead.com/termsofservice). Clause text could not be fetched.
- **Icy Veins** (from search summaries): copying needs written approval, except on non-commercial sites with credit and a link.
- **wow-professions.com:** disclaimer only ("not associated with or endorsed by Blizzard"); no reuse clause found.
- **wago.tools:** no terms found. The data itself is Blizzard client data.
- **Blizzard UI Add-On Development Policy** (us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534):
  - Add-ons must be free.
  - Code must not be hidden or obfuscated.
  - Add-ons must not harm realms or players.
  - A 2009 notice says distributing copyrighted in-game audio without authorization is illegal.
  - There is no clause on redistributing game data tables.
- **Already established:** Auctionator is All Rights Reserved; AtlasLootContinued is GPL v2.
- **Forever context:** beta 2026-09-17 to 10-21, launch 2026-11-04 (warcrafttavern.com, itwire.com). Patch 1.60.1 notes say high-end recipes cost "Merchant's Favor" and have reputation requirements (warcraft.wiki.gg/wiki/Patch_1.60.1).

## Open Areas
- The exact output of `GetRecipeSourceText`, `GetRecipeRequirements` and `sourceType` for unlearned recipes on Forever (needs an in-game probe).
- Character reputation standings behind the 10% vendor gap.
- Recipes priced in "Merchant's Favor" (Patch 1.60.1) have `hasExtendedCost` and are skipped by `ScanMerchant` (`Core.lua:110`).
- Green = midpoint rests on two in-game samples. Yellow = Low rests on three.
- One-row gap between 472 DB2 recipes and 471 in game for Tailoring.
- Leatherworking 165 / Alchemy 171 professionIDs are unverified in game (DB2 does contain SkillLine rows 165 and 171).
- Wowhead ToS clause text and VMaNGOS license not read. QuestieDB has no license file in its repo (Questie is GPLv3 per CurseForge).
- The CBOR contents of the local Auctionator `PvE` DB were not decoded.
