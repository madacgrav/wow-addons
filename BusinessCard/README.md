# BusinessCard

WoW Forever addon (Interface 16001). It remembers who advertised professions, summons and portals in public chat, so you can whisper them later. When both players run BusinessCard, it also swaps "cards": professions, skill, services, and an available/busy status.

## Features

- **Seen** (`/bcard` or keybind): advertisers from Trade, Services, TradeLocal, General, LookingForGroup, say, yell and whispers, kept per realm for 7 days.
  - Filter by category.
  - Click to whisper, shift-click to open their card, right-click to remove.
- **My card:** your professions and services, each set Available, Busy or Off, plus an Overall switch (`/bcard busy`, `/bcard avail`). Opening a profession window caches its recipes.
- **Card sharing** (both players need BusinessCard):
  - Your card goes to your guild on login and after any status change.
  - Advertisers get a silent card request.
  - Rows show a green or red status dot.
  - The card detail fetches their recipe list for a profession.

## Commands

- `/bcard`: toggles the window.
- `/bcard seen`: prints the newest 20 advertisers.
- `/bcard busy` / `/bcard avail`: sets your overall status.
- `/bcard probe`: prints client facts (channels, chat secrecy, spells, professions) and saves them to `BusinessCardDB.lastProbe`.
- `/bcard ping <name>`: sends an addon whisper to another BusinessCard user and prints the result code. The other side replies `pong`.
- `/bcard lock`: locks or unlocks frame dragging.
- `/bcard reset`: resets frame positions.

## Known limits

- Trial accounts (and, per one wiki page, Veteran accounts) cannot send addon messages. Card sharing is unavailable for them, but the ad log still works.
- Ads whose text or sender come through as a secret value (chat lockdown in encounters or instances) are skipped.
- Dungeons drop the Trade and Services channels, so the log goes quiet inside them. No card requests are sent from instances.
- Whisper card requests to players outside your guild have not been verified on Forever yet.
