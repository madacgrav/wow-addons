# Design Discussion

## Current State
- `WUKStrip` is a fixed 284x76 `BackdropTemplate` rectangle (`UI.lua:31-35`). It holds 7 x 36px secure buttons in one row, all anchored to the strip's TOPLEFT. The offsets are literals split across files:
  - armor/pet at x=4/44 (`Prep.lua:6,23`);
  - stones at `4+(i+1)*40` (`UI.lua:39`).
- Two labels sit under the row: the soulstone timer (`UI.lua:48-49`, ticker at `Prep.lua:44-47`) and the assignment text (`UI.lua:50-51`, set at `Board.lua:187`).
- Geometry is set once at login and never changes. Only textures, text and attributes change per refresh (`UI.lua:57-71`, `Prep.lua:12-35`).
- Unavailable actions are shown by `SetDesaturated`, never by hiding (`UI.lua:64`, `Prep.lua:15`).
- Secure attribute writes are guarded by `InCombatLockdown()` and redone on `PLAYER_REGEN_ENABLED -> WUK.Refresh` (`Core.lua:152`). `PLAYER_REGEN_DISABLED` is not registered.
- The addon has no animation or scale code at all. The only circular placement is the minimap `Place()` with cos/sin (`Settings.lua:78-81`). The only `OnUpdate` is the minimap drag (`Settings.lua:85-94`).
- Dock chains the Blizzard Cooldown Manager viewers to `WUK.strip` BOTTOMLEFT (`Dock.lua:8-13`).
- Position is saved as one UIParent-relative point under `db.frames.strip` (`UI.lua:16-23`).
- Tests load only `Logic.lua` (`tests/run.lua:3`). No layout code is covered.

## Desired End State
The strip becomes a warlock-themed **ring + core**:

```
        [HS]
   [Pet]      [SS]
        (SHARD)          <- larger "core" button
  [Arm]       [Sp]
        [Fire]
  Soulstone: Bob 29:12
  Curse: Elements {skull}
```

- **Core:** the soul shard button, larger (~44px), at the center.
- **Orbit:** six 36px buttons evenly spaced on a circle. Clockwise from the top: healthstone, soulstone, spellstone, firestone, armor, pet.
- **Labels:** both labels centered under the ring.
- **Container:** a square-ish backdrop frame (named `WUKStrip`, kept as `WUK.strip`) bounds the ring and labels. Dock and MakeMovable keep working unchanged.

Dynamic behaviour:
1. **Alert pulse.** A button that needs action pulses a glow overlay using an `AnimationGroup` (alpha loop) on a non-secure texture:
   - armor buff missing;
   - wrong or no pet out;
   - 0 healthstones or soulstones while the create spell is known.
   It runs in and out of combat, because it touches textures only.
2. **Ready shine.** When a stone count goes from 0 to more than 0, the icon does a brief scale/alpha pop (one-shot `AnimationGroup`).
3. **Slow orbit spin.** Out of combat the ring rotates slowly (one turn per ~60s) via `OnUpdate`, repositioning the orbit buttons. It stops on `PLAYER_REGEN_DISABLED` and resumes on `PLAYER_REGEN_ENABLED`.
4. **Collapse to core.** Out of combat, with the mouse away, the orbit folds into the core:
   - orbit buttons go to radius 0 with alpha 0, and mouse is disabled on them;
   - hovering the container blooms them out over ~0.2s;
   - on `PLAYER_REGEN_DISABLED` the ring snaps fully open and stays open through combat.

How to verify:
- `tests/run.lua` asserts the pure ring-geometry function: count, angles, radius, rotation offset, and radius-0 collapse.
- In game, out of combat: the ring spins, collapses, and blooms on hover.
- Entering combat snaps it open and freezes it. All buttons stay clickable in combat, with no "action blocked" taint errors.
- Pulses show for a missing armor buff and for the wrong pet.
- Creating a healthstone triggers the shine.
- Dock still places the viewers under the frame.

## Patterns to Follow
- **inits/refreshers registration** (`UI.lua:30,57`; `Core.lua:137-150`). Build frames in an init and update visuals in a refresher.
- **Guard and redo on Refresh** for secure work (`UI.lua:66-69`, `Summon.lua:39,63`). All `SetPoint`, `EnableMouse` and `SetAttribute` calls on secure buttons happen only when `not InCombatLockdown()`.
- **Pure logic in `Logic.lua`, tested in `tests/run.lua`** (`tests/run.lua:3,10-86`). Ring math goes there as a pure function, e.g. `WUK.RingPoint(i, n, radius, offsetDeg) -> x, y`.
- **Trig placement precedent** (`Settings.lua:78-81`): `SetPoint("CENTER", parent, "CENTER", cos(a)*r, sin(a)*r)`.
- **OnUpdate set and cleared as needed** (`Settings.lua:85-94`). Don't leave a permanent OnUpdate running in combat or while idle.
- **Desaturate for unavailable** (`UI.lua:64`, `Prep.lua:15`). Keep it, and layer the pulse on top for "needs action".
- **Options via slash, with Settings checkboxes routed through `Run(cmd)`** (`Settings.lua:6,28-32`; `Core.lua:221-241`), plus `DEFAULTS` merge (`Core.lua:19`).

Do NOT follow:
- **Literal geometry split across files** (`Prep.lua:6,23` vs. the hidden `(i+1)` slot reservation in `UI.lua:39`). One layout function in `UI.lua` places all seven buttons. Prep keeps creating and refreshing its buttons but no longer positions them.
- **The hard-coded `SetSize(4+7*40,76)` with a stale comment** (`UI.lua:32-33`). Size the container from the ring radius.

## Design Decisions
1. **Shape: ring + core.** It is chosen by the user, reuses the existing trig precedent, and fits 1 core + 6 orbit.
2. **Replace the bar outright.** There is no layout option, so there is only one code path to maintain and test.
3. **Docking: keep the rectangular container and leave Dock.lua unchanged.** Viewers still attach to `WUK.strip` BOTTOMLEFT (`Dock.lua:8`).
4. **Combat freeze on `PLAYER_REGEN_DISABLED`.** This is the new event. Its handler runs before lockdown starts. It stops the spin, snaps the ring to full radius, sets alpha 1, enables mouse on all orbit buttons, and stops collapse handling. `PLAYER_REGEN_ENABLED` (already `Refresh`) resumes the spin and collapse.
5. **One animator.** A single `OnUpdate` on the container drives both the spin angle and the collapse radius. It is removed whenever nothing is animating: spin is off or in combat, and the radius is at its target. It does not run per button.
6. **Pulse and shine use `AnimationGroup` on textures only.** Each button gets one glow texture with a looping alpha anim, and the icon gets a one-shot scale pop. They are started and stopped from the existing refreshers based on state already computed there (`UI.lua:64`, `Prep.lua:15,33`). The previous count per kind is kept on the button to detect 0 to >0.
7. **Settings.** Two new `DEFAULTS` keys, `spin=true` and `collapse=true`. Each has a slash command (`/wuk spin`, `/wuk collapse`), is refused in combat like `dock` (`Core.lua:236`), and has a Settings checkbox. Pulse and shine are always on, with no option.
8. **Prep buttons are exposed to the layout.** `armorBtn` and `petBtn` are registered on `WUK.strip.icons.armor` and `.pet`, so UI.lua's layout function can position them. Creation order still works: UI init runs before Prep init (`WarlockUtilityKit.toc:9-18`), so layout runs after both, from a later init or the first refresh.
9. **Glow art: a stock Blizzard texture.** There is no custom media folder. The exact path will be confirmed in game, with candidates such as `Interface\Buttons\UI-ActionButton-Border` in ADD blend mode.

## What We're NOT Doing
- No pentagram line art, custom textures, or media folder.
- No bar layout option, and no layout picker.
- No scale, radius, or spin-speed settings beyond the two on/off toggles.
- No changes to the Summon panel, minimap button, Board, or Settings window look.
- No cooldown swipes, and no Masque or glow libraries.
- No migration of the old saved `db.frames.strip` point. The frame may shift once, and Shift-drag or `/wuk reset` fixes it.
- No in-combat movement of secure buttons, ever.

## Open Risks
- **AnimationGroup on Interface 16001 is untested.** `probe-results.md` records nothing on it. Phase 1 should verify it in game before building pulse and shine on it.
- **`PLAYER_REGEN_DISABLED` timing.** We rely on its handler running before lockdown. If combat starts mid-collapse, the snap-open must finish in that handler. Edge case: combat begins while the player is mounted or the frame is hidden.
- **Moving secure buttons every frame via OnUpdate while spinning.** This could interact with Dock's `hooksecurefunc` only if Dock hooks the strip. It doesn't, since Dock hooks the viewers only (`Dock.lua:21`). Per-frame `SetPoint` cost on 6 buttons should be negligible.
- **Clicking a moving button.** Spin is slow, but a click while it moves could feel slippery. A pause-spin-on-hover fallback can be added if it feels bad.
- **Collapsed ring hides actions out of combat.** Pulses on collapsed buttons are invisible. The core may need to pulse when any orbit button is alerting.
- **Container hit-area for hover.** When collapsed, the container's mouse region decides when it blooms. The frame is larger than the visible core, so hover may trigger early.
