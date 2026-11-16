# Design Discussion

## Current State
- Both WCK spell dropdowns, rotation rules (`WarlockCombatKit/Settings.lua:33-40`) and mouseover slots (`Settings.lua:100-111`), list `KnownSpells()` (`Settings.lua:19-23`). That function filters a fixed list of 24 enUS names, `WCK.DATA.rotation` (`Data.lua:20-23`), through `WCK.Known` (`Core.lua:153-156`). Wrack (a castable Affliction capstone on Forever) is not in the list, so it can never be picked.
- Rule state is also limited to that list. `BuildRuleState` loops `DATA.rotation` (`Core.lua:160`), and `EvalRules` skips any rule whose spell is not in `state.known` (`Logic.lua:117`). So a spell outside the list, even a hand-saved one, never evaluates.
- Slots don't depend on the list at cast time. `CastMacro` builds `/cast ... <name>` from any string (`Logic.lua:137-140`), and attributes are applied out of combat only (`Actions.lua:17-20`).
- WUK already scans the spellbook successfully on Forever with `C_SpellBook` skill lines and slots (`WarlockUtilityKit/Core.lua:64-85`), rescanning on `SPELLS_CHANGED`.
- Tests cover only `Data.lua` and `Logic.lua` with no WoW stubs (`tests/run.lua:1-4`). They never reference `DATA.rotation`.
- The panel core shows `WCK.next` but can't be clicked (`Panel.lua:193-199`). Addons can't change a secure button's spell in combat, so one changing button can't work. Issue 28 asks for a fixed button per rule spell instead.
- Glow helpers already exist: `WCK.AddGlow` / `WCK.SetAlert` (`Panel.lua:24-38`, texture-only, combat safe), and the Nightfall orb glows fel green (`Panel.lua:142-157`, `:200-206`). `WCK.MakeMovable` saves positions under `db.frames[key]` and blocks dragging in combat (`Panel.lua:8-21`).

## Desired End State
- Both dropdowns list every **active (non-passive) spell in the player's spellbook**, grouped into one submenu per spellbook tab (skill line), with names sorted inside each tab.
- New talents and capstones (Wrack) appear without code edits after learning them (`SPELLS_CHANGED`).
- Rules on any listed spell evaluate: known, ready and usable state are computed for them, and the panel core can suggest them.
- `WCK.DATA.rotation` is gone; nothing hard-codes the offered spells.
- **Rotation button bar:** a horizontal row of round, clickable spell buttons, one per distinct spell in `WCK.char.rules`, in rule order (10 max, duplicates share one button).
  - Fear and Banish (when known) are always appended at the right end as emergency buttons, after a small gap.
  - Clicking a button casts its spell.
  - The button for the current suggestion (`WCK.next`) lights up with a purple pulse.
  - Shadow Bolt glows fel green while Nightfall is up.
  - Spells that are on cooldown or unusable are desaturated.
  - The bar is rebuilt only out of combat. A rule edit made in combat applies after combat.
- Verify:
  - `lua WarlockCombatKit/tests/run.lua` passes, with a new test for the grouping and filtering logic.
  - In game on a warlock with Wrack:
    - Wrack shows under its tab in both dropdowns.
    - A `Wrack / ready` rule lights the panel core.
    - A slot set to Wrack casts it.
    - Existing saved rules (Corruption, Shadow Bolt and so on) still work.
    - The bar shows one button per rule spell. Clicking casts it, including in combat.
    - The suggested button pulses as the suggestion changes in combat, with no taint or blocked-action errors.
    - Shadow Bolt glows green on a Nightfall proc.
    - A rule edited in combat changes the bar after combat.
    - Shift+drag moves the bar out of combat, and its position persists.

## Patterns to Follow
- **Spellbook walk:** `WarlockUtilityKit/Core.lua:66-74`. Loop `GetNumSpellBookSkillLines`, then `GetSpellBookSkillLineInfo(i)`, then the slots `itemIndexOffset+1..+numSpellBookItems` with `Enum.SpellBookSpellBank.Player`. WCK uses `C_SpellBook.GetSpellBookItemInfo` instead of `GetSpellBookItemName`, so it gets `itemType`, `isPassive` and `name` in one call. Wiki fields are in `research.md` Q4.
- **Rescan on `SPELLS_CHANGED`** (WUK plan, `thoughts/qrspi/2026-10-19-warlock-utility-kit/plan.md:318-372`), registered through WCK's own `WCK.On` (`Core.lua:146-148`).
- **Pure logic in `Logic.lua`, API glue in `Core.lua`** (research cross-cutting). The grouping, filtering and sorting goes in a pure function over plain tables so `tests/run.lua` can test it, like `RowsView` (`Logic.lua:75`, tested at `run.lua:38`).
- **Guard client calls** with `pcall` plus `WCK.Secret` (`Core.lua:154`, `:163-166`). Keep the last good list if a scan fails.
- **Menu rebuilt on `GenerateMenu()`** in `SyncRules` and slot sync (`Settings.lua:79`, `:117`). The menu builder reads the cached scan, so no extra wiring is needed.
- **Out-of-combat secure updates** stay exactly as they are (`Actions.lua:18`, PLAYER_REGEN_ENABLED, `Core.lua:51`). The bar's attribute and show/hide changes use the same guard.
- **Secure buttons** follow `Actions.lua:7-14`: `SecureActionButtonTemplate`, `type="macro"`, `RegisterForClicks("AnyUp","AnyDown")`, and macro text from `WCK.CastMacro` (`Logic.lua:137-140`), so mouseover-harm casting matches the slots.
- **Glow and highlight:** `WCK.AddGlow` / `WCK.SetAlert` (`Panel.lua:24-38`). Fel tint is copied from the proc orb (`Panel.lua:151`). Round icon plus purple rim come from the panel's `Round`/rim style (`Panel.lua:75`, `:148`).
- **Position:** `WCK.MakeMovable(bar, "bar", x, y)` (`Panel.lua:8-21`).
- **Do NOT follow:**
  - Per-name probing of a fixed candidate list (`Core.lua:160`, `WUK/Core.lua:48-62`). That is the pattern that caused this bug.
  - WUK's Classic `GetNumSpellTabs` fallback (`WUK/Core.lua:75-82`). Forever has `C_SpellBook` (WUK runs on it), so it is dead code for WCK.

## Design Decisions
1. **List source: spellbook scan.** It replaces `DATA.rotation`, which is deleted. The fixed list is the root cause, and a curated union would keep the bug alive for the next missing spell.
2. **Filter: all active Player-bank spells.** Keep entries with `itemType == Enum.SpellBookItemType.Spell` and `not isPassive`. Skip lines with `shouldHide`, `FutureSpell` (unlearned), flyouts and pet actions. Utility spells such as Life Tap stay because rules use them. Harmful/helpful is not used as a filter.
3. **Layout: one submenu per tab.** `root:CreateButton(tabName)` is the submenu and `CreateRadio` sits inside it. Spells inside a tab are sorted alphabetically, and tabs keep spellbook order. The slot dropdown keeps "(none)" at the top level.
4. **Cache shape:**
   - `WCK.spellTabs = { {name=tab, spells={names...}}, ... }`
   - `WCK.spellSet = {[name]=true}`
   - Both are built by the pure `WCK.BuildSpellTabs(entries)` from raw scan rows `{tab, name, itemType, isPassive}`. Core scans on PLAYER_LOGIN (inside the existing warlock-only init, `Core.lua:195`) and on `SPELLS_CHANGED`.
5. **Rule state iterates the rule spells, not a catalogue.** `BuildRuleState` loops the distinct `spell` values in `WCK.char.rules` (at most 10). Known is `WCK.spellSet[name]`, and ready/usable reads stay unchanged. This means fewer API calls than today, and any saved spell that is in the book works.
6. **Spell names stay the key.** Rules, slots, macros and `C_Spell` calls are all name-based today (research cross-cutting). Saved data is unchanged and needs no migration.
7. **`WCK.Known` stays** for the proc refresher (`Core.lua:136-138`). Only the rotation and settings uses move to `spellSet`.
8. **One distinct-spells helper:** pure `WCK.RuleSpells(rules)` returns the ordered, de-duplicated, non-empty spell names. Both `BuildRuleState` (decision 5) and the bar use it, and it gets a test in `tests/run.lua`.
9. **Bar is its own frame, not part of the panel:** a new file `Rotation.lua` (in the TOC after `Actions.lua`).
   - The bar frame `WCKRotationBar` (parent UIParent) is movable through `MakeMovable` with key `"bar"`, default position just under the panel.
   - It is not anchored to `WCKPanel`. A protected child would restrict the panel's moving and resizing in combat, and the panel resizes every render (`Panel.lua:230`).
   - Buttons are 32px round, spaced 4px, laid out left to right.
10. **Rebuild only out of combat.**
    - The refresher runs `if InCombatLockdown() then return end`, then assigns `RuleSpells` to buttons 1..n (setting macrotext and icon texture, and showing them) and hides the rest. Buttons are pooled (10, created at init), and the bar width is set to fit.
    - In combat the spell set stays frozen. PLAYER_REGEN_ENABLED, then Refresh, picks up any rule edit, the same as the slots.
11. **Highlights run every refresh, in and out of combat (non-secure textures only):**
    - Each button gets `WCK.SetAlert(b, b.spell == WCK.next)` in purple.
    - The Shadow Bolt button gets a second, fel-tinted glow while `WCK.procs.nightfall` is set (and `db.procAlerts`).
    - Icons are desaturated when `state.ready[spell] == false or state.usable[spell] == false` or the spell isn't known. The refresher stores its state as `WCK.ruleState` so the bar can read it without querying again.
    - Highlights read the button's frozen spell, so they stay correct in combat even if the rules changed.
    - Grey is visual only. The button is never disabled, and clicks always go through (the game itself rejects a cast that isn't possible). `SetDesaturated` goes on the icon texture only, never `Disable()` or `EnableMouse(false)` on the button.
12. **Emergency buttons:** Fear and Banish always sit at the right end of the bar, after the rule spells.
    - **Revised during Phase 2 (user request):** the end group is `WCK.DATA.tail = { "Shadow Bolt", "Fear", "Banish" }`, with Shadow Bolt first. Tail spells are pulled out of the rule order, so they never show twice and always sit in the end group. The flag is `tail` instead of `emergency`, and `BAR_MAX` = 13. Rules still evaluate Shadow Bolt normally. Only its bar position changes. The bullets below are the original wording.
    - The fixed list is `WCK.DATA.emergency = { "Fear", "Banish" }` in `Data.lua`. This is deliberate and separate from rules.
    - Each one shows only if it's in `WCK.spellSet`.
    - A spell already in the rules keeps its rule-order slot and isn't repeated at the end.
    - An 8px gap separates them from the rule buttons.
    - Their highlights are the same as other buttons: they pulse if a rule makes one of them `WCK.next`, and go grey when not ready or usable. They are always clickable.
    - Pure `WCK.BarSpells(rules, emergency, known)` returns `{ {spell, emergency=bool}, ... }` (rule spells, then emergency spells not already listed and known). It's tested in `tests/run.lua`.
    - The button pool grows to `MAX_RULES + #emergency` = 12.
12b. **Revised during Phase 2 (user request): dock the bar to the circle and make the core Life Tap.**
    - The core is a fixed secure Life Tap button (`WCK.DATA.core`) and pulses when a rule suggests Life Tap. It no longer shows the suggestion icon.
    - The bar docks to the right of the circle.
    - The panel anchors to the secure core button, so decision 9's "not anchored" rule holds in the safe direction: no secure frame is anchored to the panel.
    - Circle and bar move together via the bar's "bar" position.
13. **Bar sits alongside the mouseover slots** and doesn't replace them. Slots are for key bindings, the bar is for clicking.
14. **Toggle:** `db.showBar` (default true) with a "Show rotation buttons" checkbox next to "Show panel" (`Settings.lua` checks list). The bar also hides when `db.shown` is false. Show/hide follows the out-of-combat rule.
15. **Click target:** reuse `CastMacro` (`/cast [@mouseover,harm,nodead][] <spell>`), the same as the slots. Clicking the bar puts the mouse over the bar, not a unit, so in practice it casts on the current target.

## What We're NOT Doing
- No auto-cast or one-button rotation. Every click is a manual press.
- No cooldown swipe: `startTime` is secret in combat (`research.md` Q4). Desaturation stands in for it.
- No key bindings for bar buttons (the slots already cover binding). No arc layout around the circle.
- No harmful/helpful classification, spell IDs or spell metadata in `Data.lua`.
- No pet-bank spells (Seduction and the like) in the dropdowns.
- No validation, pruning or "unknown spell" display for saved names that aren't in the book. They keep today's behaviour: skipped, with blank dropdown text.
- No ScrollBox or MAX_RULES change, no localisation, no Classic spellbook fallback.
- No change to `DATA.tracked` (cast map/DoT rows) or the proc logic.

## Open Risks
- **`GetSpellBookItemInfo` on Forever is unprobed** (`research.md` Open Areas). Field names or `isPassive` could differ from the wiki. Mitigation: WUK proves the slot walk works, so first deploy with an in-game check. If info fails, fall back to `GetSpellBookItemName` plus `C_SpellBook.IsSpellBookItemPassive`.
- **`SPELLS_CHANGED` in combat:** the scan may read secret values or fire mid-fight. Guard with pcall/Secret and keep the previous cache. Rule state only reads the cache.
- **Override names:** `name` from item info may show the override (Bane vs Curse). Whatever the book shows is what the user picks, and it matches what the cast and cooldown calls accept by name. Saved rules on the other name keep today's skip behaviour.
- **Dropdown selected text with submenus:** confirm in game that `WowStyle1DropdownTemplate` shows the checked radio from inside a submenu. If not, set the text explicitly via `SetSelectionText`.
- **Secure frame in combat:** showing, hiding or resizing the bar in combat is blocked. Every such call must sit behind `InCombatLockdown()`. A `/wck hide` in combat would hide the panel and leave the bar until after combat, which is acceptable.
- **`WCK.next` can name a spell with no button:** that happens if rules changed in combat. Then no button pulses until combat ends. The panel core still shows it.
- **General tab noise:** racials and Auto Attack-type spells will appear under "General". This is accepted under the all-active-spells choice.
