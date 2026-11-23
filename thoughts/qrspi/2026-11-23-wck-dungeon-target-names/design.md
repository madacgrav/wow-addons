# Design Discussion

## Current State
- A tracker row is keyed by `WCK.EnemyKey(guid, name)`. It uses `guid:` if the GUID is readable, then `name:`, and otherwise the literal `"target"` (`Logic.lua:16-20`).
- GUID and name come from `WCK.Identify`, which turns secret values into nil (`Core.lua:119-127`, `NonSecret` at `Core.lua:111`).
- The SENT handler chooses a unit token by matching the SENT target name, then calls Identify on it (`Core.lua:254-263`). The SENT name is used only as a label fallback, never as a key (`Core.lua:262`).
- Seduction keys on `Identify("pettarget")` (`Core.lua:266-272`).
- `CastLanded` merges every cast with the same key into one row. A nil label never overwrites an earlier one (`Logic.lua:38-43`).
- The panel shows `v.label`, otherwise "Target" for the `"target"` key, otherwise "?" (`Panel.lua:206`).
- Result when identity is secret: every cast collapses into one row labelled "Target". This matches the dungeon symptom.
- Clearing a single enemy's row needs a readable GUID:
  - `ClearGUID` (`Logic.lua:55-59`) is called by the plate-removed handler (`Core.lua:278-281`) and the 0.5s dead-target ticker (`Core.lua:283-292`).
  - `"target"` and `name:` rows clear only on PLAYER_REGEN_ENABLED (`Core.lua:282`).
- Every recorded secrecy fact comes from the open world. The dungeon checklist item is still open (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:197`).
- The Forever API index lists `C_Secrets.ShouldUnitIdentityBeSecret`, `CanCompareUnitTokens`, `ShouldUnitComparisonBeSecret` and `HasSecretRestrictions` by name only (`forever-api-index.md:873-874`).
- The skill notes say secret values can be passed to Blizzard widgets, `FontString:SetText` included (`forever-api-notes.md:41`).

## Desired End State
- In a dungeon pull with several mobs, the tracker shows one row per enemy cast on, each with its DoT/curse/CC icons.
- Each row is labelled with the mob's name, shown even when the addon cannot read it, or "Enemy N" as a last resort.
- Open-world behaviour is unchanged: `guid:` keys, readable labels, the same clears.
- When the current target dies, its row clears even if its GUID was secret.
- The cause is confirmed by data, not assumed. `/wck probe` run in a dungeon in combat records what is secret, and the results go into `probe-results.md`.

**Verification**
1. Logic tests in `tests/run.lua` cover the new key chain and slot behaviour with nil inputs. Run with `lua5.1 WarlockCombatKit/tests/run.lua`.
2. In-game: a dungeon pull with Corruption and Curse of Agony on 2-3 mobs gives separate named rows. Killing the target removes its row.
3. In-game: the open-world pull looks identical to before.

## Patterns to Follow
- **Turn secrets into nil at the Core boundary; Logic treats nil as unknown.** Use `NonSecret`/`Clean` in Core (`Core.lua:111,209`). Logic functions stay pure and take nil for secret (`Logic.lua:15,21`). That keeps them testable in plain Lua (`tests/run.lua:1-4`).
- **pcall-wrap unit API reads** as Identify does (`Core.lua:120-122`). The SENT `names[]` loop does not (`Core.lua:259`); see "NOT followed".
- **Freeze identity at SENT time** in `pending[castGUID]` and land it on SUCCEEDED (`Logic.lua:32-50`). Any new key or slot must be decided at SENT, not at SUCCEEDED.
- **`row.x = x or row.x` merge** in CastLanded (`Logic.lua:41-42`). A secret label must be stored the same way. It may only ever be passed to a widget, never compared or concatenated.
- **Probe output** goes through `P(k,v)` / `Try(k,fn)` with `S()` printing "SECRET" (`Core.lua:59,301-304`). Results are recorded as numbered runs in `probe-results.md`.
- **Always-on trace ring** via `WCK.Trace(ev, detail)` (`Core.lua:53-58`). Detail strings must not concatenate secret values; wrap them with `S()`, as at `Core.lua:65`.
- **Tests:** plain `eq`/`near` cases in `tests/run.lua`, one line per behaviour, with nil standing in for secret (`run.lua:20-25`).

**NOT followed / noted**
- `Core.lua:259` reads `UnitName` without pcall. New code must not copy that.
- The comment at `Core.lua:72` says "20-entry ring" but the code holds 40. Do not rely on comments for sizes.
- `ClearRow` (`Logic.lua:53`) has no caller. Reuse it for slot clearing rather than adding another clear function.

## Design Decisions
1. **Probe first, then fix.** Phase 1 extends `/wck probe`, and the user runs it in a dungeon in combat. Later phases are adjusted to the findings. If the probe shows readable identity in dungeons, the root cause is elsewhere and we stop and re-research.
   Probe additions:
   - `C_Secrets.ShouldUnitIdentityBeSecret("target")`, `CanCompareUnitTokens`, `ShouldUnitComparisonBeSecret` and `HasSecretRestrictions`. Each goes through `Try` because their signatures are unknown.
   - `UnitIsUnit("target", "nameplateN")` secrecy.
   - Secrecy of the SENT `target` arg. The existing SENT trace already shows it via `S()` (`Core.lua:65`).
   - A new trace line per cast with the key and label source that was chosen.
2. **Key chain: guid, then name, then SENT name, then target slot.** `EnemyKey` gains a SENT-name step (`name:<sent>`) before the slot step. The last resort replaces the shared `"target"` key with `slot:N`.
   - The SENT handler gets N from a counter in Core, bumped on PLAYER_TARGET_CHANGED (today that event only refreshes, `Core.lua:239`).
   - Casts on the current target reuse the current N.
   - Same-name mobs share a row when only the SENT name is readable. That is accepted.
3. **Label: pass the secret name through.** Store the raw (possibly secret) UnitName as `row.label`. The panel passes it straight to `FontString:SetText`, which can display secrets.
   - Logic never inspects the label.
   - The fallback label is "Enemy N" for slot rows, replacing the "Target" literal at `Panel.lua:206`.
   - `RowsView`'s sort uses `last`, not the label, so sorting is unaffected (`Logic.lua:81`).
4. **Clear on target death without a GUID.** The 0.5s ticker (`Core.lua:286-289`) falls back to clearing the current target's row by key: the current slot key, or `name:`. It uses `ClearRow` when the GUID is nil.
5. **Pettarget follows the same chain** (`Core.lua:269`). With no SENT name it falls through to the slot step only if pettarget is the player's target (needs UnitIsUnit, pending the probe), otherwise to a separate "pet" slot.
6. **Plate markers stay gated to the open world** (`Panel.lua:46` `PLATE_OK(kind) == "none"`). Unchanged.

## What We're NOT Doing
- No combat-log (CLEU) tracking. It triggers the blocked-action prompt (`probe-results.md:6`).
- No aura reading for DoT timers. Ages stay cast-time based (`Logic.lua:63-83`).
- No nameplate markers in instances.
- No change to open-world key format, row limits (`Panel.lua:4`), sorting, or icon fading.
- No re-identification of a mob when the player tabs back to it with secret identity. It gets a new slot, an accepted duplicate.
- No battleground or raid testing beyond what the dungeon probe covers.
- No wowmock adoption or `issecretvalue` mock. Tests stay nil-as-secret.

## Open Risks
- **The probe may not confirm the theory.** If GUID and name are readable in dungeons, the bug is elsewhere (for example the SENT handler returning early because `castGUID` or `spellID` is secret, `Core.lua:257`). The plan pauses after phase 1 for that reason.
- **The SENT target name may also be secret.** Then step 2 of the chain never fires and every row is a slot.
- **SetText with a secret label may fail** or show nothing on this client. The fallback is the "Enemy N" label. Wrap the call in pcall.
- **PLAYER_TARGET_CHANGED may fire for the same mob** (for example a clear then reacquire), creating spurious slots. The cost is an extra row, never wrong icons.
- **castGUID or spellID could be secret in instances.** The SENT handler would then drop every cast and no rows would appear at all. That does not match the symptom, but the probe checks it.
- **`C_Secrets.*` signatures are unknown.** All calls go through `Try`/pcall.
