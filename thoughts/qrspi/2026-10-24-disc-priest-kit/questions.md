# Research Questions

## Context
Focus on the existing addons in this repo (WarlockCombatKit, WarlockUtilityKit, TackleBox, ProfessionPlanner), their `probe-results.md` files under `thoughts/qrspi/`, and the WoW Forever client API (Interface 16001). Some questions also need web research into the community addon ecosystem for classic-era / Forever clients.

## Questions
1. How do the existing addons read auras today (`C_UnitAuras.GetAuraDataByIndex`, `GetUnitAuras`, `GetPlayerAuraBySpellID`, `GetAuraDuration`), on which units, with which filters, and what do the probe results record about which aura fields (duration, expirationTime, sourceUnit, spellId) are actually populated on this client for player, target, and party/raid units?
2. How do the existing addons build party/raid unit lists and react to roster changes (`IsInRaid`, `GetNumGroupMembers`, `GROUP_ROSTER_UPDATE`, `UNIT_AURA`, etc.), and what events/throttling patterns are used to refresh state?
3. How is a typical addon in this repo structured end to end — .toc fields, Core/Data/Logic/Panel/Settings split, SavedVariables and per-character DB init, slash commands, Bindings.xml, frame/panel creation, movable/lockable UI, combat lockdown handling — and how are `tests/run.lua` and the `.github/workflows/package-*.yml` packaging set up?
4. How do WarlockCombatKit and WarlockUtilityKit handle spell data (spell IDs by rank, cooldown reads via `C_Spell.GetSpellCooldown`, pcall wrapping), secure action buttons/click-casting on units, and spell-cast or combat-log events?
5. What community addons exist for priests or healers on classic-era / Season / Forever clients (e.g. Weakened Soul / shield trackers, raid frame addons like Grid/VuhDo/Healbot/Cell, buff-reminder addons, Power Infusion / Fear Ward / Inner Fire / Power Word: Fortitude trackers, mana/regen/5-second-rule trackers, Spirit Tap/Inspiration/Renew trackers), which ones are known to work on the WoW Forever client, and what does each cover or miss?
6. What priest-relevant spell mechanics apply on WoW Forever — Weakened Soul duration, Power Word: Shield ranks/IDs/cooldown, Discipline talents (Inner Focus, Power Infusion, Divine Spirit, Mental Agility, Improved PW:S), any Season-of-Discovery-style runes or Forever-specific changes — and how do those spell IDs show up via the client's aura and spell APIs?
7. What is in the root `WoW Forever Addon Ideas — PRD.md` and the root `README.md`, and do they list planned addons, conventions, or constraints that apply to new addons in this repo?
