# Research Questions

## Context
Focus on the `WarlockCombatKit` addon: `Data.lua`, `Core.lua`, `Settings.lua`, `Logic.lua`, `Actions.lua`, and `tests/run.lua`. Prior WCK research and probe notes live in `thoughts/qrspi/GH-23-warlock-combat-kit/` and `thoughts/qrspi/2026-10-21-warlock-combat-tooling/`. The target client is WoW Forever (Midnight-era API, with "secret" values in combat).

## Questions
1. Where does `WCK.DATA.rotation` come from, and trace every consumer of it (settings dropdowns, `BuildRuleState`, `EvalRules`, mouseover slots, panel, tests). What does each consumer assume about the list's contents?
2. How does `WCK.Known(name)` decide a spell is known? How do `C_Spell.GetSpellInfo` by name and `IsPlayerSpell` behave for talent-granted or capstone spells, and for spells that replace another spell (override spells)?
3. What spell metadata does the addon or its research notes record about Warlock spells on Forever (names, IDs, harmful vs. helpful, passive vs. active, talent capstones such as Wrack)? Where is each recorded?
4. What APIs on this client can enumerate the player's spellbook or known spells (e.g. `C_SpellBook`, spell book tabs/skill lines, `C_AssistedCombat.GetRotationSpells`), and what does each return — including passive/active, offensive/utility flags — and whether results are secret in or out of combat? Check other addons in this repo (e.g. `WarlockUtilityKit`, `TackleBox`) for existing spellbook scanning code.
5. How are saved rules and mouseover slots stored in `WCK.char`, and how do they handle a spell name that is not in `WCK.DATA.rotation` (load, display, evaluation, secure button setup)?
6. How does `tests/run.lua` stub the WoW API and exercise rule state and the settings data, and which tests reference the rotation list?
