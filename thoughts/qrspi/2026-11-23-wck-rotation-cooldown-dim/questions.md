# Research Questions

## Context
Focus on the WarlockCombatKit addon (`WarlockCombatKit/`), especially `Rotation.lua`, `Logic.lua`, `Core.lua`, `Panel.lua` and `tests/run.lua`. WarlockUtilityKit (`WarlockUtilityKit/UI.lua`, `Prep.lua`) has related icon-state code worth comparing. Target client is WoW Forever (Retail 12.x API family, secret values in combat).

## Questions
1. How does the rotation bar refresher in `Rotation.lua` decide each button's visual state (desaturation, alpha, glow, fel/proc overlay), and what inputs does `WCK.ButtonLook` take and return?
2. How is per-spell cooldown and usability data gathered (`WCK.BuildRuleState`, `C_Spell.GetSpellCooldown`, `C_Spell.IsSpellUsable`), which spells it covers (rule spells vs. the fixed tail such as Shadow Bolt/Fear/Banish), how GCD is treated, and what happens when a value is secret or a call errors?
3. What events and timers trigger `WCK.Refresh`, and is there anything that refreshes when a cooldown expires (as opposed to when one starts)?
4. How do the existing offline tests in `tests/run.lua` exercise `ButtonLook`, `BuildRuleState` and the rotation bar, and how are cooldown/usable APIs stubbed?
5. What patterns elsewhere in WCK and WUK express "unavailable" vs. "suggested" on icons (e.g. `Panel.lua` proc icons, WUK `SetAlert`/`AddGlow`, `SetDesaturated` uses), and are any documented in the addons' READMEs or CHANGELOGs?
