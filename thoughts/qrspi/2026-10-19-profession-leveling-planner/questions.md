# Research Questions

## Context
Research covers the existing repository (`WarlockUtilityKit/`, `.github/workflows/`, `tests/`) and the WoW Forever client's APIs. Forever is interface 16001: a Mainline 12.x API base with Midnight "secret values" restrictions and Classic-era content. Use warcraft.wiki.gg, CurseForge and GitHub. Prior Forever research lives in `thoughts/qrspi/2026-10-19-warlock-utility-kit*/research.md` and `probe-results.md`; extend it, don't repeat it.

## Questions
1. How is the existing addon in this repo organized and built?
   - TOC fields and load order, and the `Logic.lua` (pure) vs WoW-API file split;
   - the `WUK.inits` / `WUK.refreshers` / `WUK.On` lifecycle, and SavedVariables defaults;
   - how `tests/run.lua` loads code;
   - which parts of `.github/workflows/package-wuk.yml` are specific to that addon's folder, name, version tag and paths filter.

   Give file:line references.
2. What does the profession (trade skill) API look like on Forever / Mainline 12.x?
   - `C_TradeSkillUI` functions for the open profession: `GetAllRecipeIDs`, `GetRecipeInfo` (fields such as `relativeDifficulty`, `learned`, `numSkillUps`, skill-up thresholds), `GetRecipeSchematic` (reagent slots, quantities, output item), `GetBaseProfessionInfo` / `GetProfessionInfoBySkillLineID` / `GetChildProfessionInfo` (current and max skill), `IsTradeSkillReady`, `GetRecipeNumItemsProduced`;
   - events (`TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`, `TRADE_SKILL_CLOSE`, `TRADE_SKILL_DATA_SOURCE_CHANGED`, `SKILL_LINES_CHANGED`);
   - the main window frame name (`ProfessionsFrame`) and its anchor points;
   - whether any of these are secret or restricted;
   - what the Forever 1.60.x notes say about the "unified profession window".

   Hemlock Forever (https://github.com/Hexx98/hemlock-forever) calls `C_TradeSkillUI.OpenTradeSkill`; read its usage as a working Forever example.
3. How do skill-ups work in Classic Era vs Forever?
   - recipe colors (orange/yellow/green/grey) and the per-recipe threshold levels;
   - the skill-up chance formula for yellow and green;
   - trainer brackets (Apprentice 75, Journeyman 150, Expert 225, Artisan 300) and their level requirements.

   For Forever, what is documented about the 600+ new recipes and changed thresholds for tailoring, enchanting, leatherworking and alchemy, and does the client expose threshold numbers or only a difficulty color?
4. How does an addon read inventory on Forever?
   - bag and personal-bank contents (`C_Container` bank container indices for Forever, `BANKFRAME_OPENED/CLOSED`, `PLAYERBANKSLOTS_CHANGED`, `C_Bank` APIs, reagent or account bank if any);
   - `C_Item.GetItemCount` with `includeBank`;
   - item info lookups for reagents (`C_Item.GetItemInfo` async loading, `ITEM_DATA_LOAD_RESULT`);
   - vendor-sold reagents (`MerchantFrame` / `GetMerchantItemInfo`, or reagent vendor flags).
5. How does disenchanting work in Classic Era and on Forever?
   - the tables mapping item level, quality and armor/weapon type to Strange Dust, Lesser/Greater Magic/Astral/Mystic/Nether/Eternal Essence, Small/Large Glimmering/Glowing/Radiant/Brilliant Shards, and their probabilities;
   - whether any API exposes disenchant results or "can be disenchanted" (e.g. a tooltip line or `C_Item` field);
   - any Forever enchanting changes.
6. How do existing profession-leveling and recipe addons work?
   - CraftSage, craftplaner, What's Crafting? (CurseForge, Classic-era), Skillet-Classic, TradeSkillMaster, and any profession addon listed for Forever 1.60.x;
   - how they obtain recipe and difficulty data (client API vs static tables), how they compute leveling paths and shopping lists, and how they attach UI to the profession window;
   - what breaks for them on the Mainline-style unified window.
