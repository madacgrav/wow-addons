# Structure Outline

## Approach
Probe first (craft methods, placement, campfire and camp buffs, cooldown source, recipe-known check, reagent IDs), then add one `camp` key to the fishing bar driven by a pure `TB.CampPick`. Place first, then cooldown, then craft, then docs.

Every phase: `lint.sh TackleBox` clean, `lua TackleBox/tests/run.lua` prints "all tests passed", robocopy deploy, in-game `/reload` with no errors.

## Phase 1: Probe camp and crafting
One `/tb camp` probe command plus temporary test buttons answer every open risk; results go to `probe-results.md` (Run 7).

**Files**: `TackleBox/Core.lua`, `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md`
**Key changes**:
- `TB.CampProbe()` (via `/tb camp`) prints:
  - helpful auras with names (to spot campfire and camp buffs);
  - `C_Container.GetItemCooldown` and `C_Spell.GetSpellCooldown` for camp items and place spells;
  - `C_Item.GetItemSpell` per camp item and kit;
  - `C_SpellBook.IsSpellKnown` and `C_TradeSkillUI.GetRecipeInfo(id)` for the 3 recipes;
  - bag items whose names hit "Wood", "Steak", "Vial", "Runecloth", "Trout", "Smallfish", "Campfire".
- Temporary `TBProbeCraft1/2/3` buttons (`/tb camp craft 1|2|3`) try the Fish Bowl craft by macro `/cast Fish Bowl`, by secure `type=spell` 1229745, and by `C_TradeSkillUI.CraftRecipe(1229745)` on click. The trace logs `UNIT_SPELLCAST_SUCCEEDED` / `TRADE_SKILL_ITEM_CRAFTED_RESULT` / `UI_ERROR_MESSAGE`.
- Temporary `/tb camp use <itemID>` secure button to observe placement (instant vs cursor).

**Verify**: lint and tests green. In game:
- Run `/tb camp` away from and next to a lit campfire, and after placing a Fish Bowl.
- Try each craft button, and use the kit and the Bowl via the test button.
- Paste the output into probe-results.md.
- **Gate:** placement works from a secure item click. If it doesn't, stop and revisit the design.

---

## Phase 2: Camp data + Camp tab from probe facts
Replace `campBuffs` with `DATA.camp` + `DATA.campfires` using probe-confirmed IDs; the Camp tab reads the new table and shows "can craft".

**Files**: `TackleBox/Data.lua`, `TackleBox/Logic.lua`, `TackleBox/Panel.lua`, `TackleBox/tests/run.lua`, `TackleBox/Core.lua` (remove temporary probe buttons; keep `/tb camp` read-only report)
**Key changes**:
- `DATA.camp = { {key, name, item, recipe, skill, aura, reagents={{id,n}}} }` (Hut, Rack, Bowl); `DATA.campfires = { {item, tier, aura?} }`; `DATA.campCraftMethod = "<probe result>"`.
- `TB.CanCraft(reagents, counts) -> ok, missingID`.
- `TB.CampRows(camp, state, skill, counts, known)`: the existing rows plus "can craft" / "missing <reagent>" sub text. The signature change updates the tests at `tests/run.lua:63-67`.
- Camp section icons come from each entry's `item`, not by index.

**Verify**: tests for `CanCraft` (all present, one missing, zero counts) and the updated `CampRows`. In game: the Camp tab shows the Bowl/Rack/Hut rows with correct buff state next to a fire and "can craft" with reagents.

---

## Phase 3: Camp button: place campfire and camp item
Fishing bar 5th key `camp`, place actions only.

**Files**: `TackleBox/Actions.lua`, `TackleBox/Logic.lua`, `TackleBox/tests/run.lua`
**Key changes**:
- `ORDER = {"pole","lure","water","camp","cast"}`, plus a `TIPS.camp` entry.
- `TB.CampPick(st) -> action, id, usable, need`, where `st = {skill, owned={[id]=n}, buffs={[key]=bool}, fireUp, cooldown}`. Actions are "fire" | "place" | nil in this phase.
- Refresher builds `st` (counts, `ReadAura`, fire detection per the probe), then `A.camp = {item=id, usable, need, action}`.
- `Apply`: `camp` → `type="item"`, `item="item:<id>"`.

**Verify**: tests for `CampPick`: kit and no fire → fire; fire up → best item by skill; buff already up → next or nil; skill too low → greyed with `need`; nothing owned → nil. In game: the button places the fire, then the Bowl; it hides when the buff is up; no taint in or after combat.

---

## Phase 4: Cooldown display
**Files**: `TackleBox/Actions.lua`, `TackleBox/Logic.lua`, `TackleBox/Panel.lua`, `TackleBox/Core.lua`, `TackleBox/tests/run.lua`
**Key changes**:
- `TB.CampCooldownText(start, duration, now) -> text|nil` (pure).
- The cooldown source chosen by the probe (item or spell cooldown) feeds `st.cooldown`; `CampPick` returns "cooldown" with `usable=false`, `need="camp ready in M:SS"`.
- The camp button gets a `CooldownFrameTemplate` child, `SetCooldown(start, duration)`.
- `BAG_UPDATE_COOLDOWN` (or `SPELL_UPDATE_COOLDOWN`) → `TB.Refresh`; the 1 s ticker also runs while the cooldown is active.
- The Camp tab header row shows "camp ready in M:SS" / "camp ready".

**Verify**: tests for `CampCooldownText` (running, finished, zero duration) and `CampPick` cooldown priority. In game: after placing, the button is greyed with a swipe and time left; it re-enables when the cooldown ends.

---

## Phase 5: Camp button: craft
**Files**: `TackleBox/Actions.lua`, `TackleBox/Logic.lua`, `TackleBox/Core.lua`, `TackleBox/tests/run.lua`
**Key changes**:
- `CampPick` adds "craft": nothing owned and `CanCraft` ok and known (by the probe-chosen known-check, else the skill/blueprint heuristic).
- `Apply` branch by `DATA.campCraftMethod`:
  - "macro" → `type="macro"`, `/cast <name>`;
  - "spell" → `type="spell"`, `spell=<recipe>`;
  - "api" → PostClick `C_TradeSkillUI.CraftRecipe(recipe)`, skipped in combat;
  - "window" → PostClick `C_TradeSkillUI.OpenTradeSkill(356)`.
- The craft icon overlay distinguishes craft from place: the item icon plus a small hammer badge.

**Verify**: tests for craft priority (owned beats craft; missing reagent → greyed with "missing X"; unknown recipe → nil). In game: with Bowl reagents and no Bowl, a click crafts it (or opens Fishing with the window method) and the button then switches to place.

---

## Phase 6: Docs and release 1.3.0
**Files**: `TackleBox/README.md`, `TackleBox/CHANGELOG.md`, `TackleBox/TackleBox.toc`, root `README.md`
**Verify**: lint and tests green; README Camp section and commands match `/tb` help; version 1.3.0.

## Testing Checkpoints
- **After 1:** probe-results Run 7 records the craft method, placement mode, fire/buff auras, cooldown source, known-check and reagent IDs; gate passed.
- **After 2:** `DATA.camp` replaces `campBuffs`; the Camp tab shows correct buffs and "can craft".
- **After 3:** the camp button places the fire and the best camp item.
- **After 4:** the cooldown is shown on the button and in the tab.
- **After 5:** the camp button crafts when nothing is owned.
- **After 6:** docs updated, 1.3.0 ready.
