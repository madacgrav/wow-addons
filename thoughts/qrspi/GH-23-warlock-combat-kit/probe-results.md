# Probe Results — WarlockCombatKit (`/wck probe`)

Client: 1.60.1 build 70532 (Forever beta). Lines are copied verbatim from chat. `SECRET` means `issecretvalue` was true.

## Run 0 — pre-fix (2026-10-22)
- Registering `COMBAT_LOG_EVENT_UNFILTERED` brought up the client's blocked-action prompt ("disable addon?"), even though `pcall` returned ok. The CLEU probe was removed in commit 3fc7f58.
- `SPELL_ACTIVATION_OVERLAY_HIDE` fires every few seconds with a nil spellID, both in and out of combat, with no proc involved. The trace now skips nil entries.
- Out of combat, open world, own pet targeted: GUID, name, dead and hostile are all readable for a friendly unit.

## Run 1 — open world, in combat (Greater Plainstrider)
```
ctx: 1.60.1 70532 instance false none combat true
unit target: guid Creature-0-4615-1-6-3244-B15831B582 name Greater Plainstrider mark nil dead false hostile true isTarget true
unit nameplate1: guid Creature-0-4615-1-6-3244-B15831B582 name Greater Plainstrider mark nil dead false hostile true isTarget true
spell Shadow Bolt: usable true/false range false cd active false gcd nil enabled true start SECRET
spell Corruption: usable true/false range false cd active false gcd nil enabled true start SECRET
secrecy 17941: 2
secrecy Shadow Trance: 2
assisted available: false
assisted rotation: 0:
assisted next: nil
plate texture: ok
loc target: 0
trace: +0.00 FAILED player 6217 guid=Cast-2-0-0-0-6217-E23DFAA02C
trace: +0.03 SENT 6223 tgt=Greater Plainstrider guid=Cast-3-4615-1-6-6223-92C63F19F8
trace: +1.20 INTERRUPTED player 6223 guid=Cast-3-4615-1-6-6223-92C63F19F8
trace: +1.27 INTERRUPTED player 6223 guid=Cast-3-4615-1-6-6223-92C63F19F8   (x3)
trace: +1.93 FAILED player 6217 guid=Cast-2-0-0-0-6217-C009154FCC
trace: +2.07 SENT 6223 tgt=Greater Plainstrider guid=Cast-3-4615-1-6-6223-870791AEDC
trace: +4.07 SUCCEEDED player 6223 guid=Cast-3-4615-1-6-6223-870791AEDC
trace: +4.07 REGEN_DISABLED
trace: +4.07 UNIT_ADDED nameplate1 guid=Creature-0-4615-1-6-3244-B15831B582
trace: +6.38 SUCCEEDED player 5782 guid=Cast-3-4615-1-6-5782-DEA2C7252F   (SENT +4.79)
```
**Observed (open world, in combat):**
- **Enemy unit reads:** `UnitGUID`, `UnitName`, `GetRaidTargetIndex`, `UnitIsDead`, `UnitCanAttack` and `UnitIsUnit` on `target` and `nameplateN` are all **non-secret**.
- **SENT payload:** the `target` name, `castGUID` and `spellID` are all **non-secret**.
- **Cast pairing:** the SENT and SUCCEEDED castGUIDs match, so pairing casts by `castGUID` works.
- **Failed casts:** `FAILED` arrives with a `Cast-2-…` GUID and no SENT before it (a client-side failure, e.g. out of range). That is harmless: `CastFailed` with an unknown GUID is a no-op.
- **Interrupted casts:** one interrupt fires `INTERRUPTED` up to 4 times with the same GUID. That is harmless: the first one clears the pending entry.
- **Spell checks:** `C_Spell.IsSpellUsable` and `IsSpellInRange` are **non-secret**. Range gives `false` when out of range and `nil` with no target.
- **Cooldown:** `GetSpellCooldown` `isActive` and `isEnabled` are non-secret, `isOnGCD` is `nil` (plain nil, not secret), and `startTime` is **SECRET**.
- **Assisted Combat:** not available for warlocks (`IsAvailable` false, no rotation spells).
- **Nameplate:** a texture can be created on the enemy plate's `UnitFrame` in the open world.

**Unrelated finding, in WarlockUtilityKit:** this pull raised `GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'WarlockUtilityKit'`. The stack runs `WarlockUtilityKit/Core.lua:98` (`ReadPlayerBuffs`) from the `Prep.lua:15` refresher, triggered by `UNIT_AURA` in combat. So player HELPFUL aura reads **error in combat**, which confirms the comment at `TackleBox/Core.lua:67`.

## Run 2 — open world, Fear then kill (Greater Plainstrider)
In combat:
```
trace: +0.00 SENT 1086 tgt=nil guid=Cast-3-4615-1-6-1086-CCBE92FA02        (Demon Armor, self-cast)
trace: +0.00 SUCCEEDED player 1086 guid=Cast-3-4615-1-6-1086-CCBE92FA02
trace: +3.65 FAILED player 6217 guid=Cast-2-0-0-0-6217-1900E6A225
trace: +3.77 SENT 6223 tgt=Greater Plainstrider guid=Cast-3-4615-1-6-6223-A83803CFA2
trace: +5.77 SUCCEEDED player 6223 guid=Cast-3-4615-1-6-6223-A83803CFA2
trace: +5.77 REGEN_DISABLED
trace: +5.77 UNIT_ADDED nameplate1 guid=Creature-0-4615-1-6-3244-0544CD2757
trace: +6.46 SENT 5782 tgt=Greater Plainstrider guid=Cast-3-4615-1-6-5782-162F4E9DB2
trace: +8.94 SUCCEEDED player 5782 guid=Cast-3-4615-1-6-5782-162F4E9DB2
"Greater Plainstrider attempts to run away in fear!"
```
After combat, the same trace continued:
```
ctx: 1.60.1 70532 instance false none combat false
plate: nil
trace: +24.00 REGEN_ENABLED
trace: +24.00 UNIT_REMOVED nameplate1 guid=Creature-0-4615-1-6-3244-0544CD2757
```
**Observed:**
- **Self-casts:** SENT has `target` nil (Demon Armor).
- **Readings repeat Run 1:** the Fear SENT/SUCCEEDED pair matches by GUID, and unit identity is non-secret.
- **Plate removal on death:** `NAME_PLATE_UNIT_REMOVED` fired on the kill, at the same moment as `REGEN_ENABLED`, and its payload GUID is non-secret. The trace did not record `UnitIsDead` at removal time. The probe now adds a dead flag to that trace line; it needs one more kill with a second mob still alive.

## Pending runs
- [ ] Kill one mob while still fighting another: does `UNIT_REMOVED ... dead=true` show for the dead plate?
- [ ] After a Nightfall proc: which overlay event fires, and its spellID.
- [ ] After a succubus Seduction: pet `SUCCEEDED`.
- [ ] A raid-marked mob, in combat: is `GetRaidTargetIndex` non-secret when it is set?
- [ ] Dungeon, in combat: unit identity, SENT target, plate texture.
- [ ] Battleground, in combat: same as the dungeon run.

## Conclusions (filled as runs land)
1. SENT `target` non-secret in combat: **yes (world)**; dungeon and BG pending.
2. `castGUID` non-secret, and SENT matches SUCCEEDED: **yes (world)**.
3. Nightfall overlay event: pending.
4. Enemy GUID, name and dead state in combat: **non-secret (world)**. Mark when set: pending. Dungeon and BG: pending.
5. `IsSpellUsable` and `IsSpellInRange` in combat: **non-secret (world)**, so `WCK.USABLE_OK` can be true.
6. `C_AssistedCombat`: **unavailable for warlocks**. Drop the fallback toggle, or keep it hidden.
7. CLEU: **unavailable** (registering it triggers the blocked-action prompt).
8. Nameplate texture: **ok (world)**; dungeon and BG pending.
9. `NAME_PLATE_UNIT_REMOVED` on death: **fires, and the GUID is non-secret (world)**. Whether `UnitIsDead` is still true at removal is pending.
10. Pet `SUCCEEDED` for Seduction: pending.
