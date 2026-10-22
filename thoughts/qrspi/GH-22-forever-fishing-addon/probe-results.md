# Probe Results — TackleBox

## Run 1 — 2026-10-22, site 1 (plain, Orgrimmar / Valley of Spirits)
Client `1.60.1 70450`, `WOW_PROJECT_ID` 18. Character at Fishing 1/75, out of combat. No fish, quest fish, Surfer Shoes or Draught in bags.

- **Skill read:** `GetProfessions()` → `7 8 5 9 6`; fishing index = 9.
  - `GetProfessionInfo(9)` → `Fishing | 136245 | 1 | 75 | 2 | 79 | 356 | 0 | -1 | 0 | Fishing`. So skillLevel 1, max 75, skillLine 356, skillModifier 0 (8th return). `TB.ReadSkill` reads this correctly.
  - `C_TradeSkillUI.GetProfessionInfoBySkillLineID(356)` → `0/0 mod 0`. The fallback path returns nothing useful on Forever (guarded by `maxSkillLevel > 0`).
- **Fishing spell:** `C_Spell.GetSpellInfo(7620)` → `Fishing id 7620`. 131474 → nil. Forever uses 7620.
- **`IsFishingLoot`:** a function exists. This settles the conflict between the wiki and the Fishing Buddy fork for this build.
- **Auras out of combat:** `GetAuraDataByIndex` gave `1086 Demon Armor exp 717156.77`; spellId, name and expirationTime are all plain, not secret. `GetPlayerAuraBySpellID(1086)` works and returns the same expiration.
- **Bag item classes:** fishing pole 6256 = class 2/20; Nightcrawlers 6530 = class 0/8 (consumable/other). Lures are consumables, not trade goods.
- **lastChannel / lastLoot:** none (no cast this session).

### Bug found
- The `/tb` usage line printed `/tb showide|lockeset|probe|flash`. A single `|` followed by `h` or `r` is a chat escape code, so `|h` and `|r` were eaten. Fixed by printing `||`. `flash` was also dropped from the usage line until Phase 3b adds it.

## Still needed
- Site 2: right after catching a fish (loot window closed).
- Site 3: after a cast that ran out without a click.
- Site 4: at a Campsite Fishing Rack / Fishing Hut.
- Site 5: with water-walking active.
- Item IDs: the four Artisan quest fish, Surfer Shoes, Draught of Waterwalking, any Uncommon/Rare/Unique fish, and the Chef's Knife product.
