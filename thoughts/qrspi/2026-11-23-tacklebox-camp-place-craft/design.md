# Design Discussion

## Current State
- **Fishing bar:** secure 40px buttons keyed `pole, lure, water, cast` (`Actions.lua:5`). The refresher builds `A[key] = {item|spell|macro, usable, need}` from pure pickers in `Logic.lua` (`Actions.lua:151-186`). `Apply()` maps keys to `type` attributes out of combat only, greys out `usable == false`, and stacks shown buttons at 44px (`Actions.lua:90-123`).
- **Camp tab:** reports only. `campBuffs` holds Rack/Hut aura IDs 1280341/1280342, which are unconfirmed in game (`Data.lua:85-89`). `ReadAura` (`Core.lua:72-79`) and `CampRows` (`Logic.lua:152-164`) give "left / active / needs skill / available". Item IDs 279965/279966 are used only for icons (`Panel.lua:331`).
- **Camp items are crafted** (research Q3):
  - Fish Bowl 279967: trainer recipe at Fishing 20, recipe spell 1229745.
  - Fishing Rack 279965: Blueprint 273141, Fishing 140, recipe spell 1262990.
  - Fishing Hut 279966: Blueprint 273119, Fishing 300, recipe spell 1262998.
  - The probe's DB2 craft spells agree (`probe-results.md:100-102,113`).
- **Camp rules** (Blizzard, verified): items need a nearby campfire; all of a player's camp items share a 1 h cooldown; sit for 1 min to gain the buff. Campfire kits are Cooking recipes: Basic 279981, Journeyman 279961, Expert 279974 (reported).
- **Unknown:**
  - whether crafting works from an addon click (`C_TradeSkillUI.CraftRecipe` present `idx:973`, protection unverified);
  - whether a secure `type=item` use of a placeable is instant or opens a cursor;
  - the real camp buff IDs and how a campfire shows up to the client.
- No cooldown API is used anywhere in the repo; `C_Container.GetItemCooldown` is present (`idx:433`, wiki lists Forever).

## Desired End State
1. **One "Camp" button** on the fishing bar (5th key, between water and cast). It shows the single most useful camp action:
   1. **Place campfire:** a campfire kit is in bags and no campfire is detected.
   2. **Cooldown:** the camp cooldown is running. The button is greyed with a cooldown swipe and the tooltip reads "camp ready in M:SS".
   3. **Place camp item:** the best owned camp item your Fishing skill allows (Hut > Rack > Bowl), when its buff is not up.
   4. **Craft camp item:** none owned, but a known recipe with all reagents in bags (Hut > Rack > Bowl).
   5. Otherwise hidden. A greyed button with `need` text covers "Requires Fishing N" / "missing reagents".
2. **Camp tab** gains a "camp ready in M:SS" or "camp ready" line, and "can craft: Fish Bowl" sub text. Buff rows use the probe-confirmed aura IDs.
3. **Crafting method** is chosen by the Phase 1 probe. The first that works from a click wins:
   1. macro `/cast <recipe name>`;
   2. secure `type=spell` with the recipe spell;
   3. `C_TradeSkillUI.CraftRecipe(id)` from the button's PostClick.

   If none works, the button opens Fishing (`C_TradeSkillUI.OpenTradeSkill(356)`) so you press Create.

Verify:
- `lint.sh TackleBox` and `lua tests/run.lua` are green, with tests for the camp picker and cooldown text.
- In game: with a kit and no fire, the button places the fire; next to the fire, it places the best item; during the cooldown it is greyed with time left; with reagents and no item, a click crafts (or opens the window per the probe); `/reload` keeps nothing stale; no `ADDON_ACTION_BLOCKED` in or after combat.

## Patterns to Follow
- **Bar button = picker + `A[key]` + `Apply` branch** (`Actions.lua:151-186`, `:90-123`). Add `camp` to `ORDER` (`Actions.lua:5`) and a `TIPS` entry (`:6`); greyed state via `usable=false` + `need` (`:96-97,108-109`); icon desaturation (`:110-111`).
- **Pure pickers in `Logic.lua` with `eq` tests:** `WaterWalkPick`/`PickLure` shape (`Logic.lua:167-201`, `tests/run.lua:70-88`). The new `TB.CampPick(...)` returns `action, id, usable, need` with no WoW calls; all inputs are passed in.
- **Item uses go through secure attributes, never insecure calls:** `type="item"` like water (`Actions.lua:103-104`); macro text like lure (`:100-102`). Set only out of combat (`:91`); `PLAYER_REGEN_ENABLED` re-applies (`Core.lua:61`).
- **Aura reads** via `TB.ReadAura` with combat cache and secret guard (`Core.lua:72-79`).
- **Data provenance:** every item/spell ID in `Data.lua` traces to `probe-results.md` or a DB2 lookup, and third-party values carry a source comment (`Data.lua:2,85`). Reagent item IDs not yet probed (e.g. Simple Wood, Seasonal Fish Steaks) are captured by the Phase 1 probe before use.
- **Probe-first** for unverified behaviour: extend `TB.Probe` with `Try` sections (`Core.lua:265-361`) and record in `probe-results.md`.
- **Do NOT follow:**
  - icons matched to rows by index (`Panel.lua:331-336`); give each camp entry its own item ID instead;
  - the unused subzone fallback in `CampRows` (`Logic.lua:156`); leave it, don't build on it.

## Design Decisions
1. **Single Camp button** (Q1 A): one 5th bar key `camp`, whose priority picker decides place-fire / cooldown / place-item / craft. One slot keeps the bar short.
2. **Crafting is probe-chosen** (Q2 A):
   - Phase 1 tests the three click methods on the Fish Bowl recipe (the cheapest reagents, and the user already knows it).
   - The working one is recorded in `probe-results.md` and hard-coded as `TB.CRAFT_METHOD = "macro" | "spell" | "api" | "window"`.
   - The "window" fallback is always implemented: it is a plain button click → `C_TradeSkillUI.OpenTradeSkill(356)`, which is safe from a click.
3. **Campfire included** (Q3 A):
   - `DATA.campfires = { {item=279981, tier=1}, {279961,2}, {279974,3} }`, preferring the highest owned.
   - "Campfire up" detection comes from the probe: aura ID or name when standing at a fire; if none exists, assume a fire is up once a camp item use succeeds or after the user places one (tracked by `UNIT_SPELLCAST_SUCCEEDED` of the kit spell, valid while the player stays within ~30 yd).
4. **Fishing items only** (Q4 A). `DATA.camp`:
   ```lua
   camp = {
     { key="hut",  item=279966, recipe=1262998, skill=300, aura=?, reagents={ {id,n},... } },
     { key="rack", item=279965, recipe=1262990, skill=140, aura=?, reagents={...} },
     { key="bowl", item=279967, recipe=1229745, skill=20,  aura=?, reagents={ {6291,1}, {3371,1} } },
   }
   ```
   - Aura IDs and missing reagent IDs are filled from the probe.
   - `campBuffs` is folded into this table (the Camp tab reads `DATA.camp`).
5. **Cooldown shown** (Q5 A):
   - `C_Container.GetItemCooldown(itemID)` on the first owned camp item; the shared cooldown means any one answers.
   - The button uses `CooldownFrameTemplate` (`Cooldown:SetCooldown`).
   - Refresh on `BAG_UPDATE_COOLDOWN`; the existing 1 s ticker also runs while the cooldown is active.
   - Pure `TB.CampCooldownText(start, duration, now)` is tested.
6. **"Known recipe":**
   - Probe whether `C_SpellBook.IsSpellKnown(recipeSpell)` or `C_TradeSkillUI.GetRecipeInfo(id).learned` answers without the profession window open.
   - Fallback: the recipe counts as known when the Blueprint item is not in bags and the skill ≥ unlock (Bowl: skill ≥ 20). The craft attempt then reports any failure through the game's own error.
7. **Reagent check:** `C_Item.GetItemCount(id)` per reagent (bags only, matching how the crafting spell consumes). The pure `TB.CanCraft(reagents, counts)` returns `ok, firstMissing`, and the tooltip names the missing reagent.
8. **Combat:** the button is configured only out of combat (existing `Apply` gate) and keeps its last state during combat; clicks there do nothing harmful. The "api" craft method is skipped in combat.
9. **No options UI, no new libs; vanilla frames.**

### Constraints
- Interface `16001` (skill `references/toc-format.md`).
- No never-emit names (`references/forever-api-notes.md`); use `C_Container`/`C_Item`/`C_Spell`/`C_SpellBook`/`C_TradeSkillUI`.
- Every API name verified in `references/forever-api-index.md` or the lint std; unverified behaviour is probed first.

## What We're NOT Doing
- Non-fishing camp items (Lute, Mana Well, Camp Tent, …).
- Upgrading campfire tiers or placing over a lower tier.
- Buying reagents or blueprints, and tracking blueprint drop sources.
- Auto-placing or auto-crafting without a click.
- Party/raid camp coordination (who places which feature).
- The unconfirmed "Simple Fish Drying Rack / Fisher's Bait Table / Grand Angler's Basin".
- Changing the Water/Lure/Pole buttons or the cast key.

## Open Risks
- **Crafting may be blocked** for every click method → window fallback (two clicks). Acceptable.
- **Placement may open a ground-target cursor:** one click arms it, a second click places it. Document it; still one button.
- **Campfire detection may have no aura** → heuristic (recent kit cast plus distance) can be wrong after moving away; the tooltip says "place near your campfire".
- **Recipe-known check** may need the profession window opened once per session. Fallback heuristic in decision 6.
- **Buff aura IDs** may differ from 1280341/1280342; the probe fixes them, and the Camp tab follows.
- **Reagent IDs** for Simple Wood and Seasonal Fish Steaks are not in repo; the probe bag scan or wago lookup must supply them before the Rack/Hut craft rows work.
- **Shared cooldown** might be a spell cooldown, not an item cooldown → probe both `C_Container.GetItemCooldown` and `C_Spell.GetSpellCooldown(placeSpell)`.
