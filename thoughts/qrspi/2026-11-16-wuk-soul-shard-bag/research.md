# Research Findings

All paths relative to repo root. Web facts from warcraft.wiki.gg (not verified in-game on the Forever client, Interface 16001).

## Q1: Trace `WUK.ScanBags` end to end

### Findings
- `WarlockUtilityKit/Core.lua:30-44`. Builds fresh table `c` with five kinds at 0 plus `ids = {}`, `slots = {}` (31).
- Bag range: `for bag = 0, NUM_BAG_SLOTS or 4` (32) — backpack + equipped bags 1-4. No keyring, bank, or reagent bag.
- Per bag `C_Container.GetContainerNumSlots(bag)` (33); per slot `C_Container.GetContainerItemInfo(bag, slot)` (34).
- Name source (35): `info.itemName or C_Item.GetItemInfo(info.itemID)`, passed to `WUK.ClassifyItem`.
  - Fields used: `itemName`, `itemID` (35, 38), `stackCount` (37, defaults to 1).
  - Empty slot: `info` nil, skipped.
  - `itemName` nil and item not cached: `C_Item.GetItemInfo` returns nil; `ClassifyItem(nil)` returns nil (`Logic.lua:10`). Item silently uncounted; no retry scheduled.
  - No guard if `info.itemID` nil.
- On match: count += stackCount (37); `ids[kind]` and `slots[kind]` set once, from the first matching slot in scan order (38-39).
- Returns `c`; caller `WUK.Refresh` assigns `WUK.counts` (`Core.lua:143`). Initial default `Core.lua:4`.
- Design history: `thoughts/qrspi/2026-10-19-warlock-utility-kit/design.md:54` chose name-substring classification via `GetContainerItemInfo().itemName`; same loop in that plan (`plan.md:124-127`).

## Q2: Classic-era bag numbering, constants, specialty bags

### Findings (wiki, https://warcraft.wiki.gg/wiki/BagID)
- Classic Era: 0 backpack; 1-4 equipped bags; -1 bank (24 slots); -2 keyring; 5-10 bank bags; -4 bank-bag container. No reagent bag in Classic; container 5 = bank bag 1. Wiki notes Mainline numbering differs (reagent bag 5) and `Enum.BagIndex` bank values "will break in Classic".
- Constants: `NUM_BAG_SLOTS` = 4, `BACKPACK_CONTAINER` = 0, `KEYRING_CONTAINER` = -2 (search summaries, not read directly). `NUM_TOTAL_EQUIPPED_BAG_SLOTS` Classic value unverified. `NUM_BANKBAGSLOTS` 6, `NUM_BANKGENERIC_SLOTS` 24.
- Specialty bags: wiki documents no separate API; `GetContainerNumSlots` / `GetContainerItemInfo` take the same container index for soul/ammo/herb bags. No documented quirks.
- `C_Container.GetContainerNumFreeSlots(bag)` returns `numFreeSlots, bagFamily` (ItemFamily bitfield). Soul Shards = family ID 3, flag `0x4`; Arrows 0x1, Bullets 0x2, Herbs 0x20, Enchanting 0x40, Keys 0x100 (https://warcraft.wiki.gg/wiki/ItemFamily). `GetItemFamily` also returns a bitfield.
- Soul Shard item ID 6265 appears in repo test (`WarlockUtilityKit/tests/run.lua:53`). Stack size in Classic believed 1 (unsourced).
- No in-game dump of Forever-client constants recorded in repo.

## Q3: Events driving `WUK.Refresh`

### Findings
- Dispatcher: `WUK.On` lazily registers per event (`Core.lua:11-17`); Core.lua is the only file calling `RegisterEvent`.
- `WUK.Refresh` (`Core.lua:141-145`): returns if `not WUK.active` (142); else `WUK.counts = WUK.ScanBags()` (143), then runs all `WUK.refreshers` (144). No combat guard in Refresh itself.
- `WUK.active` set only at `PLAYER_LOGIN` for class WARLOCK (`Core.lua:147-154`), which then runs inits and Refresh.
- Direct triggers: `BAG_UPDATE_DELAYED` (155), `PLAYER_REGEN_ENABLED` (156), `SPELLS_CHANGED` if active (157), `UNIT_AURA` player (158), `UNIT_PET` player (159), slash `/wuk pet` (234), `/wuk spin|collapse` (246).
- Indirect: `Prep.lua:42-47` UNIT_SPELLCAST_SUCCEEDED "Soulstone Resurrection"; `Board.lua:20` `BoardChanged` (from GROUP_ROSTER_UPDATE on leaving group, `Board.lua:175-178`).
- Not listened to anywhere in repo: `BAG_UPDATE`, `GET_ITEM_INFO_RECEIVED`, `ITEM_DATA_LOAD_RESULT`, `BAG_CONTAINER_UPDATE`, `PLAYERBAGSLOTS_CHANGED`, `UNIT_INVENTORY_CHANGED`.
- Wiki: `BAG_UPDATE(bagID)` fires per affected bag; `BAG_UPDATE_DELAYED` fires once after all BAG_UPDATEs of an action, no payload. No documented exception for specialty bags.
- Refreshers registered: `UI.lua:154`, `Prep.lua:12`, `Prep.lua:31`, `Board.lua:185`, `Dock.lua:26`, `Summon.lua:95`. Combat skips inside refreshers: `UI.lua:166`, `Prep.lua:18,38`, `Dock.lua:7`, `Summon.lua:39`, `Core.lua:97`.

## Q4: `WUK.ClassifyItem` matching

### Findings
- `WarlockUtilityKit/Logic.lua:4-14`. Ordered `STONES` array (4-7): "Soul Shard", "Healthstone", "Soulstone", "Spellstone", "Firestone"; `ipairs`, first match wins.
- `name:find(s[1], 1, true)` — plain, case-sensitive, unanchored substring (12). enUS only (comment line 3).
- Non-string input returns nil (10).
- Matches: any name containing "Soul Shard". Bag names "Soul Pouch", "Felcloth Bag", "Core Felcloth Bag", "Box of Souls" contain no key and do not match. Ranked stones ("Major Healthstone", "Greater Firestone") match.
- Fails: nil/uncached names, non-enUS names, different casing.
- Name strings in practice: `info.itemName` first. Wiki says the `itemName` field was added to `ContainerItemInfo` in Mainline 10.1.5 and Classic "incorrectly" mirrors an earlier Mainline field list, so whether `itemName` is populated on this client is unverified. Fallback `C_Item.GetItemInfo` returns nil when uncached (https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo).
- Tests: `WarlockUtilityKit/tests/run.lua:10-16` cover "Soul Shard" and stone names.

## Q5: Consumers of `WUK.counts.shard` / `ids` / `slots`

### Findings
- Only `UI.lua`, `Summon.lua`, `Trade.lua` read `WUK.counts`.
- `UI.lua:154-172` refresher, per kind in `KINDS` (`UI.lua:3`):
  - `c.ids[kind]` -> `C_Item.GetItemIconByID` -> cached in `WUK.db.icons[kind]` (157-160), else `FALLBACK` texture (`UI.lua:6`).
  - `c[kind] == 0` desaturates (161); count text `b.count:SetText(c[kind])` (163); pop animation 0 to >0 (164-165).
  - Alert glow only for healthstone/soulstone at 0 (162). Separate ring alert on shard icon `UI.lua:46`.
  - Macro via `WUK.StoneMacro` (168); returns nil for shard (`Logic.lua:27`), so shard core has no click action.
  - Shard is the ring core button, larger and higher frame level (`UI.lua:114, 129-131`, positioned `UI.lua:37`).
- `Summon.lua:16`: `ctx.shards = WUK.counts.shard`; `WUK.SummonFailure` (`Logic.lua:68-77`) returns "no shard" when `< 1` (74), shown red on summon queue rows (`Summon.lua:49`).
- `Trade.lua:14`: `counts.healthstone > 0` decides READY/EMPTY whisper. `Trade.lua:21-23`: `counts.slots.healthstone` used for `C_Container.PickupContainerItem`.
- `counts.ids` read only at `UI.lua:157`; `counts.slots` only at `Trade.lua:21`.
- WarlockCombatKit draws a decorative shard texture only (`WarlockCombatKit/Panel.lua:173-175`); no bag reads.

## Q6: Bag enumeration elsewhere in repo

### Findings
- Manual slot loop `0..NUM_BAG_SLOTS or 4`: `WarlockUtilityKit/Core.lua:32`, `TackleBox/Core.lua:207-215` (debug probe; `select(12, C_Item.GetItemInfo(id))`), `TackleBox/Actions.lua:79-91` (`C_Container.GetContainerItemID` + `C_Item.GetItemInfoInstant` — classifies by instant data, no cache dependency).
- Loop to reagent bag: `ProfessionPlanner/Core.lua:91-102` `ScanContainers(0, Enum.BagIndex.ReagentBag or NUM_BAG_SLOTS or 4)`, tallies by `itemID`, not name.
- `C_Item.GetItemCount`: `TackleBox/Core.lua:85` (with bank), `TackleBox/Actions.lua:68,107,114`, `ProfessionPlanner/Core.lua:231` (debug).
- All three addons refresh on `BAG_UPDATE_DELAYED` only (`WarlockUtilityKit/Core.lua:155`, `ProfessionPlanner/Core.lua:185`, `TackleBox/Core.lua:59`).
- Not used anywhere: `GetContainerNumFreeSlots`, `GetItemFamily`, `GET_ITEM_INFO_RECEIVED`, `ITEM_DATA_LOAD_RESULT`, `Item:ContinueOnItemLoad`.
- Prior Forever work: `thoughts/qrspi/GH-22-forever-fishing-addon/plan.md:185` probe reads `itemName` from `GetContainerItemInfo` on this client.

## Q7: Test harness

### Findings
- `WarlockUtilityKit/tests/run.lua:1-3` loads only `Logic.lua` via `loadfile(dir.."/Logic.lua")("WarlockUtilityKit", WUK)`. No WoW API stubs (no `C_Container`, `C_Item`, `CreateFrame`).
- Helpers: `eq` (5-7), `near` (89-91), `assert`; prints "all tests passed" (98).
- Run: `lua5.1 WarlockUtilityKit/tests/run.lua` (`WarlockUtilityKit/README.md:166`); CI `.github/workflows/package-wuk.yml:20-21`.
- Covered (Logic.lua): ClassifyItem, MergeDefaults, FormatTime, SoulstoneRemaining, IsSummonRequest, Queue*, SummonFailure, IsHealthstoneRequest, StoneMacro, MarkToken, AssignmentText, NextRev, Encode/Decode, AcceptRow/AcceptLead, AnnounceLines, RingPoint.
- Not covered: `ScanBags`, `Refresh`, ScanSpells, ReadPlayerBuffs, group helpers, event wiring, Trade, UI.
- Other addons (TackleBox, WarlockCombatKit, ProfessionPlanner): same pattern, pure Logic/Data only, no container stubs.

## Cross-Cutting Observations
- Convention: WoW API calls live in Core/UI files; pure functions in `Logic.lua` are the only tested surface.
- Item identification varies by addon: WUK by name substring, ProfessionPlanner by itemID, TackleBox by `GetItemInfoInstant` class/subclass.
- Every addon relies on `BAG_UPDATE_DELAYED` as sole bag-change trigger.
- `ponytail:` comments mark known ceilings (e.g. enUS matching `Logic.lua:3`).

## Open Areas
- Whether `ContainerItemInfo.itemName` is populated on the Forever client (wiki ambiguous for Classic; GH-22 probe read it but repo records no result).
- Actual `NUM_BAG_SLOTS` value and bag ID layout on Interface 16001 (wiki covers Classic Era/Mainline; Forever unknown).
- Whether soul-bag contents return normally from `GetContainerItemInfo`, and whether `BAG_UPDATE_DELAYED` fires for shard create/consume inside a soul bag — undocumented; needs in-game check.
- Soul Shard max stack size on this client unverified.
