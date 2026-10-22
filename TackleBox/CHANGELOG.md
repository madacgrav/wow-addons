# Changelog — TackleBox

All notable changes to this addon. Versions match `## Version` in `TackleBox.toc`; each version is published as a `tb-vX.Y.Z` GitHub release.

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
