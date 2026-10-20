# Research Questions

## Context
Focus on the `ProfessionPlanner/` addon (Logic.lua, Core.lua, Panel.lua, the .toc, and tests/run.lua), plus the prior design docs in `thoughts/qrspi/2026-10-19-profession-leveling-planner/`. The client targets `## Interface: 16001` (a Classic-family client). Two questions are external and need web research.

## Questions
1. Trace how `PP.ScanProfession` in Core.lua reads recipes from the tradeskill UI and what it stores in `ProfessionPlannerCharDB.recipes`: record shape, which IDs are keys (recipeID, spellID, output itemID), how reagents and quantities are recorded, and how that data flows into `PP.Plan` and `PP.ShoppingList`.
2. How are skill color thresholds (orange/yellow/green/grey) represented, learned (`PP.LearnThresholds`, `PP.LearnGrey`), stored in `ProfessionPlannerDB.thresholds`, and consumed by `PP.ProjectColor`, `PP.NextThreshold`, `PP.CHANCE` and `PP.Plan`? What happens in each path when a threshold is unknown?
3. Trace item prices end to end: how `ScanMerchant` writes `PP.db.prices`, how `CraftCost`, `PP.Plan`, `PP.ShoppingList` and Panel.lua read them, and how the `UNKNOWN_COST` / `unknownCost` fallback affects ranking and display.
4. How are SavedVariables defaults declared and merged (`PP.MergeDefaults`), what is the .toc load order, and do any addons in this repo (ProfessionPlanner or WarlockUtilityKit) declare `OptionalDeps`, check whether another addon is loaded, or call another addon's API? Document the existing patterns.
5. How does `tests/run.lua` exercise Logic.lua — how it is run, what fixture data shapes it builds (recipes, prices, thresholds), and which behaviors it covers?
6. (External) What public API does the Auctionator addon expose to other addons for reading auction prices — function names and namespaces, arguments (itemID vs itemLink), caller registration requirements, return values and units, behavior when no price exists, and which API versions/clients (Retail, Classic Era, Anniversary/Classic-family clients) support it?
7. (External) What widely used WoW Classic (vanilla, skill 1-300) profession leveling guides exist (e.g. Wowhead, other guide sites, leveling addons), what structure do they share (skill ranges, recipe per range, craft counts, total reagent lists, trainer/vendor recipe sources, color thresholds), and is any of this data available in machine-readable form (data dumps, open-source addon databases, GitHub repos) along with its license?
