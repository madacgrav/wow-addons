# Structure Outline

## Approach
Replace the bar with a ring of 6 orbit buttons around a larger shard core. The ring is placed by one layout function in `UI.lua` that uses a pure, tested `WUK.RingPoint` in `Logic.lua`. The dynamic layers come next, in order of risk: pulse, shine, spin plus the combat freeze, then collapse. Each is driven from the existing refreshers, and a single container `OnUpdate` drives motion. All secure geometry is out of combat only.

After each phase, deploy to `_classic_beta_\Interface\AddOns` and test in game.

## Phase 1: Static ring layout
The strip becomes the ring. The shard core sits at the center and the six orbit buttons are placed clockwise from the top: healthstone, soulstone, spellstone, firestone, armor, pet. Both labels are centered under the ring, and the container is sized from the radius. Docking, dragging and clicks work as before. This phase alone is a shippable layout change.

**Files**: `Logic.lua`, `tests/run.lua`, `UI.lua`, `Prep.lua`

**Key changes**:
- `WUK.RingPoint(i, n, radius, offsetDeg) -> x, y` (new, pure). Slot `i` of `n`, clockwise from 12 o'clock, offset by `offsetDeg`. `radius=0` returns `0,0`.
- `WUK.ORBIT = { "healthstone","soulstone","spellstone","firestone","armor","pet" }` (new, in UI.lua). Shard is the core.
- `WUK.LayoutRing(radius, offsetDeg)` (new, UI.lua). Does nothing in combat. Places the core at CENTER and each orbit button at `RingPoint` from the container CENTER, both shifted up so the labels fit underneath.
- `WUK.strip.icons.armor` / `.pet` are registered in `Prep.lua` inits. The `SetPoint` literals in `Prep.lua:6,23` are removed.
- Container: `SetSize(2*(R+18)+8, 2*(R+18)+8+30)` with `R≈58`. The stale comment and the `4+7*40` sizing are removed. The core is 44x44.
- Layout runs once after all inits. It is called from the first refresh, or from an init registered after Prep (Dock's init is later in toc order).

**Verify**:
- `lua tests/run.lua` passes, with new asserts:
  - `RingPoint(1,6,R,0) == 0,R`;
  - slot 4 is at `0,-R`;
  - slot 2 has x > 0;
  - the offset rotates slot 1;
  - radius 0 returns `0,0`.
- In game:
  - The ring renders as drawn.
  - Every button casts or uses its item.
  - Count, desaturation and both labels show.
  - Shift-drag saves the position.
  - `/wuk dock` puts the viewers under the frame.
  - `/wuk hide`/`show` works.

---

## Phase 2: Alert pulse (+ AnimationGroup probe)
Buttons that need action pulse a glow. This phase first confirms in game that `AnimationGroup` works on Interface 16001, which is the design's top risk.

**Files**: `UI.lua`, `Prep.lua`

**Key changes**:
- `WUK.AddGlow(b)` (new, UI.lua). Creates `b.glow`, an OVERLAY texture in ADD blend mode using a stock border texture, plus `b.pulse`, a looping `Alpha` AnimationGroup with BOUNCE. The glow starts hidden.
- `WUK.SetAlert(b, on)` (new). Plays or stops `b.pulse` and shows or hides `b.glow`. It is texture-only, so it is safe in combat.
- Refreshers call `SetAlert` when a button needs action:
  - armor buff missing (`Prep.lua:15` inverse);
  - chosen pet not out (`Prep.lua:33`);
  - healthstone or soulstone count is 0 while the create spell is known (`UI.lua:64` plus `WUK.known`).

**Verify**:
- Tests pass.
- In game:
  - Remove the armor buff and the armor button pulses.
  - Dismiss the pet and the pet button pulses.
  - Trade away all healthstones and the healthstone button pulses.
  - Pulses keep running in combat.
  - No Lua errors.
  - If AnimationGroup fails, stop and revisit the design.

---

## Phase 3: Ready shine
A one-shot pop plays when a stone count goes from 0 to more than 0.

**Files**: `UI.lua`

**Key changes**:
- `b.shine` (new). A one-shot AnimationGroup on the icon: `Scale` 1 to 1.3 to 1 plus an `Alpha` flash.
- `b.lastCount` (new field). The stone refresher plays `b.shine` when `lastCount == 0 and count > 0`. It skips the very first refresh, which runs when `lastCount == nil`.

**Verify**:
- Tests pass.
- In game:
  - Create a healthstone from 0 and the button shines once.
  - Login with stones in bags causes no shine.
  - Stacking from 1 to 2 causes no shine.

---

## Phase 4: Spin + combat freeze
Out of combat the ring rotates slowly. Entering combat freezes the ring at full radius, and leaving combat resumes the spin. The setting can be toggled.

**Files**: `UI.lua`, `Core.lua`, `Settings.lua`

**Key changes**:
- Ring state on the strip: `WUK.strip.angle` (deg), `.radius`, `.targetRadius`.
- `WUK.Animate()` (new). Installs or removes the container `OnUpdate`. The OnUpdate advances the angle by `360/60*elapsed` when `db.spin` is on, eases the radius toward `targetRadius`, then calls `LayoutRing`. It removes itself when idle: no spin, or in combat, and the radius is at its target.
- `WUK.On("PLAYER_REGEN_DISABLED", WUK.CombatFreeze)` (new event). `CombatFreeze()` removes the OnUpdate, snaps the ring to full radius, and runs a final `LayoutRing` while still unlocked.
- The `PLAYER_REGEN_ENABLED` path (`Core.lua:152`, via Refresh) gets a refresher that calls `WUK.Animate()`.
- `DEFAULTS.spin = true` (`Core.lua:19`).
- `/wuk spin` toggles it and is refused in combat (pattern from `Core.lua:236`). The usage line is updated.
- Settings checkbox "Spin ring" routes through `Run("spin")` (`Settings.lua:28-32` pattern). The window height grows if needed (`Settings.lua:20`).

**Verify**:
- Tests pass.
- In game:
  - The ring rotates about one turn per minute.
  - Pull a mob and it stops immediately. Every button stays clickable in combat, with no "action blocked" message.
  - After combat it resumes.
  - `/wuk spin` stops and starts it, and the setting persists across `/reload`.
  - Dragging the strip while it spins works.

---

## Phase 5: Collapse to core
Out of combat, with the mouse away, the orbit folds into the core. Hovering blooms it open, and combat forces it open. When collapsed, the core pulses if any orbit button is alerting.

**Files**: `UI.lua`, `Core.lua`, `Settings.lua`

**Key changes**:
- The container gets `OnEnter`/`OnLeave`. These set `targetRadius` to R or 0 when `db.collapse` is on and the player is out of combat, then call `WUK.Animate()`. OnLeave uses `MouseIsOver(strip)` so moving onto a child button doesn't collapse the ring.
- `LayoutRing` sets orbit alpha in proportion to `radius/R`. At radius 0 it calls `EnableMouse(false)`, and above 0 it calls `EnableMouse(true)`. These run out of combat only.
- `CombatFreeze()` is extended: it sets `targetRadius = R`, alpha 1, and `EnableMouse(true)` on all orbit buttons.
- Core proxy alert: `SetAlert(core, anyOrbitAlert and collapsed)`.
- `DEFAULTS.collapse = true`. `/wuk collapse` toggles it and is refused in combat. Settings checkbox "Collapse until hover".

**Verify**:
- Tests pass.
- In game:
  - When idle, only the core shows.
  - Hovering blooms the ring in about 0.2s, and moving between buttons keeps it open.
  - Leaving collapses it.
  - Entering combat while collapsed snaps it open and every button is clickable.
  - The core pulses when collapsed with the armor buff missing.
  - With `/wuk collapse` off, the ring stays open.

---

## Phase 6: Release
Bump the version and update the docs.

**Files**: `WarlockUtilityKit.toc`, `README.md` (if it describes the strip)

**Key changes**:
- Version goes from 0.2.0 to 0.3.0.
- The README describes the ring, `/wuk spin` and `/wuk collapse`.

**Verify**:
- Tests pass.
- `/reload` with fresh SavedVariables shows the defaults.
- The package workflow `.github/workflows/package-wuk.yml` is unaffected.

## Testing Checkpoints
- **After 1**: the ring layout is static and fully functional. Docking and dragging work. The `RingPoint` tests pass.
- **After 2**: AnimationGroup is confirmed working on the client. Alert pulses work in and out of combat.
- **After 3**: the shine plays only on the 0 to >0 transition.
- **After 4**: spin works out of combat, with a hard freeze on combat start and no taint. The `spin` setting persists.
- **After 5**: collapse and bloom work on hover, combat forces the ring open, and the core proxies alerts. The `collapse` setting persists.
- **After 6**: version 0.3.0, docs are updated, and the addon is ready to package.
