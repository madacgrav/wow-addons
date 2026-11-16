# Structure Outline

## Approach
Replace the fixed `DATA.rotation` with a cached spellbook scan that feeds both dropdowns (grouped by tab) and the rule state. Then add a separate, movable bar of secure buttons: one per rule spell plus Fear/Banish. Its spell set is rebuilt out of combat, and its highlights are drawn every refresh.

Each phase ends with: `lua WarlockCombatKit/tests/run.lua` passes, then robocopy `WarlockCombatKit` into `_forever_\Interface\AddOns`, then an in-game check.

---

## Phase 1: Spellbook-driven dropdowns and rule state
After `SPELLS_CHANGED`, Wrack (and any learned active spell) shows in both dropdowns under its spellbook tab, and a rule on it lights the panel core.

**Files**: `WarlockCombatKit/Logic.lua`, `Core.lua`, `Settings.lua`, `Data.lua`, `tests/run.lua`, `CHANGELOG.md`
**Key changes**:
- `WCK.BuildSpellTabs(entries) -> tabs, set` (new, pure, `Logic.lua`)
  - `entries`: `{ {tab=string, name=string, itemType=number, isPassive=bool}, ... }` in spellbook order
  - `tabs`: `{ {name=tab, spells={sorted names}}, ... }` in tab order; empty tabs dropped
  - `set`: `{[name]=true}`
  - Keeps only `itemType == 1` (Spell) and `not isPassive`
- `WCK.RuleSpells(rules) -> {names}` (new, pure, `Logic.lua`): distinct, non-empty `rule.spell` values in rule order.
- `WCK.ScanSpellbook()` (new, `Core.lua`)
  - Walks `C_SpellBook` skill lines (skips `shouldHide`) and calls `GetSpellBookItemInfo(slot, Player)` under pcall.
  - Sets `WCK.spellTabs` and `WCK.spellSet`, keeping the old cache on failure.
  - Called from the warlock init (`Core.lua:195`) and from `WCK.On("SPELLS_CHANGED", ...)`, followed by `Refresh`.
- `WCK.BuildRuleState(now)` (modified, `Core.lua:158`): loops `RuleSpells(WCK.char.rules)`, and `known[name] = WCK.spellSet[name]`. Ready/usable are unchanged.
  - The refresher stores the state as `WCK.ruleState` (used in Phase 3).
- `Settings.lua`: delete `KnownSpells()`. Both dropdowns build one `root:CreateButton(tab.name)` submenu per `WCK.spellTabs` entry, with radios inside. The slot dropdown keeps "(none)" at the top level.
- `Data.lua`: delete `WCK.DATA.rotation`. Add `WCK.DATA.emergency = { "Fear", "Banish" }` (used in Phase 2).

**Verify**:
- Tests: new cases for `BuildSpellTabs` (passive, future-spell and empty tabs dropped; sorting) and `RuleSpells` (dedupe, order, empty or nil spell skipped).
- In game:
  - Rule and slot dropdowns show tab submenus, and Wrack is under Affliction.
  - The selected spell's text still shows on the dropdown button.
  - A `Wrack / ready` rule puts Wrack in the panel core.
  - Old saved rules still evaluate.
  - `/reload` in combat shows no errors.

---

## Phase 2: Rotation button bar (click and suggestion pulse)
A horizontal bar of round buttons: one per rule spell, then Fear and Banish after a gap. Clicking casts. The button for `WCK.next` pulses purple. A checkbox toggles the bar.

**Files**: `WarlockCombatKit/Rotation.lua` (new), `WarlockCombatKit.toc`, `Logic.lua`, `Core.lua` (DEFAULTS), `Settings.lua`, `tests/run.lua`, `README.md`, `CHANGELOG.md`
**Key changes**:
- `WCK.BarSpells(rules, emergency, known) -> { {spell=string, emergency=bool}, ... }` (new, pure, `Logic.lua`): `RuleSpells(rules)`, then emergency names that are known and not already listed.
- `WCK.BAR_MAX = 12` (`MAX_RULES + #DATA.emergency`).
- `Rotation.lua`:
  - Init creates `WCKRotationBar` (UIParent). It is not anchored to `WCKPanel`.
  - `WCK.MakeMovable(bar, "bar", x, y)`, defaulting under the panel.
  - Pools 12 `SecureActionButtonTemplate` buttons (`type="macro"`, AnyUp/AnyDown), 32px, round icon with purple rim, plus `WCK.AddGlow`.
  - Secure refresher (returns early under `InCombatLockdown()`):
    - Assigns `BarSpells(...)` to buttons: `b.spell`, macrotext `WCK.CastMacro(spell)`, icon texture, and position (+8px before the first emergency button).
    - Hides unused buttons and sizes the bar.
    - Bar shown = `db.shown and db.showBar`.
  - Highlight refresher (every refresh, non-secure): `WCK.SetAlert(b, b.spell == WCK.next)`.
- `Core.lua` DEFAULTS: `showBar = true`.
- `Settings.lua`: a "Show rotation buttons" checkbox under "Show panel".
  - This shifts the following checkboxes down 28px. The window height grows if needed.
- TOC: `Rotation.lua` goes after `Actions.lua`, before `Settings.lua`.

**Verify**:
- Tests: `BarSpells` keeps rule order, dedupes, appends only known emergency spells, and doesn't repeat Fear if it's already in the rules.
- In game:
  - The bar shows rule spells, then a gap, then Fear and Banish.
  - Clicking casts on the target, both in and out of combat.
  - The suggested button pulses and follows `WCK.next` during combat.
  - Shift+drag moves the bar, and the position survives `/reload`.
  - The checkbox and `/wck hide` hide the bar out of combat.
  - Editing rules in combat updates the bar after combat.
  - No "blocked action" or taint messages.

---

## Phase 3: Nightfall glow and grey-out
The Shadow Bolt button glows fel green while Nightfall is up. Buttons for unknown, on-cooldown or unusable spells are desaturated but stay clickable.

**Files**: `WarlockCombatKit/Rotation.lua`, `Logic.lua`, `tests/run.lua`, `CHANGELOG.md`
**Key changes**:
- `WCK.ButtonLook(spell, state, procs) -> { dim=bool, fel=bool }` (new, pure, `Logic.lua`)
  - `dim = not state.known[spell] or state.ready[spell] == false or state.usable[spell] == false`
  - `fel = spell` matches a `DATA.procs` entry whose `key` is up in `procs`
- `BuildRuleState` also covers emergency spells, so Fear and Banish get ready/usable state. It loops `BarSpells` names instead of only `RuleSpells`.
- `Rotation.lua` buttons get a second glow (`b.fel`, fel tint as at `Panel.lua:151`). The highlight refresher applies `icon:SetDesaturated(look.dim)` and `WCK.SetAlert` on the fel glow, gated by `db.procAlerts`.
  - It never calls `Disable()` or `EnableMouse(false)`.

**Verify**:
- Tests: `ButtonLook` for each of: known/ready/usable all true, cooldown, unusable, unknown, Nightfall up on Shadow Bolt, and Nightfall up on another spell.
- In game:
  - Shadow Bolt glows green on a Nightfall proc while the existing orb/pulse/sound still fire.
  - A spell on cooldown goes grey, and clicking it still attempts the cast (the game shows its error).
  - Fear and Banish grey out when not usable.

---

## Testing Checkpoints
- **After Phase 1:**
  - `DATA.rotation` is gone.
  - Dropdowns come from the spellbook, grouped by tab, and include Wrack.
  - Rule state is keyed by rule spells.
  - All tests pass, and the release is usable on its own (it fixes the reported bug).
- **After Phase 2:**
  - The bar exists, is movable and toggleable, and its spell set is out-of-combat only.
  - Clicks cast.
  - The suggestion pulses.
  - Fear and Banish sit at the end.
- **After Phase 3:**
  - Fel Nightfall glow on Shadow Bolt.
  - Dim icons for unready spells, still clickable.
  - Full design delivered.
