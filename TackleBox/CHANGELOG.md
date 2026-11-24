# Changelog — TackleBox

All notable changes to this addon. Versions match `## Version` in `TackleBox.toc`; each version is published as a `tb-vX.Y.Z` GitHub release.

## [1.3.0] — 2026-11-23

### Added
- **Camp button** on the fishing bar. One button for the whole fishing camp:
  - places your campfire kit when no campfire is nearby, then your best camp item (Fishing Hut, Fishing Rack, Fish Bowl) your skill allows;
  - shows the shared 1-hour camp cooldown as a greyed countdown ("camp ready in M:SS");
  - when you own no camp item, offers to craft a Fish Bowl (hammer badge): the click opens Fishing so you press Create, or names the missing reagent.
- **`/tb camp`** prints camp facts (buffs, cooldowns, recipes, camp reagents in bags) for troubleshooting.

### Changed
- Camp tab: shows Camp Benefits time left or when the next camp is ready, and per item "in bags", "can craft", "missing <reagent>" or "needs skill N". Uses the camp buffs confirmed in game ("Camp Benefits", "Campfire Nearby").
- The fishing bar lines up with the collapsed panel (two rows); one column when expanded.

### Fixed
- Riverglades shows its skill band (the zone was listed as "The Riverglades").

## [1.2.0] — 2026-11-23

### Added
- **Spots tab.** Best zones for your skill with their notable catches and the pool types that spawn there; your current zone comes first. Hover a row for the full text.
- **Learned pools.** Hover a pool and cast at it (within 60 seconds of hovering): once the catch lands, TackleBox saves the spot, account-wide. Repeat catches at the same pool raise its count.
- **Nearby pools.** The top of the Spots tab lists learned pools on your map, nearest first, with distance and times seen. Click one to set a waypoint.
- **Map pins.** Learned pools show on the world map and minimap. `/tb pins map` and `/tb pins minimap` turn them off or on.
- **Pool alerts.** Hovering a pool prints "<pool> nearby" and flashes, once per pool per minute, never in combat. `/tb detect` turns them off or on.

### Changed
- Zone bands follow the published Forever tiers and include Zephras Isle, The Riverglades, Shen'Dralas and Mount Hyjal.
- Panel polish: display-font title, header glow, framed row icons, a centred empty state, icon-only tabs, and matching hover strength.
- Embeds LibStub, CallbackHandler-1.0 and HereBeDragons 2.18 (map and minimap pins). Licence texts ship in `Libs/`.

## [1.1.0] — 2026-11-23

### Added
- **One-key cast.** `/tb bind <key>`: the key casts Fishing, and while the line is out it reels in the bobber without a mouse-over. `/tb unbind` removes it.
- **Weapon memory.** Your main hand and off hand are remembered when you equip a pole; the pole button becomes a Weapons button that puts them back.
- **Zone line.** The header shows your current zone's skill range and flag.
- **Collapsible tabs.** A plus/minus button hides the tabs; the choice is remembered.

### Changed
- Tab rows scroll, 10 at a time. The Catch list is no longer cut off at 30.

### Fixed
- The cast bar and got-away count now work at every Fishing rank, not only Apprentice.

## [1.0.0] — 2026-10-22

The full fishing companion: tabs, a fishing bar and a fishing-themed look.

### Added
- **Quest tab.** Have/need counts for the four Artisan quest fish, across bags and bank, with the zone to fish each one.
- **Where tab.** Zones for your skill band, the no-get-away skill per zone, lure notes for 225+ zones, and a here / outgrown / too low flag for your current zone.
- **Catch tab.** Every fishing catch per character, with counts, best loot quality, and the zones you caught it in. Grouped Uncommon / Rare / Unique / Other.
- **Camp tab.** Fishing Rack and Fishing Hut buffs with time left, or the skill you still need (140 / 300).
- **Water tab.** Water-walking status from the Draught of Water Walking, Surfer Shoes and other water-walk buffs.
- **Fishing bar.** Click-to-use Pole, Lure, Water and Cast buttons docked on the panel's left side. Lures and water items you cannot use yet are greyed out with the requirement in the tooltip.
- **Cast bar.** A line-style countdown of the 30-second cast, docked under the panel.
- **Got-away flash.** A blue screen-edge flash and a session counter when a cast ends without a catch; `/tb flash` toggles the flash.

### Changed
- **Look.** Sea-and-rope frame, round fishing portrait with an angler quip, water-filled skill bar, and tabs in place of a single list.

## [0.1.0] — 2026-10-22

First release: the panel shell and the data probe.

### Added
- **Panel.** A movable panel showing your fishing skill, with collapsible sections.
- **Minimap button.** Click toggles the panel; right-click prints your skill.
- **Slash commands.** `/tb show|hide|lock|reset|probe`.
- **Probe.** `/tb probe` records skill, spells, buffs, fishing items, the last cast and the last loot to `TackleBoxDB.lastProbe`.
