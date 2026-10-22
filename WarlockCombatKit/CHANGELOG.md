# Changelog — Warlock Combat Kit

All notable changes to this addon. Versions match `## Version` in `WarlockCombatKit.toc`; each version is published as a `wck-vX.Y.Z` GitHub release.

## [Unreleased]

### Added
- **Probe (`/wck probe`).** Reports, in and out of combat and per instance type:
  - unit identity and death state on target, focus, mouseover and nameplates;
  - spell usability, range and cooldown flags;
  - aura secrecy for Shadow Trance;
  - Assisted Combat;
  - combat log registration;
  - nameplate decoration;
  - the last 20 cast, proc-overlay and nameplate events.

  Output is saved to `WarlockCombatKitDB.lastProbe`.
