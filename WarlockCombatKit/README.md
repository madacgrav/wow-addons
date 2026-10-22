# Warlock Combat Kit

An in-combat helper for warlocks on WoW Forever. It is planned to track what you cast on each enemy, highlight crowd-controlled mobs, suggest your next spell, flash procs and add mouseover cast keys. It is separate from Warlock Utility Kit.

This build (0.1.0, in progress) only contains the probe. It reports which game APIs addons can read in combat on Forever, so the features can be built against real results.

## Install

1. Download `WarlockCombatKit-X.Y.Z.zip` from the repo's GitHub releases (tag `wck-vX.Y.Z`).
2. Extract it so that the folder `WarlockCombatKit` sits in `_classic_beta_\Interface\AddOns\`.
3. Restart the game or `/reload`.

## Slash commands

The addon only loads for warlocks.

| Command | What it does |
|---|---|
| `/wck probe` | Prints the in-combat API facts and the last 20 cast, proc and nameplate events. The output is also saved to `WarlockCombatKitDB.lastProbe`. |
| `/wck lock` | Toggles frame locking (no Shift+drag). |
| `/wck reset` | Resets frame positions; `/reload` to apply. |

## Development

Pure logic lives in `Logic.lua` and is tested with plain Lua 5.1:

```bash
lua5.1 WarlockCombatKit/tests/run.lua
```

CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).
