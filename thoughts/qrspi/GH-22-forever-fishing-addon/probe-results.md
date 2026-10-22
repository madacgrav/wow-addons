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

## Still needed
- Site 2: right after catching a fish (loot window closed). This gives the `CHANNEL_STOP` vs `LOOT_READY` order.
- Site 4: at a Campsite Fishing Rack / Fishing Hut.
- Site 5: with water-walking active.
- Item IDs: the four Artisan quest fish, Surfer Shoes, Draught of Waterwalking, any Uncommon/Rare/Unique fish, and the Chef's Knife product.
