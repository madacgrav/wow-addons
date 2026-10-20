# Design Discussion

Refs: `R:Qn` = sections of this folder's `research.md`. `WUK/…` = `WarlockUtilityKit/…`.

## Current State
- **The repo has one addon, `WarlockUtilityKit/`.** It uses:
  - a shared namespace header;
  - pure logic in `Logic.lua`, tested by `tests/run.lua` under Lua 5.1 in CI;
  - nil-safe SavedVariables;
  - a lazy `BasicFrameTemplateWithInset` window with `WowStyle1DropdownTemplate`;
  - a per-addon CI workflow that zips and releases on merge (R:Q1).

  A `ProfessionPlanner/` folder does not exist yet.
- **Forever uses the Mainline profession API** (R:Q2):
  - `C_TradeSkillUI.GetAllRecipeIDs`, `GetRecipeInfo` (with `relativeDifficulty` 0–3 and `learned`), `GetRecipeSchematic` (reagents, outputs), and `GetBaseProfessionInfo` (`skillLevel`, `maxSkillLevel`, `professionID`);
  - the window is `ProfessionsFrame`;
  - legacy `GetTradeSkillInfo` and `C_SkillInfo` are gone.
- **No API exposes skill-up threshold numbers, only the current color.** `maxTrivialLevel` exists, but whether it is populated is UNVERIFIED (R:Q2/Q3).
- **Inventory:** bags come from `C_Container`; the bank from character bank tabs `Enum.BagIndex.CharacterBankTab_1..9` while it is open (GuildStock pattern). Merchant prices come from `C_MerchantFrame.GetItemInfo` (R:Q4).
- **Competitors** (R:Q6): Forever Profession Master, Forever Buddy and WoW Forever Tracker already plan routes and shopping lists, all in standalone windows or a website. None attaches a panel to the profession window or learns thresholds from play.

## Desired End State
A separate addon, **`ProfessionPlanner/`**, with its own TOC, SavedVariables, tests, CI workflow and `pp-v<version>` release.

1. **Side panel.** When `ProfessionsFrame` is open on tailoring, enchanting, leatherworking or alchemy, a panel docks to its right edge. It shows:
   - **Header:** profession, current skill, target bracket (the next of 75/150/225/300 above current, capped by `maxSkillLevel`).
   - **Next 3 steps:** recipe icon and name, color, "×N → skill S" (or "until it turns yellow/green" when the threshold isn't known yet), and the cost of the step.
   - **Shopping list** for those steps: item, need, have (bags + cached bank), still to buy, and a vendor price if known.
   - It refreshes on every craft and every list update. There is no configuration.
2. **Learned thresholds.**
   - Each scan records the color of every learned recipe at the current skill.
   - When a recipe's color changes between scans, the skill at the change is saved as that recipe's yellow, green or grey threshold. Thresholds are stored account-wide, so alts benefit.
   - A populated `maxTrivialLevel` is taken as the grey threshold directly.
3. **Prices.** On every merchant visit, `price/stackCount` is saved for each item. The planner costs owned items at 0, vendor items at their learned price, and anything else at a flat weight.
4. **`/pp probe`** prints, for the open profession, a few recipes with `relativeDifficulty`, `maxTrivialLevel`, `numSkillUps` and the schematic reagent counts, plus `GetItemCount(includeBank)` vs the bag scan. This settles the open API questions in game.
5. **Verification**
   - `tests/run.lua` covers the planner, threshold learning, bracket choice and shopping-list math.
   - In game: open Tailoring at skill N; the panel shows sensible orange or yellow next steps and a shopping list matching bags and bank. After crafting, it updates. After enough skill-ups, the thresholds learned for those recipes show real "→ skill S" numbers.

## Patterns to Follow
- **Namespace and split:**
  - `local ADDON, PP = ...` in every file (`WUK/Core.lua:1` pattern);
  - pure planner and threshold code in `Logic.lua`, loaded alone by `tests/run.lua` (`WUK/tests/run.lua:1-7`).
- **Lifecycle:** one `PP.On` dispatcher, plus `inits` and `refreshers` arrays (`WUK/Core.lua:3, 11-17`).
- **SavedVariables:** `ADDON_LOADED` + `MergeDefaults`, nil-safe (`WUK/Core.lua:19-28`, `WUK/Logic.lua:16-23`). Copy `MergeDefaults`; don't depend on WUK.
- **Secret guard** helper (`WUK/Core.lua:7`) on any value read during a scan.
- **CI:** copy `package-wuk.yml` to `package-pp.yml`, changing only the addon-specific strings listed in R:Q1 (paths filter, TOC path, zip name, `pp-v` tag, title).
- **Deploy after each phase:** robocopy to `_classic_beta_\Interface\AddOns\ProfessionPlanner`.
- **Profession window access:** like Hemlock Forever, read `GetBaseProfessionInfo()` and `IsTradeSkillReady()` and check `ProfessionsFrame:IsShown()` (R:Q2).
- **Bank scan:** like GuildStock, only while `BANKFRAME_OPENED`, iterating `Enum.BagIndex.CharacterBankTab_1..9` with `C_Container.GetContainerItemInfo` (R:Q4).

**Do NOT:**
- use legacy `GetTradeSkillInfo`, `GetNumTradeSkills`, `TradeSkillFrame` or `C_SkillInfo` (removed or untagged on Forever, R:Q2/Q6), as the Classic addons do;
- call `OpenTradeSkill`, which needs a hardware event; the panel only reacts to the window the player opened;
- hook `ProfessionsFrame.CraftingPage.SchematicForm` internals; anchoring to `ProfessionsFrame` alone is less fragile across builds;
- ship static recipe or threshold tables (task constraint; the CraftSage/SkillUp approach goes stale);
- share files with WarlockUtilityKit.

## Design Decisions
1. **Positioning: a side panel on `ProfessionsFrame`, live client data, zero setup.** This is the PRD's original design and differs from the standalone-window competitors.
2. **Profession detection: by skill-line ID**, not by name. Tailoring 197, Enchanting 333, Leatherworking 165, Alchemy 171 (Classic IDs). Unknown professions get no panel. `/pp probe` prints the IDs so they can be verified.
3. **Planner: greedy, re-planned after every scan** (pure `PP.Plan(state) → steps[]`). At the current skill, every learned, craftable-in-principle recipe that is orange or yellow is scored as `expected cost per skill point = craftCost / chance`:
   - Chance: orange 1.0, yellow 0.6 (from the wiki's "~60%"), green 0.25. Green is only used when no orange or yellow recipe exists. Grey is never used.
   - Cost: Σ (reagent qty × unit price), where owned units are consumed first at 0, vendor units use the learned price, and unknown units use a flat 1g weight.

   The cheapest recipe becomes step 1, and its length runs to its next known threshold or the target bracket. Steps 2 and 3 repeat from the projected skill, using learned thresholds to project colors. When a projection is unknown, the step shows "until color changes" and planning stops after it.
   - *ponytail:* greedy rather than optimal. A DP over skill points is the upgrade if plans look poor.
4. **Threshold learning (pure `PP.LearnThresholds(prev, cur, skill)`)**
   - Data: `db.thresholds[recipeID] = { yellow=, green=, grey= }`, the first skill at which each color was seen.
   - Updates are monotonic: a value is only set when a color change is observed, and a lower observed value replaces a higher one.
5. **Inventory**
   - Bags are scanned live on `BAG_UPDATE_DELAYED`.
   - The bank is scanned while open (`BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED`, `BAG_UPDATE_DELAYED` while open) and saved per character as `char.bank[itemID] = count`.
   - Have = bags + cached bank.
6. **Recipe cache.**
   - Saved per character: `char.recipes[professionID]` holds `{ id, name, icon, learned, color, reagents={{itemID, qty}}, qtyMin }` per recipe, refreshed on `TRADE_SKILL_LIST_UPDATE` / `TRADE_SKILL_SHOW` while `IsTradeSkillReady()`.
   - Schematics are cached once per recipe, since reagents don't change, so later scans only read colors.
7. **SavedVariables**
   - `ProfessionPlannerDB` (account): `thresholds`, `prices`, `panel` options.
   - `ProfessionPlannerCharDB`: `recipes`, `bank`.
8. **Files**
   - `ProfessionPlanner.toc`
   - `Logic.lua` (Plan, LearnThresholds, NextBracket, ShoppingList, MergeDefaults)
   - `Core.lua` (events, SavedVariables, scans, slash `/pp`, probe)
   - `Panel.lua` (side panel)
   - `tests/run.lua`
   - `.github/workflows/package-pp.yml`

## What We're NOT Doing
- Disenchant-aware planning for the tailoring → enchanting loop (deferred to v2; Forever's disenchant data is unverified).
- Auction house prices, Auctionator integration, buying anything (vendor or AH).
- Alt recipe tracker, trainer-only filter, map pins, Legacy-point display (PRD v2).
- Professions beyond the four in v1.
- A community threshold overlay or import/export (PRD mentions it; later).
- Unlearned-recipe suggestions ("train X next"). The planner only uses learned recipes.
- Crafting automation (`CraftRecipe` buttons) and any secure or protected actions.
- Localization (thresholds and recipes are keyed by ID; the UI strings are enUS).

## Open Risks
- **`relativeDifficulty` may lag** behind skill until `TRADE_SKILL_LIST_UPDATE`. Learning only on list updates while `IsTradeSkillReady()` handles that.
- **Classic skill-line IDs on Forever** (197/333/165/171) are unverified; `/pp probe` confirms them in Phase 1.
- **Bank tabs:** whether `CharacterBankTab_1..9` are the right indices and readable on Forever (GuildStock assumes so); verify with the probe.
- **The 0.6 / 0.25 chances are guesses** (no official formula, R:Q3). They only affect ranking, and the plan re-runs after every craft anyway.
- **Recipes with multiple outputs, and enchanting recipes** with no output item (`recipeType` 3), just count as crafts. That's fine for skill planning.
- **`ProfessionsFrame` layout changes** between builds could overlap the panel. Anchor only to the frame's outer edge.
- **Competitor overlap:** Forever Profession Master may add a docked panel. Our advantage is learned thresholds plus zero setup.
