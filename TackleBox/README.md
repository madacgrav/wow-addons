# TackleBox

Fishing companion for WoW Forever. One sea-and-rope panel tracks your fishing skill, tells you where to fish, follows the Artisan quest fish, logs every catch, watches camp buffs and water-walking, and docks a click-to-use fishing bar on its side. Every action needs your click: TackleBox never casts on its own and never reacts to a bite.

- Client: WoW Forever (Interface 16001)
- Language: English client. Zones are matched by their enUS names.

## Install

1. Download `TackleBox-X.Y.Z.zip` from the repo's GitHub releases (tag `tb-vX.Y.Z`).
2. Extract it so that the folder `TackleBox` sits in `_classic_beta_\Interface\AddOns\`.
3. Restart the client.

## The panel

The header shows your fishing skill as a water-filled bar (`Fishing level/max (+modifier)`) and the session's "got away" count. Shift-drag the panel to move it; the position is saved. The close button, `/tb hide` or the minimap button hides it.

Five tabs sit under the header. Each shows how many rows it holds, and the last tab you picked is remembered.

| Tab | Shows |
|---|---|
| Quest | The four Artisan quest fish (Feralas Ahi, Misty Reed Mahi Mahi, Sar'theris Striker, Savage Coast Blue Sailfin): have/need counts across bags and bank, with the zone to fish them |
| Where | Zones for your skill band, the skill at which fish stop getting away, and lure notes for 225+ zones. Your current zone is flagged *here*, *outgrown* or *too low* |
| Camp | Fishing Rack (Uncommon catches, Fishing 140) and Fishing Hut (Rare catches, Fishing 300): time left when active, otherwise the skill you still need |
| Water | Whether you are water-walking, or which item on the fishing bar will do it |
| Catch | Every fish you have caught on this character, grouped Uncommon / Rare / Unique / Other by the best quality seen. Hover a fish for the zones where you caught it most |

## Fishing bar

A rope-framed strip on the left side of the panel holds up to four click-to-use buttons, stacked top to bottom. It moves with the panel (shift-drag either one), hides with the panel, and shows each button only when it is useful:

| Button | Shows when | Click |
|---|---|---|
| Pole | A fishing pole is in your bags and not equipped | Equips it |
| Lure | A pole is equipped, it has no lure, and you carry one | Applies the best lure your Fishing skill allows. Greyed out (does nothing) when you only carry lures above your skill; the tooltip shows the skill needed |
| Water | You carry a Draught of Water Walking or Surfer Shoes and are not water-walking | Uses it. Greyed out below the item's required level (Draught: 24) |
| Cast | You know Fishing | Casts Fishing |

The buttons only update out of combat.

## Cast bar and "got away" flash

While you fish, a line-style bar under the panel counts down the 30-second cast. When a cast ends without a catch (a fish got away, the cast ran out, or you moved), the screen edge flashes blue and the header's "got away" count goes up. `/tb flash` turns the flash off or on; the count keeps counting either way. The game does not tell addons when a fish bites, so the flash only ever reacts to a cast that already ended.

The minimap button toggles the panel (left-click) and prints your skill (right-click). Drag it around the minimap.

## Slash commands

| Command | Effect |
|---|---|
| `/tb` | Toggle the panel |
| `/tb show` / `/tb hide` | Show or hide the panel |
| `/tb lock` | Lock or unlock frame dragging |
| `/tb reset` | Forget saved positions (applies after `/reload`) |
| `/tb flash` | Turn the got-away flash on or off |
| `/tb probe` | Dump fishing facts to chat and `TackleBoxDB.lastProbe` |

## Probe

`/tb probe` prints the facts the addon's data depends on: skill APIs, fishing spell IDs, whether `IsFishingLoot` exists, your zone, your buffs, fishing-related bag items, the last cast and the last loot window. The output is also saved in `WTF\Account\<account>\SavedVariables\TackleBox.lua` under `lastProbe`. It is useful after a game patch, to check that the IDs in `Data.lua` still hold.

## Notes

- Item, spell and skill-requirement IDs in `Data.lua` come from in-game probes and the client's own data tables for build 1.60.1.70450. Zone bands and lure bonuses come from Forever fishing guides.
- The Rack and Hut buff IDs ("Uncommon Fishing", "Rare Fishing") have not yet been confirmed at a real camp.
- Forever has no separate Uncommon/Rare fish items; a better catch is the same fish at a higher loot quality, which is what the Catch tab records.
- There is no bite alert: the game gives addons no bite event.

## Development

Pure logic lives in `Logic.lua` and is tested with plain Lua 5.1:

```bash
lua5.1 TackleBox/tests/run.lua
```

CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).
