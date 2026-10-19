# /wuk probe results

## Run 1: open world, out of combat, no target (2026-10-19)
- instance: false none; combat: false
- **chat lockdown: n/a**. `C_ChatInfo.InChatMessagingLockdown` does not exist on the Forever client.
- **Every probed spell has secrecy 2 (ContextuallySecret):** Curse of Agony, Curse of Doom, Bane of Agony, Bane of Doom, Corruption, Immolate, Curse of the Elements, Curse of Recklessness, Curse of Shadow, Banish.
  - None is NeverSecret, so DoT/curse auras may turn secret whenever restrictions apply (combat, encounter, restricted map).
  - The same value comes back for "Bane of …" and "Curse of Shadow", so the API probably returns 2 for any name, known or not. It does **not** confirm those spells exist.
- target: none. The aura-readability lines are not tested yet.

## Still needed
- [ ] Cursed hostile target in the open world, out of combat
- [ ] Same target in combat
- [ ] Cursed target inside a dungeon
