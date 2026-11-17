# BusinessCard

WoW Forever addon (Interface 16001). It remembers who advertised professions, summons and portals in public chat, so you can whisper them later. When both players run BusinessCard, it also swaps "cards": professions, skill, services, and an available/busy status.

## Install

1. Download `BusinessCard-X.Y.Z.zip` from the repo's GitHub releases (tag `bcard-vX.Y.Z`).
2. Extract it so that the folder `BusinessCard` sits in `_forever_\Interface\AddOns\`.
3. Restart the game. A `/reload` is not enough on first install, because key bindings load at startup.

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
- Ctrl-click a Seen row: /who lookup that fills in their zone.
- `/bcard busy` / `/bcard avail`: sets your overall status.
- `/bcard lock`: locks or unlocks frame dragging.
- `/bcard reset`: resets frame positions.

## Known limits

- Trial accounts (and, per one wiki page, Veteran accounts) cannot send addon messages. Card sharing is unavailable for them, but the ad log still works.
- Ads whose text or sender come through as a secret value (chat lockdown in encounters or instances) are skipped.
- Dungeons drop the Trade and Services channels, so the log goes quiet inside them. No card requests are sent from instances.
- Whisper card requests to players outside your guild have not been verified on Forever yet.

## Development

Pure logic lives in `Logic.lua` and is tested with plain Lua 5.1:

```bash
lua5.1 BusinessCard/tests/run.lua
```

CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).

The [addon site](https://madacgrav.github.io/wow-addons/) reads this README and CHANGELOG live from `main`. A brand-new addon also needs a line in `ADDONS` in `docs/index.html`.
