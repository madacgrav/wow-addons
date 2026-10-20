# Research Questions

## Context
Focus on the WarlockUtilityKit addon (`WarlockUtilityKit/`), especially `UI.lua`, `Prep.lua`, `Dock.lua`, `Summon.lua`, `Settings.lua`, `Core.lua`, and `Logic.lua`, plus the prior design docs under `thoughts/qrspi/2026-10-19-warlock-utility-kit*/`. The target client is WoW Classic (Interface 16001, "Forever" client).

## Questions
1. How is the `WUKStrip` frame built and sized, and how is each child (stone buttons `WUKStone_<kind>`, `WUKArmorButton`, `WUKPetButton`, `f.stone`/`f.assign` labels) anchored within it? List every `SetPoint`/`SetSize` call and the offset math, and note whether frame size depends on button count.
2. How is the set of visible buttons determined at runtime (which stone kinds exist, when buttons are shown/hidden, `WUK.ApplyShown`), and does the number or order of buttons change after creation?
3. How do `WUK.MakeMovable` and `Dock.lua` (`WUK.ApplyDock`, the `hooksecurefunc` on `SetPoint`) position the strip, what do they save to `WarlockUtilityKitDB`/`WarlockUtilityKitCharDB`, and what assumptions do they make about the strip's shape or anchor point?
4. Which secure-template constraints apply to repositioning, resizing, showing/hiding, or reparenting these buttons in and out of combat, and where does the code currently check `InCombatLockdown()` or defer work until `PLAYER_REGEN_ENABLED`?
5. What state (counts, missing stones, buffs, pet, assignments) is computed in `Core.lua`/`Logic.lua`, and how and when does `WUK.Refresh` and the Prep ticker push it to the buttons and labels?
6. Which frame-geometry and animation APIs are used or recorded as working on this client (`AnimationGroup` Translation/Rotation/Scale/Alpha, `SetScale`, OnUpdate, `C_Timer`), including anything in `probe-results.md`?
7. How do the settings window and saved variables expose layout options today (shown/hidden, dock, reset position), and how does `tests/run.lua` stub frames — which layout code paths are covered by tests?
