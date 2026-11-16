# BusinessCard

WoW Forever addon (Interface 16001). It remembers who advertised professions, summons and portals in public chat, so you can whisper them later. When both players run BusinessCard, it also swaps "cards": professions, skill, services, and an available/busy status.

## Status

Version 0.1.0 contains only the skeleton and the probe. The features arrive in later phases (see `thoughts/qrspi/2026-11-16-profession-business-card/plan.md`).

## Commands

- `/bcard probe`: prints client facts (channels, chat secrecy, spells, professions) and saves them to `BusinessCardDB.lastProbe`.
- `/bcard ping <name>`: sends an addon whisper to another BusinessCard user and prints the result code. The other side replies `pong`.
- `/bcard lock`: locks or unlocks frame dragging.
- `/bcard reset`: resets frame positions.

## Known limits

- Trial accounts (and, per one wiki page, Veteran accounts) cannot send addon messages. Card sharing is unavailable for them, but the ad log still works.
- Ads whose text or sender come through as a secret value (chat lockdown in encounters or instances) are skipped.
