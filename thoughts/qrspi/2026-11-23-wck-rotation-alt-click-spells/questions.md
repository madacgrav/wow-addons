# Research Questions

## Context
Focus on the WarlockCombatKit addon (`WarlockCombatKit/`): `Rotation.lua`, `Actions.lua`, `Logic.lua`, `Settings.lua`, `Core.lua`, `Data.lua`, and `tests/`. Also consult the wow-forever-addon skill references on secure frames (`references/taint-and-secure.md`) and the Forever API index.

## Questions
1. How are the rotation bar buttons created, populated and refreshed in `Rotation.lua` (attributes set, click registration, which spell each button holds, when the spell set may change relative to combat lockdown), and how does the `Actions.lua` button set differ in its click and attribute setup?
2. What does `WCK.CastMacro` produce, and how do `WCK.BarSpells`, `WCK.RuleSpells` and the rules list decide which spell lands on which bar slot? Is a slot's spell identity stable across rule edits and refreshes, or recomputed by position?
3. How does `SecureActionButtonTemplate` resolve which attribute to use per mouse button and modifier key (e.g. `type`, `type2`, `shift-type1`, `macrotext` variants) on WoW Forever, and what constraints apply to changing those attributes in or out of combat? Cite the skill references and API index.
4. How are per-character and account-wide saved variables structured (`WarlockCombatKitDB`, `WarlockCombatKitCharDB`), where are defaults merged and migrations handled, and what shapes do `char.rules` and `char.slots` currently have?
5. How does the `Settings.lua` panel build its rows and spell selection menus (`SpellMenu`, `MenuUtil` usage, pooled rows, `Changed()` flow), and how do edits propagate to the bar and other secure buttons?
6. How do the rotation buttons' tooltips, glow/alert and cooldown-dim visuals get their spell (`b.spell`, `WCK.ButtonLook`, `WCK.SetAlert`, cooldown tracking in `Core.lua`), and what spell lists feed cooldown tracking?
7. What does the offline test harness in `WarlockCombatKit/tests/` cover today for rotation/bar logic and secure attributes, and what wowmock stubs exist for `SetAttribute`, click registration and menus?
