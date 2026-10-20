# Task

Build Idea 2 from `WoW Forever Addon Ideas — PRD.md`: the **Profession Leveling Planner for Forever**.

It is a **separate addon** in its own top-level folder, `ProfessionPlanner/`:
- its own TOC, SavedVariables, tests and release zip;
- no code shared with or dependent on `WarlockUtilityKit/`;
- installable and loadable alone.

Repo conventions (test layout, CI packaging, deploy step) are copied as patterns, not shared code. CI gets its own workflow and release tag prefix.

v1 scope:
- When the unified profession window opens, scan it and cache known recipes, skill-up thresholds and reagents per character.
- Compute the cheapest path from the current skill to the next bracket (75/150/225/300) using only known recipes, with a craft count per step.
- Show a live shopping list: required vs owned, across bags and the cached personal bank.
- Add an enchanting option that prefers crafts whose disenchant output feeds the tailoring → enchanting loop.
- Show it all in a side panel attached to the profession window, with no setup.

Professions in v1: tailoring, enchanting, leatherworking, alchemy. There is no static recipe table; data is learned from the client, because Forever changed recipes and thresholds. The addon should follow the repo conventions established by WarlockUtilityKit (pure-logic tests, CI zip packaging, deploy to the `_classic_beta_` AddOns folder).
