# Task

Add the v2 scope of Idea 1 ("Warlock Utility Kit for Forever", PRD `WoW Forever Addon Ideas — PRD.md`) to the existing `WarlockUtilityKit/` addon:
- A curse and banish assignment board, shared across multiple warlocks in a raid over the raid/guild addon channel. This fills the Warlock Curse Power niche.
- DoT and curse timers, but only if Forever's Midnight "secrets" leave the needed aura data readable.

v1 is merged on main. It has strip buttons (armor, pet, stones), a soulstone timer, a local summon queue, a healthstone trade helper, and a minimap/settings window. Its summon queue deliberately has no addon-message sync. v2 introduces the addon's first cross-player messaging and must degrade gracefully for trial accounts, which cannot send addon messages, and under addon-message throttling or lockdown.
