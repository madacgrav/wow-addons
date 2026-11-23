# Research Questions

## Context
Focus on the `TackleBox/` addon (`Panel.lua`, `Core.lua`, `Logic.lua`, `Data.lua`, `tests/run.lua`), the other addons in this repo as UI pattern references (`BusinessCard/Panel.lua`, `WarlockCombatKit/Settings.lua`, `WarlockUtilityKit/Settings.lua`), prior TackleBox planning docs under `thoughts/qrspi/` (`GH-22-forever-fishing-addon/`, `2026-10-21-forever-fishing-addon-gaps/`, `2026-11-23-tacklebox-weapon-swap-one-click/`), and the wow-forever-addon skill references at `D:\Source\wowskill\skills\wow-forever-addon\references\` (`forever-api-index.md`, `forever-api-notes.md`, `widgets.md`, `events.md`, `performance.md`). Web research is allowed only where those lack a fact; label each such fact verified / reported / unverified for Forever.

## Questions
1. How is the TackleBox panel built end to end in `Panel.lua`: which frames, templates, textures, fonts, backdrops, colors and anchors are used for the dock, panel, skill bar, row pool, custom tabs (`MakeTab` / `RenderTabs`) and minimap button; how are tabs defined, selected and persisted (`TB.TabRows`, `TB.db.tab`); and how do these choices compare to the tab, skin and minimap-button conventions in `BusinessCard/Panel.lua` and the WCK/WUK `Settings.lua` files and to the guidance in the skill's `widgets.md`?

2. Trace the data flow from `Data.lua` through `Logic.lua` and `Core.lua` into `TB.RenderPanel`: what fishing data is stored today (zones, skill bands, lures, quest fish, the empty `fish` table), how the current zone and Fishing skill are read, and how sections/rows are produced per tab. What does `probe-results.md` and the fishing-gaps `research.md` record about the provenance rules for this data?

3. What fishing location data exists for Classic-era / Forever content — per zone or sub-area: catchable fish and notable loot, required/recommended skill, and fishing pool or school types (e.g. Floating Wreckage, Oily Blackmouth School, Firefin Snapper School) with their spawn coordinates? Which public sources publish it (wowhead classic, warcraft.wiki.gg, wago DB2), in what coordinate system, and how do Forever's zones and loot differ from Classic Era?

4. Which Forever APIs and Blizzard frameworks let an addon draw markers on the world map and minimap: `C_Map` (map IDs, `GetBestMapForUnit`, `GetPlayerMapPosition`, world-position conversion), `WorldMapFrame` data providers / `MapCanvasPinMixin` / pin templates, minimap coordinate math, and `C_Minimap` tracking? What are the taint and performance notes for each, and what do common libraries (HereBeDragons, HereBeDragons-Pins) wrap?

5. Can a Forever addon detect nearby game objects such as fishing pools at runtime? Cover tooltip/mouseover of world objects, `SoftTarget` / interact-target CVars and APIs, nameplates (and whether game objects get them), minimap "Find Fish" tracking (how it is obtained in vanilla-era data and whether `C_Minimap` exposes tracked blips), and any relevant events. State what is documented in the skill's API index versus reported only on the web.

6. How does TackleBox handle SavedVariables (shape, defaults merge, per-account vs per-character), event registration and its `ADDON_LOADED` / `PLAYER_LOGIN` order, `OnUpdate` usage, and file load order in `TackleBox.toc`; and how does `tests/run.lua` mock the WoW API — which globals it stubs and how panel/logic behavior is asserted?
