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

## Run 2 — 2026-10-22, site 3 (cast left alone, no click; same place)
- **Channel info:** `lastChannel: 7620 start 716446213 end 716476213 secret false`.
  - `UnitChannelInfo` start and end times are plain milliseconds, not secret.
  - The full channel is 30 000 ms, so a cast lasts **30 s**. `TB.DATA.castSeconds = 30` stays; the cast bar can use the real times.
- **Trace:** `+0.00 CHANNEL_START 7620`, then `+20.81 CHANNEL_STOP`, with no `LOOT_READY`.
  - The channel ended early at ~20.8 s, not at 30 s. This fits the Classic rule: an unclicked bite ends the cast ("fish got away") after its short window.
  - So a no-loot `CHANNEL_STOP` before the end time likely means a missed bite, while a stop at the end time means nothing bit. The addon still cannot see the bite itself.
  - This is one sample, not confirmed.
- **lastLoot:** none. This is consistent with no click.

## Run 3 — 2026-10-22, second cast, no loot (same place)
- **Channel info:** `lastChannel: 7620 start 716521695 end 716551695 secret false`. The channel is again 30 000 ms.
- **Trace:** `+75.48 CHANNEL_START 7620` and `+107.11 CHANNEL_STOP`, so the stop came 31.63 s after the start. That is about 1.6 s past the channel's end time. No `LOOT_READY`.
- **Reading:**
  - Cast 1 stopped well before the end time (20.8 s). Cast 2 stopped at or just after it.
  - If "early stop = missed bite" holds, cast 2 had no bite.
  - Either way, `CHANNEL_STOP` can arrive more than 1 s after the nominal end time. Any end-vs-early comparison needs about 2 s of slack.
- **Open:** what the player did on each cast (no click vs a click on the bobber) is not in the trace. Ask before relying on the early-stop rule.

## Run 4 — 2026-10-22, site 2 (after a catch; Orgrimmar / Valley of Honor)
- **Skill:** `GetProfessionInfo` → `2 | 75 | ... | 356 | 25`. Skill is 2/75 with **skillModifier 25**.
  - The fishing pole is no longer in bags, so it is equipped. The +25 most likely comes from the pole or a lure; the source is not confirmed.
  - This confirms the 8th return is the modifier.
- **Catch:** `lastLoot: hasAPI true fishing true`, loot 1 `[Raw Longjaw Mud Snapper] q1 x1`. Bag item `6289 Raw Longjaw Mud Snapper q1 class 7/8`.
  - Common fish are quality 1, class 7 (trade goods), subclass 8 (meat).
- **Event order:** `+398.34 CHANNEL_STOP`, then `+398.35 LOOT_READY 1`.
  - Loot arrives about 10 ms **after** the stop. `TB.IsMiss` (loot ≥ stop − 0.5 s) treats this as a catch.
  - `LOOT_READY` fired once for this window.
- **Other casts in the same trace:**
  - 156.41→179.02 (22.6 s): stopped, no loot.
  - 373.12→386.65 (13.5 s): stopped, no loot.
  - 388.40→398.34 (9.9 s): catch.
  - Early no-loot stops are common at this skill level, which fits missed or escaped bites.
- Every channel is again 30 000 ms, never secret.

## Item IDs from client data (wago.tools DB2, build 1.60.1.70450, same build as the probes)
- **Source:** `ItemSparse` and `Item` CSV for `?build=1.60.1.70450`. This is the build string the probe reported, so the IDs are the client's own.
- **Check:** each ID can be confirmed in game with `/dump C_Item.GetItemInfo(<id>)`.

| ID | Name | Quality | Class/sub |
|---|---|---|---|
| 16967 | Feralas Ahi | 1 | 15/0 |
| 16970 | Misty Reed Mahi Mahi | 1 | 12/0 (quest) |
| 16968 | Sar'theris Striker | 1 | 12/0 (quest) |
| 16969 | Savage Coast Blue Sailfin | 1 | 12/0 (quest) |
| 8827 | Draught of Water Walking | 1 | 0/2 |
| 276274 | Surfer Shoes | 3 | 4/1 (cloth feet) |
| 6529 / 6530 / 6532 / 6811 / 7307 / 6533 | Shiny Bauble / Nightcrawlers / Bright Baubles / Aquadynamic Fish Lens / Flesh Eating Worm / Aquadynamic Fish Attractor | 1 | 0/8 (Attractor 0/14) |
| 279965 / 279966 / 279967 | Fishing Rack / Fishing Hut / Fish Bowl (placeables) | 1 | 0/8 |
| 273141 / 273119 | Blueprint: Fishing Rack / Fishing Hut | 2 | 9/9 |
| 273636 | Chef's Knife | 1 | 7/11 |
| 273295 | Seasonal Fish Steaks ("seasonal fish ready to be used in recipes"); likely the knife product, unconfirmed | 1 | 7/8 |
| 274026 | Extravagant Extravaganza Coin | 3 | 15/4 |

- The item is spelled **"Draught of Water Walking"**, not "Waterwalking". The probe's name filter missed it, so it was searched by name here.
- **No separate Uncommon/Rare fish items exist** in this build. The only quality ≥ 2 fish are the old Bloated/Angelfish containers and quest fish.
  - So Forever's Uncommon/Rare catches are most likely the same item IDs with a higher quality at loot time (item bonus).
  - **Impact on Phase 3:** read quality from the loot slot (`GetLootSlotInfo` quality) and store the best seen per catch. `C_Item.GetItemQualityByID` returns base quality only.
- **No "Unique Fish" item** was found by name. Unique fish stay unlisted until a catch shows one.
- Rack/Hut buff spell IDs are not in item data. They still need probe site 4.

## Spell and skill data from client DB2 (build 1.60.1.70450)
Sources are `SpellName`, `SpellEffect` and `ItemSparse.RequiredSkill/RequiredSkillRank`.

**Unlock skills (Fishing = skill line 356)**

| Item | Required Fishing |
|---|---|
| Blueprint: Fishing Rack | 140 |
| Fishing Rack | 140 |
| Blueprint: Fishing Hut | 300 |
| Fishing Hut | 300 |
| Fish Bowl | 20 |
| Chef's Knife | 275 (plus level 35) |

This settles the Rack ~140 / Hut 300 conflict in the guides.

**Placeable spells**
- **Rack (1307247) and Hut (1307246):** each summons a game object (effect 50) and creates an area trigger (effect 179; misc 43850 for the Rack, 43851 for the Hut). Neither applies an aura directly.
- **Craft spells:** 1262990 makes the Rack and 1262998 makes the Hut (effect 24).

**Candidate buff auras** (effect 6, aura 4 = dummy)
- `1280341 Uncommon Fishing`
- `1280342 Rare Fishing`
- The guides say the Rack allows Uncommon catches and the Hut allows Rare. So the likely mapping is Rack = 1280341 and Hut = 1280342, applied by the area triggers. **Needs an in-game check at a camp.**

**Other auras found**
- `1225455 Luremaster` (aura 4)
- `1277246 Fishing Lure`
- `1299323 Master Angler!`
- Fish Bowl's buff aura was not identified: 1255254 triggers 1229745, which only creates an item.

**Water-walking auras** (aura 104 = water walk)
- `11319 Water Walking`: the Draught's aura in Classic.
- `1299351` and `1310296 Water Walking`: likely Surfer Shoes or other new sources.
- `546` (shaman) and `1221095 Water Walk`.
- Spell 11447 "Draught of Water Walking" creates an item (crafting), so it is not an aura.

## Still needed
- Site 4: at a Campsite Fishing Rack / Fishing Hut.
- Site 5: with water-walking active.
- Item IDs: the four Artisan quest fish, Surfer Shoes, Draught of Waterwalking, any Uncommon/Rare/Unique fish, and the Chef's Knife product.
