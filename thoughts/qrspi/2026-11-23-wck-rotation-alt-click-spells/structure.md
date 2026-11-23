# Structure Outline

## Approach
Per-spell alternates in `char.alts[mainSpell] = { right, shift }`. A pure helper in `Logic.lua` turns a main spell and its alternates into secure attributes. The Rotation secure refresher applies them out of combat, and a new "Alt clicks" settings section edits them. Right-click ships first because it is the slice that proves Forever's modified-attribute lookup works. Shift+left reuses the same plumbing.

Deploy after each phase: robocopy `WarlockCombatKit` into `_forever_\Interface\AddOns` before the in-game check.

## Phase 1: Right-click alternate, end to end
Right-click on a bar button casts the spell chosen in settings. Unset falls back to the main spell. The tooltip shows the alternate.

**Files**: `WarlockCombatKit/Logic.lua`, `WarlockCombatKit/Core.lua`, `WarlockCombatKit/Rotation.lua`, `WarlockCombatKit/Settings.lua`, `WarlockCombatKit/tests/run.lua`

**Key changes**:
- `WCK.ALT_ATTRS = { right = "macrotext2", shift = "shift-macrotext1" }`: new, in `Logic.lua`. This phase handles only `right`; the table already names both.
- `WCK.AltAttrs(spell: string, alt: {right?:string, shift?:string}|nil) -> { [attrName]: string|nil }`: new. Returns `macrotext = CastMacro(spell)`, plus `CastMacro(alt.right)` for `right`, or `nil` when it is unset or empty. Callers iterate `WCK.ALT_ATTRS` so `nil` values clear stale attributes.
- `CHAR_DEFAULTS = { slots = {}, alts = {} }`: modified (`Core.lua:25`).
- Rotation secure refresher (`Rotation.lua:57-77`): replaces the single `SetAttribute("macrotext", …)` with a loop over `AltAttrs(e.spell, WCK.char.alts[e.spell])`. A hidden button clears its alternate attributes.
- Bar button `OnEnter` (`Rotation.lua:47-50`): appends a "Right-click: X" line when one is set.
- New `WCK.settingsSections` entry "Alt clicks" (after the slots section, `Settings.lua:92-121`). It has 13 pooled rows: a label (main spell) and a Right dropdown (`(none)` + `SpellMenu`). The sync rebuilds rows from `WCK.BarSpells(...)` and hides unused ones. A pick writes `char.alts[spell].right`, then calls `WCK.Refresh()` and prints "applies after combat" when locked.

**Verify**:
- `lua WarlockCombatKit/tests/run.lua` passes, with new `AltAttrs` cases: no alternate, right set, empty string, nil spell, and an alternate equal to the main spell.
- Skill `lint.sh WarlockCombatKit` is clean.
- In-game:
  - Set Right on Corruption to Fear. Left-click casts Corruption; right-click casts Fear.
  - An unset button's right-click casts its main spell.
  - Reorder rules: the alternate follows Corruption.
  - Change it in combat: no `ADDON_ACTION_BLOCKED`, and it applies after combat.
  - Core right-click still opens options.

**Fallback if `macrotext2` is ignored on Forever:** try `type2 = "macro"` plus `macrotext2`. If that also fails, stop and return to design.

---

## Phase 2: Shift+left alternate
Shift+left-click casts the shift spell. Shift+right resolves to the right alternate, then to the main spell.

**Files**: `WarlockCombatKit/Logic.lua`, `WarlockCombatKit/Rotation.lua`, `WarlockCombatKit/Settings.lua`, `WarlockCombatKit/tests/run.lua`

**Key changes**:
- `WCK.AltAttrs` also fills `["shift-macrotext1"]` from `alt.shift`.
- Tooltip: adds a "Shift-click: Y" line.
- "Alt clicks" rows: add a Shift dropdown beside Right (rows may need narrower dropdowns, roughly 110 px each, to fit 348 px).

**Verify**:
- Tests pass, with new cases: shift only, and both set.
- Lint is clean.
- In-game:
  - Shift+left casts the shift spell.
  - Shift+right casts the right alternate, or the main spell if none is set.
  - Plain clicks are unchanged.
  - Shift+drag starting on the bar background or panel still moves the kit.
  - Shift+drag starting on a button: record the result. If it casts, note it in the README rather than changing the code.

---

## Phase 3: Docs and release
Users can discover the feature, and the version is bumped.

**Files**: `WarlockCombatKit/README.md`, `WarlockCombatKit/CHANGELOG.md`, `WarlockCombatKit/WarlockCombatKit.toc`

**Key changes**:
- README rotation-bar section (around `README.md:72-75`): right-click and shift-click behaviour, the "Alt clicks" settings section, the fallback rule, and the Shift+drag note from Phase 2.
- CHANGELOG entry. TOC `## Version: 0.3.0` (feature bump from 0.2.2).

**Verify**:
- Tests and lint are clean.
- The TOC loads in-game with the new version shown in the AddOns list.
- The README matches observed behaviour.

## Testing Checkpoints
- **After Phase 1:**
  - `char.alts` exists after login, an empty table on existing characters.
  - Right-click alternates work and survive `/reload` and rule reorder.
  - Left-click and the core button are unchanged.
  - The Forever attribute lookup is confirmed for `macrotext2`; record which variant worked in `plan.md`.
- **After Phase 2:**
  - Both alternates work independently.
  - Shift+right falls back correctly.
  - The Shift+drag interaction is documented.
- **After Phase 3:**
  - Version 0.3.0.
  - README and CHANGELOG updated.
  - Ready for `/qrspi-plan-toolkit:8-pr`.
