# TackleBox

Fishing companion for WoW Forever. One movable panel shows your fishing skill and, as later versions land, where to fish, quest fish, your catch collection, camp buffs and water-walking. It runs alongside a casting addon such as BetterFishing; TackleBox does not cast, swap gear or react to bites.

- Client: WoW Forever (Interface 16001)
- Language: English client. Zones are matched by their enUS names.

## Install

1. Download `TackleBox-X.Y.Z.zip` from the repo's GitHub releases (tag `tb-vX.Y.Z`).
2. Extract it so that the folder `TackleBox` sits in `_classic_beta_\Interface\AddOns\`.
3. Restart the client or `/reload`.

## The panel

The header shows your fishing skill as a water-filled bar (`Fishing level/max (+modifier)`) and the session's "got away" count. Below it, five tabs switch between Quest, Where, Camp, Water and Catch; each tab shows how many rows it holds, and the last tab you picked is remembered. Shift-drag the panel to move it; the position is saved. The close button or `/tb hide` hides the panel.

## Fishing bar

A rope-framed strip on the left side of the panel holds up to four click-to-use buttons, stacked top to bottom. It moves with the panel (shift-drag either one), hides with the panel, and shows each button only when it is useful:

| Button | Shows when | Click |
|---|---|---|
| Pole | A fishing pole is in your bags and not equipped | Equips it |
| Lure | A pole is equipped, it has no lure, and you carry one | Applies the best lure your Fishing skill allows. Greyed out (does nothing) when you only carry lures above your skill; the tooltip shows the skill needed |
| Water | You carry a Draught of Water Walking or Surfer Shoes and are not water-walking | Uses it. Greyed out below the item's required level (Draught: 24) |
| Cast | You know Fishing | Casts Fishing |

The buttons only update out of combat. Every action needs your click; TackleBox never casts or reacts to a bite on its own.

The minimap button toggles the panel (left-click) and prints your skill (right-click). Drag it around the minimap.

## Slash commands

| Command | Effect |
|---|---|
| `/tb` | Toggle the panel |
| `/tb show` / `/tb hide` | Show or hide the panel |
| `/tb lock` | Lock or unlock frame dragging |
| `/tb reset` | Forget saved positions (applies after `/reload`) |
| `/tb probe` | Dump fishing facts to chat and `TackleBoxDB.lastProbe` |

## Probe

`/tb probe` prints the facts the addon's data depends on: skill APIs, fishing spell IDs, whether `IsFishingLoot` exists, your zone, your buffs, fishing-related bag items, the last cast and the last loot window. The output is also saved in `WTF\Account\<account>\SavedVariables\TackleBox.lua` under `lastProbe`. Run it right after a catch, after a missed cast, at a camp, and with water-walking active.

## Notes

- Forever IDs in `Data.lua` come from probe runs, not from guides.
- There is no bite alert: the game gives addons no bite event.

## Development

Pure logic lives in `Logic.lua` and is tested with plain Lua 5.1:

```bash
lua5.1 TackleBox/tests/run.lua
```

CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).
