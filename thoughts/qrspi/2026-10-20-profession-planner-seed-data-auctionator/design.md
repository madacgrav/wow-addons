# Design Discussion

## Current State
- **Thresholds are learned only by playing.**
  - `PP.LearnThresholds` records yellow/green when a color change is seen between scans (`Logic.lua:117-127`).
  - `PP.LearnGrey` takes grey from `maxTrivialLevel` (`Logic.lua:130-136`).
  - A fresh character therefore plans one step "until color changes" and stops (`Logic.lua:79-85`).
- **Recipes come only from the open profession window.**
  - Learned recipes only (`Core.lua:42`), stored per character as `recipes[profID][recipeID] = {name, icon, reagents, color, maxTrivial, ...}` (`Core.lua:43-62`).
  - The game also lists unlearned recipes (Tailoring 471 total, 40 learned), which are skipped.
- **Prices come only from vendor scans.**
  - `ScanMerchant` writes `db.prices[itemID]` (`Core.lua:107-114`).
  - Unpriced reagents cost a flat `UNKNOWN_COST = 10000` in Plan (`Panel.lua:50`), with no "estimated" marker.
  - ShoppingList shows no price for them (`Logic.lua:99`, `Panel.lua:77`).
- **There is no cross-addon code anywhere.**
  - No `OptionalDeps` in either .toc (`ProfessionPlanner.toc`, `WarlockUtilityKit.toc`).
  - The only optional-global pattern is the nil-checked `_G[name]` lookup (`WarlockUtilityKit/Dock.lua:11,19`).
- **What research established:**
  - **Forever's own game tables** (wago.tools, build 1.60.1.70450) give, per recipe spell:
    - grey = `TrivialSkillLineRankHigh` (66/66 in-game matches).
    - yellow = `TrivialSkillLineRankLow` (3/3).
    - green = midpoint (2/2).
    - reagents from `SpellReagents`.
    - output item from `SpellEffect` (Effect 24).
    - learn-at skill for pattern-taught recipes from the item's `ItemSparse.RequiredSkillRank`.
  - **Era data differs from Forever** for some recipes.
  - **Guide sites** publish route tables only, with Era numbers, and are copyrighted.
  - **Auctionator 340 is installed and supports Forever.**
    - `Auctionator.API.v1.GetAuctionPriceByItemID(callerID, itemID)` returns copper or nil.
    - It returns nil until Auctionator's `PLAYER_LOGIN`.
    - `RegisterForDBUpdate` fires after scans (ModernAH branch, active on Forever).
  - **QuestieDB is installed with a Forever build**, exposing `_G.LibQuestieDB.Item.vendors(id)` and `Npc.name/subName/zoneID/friendlyToFaction`.
  - **Recipe sources:** the Forever UI calls `C_TradeSkillUI.GetRecipeSourceText(recipeID)` for unlearned recipes. Its output on Forever is unobserved.

## Desired End State
- **On a character with no learned thresholds**, opening Tailoring/Enchanting/Leatherworking/Alchemy shows a multi-step plan to the next bracket. Each step ends at a concrete `-> skill`, driven by seeded thresholds.
- **In-game observations still win.**
  - Scanned reagents override seeded ones.
  - Learned thresholds override seeded ones per color.
  - Vendor-scanned prices are kept as today.
- **The planner also considers unlearned recipes** whose learn-at skill is reached.
  - Such a step reads e.g. `Learn: Pattern: Red Woolen Bag (vendor) then x12 Red Woolen Bag -> 115`.
  - The pattern's price is included in the step cost when known.
- **Reagent price = cheapest known of (vendor scan, Auctionator AH).**
  - If neither is known, fall back to the seeded base vendor price for items QuestieDB says a vendor sells.
  - Otherwise use the unknown cost, and the cost is marked as an estimate.
- **Shopping list rows show the price source** (`vendor` / `AH` / `est.`).
  - When QuestieDB is loaded they also show the first faction-appropriate vendor: name and zone.
- **A short hand-written route hint per bracket** (our own words, checked against seed data) shows under the header. It is the fallback text when no plan step exists.
- **Everything works with Auctionator and QuestieDB absent.** No errors, and those features are simply not shown.

### Verification
- `lua ProfessionPlanner/tests/run.lua` passes, with new cases for:
  - seed/learned threshold merge;
  - seed/scan reagent merge;
  - unlearned-recipe eligibility and learn step;
  - price pick (min, sources, fallback, estimate flag);
  - every hint's recipe being orange/yellow/green across its stated range per seed thresholds.
- In game (Forever):
  - A fresh Tailoring character shows ≥2 steps with `->` targets before any learning.
  - After an Auctionator full scan, the panel refreshes and some rows show `AH`.
  - With Auctionator and QuestieDB disabled, the panel still works.
  - `/pp probe` output documents `GetRecipeSourceText` / `GetRecipeRequirements` / `sourceType` for unlearned recipes.

## Patterns to Follow
- **Shared private namespace:** `local ADDON, PP = ...` at the top of every file (`Logic.lua:1`, `Core.lua:1`, `Panel.lua:1`). The new `Data.lua` and `Hints.lua` use it too and only assign tables onto `PP`.
- **Pure logic in Logic.lua, tested by `tests/run.lua`** with the `eq` helper and fixture builder `S(o)` (`tests/run.lua:5-7,25-26`).
  - Price picking, threshold merge and unlearned eligibility go in Logic.lua as pure functions taking plain tables.
  - Core/Panel do the WoW/addon API calls and pass the tables in.
  - This is how `Plan` gets `prices`/`thresholds` today (`Panel.lua:65-66`).
- **Events:**
  - `PP.On(event, fn)` registered inside `PP.inits` (run on `PLAYER_LOGIN`, `Core.lua:23,116-129`).
  - UI updates through `PP.refreshers` / `PP.Refresh()` (`Core.lua:14`, `Panel.lua:60`).
  - Auctionator's DB-update callback just calls `PP.Refresh()`.
- **Saved variables:** defaults via `PP.MergeDefaults` in `ADDON_LOADED` (`Core.lua:16-22`, nil-safe for the Forever loader bug). New saved state, if any, goes through the same call.
- **Optional globals:** nil-check before use, like `WarlockUtilityKit/Dock.lua:11,19`.
  - Third-party calls are wrapped in `pcall`, because Auctionator raises `error()` on bad arguments (`Auctionator\Source\API\Internal.lua:1-13`).
- **One-time probe command** for unknown APIs: `PP.Probe` / `/pp probe` (`Core.lua:132-165`, `167-193`). Extend it rather than adding a new command.
- **Do NOT follow:**
  - **Silent unknown-cost inflation** (`Panel.lua:50`, `Logic.lua:56`). Steps using the fallback must carry an `estimated` flag that the panel shows.
  - **Writing derived data into SavedVariables.**
    - `db.prices` stays vendor-scan only; AH prices are read live.
    - Seed data is never copied into `db.thresholds` or `char.recipes`. Merges happen in memory per refresh.
  - **`UNKNOWN_COST` living in Panel.lua** while Logic depends on it. Pass it the same way, but keep the value in one place.

## Design Decisions
1. **Seed source = Forever game data, generated offline.**
   - A dev-only script `ProfessionPlanner/tools/gen_seed.py` reads wago.tools CSV exports for a pinned Forever build and writes a committed `ProfessionPlanner/Data.lua`.
   - Tables used: SkillLineAbility, SpellReagents, SpellEffect, ItemEffect, ItemXItemEffect, ItemSparse, SpellName.
   - Scope: the 4 supported professions only. Rows with High=0 (rank spells) are dropped.
   - The script is not listed in the .toc. It lists Data.lua first in the .toc.
   - Why: it matched every in-game observation, guide numbers are Era-based, and guide text is copyrighted.
2. **Seed shape:**
   - `PP.SEED.recipes[spellID] = { prof, yellow, green, grey, reagents = {{itemID, qty}}, item, learnAt?, taughtBy? }`, where `taughtBy` is the pattern itemIDs.
   - `PP.SEED.price[itemID] = BuyPrice` for reagent and pattern items only.
   - `green = math.ceil((yellow + grey) / 2)`; recorded as a known approximation.
   - Keyed by the same recipeID the scan uses (`Core.lua:37`).
3. **Precedence:**
   - **Thresholds:** in-game learned value wins, per color, else seed.
   - **Reagents:** scanned schematic wins (`Core.lua:44-56`), else seed.
   - **Recipe list:** the scanned list (learned and unlearned) is the source of which recipes exist for this character. Seed only annotates them, so recipes not offered on the character's client never appear.
4. **Guide hints:**
   - `ProfessionPlanner/Hints.lua` holds `PP.HINTS[prof] = { {from, to, recipeID, note?}, ... }`, about 6-12 rows per profession, written by us.
   - Guides are used only to sanity-check route choice; no text is copied.
   - The display name comes from the scanned or seeded recipe name.
   - A test asserts each hint recipe is not grey within its range per seed thresholds. This catches Era numbers leaking in.
5. **Unlearned recipes:**
   - `ScanProfession` also stores unlearned recipes, with `learned = false` and the source text from `GetRecipeSourceText` when the API exists.
   - Plan treats an unlearned recipe as a candidate only when:
     - its seed `learnAt` ≤ the current skill, or
     - (trainer recipes without learnAt) the game reports it as learnable. The exact signal is settled by the probe in the first slice.
   - A chosen unlearned step gets `learn = {source, taughtBy}`, and the pattern's price is added to the step cost.
   - The seed carries no trainer cost.
6. **Prices:**
   - Logic: `PP.PickPrice(vendor, ah, seed, vendorSold)` returns `price, source`.
     - Rule: min of the known vendor/AH prices.
     - If neither is known: the seed price when `vendorSold`.
     - Otherwise nil.
   - Panel builds the per-refresh `prices` table for the reagents and patterns involved and passes it to Plan/ShoppingList as today. Steps whose cost used `unknownCost` get `estimated = true`.
7. **Auctionator integration:**
   - .toc gets `## OptionalDeps: Auctionator, QuestieDB`.
   - The AH lookup is `pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "ProfessionPlanner", id)`, guarded by `Auctionator and Auctionator.API and Auctionator.API.v1`. A nil result means no price.
   - `RegisterForDBUpdate("ProfessionPlanner", PP.Refresh)` is registered once in a `PP.inits` function, also under pcall.
   - No staleness filter; Auctionator already drops items unseen for more than 21 days from age reporting.
8. **QuestieDB integration:**
   - When `_G.LibQuestieDB` exists and `RequireContract(3)` is true, `PP.VendorFor(itemID)` returns the first vendor NPC whose `friendlyToFaction` matches `UnitFactionGroup("player")`.
     - It returns `{name, zone}`, with the zone from `C_Map.GetAreaInfo(zoneID)`.
     - "First", not nearest.
   - The same lookup supplies `vendorSold` for Decision 6.
   - All of this lives in Core.lua behind one function, so Panel stays dumb.

9. **Flyout and click-to-craft** (added 2026-10-20 at the user's request):
   - The panel becomes a flyout toggled by an edge tab under Forever's side profession tabs. Open/closed is remembered account-wide.
   - Clicking a plan step selects the recipe with the count filled in; shift-click crafts.
   - `C_TradeSkillUI.CraftRecipe` is called inside the click handler (hardware event).

10. **Route hints dropped** (2026-10-20): Classic guide routes don't fit Forever's reworked professions (renamed Alchemy recipes, short-range Forever-only recipes, moved thresholds); the live planner covers routing.

## What We're NOT Doing
- **Other professions.** No Blacksmithing, Engineering, Cooking, First Aid etc. `PP.PROFESSIONS` stays the same 4.
- **Era/Anniversary/other-client data.** The seed targets Forever only.
- **Downloading or scraping at runtime**, or copying guide text.
- **Scanning the AH ourselves**, TSM or other price addons, or price history and averages.
- **Trainer training costs**, trainer NPC locations, nearest-vendor pathing, or map pins.
- **Merchant's Favor (extended-cost) recipes.** They stay skipped, as in `Core.lua:110`.
- **Replacing the greedy 3-step planner** with DP. That is a `ponytail:` note at `Logic.lua:62`.
- **Automatic seed refresh in game.** Regenerating = rerun the script for a new build.
- **Persisting AH prices or seed data in SavedVariables.**

## Open Risks
- **`GetRecipeSourceText` / `GetRecipeRequirements` / `sourceType` on Forever are unobserved.** Whether trainer recipes expose a learn-at skill is unknown. Mitigation: the first slice is an in-game probe; if no signal exists, unlearned trainer recipes are listed as "available at trainer" but not planned.
- **The green threshold formula** rests on 2 samples and the rounding is guessed. A one-point error only shifts a step boundary; learned values override it.
- **Seed staleness:** Forever patches can change thresholds. The script pins a build string, written into Data.lua as `PP.SEED.build`, and learned values override.
- **Data.lua size/load time:** about 1,585 recipes, with item rows trimmed to reagents and patterns. Estimated at under 200 KB; check that load time is not noticeable.
- **Professions 165/171** are unverified in game. Seed rows exist; the scan filter is unchanged.
- **Auctionator has not been called on Forever by this addon yet.** pcall plus nil-handling covers failures, and an in-game check is in the verification list.
- **QuestieDB contract or field changes** in future releases. Guarded by `RequireContract(3)`.
- **The 10% vendor discount** (likely Honored reputation) means the seed `BuyPrice` overstates cost when no scan exists. That is acceptable for a fallback and is labelled `est.`.
- **Data sources' terms:**
  - The seed is Blizzard client data via wago.tools, which states no terms.
  - Auctionator and QuestieDB are only called at runtime, not redistributed.
