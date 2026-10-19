# Task

Build v1 of the "Warlock Utility Kit for Forever" addon (Idea 1 in `WoW Forever Addon Ideas — PRD.md`): inventory strip (shards, healthstone/soulstone/spellstone/firestone, soulstone target + duration), one-click out-of-combat prep sequence, chat-parsed summon queue with failure reasons, and a healthstone trade helper. WoW Forever (launch Nov 4, 2026) runs on Mainline/retail UI APIs with Midnight "secrets" restrictions, so Classic warlock addons (Necrosis, Warlock Prep, Logroño's Warlocks) cannot load and there is no equivalent.

The addon must live entirely in its own subfolder of this repo (e.g. `WarlockUtilityKit/`), self-contained and installable alone. Repo currently has no addon code, so there is no existing core library to reuse; v2 features (curse/banish board, DoT timers) are out of scope.
