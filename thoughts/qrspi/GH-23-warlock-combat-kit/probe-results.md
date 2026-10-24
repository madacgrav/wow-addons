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

## Run 3 — open world, Razormane pack, succubus summoned, Seduction
The client was still on the pre-`dead=` build, so the UNIT_REMOVED lines have no dead flag.
```
unit target: guid Creature-0-4615-1-6-3458-32A8484EEE name Razormane Seer mark nil dead false hostile true isTarget true
spell Shadow Bolt: usable true/false range true cd active false gcd nil enabled true start SECRET
trace: +0.00 UNIT_REMOVED nameplate2 guid=Creature-0-4615-1-6-3457-8484860EA7
trace: +1.50 SENT 6217 tgt=Razormane Seer guid=Cast-3-...-6217-51E6147AF9      (Curse of Agony, instant)
trace: +1.50 SUCCEEDED player 6217 guid=Cast-3-...-6217-51E6147AF9
trace: +4.19 SENT 8288 tgt=Razormane Seer guid=Cast-3-...-8288-3D6B567093      (Drain Soul, channel)
trace: +4.19 SUCCEEDED player 8288 guid=Cast-3-...-8288-3D6B567093
trace: +12.26 SENT/SUCCEEDED 8288 (second channel)
trace: +15.39 UNIT_ADDED nameplate2 guid=Creature-0-4615-1-6-3457-8484860EA7
trace: +18.68 UNIT_REMOVED nameplate3 guid=Creature-0-4615-1-6-3844-4A713C3F99   (in combat)
trace: +25.51 UNIT_REMOVED nameplate2 guid=Creature-0-4615-1-6-3457-8484860EA7
trace: +26.28 REGEN_ENABLED
trace: +26.54 UNIT_REMOVED nameplate1 guid=Creature-0-4615-1-6-3458-32A8484EEE
trace: +38.56 SENT 712 tgt=nil ... +48.55 SUCCEEDED player 712                  (Summon Succubus)
trace: +49.85 SENT 1248383 tgt=nil; SUCCEEDED player 434 (Cast-15-…) and 1248383   (food or drink)
trace: +120.61 SUCCEEDED pet 6358 guid=Cast-3-4615-1-6-6358-FF17C2FDE9           (Seduction)
trace: +120.71 REGEN_DISABLED
trace: +120.71 UNIT_ADDED nameplate1 guid=Creature-0-4615-1-6-3458-32A8484EEE
```
**Observed:**
- **Instant casts and channels:** SENT and SUCCEEDED arrive in the same frame. A channel (Drain Soul) reports SUCCEEDED when the channel starts.
- **Pet casts:** pet `UNIT_SPELLCAST_SUCCEEDED` fires for Seduction (6358), and its spellID and castGUID are non-secret. It arrived just before `REGEN_DISABLED`.
- **Plate removal:** `NAME_PLATE_UNIT_REMOVED` also fires mid-combat (nameplate3, nameplate2), for deaths or for plates leaving view. Telling those apart still needs the dead flag.
- **`IsSpellInRange`:** `true` when in range.

## Run 4 — open world, Razormane pack (client still on the pre-`dead=` build)
- **Pet casts:** pet SUCCEEDED fires for every succubus ability (7809, 17735), not only Seduction. The pet handler must filter to tracked spells, which the plan already does.
- **Same-frame events:** a `FAILED` with a `Cast-2-…` GUID (no SENT) is often followed in the same frame by a real SENT/SUCCEEDED of a different spell. These come from the client trying a spell and falling through. Harmless.
- **Death detection:** a mid-combat `UNIT_REMOVED nameplate1` again lacks the dead flag. Still pending.

## Run 5 — open world, two Razormane Stalkers, one killed mid-fight (new build with the dead flag)
```
trace: +0.00 UNIT_ADDED nameplate2 guid=Creature-0-4615-1-6-3457-F33C72A9A8 dead=false
trace: +12.07 SENT 709 tgt=Razormane Stalker guid=Cast-3-4615-1-6-709-618BC49831
trace: +12.07 FAILED player 709 guid=Cast-3-4615-1-6-709-618BC49831
trace: +12.34 UNIT_REMOVED nameplate1 guid=Creature-0-4615-1-6-3457-D9E5AAFC6E dead=true   (still in combat)
trace: +17.74 REGEN_ENABLED
trace: +18.01 UNIT_REMOVED nameplate2 guid=Creature-0-4615-1-6-3457-F33C72A9A8 dead=true
```
**Observed:**
- **Death detection:** `UnitIsDead(unit)` inside `NAME_PLATE_UNIT_REMOVED` is **non-secret and `true` for a kill**, both mid-combat and at the end of combat. Clearing a row by GUID on removal plus dead works.
- **Failed casts:** `FAILED` can also carry a real `Cast-3-…` GUID right after its SENT. `CastFailed` drops the pending entry, as designed.
- **From the previous run:** an untargeted enemy plate (Healing Ward IV) also reads GUID, name and dead as non-secret in combat.

## Run 6 — open world, raid-marked Razormane Stalker, in combat
```
unit target: guid Creature-0-4615-1-6-3457-0E615DFAE6 name Razormane Stalker mark SECRET dead false hostile true isTarget true
unit nameplate1: guid Creature-0-4615-1-6-3457-0E615DFAE6 name Razormane Stalker mark SECRET dead false hostile true isTarget true
trace: +16.25 UNIT_REMOVED nameplate4 guid=Creature-0-4615-1-6-3457-0D9461C413 dead=true
```
**Observed:**
- **`GetRaidTargetIndex` is SECRET in combat when a mark is set**, but plain `nil` when no mark is set (Runs 1-5). GUID and name stay non-secret on the same unit.
- **What this means:** the mark cannot be used as a table key or compared in combat. "Is marked" can still be known without comparing: `Secret(mark) or mark ~= nil`, with the `Secret` check run first. A mark icon could still be shown by passing the secret index straight to a Blizzard texture call, but that is unverified.

## Run 7 — open world, probe right after a Nightfall proc
- **No overlay events in the trace:** no `OVERLAY_SHOW` or `GLOW_SHOW` entries appear between the casts, even though the user reported a proc just before the probe. **Inconclusive**: the trace dropped every overlay event whose spellID was nil, so a nil-payload SHOW would have been hidden too.
- **Probe changes (next build):**
  - Overlay events are traced even when their spellID is nil; only `OVERLAY_HIDE` with nil is still skipped.
  - The probe prints which overlay events registered.
  - It post-hooks Blizzard's proc alert on action buttons (`ActionButtonSpellAlertManager:ShowAlert`/`HideAlert`, or `ActionButton_ShowOverlayGlow` on older UIs) and traces `ALERT_SHOW` with the button's action.
- Re-run needed: a probe right after a Nightfall proc on the new build.

## Run 8 — open world, Nak, instant Shadow Bolt (Nightfall consumed)
```
overlay events: GLOW_HIDE=true HIDE=true GLOW_SHOW=true SHOW=true
alert hook: ActionButtonSpellAlertManager
trace: ALERT_HIDE spell:2941 / spell:1098 / spell:5740 / macro:709 / nil:nil ... (every button, repeatedly)
trace: +2.30 SENT 1106 tgt=Nak ...; +2.30 SUCCEEDED player 1106   (instant Shadow Bolt = Nightfall consumed)
```
**Observed:**
- **Overlay events:** all four `SPELL_ACTIVATION_OVERLAY_*` events register on Forever.
- **Proc alert hook:** `ActionButtonSpellAlertManager` exists and its `ShowAlert`/`HideAlert` hooks attach. `GetActionInfo` on the buttons is non-secret (`spell:<id>`, `macro:<id>`).
- **Trace flooded:** `HideAlert` runs for every action button on each bar update, which filled the 20-entry ring, so any `ALERT_SHOW` or `OVERLAY_SHOW` from before the instant Shadow Bolt was pushed out. Still inconclusive. The next build traces `ALERT_HIDE` only for a button that was shown.

## Run 9 — open world, Nak (new build, alert-hide filter)
```
trace: +0.00 REGEN_DISABLED
trace: +8.55 REGEN_ENABLED
trace: +8.76 UNIT_REMOVED nameplate1 guid=Creature-...-5919-3785D5BAA7 dead=false
trace: +8.76 UNIT_REMOVED nameplate2 guid=Creature-...-3434-E70846B549 dead=false
trace: +10.12 SENT/SUCCEEDED 6217 tgt=Nak; REGEN_DISABLED; UNIT_ADDED nameplate1 ...-E70846B549 dead=false
```
**Observed:**
- **Leash/evade:** combat dropped and both plates were removed with `dead=false` (the mob reset), then the same GUID came back on re-pull. Rows must therefore not be cleared on removal unless `dead=true`, which matches the Phase 2 plan.
- **Proc events:** no proc signal at all in this trace (no ALERT/OVERLAY lines), so no Nightfall happened in the window. Still pending.

## Run 10 — open world, Razormane Stalker; user report on Nightfall
- **User report:** on Forever, Nightfall shows **only a buff icon**. Shadow Bolt does not light up and there is no screen overlay. No `OVERLAY_*` or `ALERT_*` lines appeared, which is consistent with that. **The overlay-event and button-glow paths do not exist for Nightfall here.**
- **Next build adds two non-overlay signals to the probe:**
  - `C_Spell.GetSpellInfo("Shadow Bolt").castTime`: is it 0 while the proc is up, and is it non-secret?
  - `pcall(C_UnitAuras.GetPlayerAuraBySpellID, 17941)` in combat: does it error like `GetAuraDataByIndex`?

## Run 11 — castTime / direct aura lookup
- **In combat, user probed after a Nightfall proc:**
  - `castTime Shadow Bolt: 0`
  - `castTime Corruption: 0`
  - `aura 17941: nil`, with **no error**
- **Out of combat, no proc (baseline):**
  - `castTime Shadow Bolt: 3000`
  - `castTime Corruption: 0` (instant through the talent)
  - `aura 17941: nil`
- **Reading:**
  - `GetSpellInfo(...).castTime` is non-secret and reflects cast-time modifiers.
  - Shadow Bolt at 0 in combat after a proc points to **castTime as a Nightfall signal**.
  - `GetPlayerAuraBySpellID(17941)` does not error in combat, but returned nil while the proc was (apparently) up, so it is hidden or unusable.
- **Still to confirm:** castTime reads 3000 in combat **without** a proc. That rules out "always 0 in combat".

## Run 12 — in combat, no proc
- `ctx ... combat true`; `castTime Shadow Bolt: 3000`; `aura 17941: nil`.
- **Confirmed:** castTime is not forced to 0 in combat. **Shadow Bolt castTime 0 means Nightfall is up.** It is non-secret in combat.

## Phase 2 check — death clearing (realm 6783)
- **Nameplates off:** with enemy nameplates hidden, no `NAME_PLATE_*` events fire at all. Rows then clear mid-fight only through the dead-target check (corpse still targeted), or at combat end.
- **Nameplates on:** the trace showed `UNIT_REMOVED nameplate1 …5B24A194FC dead=true` immediately followed by `CLR_PLATE …5B24A194FC rows=1`, mid-combat, with two same-named Razormane Warfrenzy mobs. Clearing by GUID on a nameplate death works.

## Pending runs
- [x] Kill one mob while still fighting another (Run 5): does `UNIT_REMOVED ... dead=true` show for the dead plate?
- [x] After a Nightfall proc (Runs 7-12): no overlay event; castTime signal works.
- [x] After a succubus Seduction: pet `SUCCEEDED` (Run 3).
- [x] A raid-marked mob, in combat (Run 6): **SECRET when set**.
- [ ] Dungeon, in combat: unit identity, SENT target, plate texture.
- [ ] Battleground, in combat: same as the dungeon run.

## Conclusions (filled as runs land)
1. SENT `target` non-secret in combat: **yes (world)**; dungeon and BG pending.
2. `castGUID` non-secret, and SENT matches SUCCEEDED: **yes (world)**.
3. Nightfall: **no overlay event and no button glow** (buff icon only). **Signal: `C_Spell.GetSpellInfo("Shadow Bolt").castTime == 0`** (3000 normally, 0 with the proc; non-secret in combat). `GetPlayerAuraBySpellID(17941)` returns nil (no error).
4. Enemy GUID, name and dead state in combat: **non-secret (world)**. Mark: **SECRET when set**, nil when unset. Dungeon and BG: pending.
5. `IsSpellUsable` and `IsSpellInRange` in combat: **non-secret (world)**, so `WCK.USABLE_OK` can be true.
6. `C_AssistedCombat`: **unavailable for warlocks**. Drop the fallback toggle, or keep it hidden.
7. CLEU: **unavailable** (registering it triggers the blocked-action prompt).
8. Nameplate texture: **ok (world)**; dungeon and BG pending.
9. `NAME_PLATE_UNIT_REMOVED` on death: **fires; the GUID is non-secret and `UnitIsDead` is true at removal (world)**.
10. Pet `SUCCEEDED` for Seduction: **yes, the spellID (6358) is non-secret (world)**.
