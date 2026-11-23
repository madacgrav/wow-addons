# Structure Outline

## Approach
Build a per-refresh cooldown map over the spells on the bar, using guarded `C_Spell.GetSpellCooldown` reads in `Core.lua`. The map feeds a pure `ButtonLook` that greys a button only when its spell is on its own cooldown (the global cooldown doesn't count). Then schedule one redraw for when the earliest readable cooldown ends. Docs and version come last.

Test command: `lua WarlockCombatKit/tests/run.lua` (CI: `lua5.1`, `.github/workflows/package-wck.yml:21`). Lint: `<skill>/scripts/lint.sh WarlockCombatKit`.

## Phase 1: Grey only on cooldown, glow marks the suggestion
Bar buttons are in colour by default and greyed while their spell is on its own cooldown. That covers every bar spell, including Shadow Bolt, Fear and Banish. The suggested spell keeps its purple pulse. Unknown or hidden values show in colour.

**Files**: `WarlockCombatKit/Logic.lua`, `WarlockCombatKit/Core.lua`, `WarlockCombatKit/Rotation.lua`, `WarlockCombatKit/tests/run.lua`
**Key changes**:
- `WCK.CooldownState(cd) -> onCD:boolean|nil, endsAt:number|nil`: new, pure, in `Logic.lua`.
  - Input: a non-secret table `{isActive, isOnGCD, startTime, duration}`.
  - Returns `true` only for `isActive and isOnGCD ~= true`, and `nil` for a missing or partial table.
  - `endsAt = startTime + duration` when both are numbers.
- `WCK.ButtonLook(spell, onCD, procs, procList) -> {dim, fel}`: modified.
  - Old signature: `(spell, nextSpell, ...)`. The `nextSpell` parameter is replaced by `onCD`.
  - `dim = onCD == true`; `fel` logic unchanged.
- `WCK.BuildCooldowns(spells) -> { [spell] = true }, earliestEnd|nil`: new, in `Core.lua`.
  - Calls `pcall(C_Spell.GetSpellCooldown)` for each spell.
  - Drops a field to `nil` when `WCK.Secret` says it's secret, then passes the cleaned table to `CooldownState`.
  - Stores the results in `WCK.onCD` and `WCK.cdEnd`.
- Refresher in `Core.lua`, registered after the `WCK.next` producer (`Core.lua:202`).
  - Builds the spell list from `WCK.BarSpells(WCK.char.rules, WCK.DATA.tail, WCK.spellSet, WCK.DATA.core)`, the same call `Rotation.lua:59` uses.
- `Rotation.lua:84-85`: pass `WCK.onCD[b.spell]` to `ButtonLook`. The glow line at `Rotation.lua:86` stays unchanged.
- Tests: replace `tests/run.lua:110-114`.
  - Not on cooldown → colour.
  - On cooldown → grey.
  - Proc keeps fel.
  - `CooldownState` cases: global cooldown only → not on cooldown; active → on cooldown and `endsAt`; nil or partial table → nil.

**Verify**: `lua WarlockCombatKit/tests/run.lua` passes, and lint is clean. Then in game, `/reload`:
- All buttons show in colour.
- The suggested spell pulses.
- Cast Fear or Death Coil: that button greys.
- Shadow Bolt never greys from the global cooldown alone.

---

## Phase 2: Back to colour when the cooldown ends
A greyed button returns to colour when its cooldown ends, even if no other event fires.

**Files**: `WarlockCombatKit/Core.lua`
**Key changes**:
- Inside the Phase 1 refresher: when `WCK.cdEnd` is set and is earlier than any end time already scheduled, `C_Timer.After(cdEnd - GetTime() + 0.05, WCK.Refresh)`.
- Track `scheduledEnd` so only one timer is pending for the earliest cooldown end. Clear it when the timer fires.
- If the cooldown time is hidden, `cdEnd` is nil and nothing is scheduled.

**Verify**: tests and lint still pass. Then in game, out of combat with no target:
- Cast a spell with a long cooldown (Howl of Terror or Death Coil) and stand still.
- The button greys, then returns to colour within about 0.2 s of the cooldown ending.
- `/etrace` shows no repeating timer afterwards.

---

## Phase 3: Docs and release bump
The docs describe the new look, and the version is bumped.

**Files**: `WarlockCombatKit/README.md` (line 75), `WarlockCombatKit/CHANGELOG.md`, `WarlockCombatKit/WarlockCombatKit.toc` (line 4)
**Key changes**:
- README: buttons show in colour, grey only while on their own cooldown, and the suggested spell pulses purple.
- CHANGELOG: add a `[0.2.1]` "Changed" entry.
- TOC: `## Version: 0.2.1`.
- Add the WCK row to the docs site if it shows a version (per the docs-site memory, check `docs/index.html`).

**Verify**: README, CHANGELOG and TOC versions match. Deploy to `_forever_\Interface\AddOns` for the final in-game pass.

## Testing Checkpoints
- **After Phase 1:**
  - `ButtonLook` no longer depends on `WCK.next`.
  - `WCK.onCD` is filled every refresh for bar spells.
  - Tests are green.
  - A button can stay grey after its cooldown ends until some other event triggers a redraw (Phase 2 fixes this).
- **After Phase 2:** at most one pending `C_Timer.After`, scheduled for the earliest readable cooldown end. No ticker.
- **After Phase 3:** docs and version are at 0.2.1, ready for PR and `wck-v0.2.1` tag.
