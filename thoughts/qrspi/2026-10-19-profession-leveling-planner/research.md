# Research Findings

Codebase refs: `WarlockUtilityKit/…` and `.github/workflows/…`. External refs: URLs. **UNVERIFIED** = not seen on a fetched page. Gathered 2026-10-19.

URL shorthand used below:
- `NOTES` = https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes
- `DIFF` = https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes

## Q1: How the existing addon is organized and built

### Findings
- **TOC** (`WarlockUtilityKit.toc:1-7`):
  - fields: Interface 16001, Title, Notes, Version 0.2.0, IconTexture, `SavedVariables: WarlockUtilityKitDB`, `SavedVariablesPerCharacter: WarlockUtilityKitCharDB`;
  - load order (`:9-18`): Logic, Core, UI, Prep, Summon, Trade, Comm, Board, Dock, Settings. No libraries, no XML.
- **Namespace:** every Lua file starts with `local ADDON, WUK = ...` on line 1. The loader passes the addon name and a shared table.
- **Pure logic in `Logic.lua`.** Examples: `ClassifyItem` (`:9`), `MergeDefaults` (`:16`), `StoneMacro` (`:26`), `Encode`/`Decode` (`:122/:128`), `AnnounceLines` (`:145`). WoW API calls live in Core, UI and the feature files, e.g. `C_Container` in `Core.lua:30-44`.
- **Lifecycle** (`Core.lua`):
  - **Arrays:** `WUK.inits` and `WUK.refreshers` (`:3`).
  - **Events:** `WUK.On(event, fn)` registers lazily on one shared frame (`:11-17`).
  - **SavedVariables:** `ADDON_LOADED` (`:22-28`) applies `MergeDefaults` with `DEFAULTS` / `CHAR_DEFAULTS` (`:19-20`). It is nil-safe because of the Forever beta loader bug (comment, `:24`).
  - **Login:** `PLAYER_LOGIN` (`:143-150`) checks class, sets `WUK.active`, runs every init, then calls `Refresh`.
  - **Refresh:** `WUK.Refresh` (`:137-141`) rescans bags and then calls every refresher.
  - **Slash command:** `/wuk` is registered at `:221-241`.
  - **Helpers:** `WUK.Secret` (`:7`) and `WUK.Print` (`:8`).
- **Window pattern** (`Settings.lua`):
  - The window is lazy-built in `Build()` (`:18-62`) and toggled by `WUK.ToggleSettings` (`:64-67`).
  - Frame: `BasicFrameTemplateWithInset`, DIALOG strata, draggable. It is added to `UISpecialFrames` (`:23`), so Escape closes it.
  - The dropdown is `WowStyle1DropdownTemplate` + `SetupMenu` + `CreateRadio` (`:38-46`).
  - On show, `Sync` refreshes the controls (`:56-60`).
- **Movable frames:** `WUK.MakeMovable(f, key, x, y)` (`UI.lua:11-24`). Shift-drag moves the frame, but not when locked or in combat. The position is saved to `db.frames[key]`.
- **Tests** (`tests/run.lua`):
  - `:1` resolves the directory from `arg[0]`;
  - `:3` calls `loadfile(dir.."/Logic.lua")("WarlockUtilityKit", WUK)`;
  - `:5-7` defines `eq`;
  - comments mark the phase sections, and `:88` prints `all tests passed`.
- **CI** (`.github/workflows/package-wuk.yml`):
  - Triggers: push to main, with paths `WarlockUtilityKit/**` and the workflow file (`:3-7`), plus `workflow_dispatch`.
  - Permissions: `contents: write` (`:9-10`).
  - Test step: apt installs `lua5.1`, then runs `lua5.1 WarlockUtilityKit/tests/run.lua` (`:18-21`).
  - Version: `sed` extracts `## Version` from `WarlockUtilityKit/WarlockUtilityKit.toc` (`:23-28`).
  - Package: zips `WarlockUtilityKit-<v>.zip`, excluding `tests/*` (`:31`).
  - Release: tag `wuk-v<v>` (`:36`). If the release exists, `gh release upload --clobber`; otherwise `create` (`:38-44`). Title "Warlock Utility Kit" (`:43`).
  - Every one of those strings is specific to this addon.

## Q2: Profession (trade skill) API on Forever / Mainline 12.x

### Findings
- **Function pages that list Forever 1.60.1 (69913)** on warcraft.wiki.gg:
  - `C_TradeSkillUI.GetAllRecipeIDs()` returns all recipes of the open profession, learned and unlearned, ignoring filters. It returns an empty table until the panel has been opened (https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI.GetAllRecipeIDs).
  - `GetRecipeInfo(recipeSpellID[, recipeLevel])` returns `TradeSkillRecipeInfo` (https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI.GetRecipeInfo). Fields include:
    - `name`, `learned`, `craftable`, `categoryID`;
    - `relativeDifficulty` (`Enum.TradeskillRelativeDifficulty`: 0 Optimal, 1 Medium, 2 Easy, 3 Trivial);
    - `maxTrivialLevel` (no description), `numSkillUps`, `canSkillUp`, `firstCraft`;
    - `skillLineAbilityID`, `previousRecipeID` / `nextRecipeID`, `isEnchantingRecipe`, `hyperlink`, `icon`.
  - `GetRecipeSchematic(recipeSpellID, isRecraft[, recipeLevel])` is AllowedWhenUntainted (https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI.GetRecipeSchematic).
    - Returns `outputItemID?`, `quantityMin`/`quantityMax`, `recipeType` (1 Item, 2 Salvage, 3 Enchant, 4 Gathering).
    - `reagentSlotSchematics[]` holds `{ reagents[{itemID?, currencyID?}], quantityRequired, reagentType (1 Basic), required }`.
  - `GetBaseProfessionInfo()` and `GetProfessionInfoBySkillLineID(id)` return `ProfessionInfo` (https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI.GetBaseProfessionInfo).
    - Fields: `professionID`, `professionName`, `skillLevel`, `maxSkillLevel`, `skillModifier`, `parentProfessionID`, `isPrimaryProfession`.
  - `IsTradeSkillReady()` is true once the UI is open and loaded.
  - `OpenTradeSkill(id)` is restricted (needs a hardware event).
  - The namespace has 89 functions and 20 events (https://warcraft.wiki.gg/wiki/Category:API_systems/TradeSkillUI). Among them: `GetChildProfessionInfo(s)`, `GetProfessionInfoByRecipeID`, `GetCraftableCount`, `GetRecipeRequirements`, `GetRecipeOutputItemData`, `IsRecipeInSkillLine`.
  - Not fetched (UNVERIFIED): `GetRecipeNumItemsProduced`, `GetTradeSkillLine`, `IsTradeSkillLinked`, `GetRecipeItemLink`.
- **Thresholds:** no API returns per-recipe orange/yellow/green/grey numbers. The closest fields are `relativeDifficulty`, `maxTrivialLevel` and `numSkillUps`; whether `maxTrivialLevel` is populated on Forever is UNVERIFIED. The "SkillUp Forever" addon ships "bundled thresholds" and has a `/su audit` command comparing them with in-game colors (https://www.curseforge.com/wow/addons/skillup-forever).
- **Events** (namespace list): `TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE` (no payload; listed for Forever, https://warcraft.wiki.gg/wiki/TRADE_SKILL_LIST_UPDATE), `TRADE_SKILL_CLOSE`, `TRADE_SKILL_DATA_SOURCE_CHANGED/CHANGING`, `NEW_RECIPE_LEARNED`, `TRADE_SKILL_ITEM_CRAFTED_RESULT`, `TRADE_SKILL_CRAFT_BEGIN`, `UPDATE_TRADESKILL_CAST_STOPPED`. GuildStock registers `SKILL_LINES_CHANGED` (Q4).
- **Removed in Forever** (`DIFF`): `C_TradeSkillUI.CanTradeSkillShowCraftingUI`, all of `C_SkillInfo` (`GetNumSkillLines`, `GetSkillLineInfo`, …), and global `AbandonSkill`.
- **Frame**
  - `ProfessionsFrame` is used on Forever by Hemlock (`ProfessionsFrame:IsShown()`, https://raw.githubusercontent.com/Hexx98/hemlock-forever/main/Hemlock.lua).
  - ProfessionShoppingList hooks `ProfessionsFrame.CraftingPage.SchematicForm` (TrackRecipeCheckbox, OutputText, OutputIcon) and `EventRegistry` `ProfessionsRecipeListMixin.Event.OnRecipeSelected`, with `app.Forever` branches (https://raw.githubusercontent.com/Slackluster/ProfessionShoppingList/HEAD/modules/ProfessionWindow.lua).
  - Whether Blizzard_Professions is load-on-demand on Forever is UNVERIFIED.
- **Hemlock Forever usage**
  - `GetBaseProfessionInfo().professionID == 40` (Poisons) plus `IsTradeSkillReady()`.
  - `pcall(GetProfessionInfoBySkillLineID, 40)` at login.
  - `pcall(OpenTradeSkill, 40)`, falling back to `CastSpellByName`, then polling about 30×0.1s.
  - Loops `GetAllRecipeIDs()` + `GetRecipeInfo` (`learned`, `name`).
  - `GetRecipeSchematic(id, false).reagentSlotSchematics` with `quantityMin` for crafts, then `CraftRecipe(id, n)`.
  - It registers no `TRADE_SKILL_*` events.
- **Forever window features** (https://www.warcrafttavern.com/forever/guides/professions/):
  - professions have "their own window instead of the main spellbook" (K / micro menu);
  - "over 600 new recipes", mostly vanilla materials;
  - filter, search and track-to-objectives;
  - an Optional Target slot for enchanting;
  - a dedicated reagent bag.
- **Secrets:** `NOTES` says Midnight secrets apply to Forever, but no trade-skill-specific secret is named. `GetRecipeSchematic` and `GetRecipeInfoForSkillLineAbility` are AllowedWhenUntainted.

## Q3: Skill-ups in Classic Era vs Forever

### Findings
- **Colors** (https://warcraft.wiki.gg/wiki/Profession, https://warcraft.wiki.gg/wiki/Skill_up):
  - orange always grants a point; yellow about 60% ("Often"); green "Seldom"; grey 0.
  - "Exact chances for a skillup are not known." No formula is published on fetched pages; the `(grey−cur)/(grey−yellow)` formula is UNVERIFIED.
  - There are no skill-ups once you reach the max for your trained rank.
- **Forever skill-up rules**: the same color semantics apply (Warcraft Tavern, above).
- **Trainer ranks**, from https://www.wow-professions.com/forever/enchanting-leveling-guide (Forever beta data):
  - Journeyman (past 75): skill 50, level 10.
  - Expert (past 150): skill 125, level 20, 50s.
  - Artisan (past 225): skill 200, level 35. For enchanting, only Annora in Uldaman trains it.
  - The beta skill cap is 225.
- **Example route** (same guide): skill ranges per recipe, e.g. "1-2 Runed Copper Rod; 2-20 Inferior Stamina bracer; … 295-300 Superior Defense cloak".
  - Forever "added a few new low level recipes" so the first 70 points are cheaper. Otherwise the ranges match Classic, with some names and material counts changed.
  - Disenchant is in the Enchanting section of the Professions window, not the spellbook.
- **Tailoring:** "tons of new recipes", including spell-school caster sets and reagent bags. These are search snippets from https://www.wow-professions.com/forever/tailoring-leveling-guide (UNVERIFIED as page text).
- **Alchemy and leatherworking:** Forever changes not found. Mobalytics returned HTTP 403.
- **Legacy points:** awarded at 150, 225 and 300 in 6 crafting professions, 18 total (https://wow.gg/guides/wow-forever-legacy-points).
- **Published Forever guides** (based on beta): wow-professions.com, rankedboost.com/world-of-warcraft/forever/professions/, kami-labs.fr.
- **Threshold exposure:** the client documents only `relativeDifficulty` (Q2). The per-recipe numeric thresholds are not exposed by any API found.

## Q4: Inventory on Forever

### Findings
- **`Enum.BagIndex`** (https://warcraft.wiki.gg/wiki/Enum.BagIndex):
  - Backpack 0, Bag_1..4 = 1..4, ReagentBag 5, Characterbanktab −2, Accountbanktab −3;
  - `CharacterBankTab_1..6` = 6..11, `AccountBankTab_1..5` = 12..16.
  - The page has no Forever column. The per-version tables on the container API pages don't mark the bank rows for Forever (https://warcraft.wiki.gg/wiki/API_C_Container.GetContainerItemID). Forever's bank indices are UNVERIFIED on the wiki.
- **GuildStock `Bags.lua`** (a Forever addon; https://github.com/luisjedev/wow-forever-addons):
  - bank tabs `Enum.BagIndex.CharacterBankTab_1 .. CharacterBankTab_9`;
  - bags 0 .. `NumBagSlots + NumReagentBagSlots`, reading `C_Container.GetContainerItemInfo` through safe-call wrappers;
  - bank gated by `BankFrame.BankPanel:GetActiveBankType() == character` and `C_Bank.CanViewBank(character)`;
  - uses `bankPanel:EnumerateValidItems()`;
  - events: `BAG_UPDATE_DELAYED`, `BAG_CONTAINER_UPDATE`, `BANKFRAME_OPENED/CLOSED`, `BANK_TABS_CHANGED`, `PLAYERBANKSLOTS_CHANGED`, `SKILL_LINES_CHANGED`, `TRADE_SKILL_LIST_UPDATE`.
- **`C_Bank`** (pages list Forever):
  - `CanUseBank(bankType)`;
  - `FetchPurchasedBankTabData(bankType)`, which is nil when the bank isn't interactable;
  - `Enum.BankType`: 0 Character, 1 Guild, 2 Account.
  - Removed in Forever (`DIFF`): `C_Bank.FetchMaxNumBankTabs`, `ShouldUsePlayerBagsInBank`, `BankBagTypeAndIDToInvSlot`, and `ReagentsFromBankAllowed`.
- **Bank events:**
  - `BANKFRAME_OPENED`: no payload, listed for Forever.
  - `PLAYERBANKSLOTS_CHANGED(slot)`: does not fire for bank-bag contents (https://warcraft.wiki.gg/wiki/PLAYERBANKSLOTS_CHANGED).
- **`C_Item.GetItemCount(item[, includeBank[, includeUses[, includeReagentBank[, includeAccountBank]]]])`** is listed for Forever (https://warcraft.wiki.gg/wiki/API:C_Item.GetItemCount). Whether `includeBank` covers Forever bank tabs is UNVERIFIED.
- **Item info:** `C_Item.GetItemInfo` may return nil until cached. The page points to `Item:CreateFromItemID(id):ContinueOnItemLoad(fn)` (https://warcraft.wiki.gg/wiki/API:C_Item.GetItemInfo).
- **Merchant**
  - `C_MerchantFrame.GetItemInfo(index)` returns `{name, price, stackCount, numAvailable, isPurchasable, …}` and is listed for Forever (https://warcraft.wiki.gg/wiki/API:C_MerchantFrame.GetItemInfo).
  - Global `GetMerchantItemInfo` was removed in 12.0.0.
  - ProfessionShoppingList uses `MERCHANT_SHOW`, `GetMerchantNumItems()`, `GetMerchantItemID(i)` and `C_MerchantFrame.GetItemInfo(i).price`.

## Q5: Disenchanting

### Findings
- **Classic tables** (https://warcraft.wiki.gg/wiki/Disenchanting_tables, iLvl 1–60, marked outdated). Quantities are given as ranges.
- **Uncommon armor:**

| iLvl | Dust | Essence | Shard |
|---|---|---|---|
| 5–15 | Strange Dust 80% ×1–2 | Lesser Magic 20% ×1–2 | — |
| 16–20 | Strange Dust 75% ×2–3 | Greater Magic 20% | Small Glimmering 5% |
| 21–25 | Strange Dust 75% ×4–6 | Lesser Astral 15% | Small Glimmering 10% |
| 26–30 | Soul Dust 75% ×1–2 | Greater Astral 20% | Large Glimmering 5% |
| 31–35 | Soul Dust 75% ×2–5 | Lesser Mystic 20% | Small Glowing 5% |
| 36–40 | Vision Dust 75% ×1–2 | Greater Mystic 20% | Large Glowing 5% |
| 41–45 | Vision Dust 75% ×2–5 | Lesser Nether 20% | Small Radiant 5% |
| 46–50 | Dream Dust 75% ×1–2 | Greater Nether 20% | Large Radiant 5% |
| 51–55 | Dream Dust 75% ×2–5 | Lesser Eternal 20% | Small Brilliant 5% |
| 56–60 | Illusion Dust 75% ×1–2 | Greater Eternal 20% | Large Brilliant 5% |

- **Uncommon weapons:** same bands, with dust about 20% and essence about 75%. The 51–60 rows are dust 22%, essence 75%, shard 3%.
- **Rare:** one shard at 100%, banded:

| iLvl | Shard |
|---|---|
| ≤25 | Small Glimmering |
| 26–30 | Large Glimmering |
| 31–35 | Small Glowing |
| 36–40 | Large Glowing |
| 41–45 | Small Radiant |
| 46–50 | Large Radiant |
| 51–55 | Small Brilliant |
| 56–65 | Large Brilliant 99.5% / Nexus Crystal 0.5% |

- **Epic:** 40–45 Small Radiant ×2–4; 46–50 Large Radiant ×2–4; 51–55 Small Brilliant ×2–4; 56–60 Nexus Crystal ×1.
- **Required enchanting skill by iLvl** (https://warcraft.wiki.gg/wiki/Disenchanting):

| Uncommon iLvl | Skill |
|---|---|
| 1–20 | 1 |
| 21–25 | 25 |
| 26–30 | 50 |
| 31–35 | 75 |
| 36–40 | 100 |
| 41–45 | 125 |
| 46–50 | 150 |
| 51–55 | 175 |
| 56–60 | 200 |

  Rare items follow the same steps from 25 up.
- **Eligibility** (https://warcraft.wiki.gg/wiki/Disenchant): only uncommon, rare and epic armor or weapons can be disenchanted (spell 13262).
- **No API** exposes disenchant results or disenchantability. None was found on the wiki.
- **Forever:** Disenchant lives in the Enchanting section of the Professions window (Q3). No Forever-specific disenchant tables were found.

## Q6: Existing profession-leveling and recipe addons

### Findings
**Forever-targeted** (the CurseForge pages list 1.60.1):
- **Forever Profession Master** (https://www.curseforge.com/wow/addons/forever-profession-master; v1.6.2, 2026-10-15; interface 16000/16001):
  - data comes from what the client exposes;
  - routes: "Cheapest and Fastest" per profession, adding extra materials for failed skill-ups, color-coded by skill-up chance;
  - the shopping list is merged, shows owned vs remaining, and is split into vendor / AH / unavailable; buys via vendor (respecting bundle sizes) or AH with confirmation;
  - a standalone window, not attached to Blizzard's frame;
  - the algorithm is not described.
- **Forever Buddy** (https://www.curseforge.com/wow/addons/forever-buddy; v1.0.1, 2026-10-04):
  - static data extracted from the Forever client files via wago.tools: 2,329 recipes in 13 professions;
  - per-recipe shopping list (breaks the recipe down to base materials, minus bags and bank).
- **WoW Forever Tracker** (https://www.curseforge.com/wow/addons/wow-forever-tracker; 2026-10-19): the website computes "the cheapest way to level a profession", with the addon as companion. Prices come from your own AH scans or Auctionator.
- **ProfessionShoppingList** (https://github.com/Slackluster/ProfessionShoppingList): TOC `16001, 120105`. It detects Forever via `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`, hooks `ProfessionsFrame` and does recipe tracking only.
- **SkillUp Forever** (Q2): bundled threshold data plus an audit command.

**Classic Era only:**
- **CraftSage** (https://github.com/Rabzizz/CraftSage; interface 11508):
  - static step tables (`CraftSageData["Tailoring"].steps[] = {recipe, spell_id, skill_up_to, qty, mats, step_type}`) built from Wowhead guides with about 30% padding;
  - `Panel:Refresh` only computes the remaining count with `math.ceil`;
  - the panel is anchored to `TradeSkillFrame` with `HookScript("OnHide")`;
  - uses the legacy calls `GetNumTradeSkills`, `GetTradeSkillInfo` and `GetItemCount`.
- **craftplaner** (https://www.curseforge.com/wow/addons/craftplaner):
  - tailoring and enchanting only;
  - rescans after each craft and recomputes the step plan, preferring disenchantable items;
  - trainer-only filter;
  - caches the bank from the last visit.
- **What's Crafting?** (https://www.curseforge.com/wow/addons/whats-crafting): a per-character recipe cache and trainer scans, shown in its own window.
- **Skillet-Classic** (https://github.com/b-morgan/Skillet-Classic):
  - replaces the Blizzard frame (`DisableBlizzardFrame`);
  - detects Forever through `LE_EXPANSION_LEVEL_CURRENT` (the comment says Forever has no distinct `_PROJECT`, while ProfessionShoppingList uses `WOW_PROJECT_CAMELOT`);
  - inventory comes from `GetItemCount(id, includeBank)`;
  - static `SkillLevelData*.lua`.

**Mainline-window breakage:** the Classic addons depend on `TradeSkillFrame` and `GetTradeSkillInfo`. The legacy `GetNumTradeSkills` page has no Forever tag (https://warcraft.wiki.gg/wiki/API:GetNumTradeSkills). None of the source read contains a path solver (greedy or dynamic programming); route steps are precomputed or computed server-side.

## Cross-Cutting Observations
- **One API surface:** the Forever client uses the Mainline `C_TradeSkillUI`, `C_Container`, `C_Bank`, `C_Item` and `C_MerchantFrame`. The legacy `GetTradeSkillInfo`-family calls are absent or untagged.
- **Two data strategies:** static data from client files or guides (Forever Buddy, CraftSage, SkillUp Forever) vs live client scans (Forever Profession Master, What's Crafting?). Live scans give difficulty colors only, not threshold numbers.
- **Existing Forever addons already cover leveling routes and shopping lists:** Forever Profession Master, Forever Buddy and WoW Forever Tracker, all dated October 2026.
- **Repo conventions available to copy:**
  - the namespace header;
  - the Logic/test split;
  - nil-safe SavedVariables;
  - the `WowStyle1DropdownTemplate` window;
  - the CI workflow, whose addon-specific strings are listed in Q1.

## Open Areas
- Whether `maxTrivialLevel` (or any numeric threshold) is populated on Forever. An in-game check is needed.
- The 600+ new recipes for alchemy, leatherworking and tailoring, and their thresholds. Mobalytics and Blizzard sources were not read.
- Forever bank container indices; whether `GetItemCount(includeBank)` covers bank tabs; `C_Bank.CanViewBank`.
- Whether Blizzard_Professions is load-on-demand on Forever, and the exact `ProfessionsFrame` child names for anchoring.
- The skill-up chance formula (no official source).
- Forever disenchant table changes.
- The algorithms behind Forever Profession Master and WoW Forever Tracker (source not read).
