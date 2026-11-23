# Research Questions

## Context
Focus on the `TackleBox/` addon folder (especially `Actions.lua`, `Core.lua`, `Logic.lua`, `CastBar.lua`, `tests/run.lua`) and on the WoW Forever skill references at `D:\Source\wowskill\skills\wow-forever-addon\references\` (`forever-api-index.md`, `forever-api-notes.md`, `taint-and-secure.md`, `events.md`, `saved-variables.md`). Prior research in `thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/research.md` and `thoughts/qrspi/GH-22-forever-fishing-addon/research.md` may be cited as background.

## Questions
1. How does TackleBox's action bar (`Actions.lua`) build its secure buttons, decide which buttons are shown, set their attributes, and defer attribute changes around combat lockdown? Trace the flow from a refresher run through `Apply()` to a click, including how the pole button's `/equip` macro and the main-hand slot check (`PoleEquipped`) work.

2. Which Forever APIs and events expose what is equipped in the main-hand (16) and off-hand (17) inventory slots, report changes to those slots, and equip a specific item into a specific slot (for example `GetInventoryItemID`, `GetInventoryItemLink`, `PLAYER_EQUIPMENT_CHANGED`, `UNIT_INVENTORY_CHANGED`, `EquipItemByName`, `/equip`, `/equipslot`, `C_Item` functions)? Which of these are protected or restricted in combat, and how are items identified (item ID vs link vs bag/slot) when two copies of the same item exist?

3. What SavedVariables does TackleBox use (`TackleBoxDB`, `TackleBoxCharDB`), what are their default shapes, how are defaults merged, and when do they become available relative to `PLAYER_LOGIN` and the init/refresher lists in `Core.lua`?

4. How does the fishing cast lifecycle work in Forever as TackleBox observes it: which events fire on cast, bobber bite, catch, miss and cancel (`UNIT_SPELLCAST_CHANNEL_START/STOP`, `LOOT_READY`, etc.), what does `UnitChannelInfo` return during a fishing channel, and how does TackleBox track the "line in the water" state today (`TB.lastChannel`, cast bar, miss detection)?

5. What mechanisms exist in Forever for an addon-provided click or key to interact with a world object such as a fishing bobber: the `INTERACTTARGET` / interact-key binding, soft-target interact CVars (`SoftTargetInteract`, `SoftTargetInteractRange`), `SetOverrideBinding` / `SetOverrideBindingClick`, secure action button types (`macro`, `click`, `/interact`-style slash commands), and double-click-on-world approaches? Which are protected, which work in combat, and what do existing fishing addons (BetterFishing, Fishing Mode, CFC, ForeverPlusPlus) use?

6. Can a single `SecureActionButtonTemplate` button change what it does between clicks based on state (for example attribute changes from insecure code, secure state drivers, `SecureHandlerWrapScript` / restricted snippets, macro conditionals like `[channeling]`), and which of those options are allowed while in combat lockdown in Forever?

7. How is TackleBox tested offline (`tests/run.lua` and the wowmock harness described in `references/testing.md`): which logic functions are covered, how are WoW APIs stubbed, and which stubs exist for inventory, equip and binding APIs?
