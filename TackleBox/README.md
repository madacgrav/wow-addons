# TackleBox

Fishing companion for WoW Forever. One sea-and-rope panel tracks your fishing skill, tells you where to fish and which pools to look for, remembers the pools you fish and pins them on your map, follows the Artisan quest fish, logs every catch, sets up your fishing camp, watches water-walking, and docks a click-to-use fishing bar on its side. Every action needs your click or key press: TackleBox never casts on its own and never reacts to a bite.

- Client: WoW Forever (Interface 16001)
- Language: English client. Zones are matched by their enUS names.

## Install

1. Download `TackleBox-X.Y.Z.zip` from the repo's GitHub releases (tag `tb-vX.Y.Z`).
2. Extract it so that the folder `TackleBox` sits in `_forever_\Interface\AddOns\`.
3. Restart the client.

## The panel

The header shows your fishing skill as a water-filled bar (`Fishing level/max (+modifier)`), the session's "got away" count, and a zone line: your current zone's skill range and its *here* (green), *outgrown* (grey) or *too low* (red) flag, plus the lure it needs. Zones with no fishing data say so. Shift-drag the panel to move it; the position is saved. The close button, `/tb hide` or the minimap button hides it.

The plus/minus button next to the zone line shows or hides the tabs; the choice is remembered. Six icon tabs sit under the header (hover one for its name). Each shows how many rows it holds, and the last tab you picked is remembered. A tab shows up to 10 rows at a time and scrolls for the rest.

| Tab | Shows |
|---|---|
| Quest | The four Artisan quest fish (Feralas Ahi, Misty Reed Mahi Mahi, Sar'theris Striker, Savage Coast Blue Sailfin): have/need counts across bags and bank, with the zone to fish them |
| Where | Zones for your skill band, the skill at which fish stop getting away, and lure notes for 225+ zones. Your current zone is flagged *here*, *outgrown* or *too low* |
| Camp | Camp Benefits time left, or when the next camp is ready (shared 1-hour cooldown). Then Fishing Hut (300), Fishing Rack (140) and Fish Bowl (20): *in bags*, *can craft*, *missing <reagent>* or *needs skill N* |
| Water | Whether you are water-walking, or which item on the fishing bar will do it |
| Catch | Every fish you have caught on this character, grouped Uncommon / Rare / Unique / Other by the best quality seen. Hover a fish for the zones where you caught it most |
| Spots | **Nearby pools** you have learned on this map, nearest first (click one for a waypoint), then the **best spots** for your skill: notable catches and the pool types in each zone, your current zone first |

## Pools

TackleBox learns pools as you fish them. The game only shows a pool's name in its mouse-over tooltip, so:

1. Hover the pool (its tooltip shows), then cast at it within 60 seconds. One-key cast works too.
2. When the catch lands, the spot is saved for all your characters: your position plus 15 yards in the direction you face. Chat says `learned <pool>` the first time.

Learned pools appear under Nearby pools on the Spots tab and as pins on the world map and minimap (hover a pin for the name and count). `/tb pins map` and `/tb pins minimap` hide or show them. Hovering a pool also prints `<pool> nearby` and flashes (once per pool per minute, never in combat); `/tb detect` turns that off. Pools are spawn points, so a learned spot may be empty until the pool respawns.

## Fishing bar

A rope-framed strip on the left side of the panel holds up to five click-to-use buttons: one column when the panel is expanded, two rows matching the panel height when it is collapsed. It moves with the panel (shift-drag either one), hides with the panel, and shows each button only when it is useful:

| Button | Shows when | Click |
|---|---|---|
| Pole | A fishing pole is in your bags and not equipped | Equips it |
| Weapons | A pole is equipped and TackleBox remembers your weapons | Puts your main hand and off hand back on. Greyed out when one of them is not in your bags; the tooltip names it |
| Lure | A pole is equipped, it has no lure, and you carry one | Applies the best lure your Fishing skill allows. Greyed out (does nothing) when you only carry lures above your skill; the tooltip shows the skill needed |
| Water | You carry a Draught of Water Walking or Surfer Shoes and are not water-walking | Uses it. Greyed out below the item's required level (Draught: 24) |
| Camp | You carry a campfire kit or a fishing camp item, or can craft a Fish Bowl | See Fishing camp below |
| Cast | You know Fishing | Casts Fishing |

Your weapons are remembered per character whenever a non-pole weapon is in your main hand, so any way of equipping the pole works. The buttons only update out of combat, and the weapon swap does not work in combat.

## Fishing camp

Forever camp items only work next to a campfire, and all of them share a 1-hour cooldown. The Camp button walks you through it, one step at a time:

1. **No campfire nearby:** shows your campfire kit (best tier you carry). Click, then click the ground to place it.
2. **Camp item:** shows the best one your Fishing skill allows (Fishing Hut, then Fishing Rack, then Fish Bowl). Click, then click a spot near the fire. Sit at the camp for a minute to get Camp Benefits.
3. **Cooldown:** while the shared cooldown runs, the button is greyed with a countdown and "camp ready in M:SS".
4. **Nothing to place:** if you know the Fish Bowl recipe, the button shows it with a hammer badge. With the reagents, a click opens Fishing so you press Create; without them, the tooltip names the missing reagent.

Placing needs two clicks because the game asks where to put the item. "You cannot place a feature that close to a creature or object" means: pick a spot with more room.

## Cast bar and "got away" flash

While you fish, a line-style bar under the panel counts down the 30-second cast. When a cast ends without a catch (a fish got away, the cast ran out, or you moved), the screen edge flashes blue and the header's "got away" count goes up. `/tb flash` turns the flash off or on; the count keeps counting either way. The game does not tell addons when a fish bites, so the flash only ever reacts to a cast that already ended.

The minimap button toggles the panel (left-click) and prints your skill (right-click). Drag it around the minimap.

## One-key cast

`/tb bind <KEY>` (for example `/tb bind F`) sets one key for the whole fishing loop:

- With no line out, the key casts Fishing.
- While the line is out, the same key reels in the bobber and loots, with no mouse-over needed. You still press it yourself when the fish bites.

If reeling in does nothing, turn on **Enable Interact Key** in the game's options. During the cast TackleBox sets `SoftTargetInteract` to 3 and `SoftTargetInteractRange` to 60, then puts your values back when the cast ends, after combat, at logout or at the next login.

Limits:
- Interact picks the nearest interactable thing, so a nearby NPC or player can be grabbed instead of the bobber.
- A bobber far away may be out of soft-target range.
- Key bindings cannot change in combat. A cast started in combat keeps the key as a cast key, and a cast that ends in combat keeps it as the reel key until combat drops.

`/tb unbind` gives the key back its normal job.

## Slash commands

| Command | Effect |
|---|---|
| `/tb` | Toggle the panel |
| `/tb show` / `/tb hide` | Show or hide the panel |
| `/tb lock` | Lock or unlock frame dragging |
| `/tb reset` | Forget saved positions (applies after `/reload`) |
| `/tb flash` | Turn the got-away flash on or off (also used by pool alerts) |
| `/tb pins map` / `/tb pins minimap` | Hide or show learned-pool pins |
| `/tb detect` | Turn pool alerts on or off |
| `/tb camp` | Print camp buffs, cooldowns, recipes and camp reagents in your bags |
| `/tb probe` | Dump fishing facts to chat and `TackleBoxDB.lastProbe` |
| `/tb bind <key>` | Use that key to cast and reel in (see One-key cast) |
| `/tb unbind` | Remove the cast key |

## Probe

`/tb probe` prints the facts the addon's data depends on: skill APIs, fishing spell IDs, whether `IsFishingLoot` exists, your zone, your buffs, fishing-related bag items, the last cast and the last loot window. The output is also saved in `WTF\Account\<account>\SavedVariables\TackleBox.lua` under `lastProbe`. It is useful after a game patch, to check that the IDs in `Data.lua` still hold.

## Notes

- Item, spell and skill-requirement IDs in `Data.lua` come from in-game probes and the client's own data tables for build 1.60.1.70450. Zone bands come from the Gfinity Forever fishing guide (Oct 2026); lure bonuses from Forever fishing guides.
- Pool types and each zone's notable catches come from warcraft.wiki.gg and WarcraftTavern (Classic data); where pools spawn in Forever is not verified.
- Camp buffs were confirmed in game: one shared "Camp Benefits" buff (about an hour) and "Campfire Nearby" while at a fire. Fish Bowl reagents (Raw Brilliant Smallfish, Empty Vial) come from warcraft.wiki.gg; Rack and Hut reagent IDs are not in the addon yet, so only the Fish Bowl can be offered for crafting.
- Forever has no separate Uncommon/Rare fish items; a better catch is the same fish at a higher loot quality, which is what the Catch tab records.
- There is no bite alert: the game gives addons no bite event.

## Libraries

TackleBox embeds [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons) 2.18 by Nevcairiel (BSD) for map coordinates and pins, plus LibStub (public domain) and CallbackHandler-1.0 (Ace3 licence). Their licence texts are in `Libs/`.

## Development

Pure logic lives in `Logic.lua` and is tested with plain Lua:

```bash
lua TackleBox/tests/run.lua
```

CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).

The [addon site](https://madacgrav.github.io/wow-addons/) reads this README and CHANGELOG live from `main`. A brand-new addon also needs a line in `ADDONS` in `docs/index.html`.
