# Research Questions

## Context
Focus on `WarlockUtilityKit/` (Core.lua, Settings.lua, Prep.lua, tests/run.lua) and how it detects known spells, stores per-character choices, and reads the active pet. The client is WoW Forever (`## Interface: 16001`), a Classic-era ruleset running on a modern client API; prior notes live under `thoughts/qrspi/` (warlock-utility-kit, GH-23 probe results).

## Questions
1. Where in WarlockUtilityKit is the set of demon/pet identifiers defined or enumerated (spell tables, settings lists, slash-command parsing, usage strings, defaults), and how do these separate lists relate to each other — is any one of them derived from another?
2. Trace how `WUK.known` is built from the spellbook: which spell names map to which keys, how ranked vs. unranked spells are resolved, and what happens when a key's spell is not in the spellbook.
3. How does the strip's pet button (Prep.lua) decide which spell to cast, which icon to show, and whether the chosen pet is "out"? Specifically, how does `WUK.PetFamily()` (via `UnitCreatureFamily`) produce its value, and what string format must a pet key match for the comparison to succeed?
4. What warlock demon summoning spells and creature families exist on WoW Forever (Interface 16001) — e.g. Felguard, Infernal, Doomguard, Felhunter, etc. — including their exact spell names, how each is obtained (trainer, talent, quest, reagent/ritual), whether they persist as a controllable `pet` unit, and what `UnitCreatureFamily` returns for each? Check existing probe/research notes in `thoughts/qrspi/` first, then external sources.
5. How are per-character settings (`WUK.char`, `CHAR_DEFAULTS`) loaded and validated on login, and what happens if a saved value is not among the currently recognised options?
6. What test coverage exists in `WarlockUtilityKit/tests/run.lua` for spell lookup, settings, or slash-command parsing, and how is the test harness stubbing WoW API functions?
