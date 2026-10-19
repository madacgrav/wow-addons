# /wuk probe results

## Run 1: open world, out of combat, no target (2026-10-19)
- instance: false none; combat: false
- **chat lockdown: n/a**. `C_ChatInfo.InChatMessagingLockdown` does not exist on the Forever client.
- **Every probed spell has secrecy 2 (ContextuallySecret):** Curse of Agony, Curse of Doom, Bane of Agony, Bane of Doom, Corruption, Immolate, Curse of the Elements, Curse of Recklessness, Curse of Shadow, Banish.
  - None is NeverSecret, so DoT/curse auras may turn secret whenever restrictions apply (combat, encounter, restricted map).
  - The same value comes back for "Bane of …" and "Curse of Shadow", so the API probably returns 2 for any name, known or not. It does **not** confirm those spells exist.
- target: none. The aura-readability lines are not tested yet.

## Run 2: open world, IN combat, hostile target with my debuffs (2026-10-19)
- instance: false none; combat: true; chat lockdown: n/a; all secrecy values 2 (same as run 1).
- target hostile: true. **raid mark: nil**: readable and not secret, but this mob had no mark.
- **`C_UnitAuras.GetUnitAuras("target", "HARMFUL|PLAYER")` raised an error:** `Auras cannot be accessed when secret while tainted by 'WarlockUtilityKit'`.

## Run 3: open world, IN combat, Cooldown Manager enabled (2026-10-19)
- `C_CooldownViewer`: true. `cooldownViewerEnabled`: 1. `IsCooldownViewerAvailable()`: true.
- **Category sets are readable by the addon in combat (not secret):**
  - Essential (3): Corruption, Immolate, Curses
  - TrackedBuff (11): Curses, Corruption, Fear, Immolate, Banish, Demon Skin, Demon Armor, Detect Invisibility, Subjugate Demon, Berserking, Rapid Regeneration
  - TrackedBar: 0
  - Utility (4): Healthstone, Soulstone Resurrection, Berserking, Rapid Regeneration
- **Global viewer frames exist and are shown:** `EssentialCooldownViewer` (6 children), `UtilityCooldownViewer` (3), `BuffIconCooldownViewer` (3), `BuffBarCooldownViewer` (3).
- Direct aura reads still error in combat (same as run 2).
- **Takeaway:** Blizzard's own viewers render DoT/curse timers, and the addon can reach their frames. Docking or anchoring those frames to the WUK strip is a possible path to timers without reading secrets. That path is untested: Edit Mode may override `SetPoint`, and moving these frames may cause taint (Enhanced CDM's changelog reports taint fixes).

## Conclusion for DoT/curse timers (v3)
- In combat, even in the open world, addon (tainted) code cannot read the player's own debuffs on an enemy. The API errors rather than returning secret values.
- Every warlock DoT and curse is ContextuallySecret, with no never-secret exemption.
- **Addon-driven DoT timers are not feasible on Forever.** Showing timers would need Blizzard's own aura frames (12.1.0 AuraContainer/AuraButton), which is out of scope for this addon.
- An out-of-combat targeted run and a dungeon run are no longer needed: combat is the only case that matters for timers, and it is blocked.
