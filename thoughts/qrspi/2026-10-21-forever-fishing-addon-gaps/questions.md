# Research Questions

## Context
Research is mostly external: CurseForge, Wago, WoWInterface, GitHub, warcraft.wiki.gg, and forum/Reddit threads. WoW Forever is interface 16001: a Mainline 12.x API base with Midnight "secret values" restrictions and Classic-era content; beta runs to 2026-10-21, launch 2026-11-04. Prior Forever API research lives in `thoughts/qrspi/2026-10-19-warlock-utility-kit*/research.md` and `probe-results.md`; extend it, don't repeat it. BetterFishing is noted as installed locally in `thoughts/qrspi/2026-10-20-profession-planner-seed-data-auctionator/research.md:307`.

## Questions
1. Which fishing addons are published for WoW Forever (interface 16001) on CurseForge, Wago, WoWInterface and GitHub?
   - For each: name, author, URL, version, last update, download count, stated Forever support;
   - feature list as documented;
   - open issues, comments and bug reports about Forever behavior.

   Include BetterFishing and any Forever forks of Classic-era fishing addons.
2. What do the established Classic-era and retail fishing addons do?
   - Fishing Buddy, FishingBuddy Classic, Angler, BetterFishing (retail), Fishing Ace, Fish! / FishFinder, Fishing Coach, Simple Fishing, and similar;
   - features covered: one-click/double-click casting, gear and lure swapping, auto-loot, sound/volume boost on bobber, bobber highlight, catch logging and per-zone/pool statistics, pool tracking and node history, fishing skill and zone-requirement display, fishing schedules (e.g. Stranglethorn Fishing Extravaganza), rare-catch alerts, quest fish tracking;
   - which of these are flagged as broken or unported on Forever.
3. How does fishing work mechanically in Classic Era vs WoW Forever?
   - skill range, zone minimum skill and get-away chance, lure items and durations, fishing poles and gear bonuses;
   - catch tables per zone and pool types (schools, floating debris, oily blackmouth, firefin, etc.);
   - any Forever changes: new recipes, Campsite interactions, Legacy points tied to fishing, fishing achievements, changed skill caps.
4. What client APIs and events relate to fishing on Mainline 12.x / Forever, and which are restricted?
   - channel spell detection (`UNIT_SPELLCAST_CHANNEL_START/STOP`, Fishing spell IDs), `LOOT_OPENED`/`LOOT_READY` and `GetLootSlotInfo`/`GetLootSourceInfo`, `C_TradeSkillUI.GetProfessionInfoBySkillLineID` for Fishing skill, `GetProfessions`;
   - secure binding methods addons use for one-click cast (`SetOverrideBindingClick`, `SecureActionButtonTemplate`, double-click on world), and protected-function limits;
   - interacting with the bobber (soft-target interact, `Interact` keybind, `C_CVar` for `SoftTargetInteract`, `Sound_*` CVars);
   - equipping gear/lures (`C_Item.EquipItemByName`, `UseItemByName`, combat lockdown);
   - whether any of these are secret-gated or changed in Forever 1.60.x API notes.
5. How do the most-used existing fishing addons implement their core features?
   - read source of BetterFishing and Fishing Buddy (or their GitHub mirrors): how cast-on-double-click, gear swapping, sound enhancement and catch logging are wired;
   - SavedVariables shape for catch history;
   - which Classic-only APIs they depend on that don't exist on Mainline.
6. What do players say they want from fishing addons on Forever?
   - Reddit (r/classicwow, Forever subreddits), CurseForge comments, Wowhead comments, Discord-public summaries;
   - recurring complaints, feature requests, and workarounds people use (macros, WeakAuras-style setups, Edit Mode tricks).
