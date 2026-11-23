# Structure Outline

## Approach
1. Confirm what dungeons hide using an extended `/wck probe`.
2. Extend the key chain: guid, then name, then SENT name, then target slot.
3. Show hidden names by handing the secret value straight to `FontString:SetText`.
4. Clear rows on target death by key when there is no GUID.

Logic stays pure: nil means secret, tested in `tests/run.lua`. Core turns secrets into nil and owns the slot counter.

## Phase 1: Dungeon probe + per-cast key trace
Adds the missing facts to `/wck probe` and traces which key each cast got. The user runs it in a dungeon in combat and the results go into `probe-results.md`.

**GATE:** stop here and review. If GUID and name are readable in dungeons, go back to research. If the SENT name is secret, Phase 2 is a no-op and is skipped.

**Files**: `WarlockCombatKit/Core.lua`, `thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md`
**Key changes**:
- `WCK.Probe()`: new `Try` lines, each printed via `S()`:
  - `secrets identity`: `C_Secrets.ShouldUnitIdentityBeSecret("target")`
  - `secrets compare`: `CanCompareUnitTokens("target","nameplate1")` and `ShouldUnitComparisonBeSecret("target","nameplate1")`
  - `secrets restricted`: `HasSecretRestrictions()`
  - `unit nameplateN isTarget`: already printed at `Core.lua:314`. Confirm it is in the dump.
- New trace event `KEY` in the SENT handler (`Core.lua:254-263`), detail `"<token> <key> lbl=<S(label)>"`. It also traces casts dropped at line 257 (`DROP spell=<S> guid=<S>`), to rule out a secret castGUID or spellID.
- `CHANGELOG.md`: Unreleased entry "probe: secret-identity checks, per-cast KEY trace".

**Verify**:
- `lua5.1 WarlockCombatKit/tests/run.lua` passes (Logic untouched).
- Deploy with robocopy to the `_forever_` AddOns folder.
- In-game, open world: `/wck probe` shows the new lines and `KEY guid:...` entries.
- In-game, dungeon pull: `/wck probe` output gets pasted back and recorded as a new numbered run, which ticks `probe-results.md:197`.

---

## Phase 2: Key on SENT name + show hidden names
When the unit's GUID and name are secret but the SENT target name is readable, each differently named mob gets its own row. Every row whose name is hidden shows the real name via `SetText`.

**Files**: `WarlockCombatKit/Logic.lua`, `WarlockCombatKit/Core.lua`, `WarlockCombatKit/Panel.lua`, `WarlockCombatKit/tests/run.lua`
**Key changes**:
- `WCK.EnemyKey(guid, name, sentName) -> key, label` (modified): adds `"name:"..sentName` after the name step. The fallback stays `"target"` until Phase 3.
- `WCK.Identify(unit) -> key, label, guid, marked, secretName` (modified): the 5th return is the raw `UnitName` value, only when `WCK.Secret(raw)` is true, otherwise nil. Existing callers ignore it.
- `WCK.CastSent(map, castGUID, spell, key, label, guid, now, secretName)` and `CastLanded(..., secretName)`: store `row.secretLabel = secretName` when it is non-nil.
  - The secret value is never compared, concatenated or truth-tested. The only check made on it is `Secret()`, done before it is stored.
- `Panel.lua:206` label: `v.label`, else `pcall(SetText, row.secretLabel)`, else the existing fallback.
- `RowsView` passes `secretLabel` through to the view entries (`Logic.lua:70-83`).
- Tests: `EnemyKey(nil, nil, "Wolf") == "name:Wolf"`; guid still beats sentName; CastLanded keeps `secretLabel` across a nil recast.

**Verify**:
- `lua5.1 WarlockCombatKit/tests/run.lua` passes.
- In-game, dungeon: two differently named mobs give two rows with readable labels.
- In-game, open world: unchanged.

---

## Phase 3: Target slot fallback
When neither the unit nor the SENT name gives anything readable, rows split per target switch instead of collapsing into one "Target" row.

**Files**: `WarlockCombatKit/Logic.lua`, `WarlockCombatKit/Core.lua`, `WarlockCombatKit/Panel.lua`, `WarlockCombatKit/tests/run.lua`
**Key changes**:
- `WCK.EnemyKey(guid, name, sentName, slot) -> key, label`: the last resort becomes `"slot:"..slot` with label `"Enemy "..slot`. It falls back to `"target"` only when `slot` is nil, which keeps old callers and tests valid.
- Core gains `local targetSlot = 0`. It is bumped on `PLAYER_TARGET_CHANGED` (today only a refresh at `Core.lua:239`) and reset to 0 in the `PLAYER_REGEN_ENABLED` clear (`Core.lua:282`).
- `WCK.Identify(unit, slot)`: the slot is passed through to EnemyKey.
  - The SENT handler passes `targetSlot` only when the picked token is `"target"`.
  - Pettarget passes a fixed `"pet"` slot (label "Pet target") unless the probe showed `UnitIsUnit("pettarget","target")` is readable and true, in which case it passes `targetSlot`.
- `Panel.lua:206`: drop the `"Target"` literal; the label now comes from EnemyKey.
- Tests: an all-nil call with slot 3 gives `"slot:3"` / "Enemy 3"; slot nil still gives `"target"`; casts with the same slot merge into one row.

**Verify**:
- `lua5.1 WarlockCombatKit/tests/run.lua` passes.
- In-game, dungeon: tab between 3 mobs while casting gives 3 rows. The probe `row slot:N` lines match.

---

## Phase 4: Clear on target death without GUID + release
When the current target dies and its GUID is secret, its row clears. Docs and version bump.

**Files**: `WarlockCombatKit/Core.lua`, `WarlockCombatKit/Logic.lua`, `WarlockCombatKit/tests/run.lua`, `WarlockCombatKit/README.md`, `WarlockCombatKit/CHANGELOG.md`, `WarlockCombatKit/WarlockCombatKit.toc`
**Key changes**:
- Dead-target ticker (`Core.lua:286-289`): when the guid is nil, `ClearRow(map, Identify("target", targetSlot))`, using the existing unused `WCK.ClearRow` (`Logic.lua:53`).
  - `ClearRow` returns the count (0 or 1) so the `CLR_TARGET` trace keeps working.
  - It never clears the `"target"` key or a `"name:"` key shared by same-name mobs unless that key is what the target resolves to now. That is accepted.
- `WCK.ClearRow(map, key) -> n` (modified to return a count).
- Tests: ClearRow removes only the matching key and returns 1, or 0 when nothing matches.
- README "Known limits": dungeon rows use the name or "Enemy N"; tabbing back to a mob creates a duplicate slot row.
- CHANGELOG entry; `## Version` bump in the toc (0.2.2).

**Verify**:
- `lua5.1 WarlockCombatKit/tests/run.lua` passes.
- In-game, dungeon: killing the target removes its row within about 0.5s, and other rows stay.
- In-game, open world: the GUID clear path is unchanged.

## Testing Checkpoints
- **After Phase 1**:
  - Tests pass.
  - The probe has new secret and KEY lines.
  - A dungeon run is recorded in `probe-results.md`.
  - Gate decision written down: continue, skip Phase 2, or go back to research.
- **After Phase 2**:
  - Differently named dungeon mobs get separate, labelled rows.
  - Hidden names show via `SetText`.
  - Open world is unchanged.
- **After Phase 3**: no shared "Target" row remains; secret-everything casts split per target switch as `slot:N` / "Enemy N".
- **After Phase 4**:
  - A dead target's row clears in dungeons.
  - Docs and changelog are updated and the version is 0.2.2.
  - Deployed to `_forever_` for the final in-game check.
