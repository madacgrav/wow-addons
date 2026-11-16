# Changelog — Warlock Combat Kit

All notable changes to this addon. Versions match `## Version` in `WarlockCombatKit.toc`; each version is published as a `wck-vX.Y.Z` GitHub release.

## [0.2.0] — 2026-11-16

### Fixed
- Rule and slot spell menus list every active spell in your spellbook, grouped by spellbook tab, instead of a fixed list. Wrack and other talent spells now appear. (#28)

### Added
- **Rotation buttons.** A movable bar of round, clickable buttons: one per spell in your rules, then Shadow Bolt, Fear and Banish in a fixed group at the end. The suggested spell pulses purple. Rule edits made in combat apply after combat. Toggle with "Show rotation buttons". (#28)
- Bar buttons other than the suggested spell are greyed out (still clickable); the Shadow Bolt button glows fel green during Nightfall. Right-click the circle to open options. (#28)

### Changed
- The summoning circle's core is now a clickable **Life Tap** button (it pulses when a rule suggests Life Tap), and the rotation bar is docked to its right; the circle and bar move together. The suggestion now shows as a pulsing bar button instead of the core icon. (#28)

## [0.1.0] — 2026-10-22

First release: an in-combat helper for warlocks, separate from Warlock Utility Kit.

### Added
- **Summoning-circle panel.** No box:
  - a breathing purple aura, a turning rune ring and a shadow swirl around a round next-spell core;
  - enemy rows hang off a fading cord as purple soul bands with round spell icons.
- **Cast map panel.**
  - One row per enemy you cast on, keyed by GUID. Rows show icons for your DoTs, curses, banes and CC, fading with age.
  - Casts are paired from your own cast events.
  - Seduction lands on the pet's target.
  - Rows clear when the mob dies (nameplates on) or when combat ends.
- **CC highlight.**
  - Rows with a fresh Fear, Banish, Seduction, Death Coil or Howl of Terror pulse purple.
  - Optional Fear marker above enemy nameplates, open world only and off by default.
- **Nightfall alert.** A proc icon that lights up, pulses and plays a sound while Shadow Bolt is instant.
- **Rotation helper.**
  - The panel core shows the first matching rule from a per-character list.
  - Conditions: off cooldown, not cast on target in N s, proc up, target marked, usable.
  - Rule editor in settings.
  - Display only.
- **Mouseover cast slots.**
  - Six `Bindings.xml` slots, bound in Blizzard's Key Bindings.
  - Each casts its spell on your hostile mouseover, or your target.
- **Settings window, minimap button,** and the slash commands `/wck config`, `show`, `hide`, `lock`, `reset`.
- **`/wck probe` diagnostics.**
  - Prints in-combat API facts, the cast-map rows and a 40-event trace.
  - Saves its output to `WarlockCombatKitDB.lastProbe`.
