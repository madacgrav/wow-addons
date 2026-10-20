# Profession Planner

Leveling planner for WoW Forever. It docks next to the profession window. It tells you what to craft and how many times to reach your next skill bracket, what that costs, and what to buy and where.

- Client: WoW Forever (Interface 16001)
- Professions: **Tailoring, Enchanting, Leatherworking, Alchemy**
- Optional: [Auctionator](https://www.curseforge.com/wow/addons/auctionator) for AH prices, and QuestieDB (`LibQuestieDB`) for vendor names and locations.

## Install

1. Download `ProfessionPlanner-X.Y.Z.zip` from the repo's GitHub releases (tag `pp-vX.Y.Z`).
2. Extract it so that the folder `ProfessionPlanner` sits in `_classic_beta_\Interface\AddOns\`.
3. Restart the game or `/reload`.

## Opening the panel

1. Open the profession window for a supported profession.
2. A **book icon** appears below the profession tabs on the right edge of the window. Click it to show or hide the planner. Your choice is remembered.
3. The panel docks to the right of the profession window and updates as you craft, loot, buy or switch professions.

## Reading the panel

### Header

```
Tailoring  87 -> 150
12 learned  |  3 at trainer  |  seed 1.60.1.70450
```

- **Skill → target:** your skill and the next bracket (75, 150, 225 or 300), capped by your current max skill.
- **learned:** how many recipes already have color thresholds you observed yourself (see *Threshold learning*).
- **at trainer:** unlearned recipes that no pattern teaches, so you must buy them from a trainer.
- **seed:** the Forever data build the addon ships with.

### Plan steps (up to 3)

```
x14 Heavy Linen Gloves
-> 105 *   ~1g 20s 40c   needs Loom
```

- **xN Recipe:** craft this many. The text is colored by the recipe's difficulty at that point: orange, yellow or green.
- **-> 105:** skill you reach by the end of the step. A `*` means the step stops before your bracket target because the recipe's color changes there.
- **(until color changes):** the addon doesn't know yet where this recipe turns worse, so the plan stops here. It updates when you get there.
- **Cost:** what you still have to buy for the step. Reagents you already own count as free. A `~` means some reagent had no price and was counted at 1g each.
- **needs …:** a required crafting station, such as Loom or Spinning Wheel.

The planner picks the cheapest recipe per expected skill point. Orange and yellow recipes come first; green ones only when nothing else is left. The skill-up odds it uses are estimates (orange 100%, yellow 60%, green 25%). The plan is recalculated after every craft, so bad luck corrects itself.

### Learn steps

If a recipe you haven't learned would be a better choice, the plan includes it once:

- your skill has reached the pattern's requirement, **and**
- the pattern has a known price.

A **Learn: <pattern>** row comes before the craft step, with the vendor that sells the pattern (name and zone, preferring your current zone) or the game's source text. The pattern's cost is included in the step cost.

### Shopping list

Below the steps is one row per reagent the plan uses:

```
Linen Cloth
12/40   buy 28 @ 15c vendor - <Vendor Name> (<Zone>)
```

- **have/need:** what you own (bags, reagent bag and bank) against what the plan uses.
- **buy N @ price source:** how many to buy and the unit price. The source is:
  - `vendor`: a price you saw at a merchant.
  - `AH`: Auctionator's last-seen buyout.
  - `est.`: the item's base price from the seed data, used only for items a vendor is known to sell.
  The cheaper of vendor and AH wins.
- **vendor name (zone):** a vendor that sells the item to your faction (requires QuestieDB).

## Click to craft

- **Click** a plan step to select that recipe in the profession window, with the craft count filled in.
- **Shift+click** to craft it immediately. The count is the planned amount or what you can currently craft, whichever is lower. If you're missing reagents, you get a chat message.

Learn steps aren't clickable until you actually learn the recipe.

## Getting better plans

The planner only knows what it has seen, so:

- **Open your bank once.** Bank contents are cached per character and counted as owned.
- **Visit merchants.** Opening any vendor window records its prices.
- **Scan the AH with Auctionator.** The panel refreshes when Auctionator's data updates.
- **Install QuestieDB** for vendor names on reagents and patterns, and to enable `est.` prices for vendor items.
- **Just level.** When a recipe changes color, the skill where it happened is saved and replaces the seed value (*threshold learning*). Grey thresholds come straight from the game. Learned thresholds are shared across your characters.

## Slash commands

| Command | What it does |
|---|---|
| `/pp probe` | With a profession window open: print API diagnostics. The full output is saved to `ProfessionPlannerDB.lastProbe`. |
| `/pp debug` | Print the current profession and a breakdown of cached recipes by color. |

## Notes

- If no recipe would give you skill-ups, the panel says *"No recipe gives skill-ups here — train new recipes"*.
- Saved data: `ProfessionPlannerDB` (account: learned thresholds, vendor prices, panel state) and `ProfessionPlannerCharDB` (character: recipe cache, bank contents, skill levels). AH prices are never saved; they're read from Auctionator each time.
- Item and vendor names may briefly show as `item:12345` while the client loads them.

## Development

- `Logic.lua` holds the pure logic (planner, pricing, thresholds) and is tested with Lua 5.1:

  ```bash
  lua5.1 ProfessionPlanner/tests/run.lua
  ```

- `Data.lua` is generated. Don't edit it by hand. Regenerate it with `tools/gen_seed.py` from Forever game data (wago.tools).
- CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).
