# Structure Outline

## Approach
- New `ProfessionPlanner/` addon (namespace `PP`), built in four slices:
  1. a loadable skeleton with `/pp probe` and CI, to settle API unknowns in game first;
  2. a docked panel listing the best-colored recipes;
  3. inventory, prices and the greedy planner with a shopping list;
  4. threshold learning feeding the planner.
- Pure logic lives in `Logic.lua`, tested by `tests/run.lua`.
- Each phase ends with a robocopy deploy to `_classic_beta_\Interface\AddOns\ProfessionPlanner`.

---

## Phase 1: Skeleton, probe, CI
The addon loads on Forever. `/pp probe` prints the facts later phases depend on, and merging to main publishes a `pp-v` zip.

**Files**: `ProfessionPlanner/ProfessionPlanner.toc`, `Logic.lua`, `Core.lua`, `tests/run.lua`, `.github/workflows/package-pp.yml`

**Key changes**:
- TOC: `## Interface: 16001`, `## Version: 0.1.0`, `## SavedVariables: ProfessionPlannerDB`, `## SavedVariablesPerCharacter: ProfessionPlannerCharDB`; files Logic, Core (Panel is added in Phase 2).
- `PP.MergeDefaults(sv, defaults)` (pure; copied, not shared).
- `PP.On(event, fn)`, `PP.inits`, `PP.refreshers`, `PP.Print`, `PP.Secret`.
- `ADDON_LOADED`: `PP.db` = `{ thresholds={}, prices={} }` and `PP.char` = `{ recipes={}, bank={} }`.
- `/pp probe`. With the profession window open, it prints:
  - from `GetBaseProfessionInfo()`: `professionID`, name, `skillLevel` / `maxSkillLevel`;
  - `#GetAllRecipeIDs()` and the count of learned recipes;
  - for 5 learned recipes: name, `relativeDifficulty`, `maxTrivialLevel`, `numSkillUps`, and the reagent `{itemID, qty}` from `GetRecipeSchematic`;
  - for the first reagent: `C_Item.GetItemCount(id)` vs `GetItemCount(id, true)`;
  - `Enum.BagIndex.CharacterBankTab_1` and whether `C_Container.GetContainerNumSlots` on it is > 0 (only with the bank open).
- `package-pp.yml`: a copy of `package-wuk.yml` with the folder, TOC path, zip name, `pp-v` tag and title changed.

**Verify**:
- `lua ProfessionPlanner/tests/run.lua` passes (MergeDefaults).
- In game:
  - The addon loads with no errors.
  - `/pp probe` with Tailoring open prints the ID (expect 197), colors and `maxTrivialLevel` values.
  - With the bank open, the bank-tab line prints.
  - The output is saved to `probe-results.md`.

---

## Phase 2: Recipe scan + docked panel
Opening one of the four professions shows a panel on the right of `ProfessionsFrame`. It lists the header bracket and the learned orange/yellow/green recipes, best first, with no costs yet.

**Files**: `Logic.lua`, `Core.lua`, `Panel.lua` (new), TOC, `tests/run.lua`

**Key changes**:
- `PP.PROFESSIONS = { [197]="Tailoring", [333]="Enchanting", [165]="Leatherworking", [171]="Alchemy" }`. IDs are corrected from probe results if needed.
- `PP.NextBracket(skill, maxSkill): number` returns the first of 75/150/225/300 above `skill`, capped at `maxSkill` (pure).
- `PP.COLOR = { [0]="orange", [1]="yellow", [2]="green", [3]="grey" }`, and `PP.CHANCE = { orange=1, yellow=0.6, green=0.25, grey=0 }` (pure).
- `PP.ScanProfession()`. While `IsTradeSkillReady()` and the professionID is known:
  - it fills `PP.char.recipes[profID][recipeID] = { name, icon, learned, color, qtyMin, reagents={{itemID, qty}} }`;
  - schematics are fetched only once per recipe;
  - it records `PP.char.skill[profID] = { skill, max }`.
- Events: `TRADE_SKILL_SHOW` and `TRADE_SKILL_LIST_UPDATE` call scan + refresh; `TRADE_SKILL_CLOSE` hides the panel.
- `Panel.lua`:
  - `PPPanel` uses `BasicFrameTemplateWithInset`, 260 wide, anchored `TOPLEFT` → `ProfessionsFrame` `TOPRIGHT`;
  - it contains a header FontString and a pool of up to 12 rows (icon, name tinted by color, sub-text);
  - it is shown only for known professions; `ProfessionsFrame:HookScript("OnHide")` hides it;
  - `PP.RenderPanel(view)`, where `view = { header: string, rows: {icon, text, sub, color}[] }`.

**Verify**:
- Tests cover `NextBracket` edges (0→75, 75→150, 299→300, capped by max) and the color/chance tables.
- In game:
  - Opening Tailoring shows the panel to the right, with "Tailoring 87 → 150" and orange/yellow recipes first.
  - Crafting updates the colors.
  - Opening First Aid or Cooking shows no panel.
  - Closing the window hides the panel.

---

## Phase 3: Inventory, prices, planner, shopping list
The panel shows the next 3 planned steps with costs, and a shopping list with have/need/buy.

**Files**: `Logic.lua`, `Core.lua`, `Panel.lua`, `tests/run.lua`

**Key changes**:
- Bag scan: `PP.ScanBags(): {[itemID]=count}` over bags `0..NUM_BAG_SLOTS + 1` (the reagent bag), using `C_Container.GetContainerItemInfo`.
- Bank scan: while `BANKFRAME_OPENED`, iterate `CharacterBankTab_1..9` and save the counts to `PP.char.bank`. It re-scans on `BAG_UPDATE_DELAYED` / `PLAYERBANKSLOTS_CHANGED` while the bank is open.
- Prices: `MERCHANT_SHOW` saves each item's `C_MerchantFrame.GetItemInfo(i).price / stackCount` to `PP.db.prices[itemID]`, with item IDs from `GetMerchantItemID(i)`.
- `PP.Plan(state): steps[]` (pure).
  - `state = { skill, target, recipes, have, prices, thresholds, unknownCost }`.
  - `step = { recipeID, name, color, crafts, toSkill?, untilColorChange: bool, cost }`.
  - Greedy: score = cost per craft / chance. Owned reagents are consumed first at 0. Green is used only if there is no orange/yellow. At most 3 steps.
- `PP.ShoppingList(steps, recipes, have, prices): items[]` (pure).
  - `item = { itemID, need, have, buy, unitPrice? }`, sorted by `buy` descending.
- Panel:
  - Header: profession, skill → target.
  - Rows for the steps: "×N Recipe → S" or "×N Recipe (until yellow)", plus the cost.
  - A divider, then shopping rows: icon, name, `have/need`, "buy X @ price".
  - Item names load via `Item:CreateFromItemID(id):ContinueOnItemLoad`.

**Verify**:
- Tests:
  - Plan prefers cheaper per point (an orange expensive recipe vs a yellow cheap one).
  - Owned reagents make a recipe free.
  - Green is skipped when yellow exists.
  - Without thresholds, step 1 is `untilColorChange` and planning stops after 1 step.
  - The craft count respects the target bracket.
  - ShoppingList sums duplicates across steps and subtracts `have`.
- In game:
  - The steps look sensible at the current Tailoring skill.
  - The shopping list "have" matches bags plus the bank after a visit.
  - Visiting a trade-goods vendor fills in prices, and steps re-rank.

---

## Phase 4: Threshold learning
Color changes seen during play become stored thresholds. Steps then show real "→ skill S" targets and can project 3 steps ahead.

**Files**: `Logic.lua`, `Core.lua`, `Panel.lua`, `tests/run.lua`

**Key changes**:
- `PP.LearnThresholds(thresholds, prevColors: {[id]=color}, curColors, skill): changed: bool` (pure).
  - When a recipe's color moves to a worse one, set `thresholds[id][newColor] = min(existing or skill, skill)`.
  - It ignores learned=false recipes and same-color scans.
  - A non-zero `maxTrivialLevel` from a scan sets `grey`.
- `PP.ProjectColor(threshold, currentColor, skill): color` (pure) returns the color at a future skill, using the known thresholds, or nil if unknown.
- `PP.Plan` uses `ProjectColor` for the step length (`toSkill = next threshold or target`) and for steps 2–3.
- `ScanProfession` keeps `PP.lastColors[profID]` and calls `LearnThresholds` before overwriting.
- Panel: a sub-text "learned" marker on steps backed by thresholds, and a header line "N thresholds known".

**Verify**:
- Tests:
  - orange → yellow at 112 records `yellow=112`;
  - re-learning a lower value replaces it; a higher value is ignored;
  - grey via `maxTrivialLevel`;
  - `ProjectColor` returns nil when thresholds are missing;
  - Plan produces 3 steps with `toSkill` when thresholds exist.
- In game:
  - Craft a recipe until it turns yellow; the panel shows "→ S" for it afterwards.
  - The thresholds persist after `/reload` and appear on an alt with the same recipe.

---

## Testing Checkpoints
- **After P1:** the addon loads, the probe output is recorded (profession IDs, `maxTrivialLevel` populated?, bank tab readable?), and CI is ready for `pp-v0.1.0`.
- **After P2:** the panel docks and lists colored recipes for the four professions only.
- **After P3:** the planned steps, costs and shopping list match inventory and vendor prices.
- **After P4:** thresholds are learned, persist and are shared account-wide, and steps show concrete skill targets.
- **Every phase:** `lua ProfessionPlanner/tests/run.lua` passes and the addon is deployed with robocopy.
