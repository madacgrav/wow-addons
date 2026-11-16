# Research Questions

## Context
Focus on the WarlockUtilityKit addon (`WarlockUtilityKit/`), especially `UI.lua` (ring/strip of orbit buttons around the shard core), `Prep.lua` (armor and pet buttons), `Core.lua` (spell name table, init/refresh lists, saved variables), `Logic.lua` (pure helpers and their tests in `tests/run.lua`), and `Settings.lua`. Target client is WoW Classic-era (Interface 16001, "Forever").

## Questions
1. How is the `WUKStrip` ring built and laid out: which buttons exist (`KINDS`, armor, pet, shard core), how are they created, positioned (`LayoutRing`, radius/angle, collapse/spin animation), and how are icon textures, counts, desaturation, and glow set on each refresh?
2. How are click actions wired on the ring buttons: how do `SecureActionButtonTemplate` attributes (`type`, `macrotext`) get set, what does `WUK.StoneMacro` and the Prep.lua equivalents produce for left/right/modified clicks, and what is changed or deferred during combat lockdown (`InCombatLockdown`, `CombatFreeze`, `PLAYER_REGEN_*`)?
3. How are spells resolved and tracked as "known": trace the `SPELLS` table in `Core.lua`, `WUK.SpellName`, `WUK.known`, and how ranked vs same-name spells are chosen. Which warlock buff and summon spells are currently listed, and which are absent (e.g. Shadow Ward, Unending Breath, Felguard/Infernal/Doomguard summons)?
4. What tooltip code exists in the addon and in the Classic-era API it targets (e.g. `GameTooltip:SetSpellByID`, `SetSpell`, `SetItemByID`, `SetBagItem`, `GetSpellInfo`/`C_Spell`), and how does the existing minimap-button tooltip in `Settings.lua` handle OnEnter/OnLeave?
5. How does per-button visual state work beyond icons: where are vertex colors, highlight textures, glow/pulse, and shine animations applied, and is any button state (shown/hidden, mode, layout) persisted in `WarlockUtilityKitDB` / `WarlockUtilityKitCharDB` or reset on reload?
6. What constraints exist on showing/hiding or retexturing secure buttons and changing their attributes from an insecure click handler (e.g. a plain `OnClick` vs `SecureHandlerClickTemplate`/`SetAttribute` snippets), and how do existing buttons in the addon (Board, Summon queue rows) combine secure actions with `HookScript("OnClick")`?
7. How are pure helpers in `Logic.lua` structured and tested by `tests/run.lua`, and how is the addon packaged/deployed (toc load order, `.github/workflows/package-wuk.yml`, CHANGELOG/version bumps)?
