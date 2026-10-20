# Structure Outline

## Approach
- An offline script turns Forever game tables into a committed `Data.lua`.
- Logic.lua gains pure merge and price functions.
- Core.lua gains optional Auctionator and QuestieDB lookups behind nil-checks and `pcall`.
- Each phase ships a visible panel improvement and is deployed to `_classic_beta_\Interface\AddOns` for an in-game check.

Test command: `lua ProfessionPlanner/tests/run.lua`.

---

## Phase 1: Probe unlearned-recipe APIs
Extend `/pp probe` so one in-game run tells us what Forever exposes for unlearned recipes. Phase 5 depends on the answer.

**Files**: `ProfessionPlanner/Core.lua`, `thoughts/.../probe-results.md` (new, findings)

**Key changes**:
- `PP.Probe()` (modified) prints the following for the first 5 unlearned recipes:
  - `GetRecipeInfo` fields `sourceType`, `disabled`, `disabledReason`, `relativeDifficulty`, `maxTrivialLevel`.
  - `C_TradeSkillUI.GetRecipeSourceText(id)`, if the function exists.
  - `C_TradeSkillUI.GetRecipeRequirements(id)` entries.
- It also prints whether `Auctionator.API.v1` and `LibQuestieDB` exist, and the result of a single `pcall`'d Auctionator price lookup for one reagent.

**Verify**:
- Tests still pass.
- In game, `/pp probe` with Tailoring open prints the above.
- Results are recorded in `probe-results.md`, including whether trainer recipes reveal a learn-at skill.

---

## Phase 2: Seeded thresholds and reagents
A fresh character gets a multi-step plan with concrete `-> skill` targets.

**Files**:
- `ProfessionPlanner/tools/gen_seed.py` (new, dev only)
- `ProfessionPlanner/Data.lua` (new, generated)
- `ProfessionPlanner/ProfessionPlanner.toc` (adds `Data.lua` first)
- `ProfessionPlanner/Logic.lua`
- `ProfessionPlanner/Panel.lua`
- `ProfessionPlanner/tests/run.lua`

**Key changes**:
- `gen_seed.py <build> <out>` fetches the wago.tools CSVs for the build, keeps professions 197/333/165/171, and drops High=0 rows.
- `Data.lua` defines:
  ```lua
  PP.SEED = {
    build = "1.60.1.70450",
    recipes = { [spellID] = { prof, yellow, green, grey, reagents = { {itemID, qty} }, item, learnAt?, taughtBy? } },
    price = { [itemID] = buyPrice },  -- reagent + pattern items only
  }
  ```
  `green = ceil((yellow + grey) / 2)`.
- `PP.MergeThresholds(learned: th?, seed: seedRecipe?): th?` (new, Logic) builds a per-color merge where the learned value wins.
- `PP.MergeReagents(scanned: reagents, seed: seedRecipe?): reagents` (new, Logic) uses the scan if it is non-empty, else the seed.
- The Panel refresher builds `thresholds` / `recipes` views for the current profession through these functions before `PP.Plan`. Nothing is written to SavedVariables.

**Verify**:
- New tests:
  - merge precedence per color;
  - seed-only plan yields ≥2 steps with `toSkill`;
  - seed reagent fallback.
- A spot-check test asserts Data.lua values for spells 3755 (grey 65, yellow 30) and 3757 (110/75).
- In game, a profession with no learned thresholds shows multiple `->` steps. The footer counts seeded thresholds.

---

## Phase 3: Auctionator prices and price sources
Reagent price becomes the cheapest of vendor scan and AH. Unknown costs are flagged, and the panel shows each price's source.

**Files**: `Logic.lua`, `Core.lua`, `Panel.lua`, `ProfessionPlanner.toc` (`## OptionalDeps: Auctionator, QuestieDB`), `tests/run.lua`

**Key changes**:
- `PP.PickPrice(vendor?, ah?, seed?, vendorSold?): price?, source?` (new, Logic):
  - Returns the minimum of vendor and ah, with source `"vendor"` or `"AH"`.
  - Else returns `seed, "est."` when `vendorSold`.
  - Else returns `nil`.
- `PP.AHPrice(itemID): copper?` (new, Core): `pcall` on `Auctionator.API.v1.GetAuctionPriceByItemID("ProfessionPlanner", id)`, guarded by nil-checks.
- In a `PP.inits` function, `pcall` `RegisterForDBUpdate("ProfessionPlanner", PP.Refresh)`.
- `PP.Plan` steps gain `estimated = true` when any reagent used `unknownCost`.
- `ShoppingList` entries gain a `source` field.
- `UNKNOWN_COST` moves to `PP.UNKNOWN_COST` in Logic.lua.
- Panel: the step sub-text shows `~` before the cost when it is estimated. Shopping rows show `@ price (vendor|AH|est.)`.

**Verify**:
- Tests: PickPrice cases (min, single source, seed fallback only when vendorSold, nil); the estimated flag on Plan.
- In game:
  - With Auctionator after a scan, some rows show `AH` and the panel refreshes when the scan completes.
  - With Auctionator disabled, the panel shows no errors and only `vendor` prices.

---

## Phase 4: QuestieDB vendors and seed price fallback
Buyable rows name a vendor, and vendor-sold items without a scan get the seeded base price as `est.`.

**Files**: `Core.lua`, `Panel.lua`

**Key changes**:
- `PP.VendorFor(itemID): { name, zone }?` (new, Core):
  - Guarded by `_G.LibQuestieDB` and `RequireContract(3)`.
  - Returns the first vendor whose `friendlyToFaction` matches `UnitFactionGroup("player")`.
  - Zone comes from `C_Map.GetAreaInfo(zoneID)`.
- The Panel price builder passes `vendorSold = PP.VendorFor(id) ~= nil` and `seed = PP.SEED.price[id]` into `PickPrice`.
- Shopping rows append ` - <vendor> (<zone>)` when `buy > 0` and a vendor is known.

**Verify**:
- Tests still pass; PickPrice already covers the fallback.
- In game:
  - Coarse Thread shows a faction-correct vendor and zone.
  - An unscanned vendor reagent shows `est.` priced at its base.
  - With QuestieDB disabled, rows show no vendor and no `est.` seed prices.

---

## Phase 5: Unlearned recipes in the plan
The planner can pick a recipe you haven't learned yet and tells you where to learn it. Pattern cost is included.

**Files**: `Core.lua`, `Logic.lua`, `Panel.lua`, `tests/run.lua`

**Key changes**:
- `PP.ScanProfession` (modified) also stores unlearned recipes: `{ learned = false, name, icon, source = GetRecipeSourceText(id)? }`, with reagents from the schematic or the seed.
  - Learn-colors only run for learned recipes.
- `PP.Learnable(r, seedRecipe, skill): bool` (new, Logic):
  - True when `seed.learnAt <= skill`.
  - Otherwise uses the Phase 1 trainer signal (e.g. `not disabled`). If there is none, it returns false for trainer recipes.
- `PP.Plan` (modified):
  - Candidates are learned recipes plus `Learnable` unlearned ones.
  - An unlearned step gets `learn = { source?, taughtBy? }`.
  - The pattern price is added to `cost`, via `prices[taughtBy[1]]`.
  - The starting color of an unlearned recipe comes from the projected thresholds at the current skill, starting from orange. This needs `ProjectColor` to start from orange, i.e. `curSkill = learnAt`.
- Panel: a learn step renders a `Learn: <pattern or "trainer"> - <source/vendor>` row before the craft row.

**Verify**:
- Tests:
  - an unlearned recipe with `learnAt` ≤ skill is chosen when cheapest;
  - `learnAt` > skill is excluded;
  - pattern cost is included;
  - a learned recipe is preferred on a tie.
- In game, Tailoring near skill 90 suggests Red Woolen Bag with "Learn: Pattern: Red Woolen Bag" and its vendor.

---

## Phase 6: Route hints
A short bracket hint is written by us and checked against the seed. It shows under the header, and it is the fallback text when the plan is empty.

**Files**: `ProfessionPlanner/Hints.lua` (new, in .toc after Data.lua), `Panel.lua`, `tests/run.lua`

**Key changes**:
- `PP.HINTS[prof] = { { from, to, recipeID, note? } }`: about 6-12 rows each for 197/333/165/171.
- `PP.HintFor(prof, skill): hint?` (new, Logic) returns the row covering `skill`.
- Panel: the header gets a line `Guide: <recipe name> until <to>`. The "No recipe gives skill-ups here" row is replaced by the hint when one exists.

**Verify**:
- Test: for every hint row, the seed thresholds put the recipe at orange/yellow/green, not grey, for each skill in `[from, to)`, using the seed's `learnAt` when present.
- Test: hint ranges per profession are contiguous from 1 to 300.
- In game, the header shows the hint matching the current skill.

---

## Testing Checkpoints
| After | True |
|---|---|
| Phase 1 | Probe documents unlearned-recipe APIs, Auctionator and QuestieDB presence. No behavior change. |
| Phase 2 | Fresh characters get multi-step plans from seed data. Learned thresholds and scanned reagents still win. |
| Phase 3 | Prices are the cheapest of vendor and AH, with source tags. Estimates are flagged. Works without Auctionator. |
| Phase 4 | Vendor names and zones from QuestieDB. Seed base price is used as `est.` for vendor-sold items. Works without QuestieDB. |
| Phase 5 | The plan can include learn-then-craft steps with pattern cost. Trainer recipes are handled per the Phase 1 findings. |
| Phase 6 | Route hints are shown and verified against seed data by tests. |

After each phase: run the tests, deploy with robocopy to `_classic_beta_\Interface\AddOns\ProfessionPlanner`, then do the in-game check.
