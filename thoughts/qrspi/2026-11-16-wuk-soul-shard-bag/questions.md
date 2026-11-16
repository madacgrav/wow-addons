# Research Questions

## Context
Focus on the WarlockUtilityKit addon (`WarlockUtilityKit/`), especially `Core.lua` (bag scanning, refresh/event wiring), `Logic.lua` (item classification), and `UI.lua` (count display). Also relevant: the C_Container / C_Item APIs as exposed by the WoW Forever client (Interface 16001, Classic-era), and how other addons in this repo read bag contents.

## Questions
1. Trace `WUK.ScanBags` end to end: which bag IDs does it iterate, which C_Container / C_Item calls does it make per slot, what fields of the returned item info does it depend on, and what happens when any of those values are nil or not yet cached?
2. On the Classic-era client used here, how are bag container IDs numbered (backpack, equipped bags, keyring, bank), what is the value of `NUM_BAG_SLOTS` / related constants, and do specialty bags (soul bags, ammo/quiver, herb bags) report slots and item info through the same C_Container calls as normal bags? Include any known differences or quirks.
3. What events does the addon register to trigger `WUK.Refresh` (in `Core.lua` and elsewhere), when does each fire relative to items moving into or out of a bag, and are there bag/item events the client fires that the addon does not listen to (e.g. `BAG_UPDATE`, `ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED`, `PLAYERBAGSLOT`/bag-equip changes)?
4. How does `WUK.ClassifyItem` match item names, what name strings does it receive in practice (from `info.itemName` vs `C_Item.GetItemInfo`), and what items could match or fail to match the "Soul Shard" pattern (including the bag items themselves, e.g. "Soul Pouch", "Core Felcloth Bag")?
5. Trace how `WUK.counts.shard` (and `counts.ids` / `counts.slots`) flows from the scan into consumers: the UI shard core and alert logic in `UI.lua`, the summon failure check in `Summon.lua`/`Logic.lua`, and any other readers. What does each consumer display or decide based on the value?
6. How do other addons in this repo (e.g. WarlockCombatKit, fishing addons) enumerate bags or count items, and do any use a different API or pattern (e.g. `C_Item.GetItemCount`, `GetItemCount`, different bag ranges)?
7. What test harness exists under `WarlockUtilityKit/tests/` (how `run.lua` stubs WoW APIs and loads files), and which functions are currently covered versus untested?
