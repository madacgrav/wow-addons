# Changelog — Warlock Combat Kit

All notable changes to this addon. Versions match `## Version` in `WarlockCombatKit.toc`; each version is published as a `wck-vX.Y.Z` GitHub release.

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
