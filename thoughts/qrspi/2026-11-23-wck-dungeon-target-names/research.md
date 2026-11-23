# Research Findings

All paths relative to `WarlockCombatKit/` unless noted. Skill root `<skill>` = `C:\Users\madac\.claude\plugins\cache\wow-forever-addon-marketplace\wow-forever-addon\1.0.0\skills\wow-forever-addon`.

## Q1: How is an enemy identified from a spell cast to a tracker row?

### Findings
- Cast-map handlers are registered inside a `WCK.inits` function (`Core.lua:248-293`), so they only exist for warlocks after login. Separate trace-only handlers on the same events live at `Core.lua:64-71`, wrapped in `Safe` (pcall, `Core.lua:62`).
- **UNIT_SPELLCAST_SENT** (`Core.lua:254-263`):
  - Returns early unless `unit == "player"` (255).
  - `spell = WCK.SpellName(spellID)` (256). That returns nil for a secret or nil spellID (`Core.lua:113-117`).
  - Returns early if the spell is not in `WCK.DATA.tracked`, or if `castGUID` is secret (257).
  - Builds `names[u] = NonSecret(UnitName(u))` for mouseover, target and focus (258-259). These reads are not under pcall.
  - `u = WCK.PickUnit(NonSecret(target), names)` (260). `target` is the SENT destination name.
  - `key, label, guid = WCK.Identify(u)` (261).
  - `WCK.CastSent(map, castGUID, spell, key, label or NonSecret(target), guid, GetTime())` (262). The label falls back to the SENT name.
- **`WCK.PickUnit`** (`Logic.lua:24-30`):
  - Token priority is target, mouseover, focus (24).
  - Returns the first token whose name equals the SENT name.
  - Returns `"target"` when the SENT name is nil or nothing matches (29).
  - Same-name ties go to target (comment `Logic.lua:23`).
- **`WCK.Identify(unit)`** (`Core.lua:119-127`):
  - Reads UnitGUID, UnitName and GetRaidTargetIndex, each under pcall.
  - guid and name each become nil if the pcall fails or the value is secret (124).
  - Returns `EnemyKey(guid, name)` plus `guid` and `marked` (126).
  - The raid mark is never part of the key. Its only use is `s.marked` in BuildRuleState (`Core.lua:195-196`).
- **`WCK.EnemyKey(guid, name)`** (`Logic.lua:16-20`):
  - With a guid: `"guid:"..guid`, with label `name`.
  - With only a name: `"name:"..name`, with label `name`.
  - With neither: the literal key `"target"` and a nil label.
  - Comment at `Logic.lua:15`: "nil for anything secret; guid > name > current target".
- **`WCK.CastSent`** (`Logic.lua:32-36`):
  - Does nothing if castGUID, spell or key is nil.
  - Prunes pending entries older than 10s (34).
  - Stores `pending[castGUID] = {spell, key, label, guid, t}` (35).
- **SUCCEEDED, player branch** (`Core.lua:265`):
  - Requires a non-secret castGUID.
  - `CastSucceeded` (`Logic.lua:45-50`) moves the pending entry into `CastLanded`.
  - Key, label and guid are frozen at SENT time and not re-read here.
  - A missing pending entry creates no row.
- **SUCCEEDED, pet branch** (Seduction) (`Core.lua:266-272`):
  - There is no SENT step and no castGUID check.
  - Calls `Identify("pettarget")`, then `CastLanded` directly.
  - If pettarget is unreadable, the key is `"target"` with a nil label.
- **FAILED / INTERRUPTED** (`Core.lua:274-276`): `CastFailed` clears the pending entry (`Logic.lua:52`). No row is touched.
- **`WCK.CastLanded`** (`Logic.lua:38-43`):
  - Gets or creates `rows[key]`.
  - `row.label = label or row.label` and `row.guid = guid or row.guid`, so a nil never overwrites an earlier value.
  - Sets `row.last = now` and `row.casts[spell] = now`.
- **Inputs that decide the key:** only (guid, name) of the token PickUnit chose. The SENT name only selects the token and supplies the label fallback.
- **Fallback chain when values are missing:**
  - SENT name nil: token `"target"`.
  - guid nil: key `"name:<name>"`.
  - guid and name both nil: key `"target"`, label = SENT name or nil.
  - Every cast whose guid and name are unreadable lands in the same `rows["target"]`, whichever mob it was cast on.
- **Aging and expiry:**
  - No enemy auras are read (comment `Core.lua:110`).
  - `RowsView` (`Logic.lua:70-83`) computes each icon's age and alpha with `IconAlpha` (`Logic.lua:63-67`): 1, fading linearly to 0.3 at `stale`, then held at 0.3.
  - `stale` comes from `tracked[spell].stale` (`Data.lua:5-17`), defaulting to 20.
  - Stale icons and rows are never removed. `RowHasCC` (`Logic.lua:86-89`) drives the CC highlight.

## Q2: How does the addon detect and filter secret values, and what is recorded about where they appear?

### Findings
- **Helper functions:**
  - `WCK.Secret(v) = issecretvalue ~= nil and issecretvalue(v)` (`Core.lua:5`).
  - `NonSecret(v)` turns a secret into nil (`Core.lua:111`).
  - `Clean(v)` is identical and used for cooldowns (`Core.lua:209`).
  - `S(v)` prints "SECRET", diagnostics only (`Core.lua:59`).
  - `Safe(fn)` is a pcall wrapper (`Core.lua:62`).
  - `WCK.On` registers events under pcall (`Core.lua:10-17`).
- **Values filtered:**
  - UnitGUID / UnitName via `Identify` (`Core.lua:124`) and `names[]` (`Core.lua:259`).
  - The SENT `target` arg (`Core.lua:260,262`).
  - castGUID (`Core.lua:257,265,275`).
  - spellID via `SpellName` (`Core.lua:114`).
  - GetRaidTargetIndex: a secret value counts as "marked" (`Core.lua:126`, comment 119).
  - UnitIsDead via `IsDead`: a secret or erroring read counts as alive (`Core.lua:243-246`).
  - UnitGUID at plate removal (`Core.lua:279`).
  - Cooldown `isActive` / `isOnGCD` (`Core.lua:185`) and `IsSpellUsable` (`Core.lua:189-190`).
  - Bar cooldown fields via `Clean` (`Core.lua:208-216`).
  - castTime (`Core.lua:136-138`).
  - UNIT_AURA unit arg (`Core.lua:146`).
  - Action IDs in `ButtonSpell` (`Core.lua:84`).
- **Recorded observations:** `thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md`, client 1.60.1 build 70532.
  - Open world, in combat (runs 1-6), non-secret values (line 36): UnitGUID, UnitName, UnitIsDead, UnitCanAttack and UnitIsUnit on target and nameplateN.
  - SENT `target`, castGUID and spellID are non-secret, and SENT/SUCCEEDED castGUIDs match (37-38).
  - GetRaidTargetIndex is SECRET once a mark is set in combat, while GUID and name stay readable (123-129).
  - Cooldown `startTime` is SECRET (42).
  - CLEU registration triggers a blocked-action prompt (6).
  - Every recorded run reports `instance false none` (e.g. line 12).
  - **Dungeon and battleground are not recorded.** Checklist items are unchecked: "[ ] Dungeon, in combat: unit identity, SENT target, plate texture" and "[ ] Battleground, in combat" (197-198). Conclusions 1, 4 and 8 say "dungeon and BG pending" (201, 204, 208).
- Other code comments: `Core.lua:151` says "IsSpellUsable is non-secret in combat (open world)".
- `README.md:115` notes in general that Forever runs secret-value rules on enemy DoTs in combat.
- `CHANGELOG.md` has no entries about secrecy by context.

## Q3: What do the Forever API docs say about when unit identity becomes secret?

### Findings
- **The index has names only, no annotations.**
  - `<skill>/references/forever-api-index.md:3-5` is generated from wow-ui-source@forever 1.60.1 (70959) and lists names only.
  - The generator keeps only `fn.Name`, `s.Namespace` and `ev.LiteralName` (`<skill>/scripts/gen_api.lua:76-86`).
  - None of `SecretArguments | SecretReturns | AllowedWhenTainted | SecretWhen | ConditionalSecret | NeverSecret` appear anywhere in the skill.
- **`C_Secrets` names** (`forever-api-index.md:873-874`):
  - Includes `ShouldUnitIdentityBeSecret`, `ShouldUnitComparisonBeSecret`, `CanCompareUnitTokens`, `HasSecretRestrictions`, `ShouldUnitSpellCastBeSecret`, `GetSpellCastSecrecy`, `GetSpellAuraSecrecy`, `ShouldAurasBeSecret`, and others.
  - No signatures, no semantics, and nothing tied to instance type.
- **Secret globals** (`forever-api-index.md:1059-1060`): `issecretvalue`, `canaccessvalue`, `canaccesssecrets`, `hasanysecretvalues`, `scrubsecretvalues`, `secretunwrap`, and more.
- **Identity APIs** are listed with no secrecy info (`forever-api-index.md:1060`): UnitGUID, UnitName, UnitNameFromGUID, UnitTokenFromGUID, UnitIsUnit, GetRaidTargetIndex, UnitCreatureID, UnitSpellTargetName.
- **Nameplate and combat-log namespaces:**
  - `C_NamePlate` (744-745).
  - `C_CombatLog` with `IsCombatLogRestricted` (411-412).
  - `C_CombatLogSecure.GetCurrentEventInfo` (417-418).
  - Events UNIT_SPELLCAST_SENT/SUCCEEDED (2737, 2740), NAME_PLATE_UNIT_* (2100-2102) and FORBIDDEN_NAME_PLATE_UNIT_* (1662-1663).
- **Prose notes:**
  - `<skill>/references/forever-api-notes.md:41`: health, power and aura data are secret in combat; "Exact scope ... is still being mapped".
  - `forever-api-notes.md:55` says to check `C_CombatLog.IsCombatLogRestricted()` because "restricted content hands back secret values". That is the only content-based condition mentioned, and "restricted content" is not defined.
  - `references/taint-and-secure.md:10` repeats the combat note.
- **Not answerable from the skill:**
  - When UnitGUID, UnitName, UnitIsUnit or nameplate tokens become secret.
  - Whether UNIT_SPELLCAST_* payloads are secret.
  - Any split by dungeon, raid or open world, or by unit relationship.
  - Any documented never-secret identity alternative.

## Q4: How does Panel.lua render, order, label and clear rows?

### Findings
- **Render cycle:**
  - `RenderPanel` (`Panel.lua:189-224`) is registered as a refresher (225).
  - `WCK.Refresh` is debounced by 0.1s (`Core.lua:35-42`).
  - View comes from `WCK.RowsView(map, GetTime(), tracked)` (`Panel.lua:201`).
- **Ordering:**
  - Rows sorted by `last` descending, no tie-break (`Logic.lua:81`).
  - Icons sorted by age ascending (`Logic.lua:78`).
  - Max 8 rows and 8 icons (`Panel.lua:4`, 203-220).
- **Merging:**
  - One row per key, one slot per spell name.
  - A recast on the same key overwrites that spell's time.
  - Different keys for the same mob (`name:X` versus `guid:...`) are never merged.
- **Label** (`Panel.lua:206`): `v.label or (v.key == "target" and "Target" or "?")`.
  - A nil label on the `"target"` key shows the literal "Target".
  - A nil label on any other key shows "?".
- **CC band and glow** (`Panel.lua:212-214`). Unused rows are hidden (216-219).
- **`RenderMarkers`** (`Panel.lua:67-77`):
  - Runs only when `plateMarker` is on and `WCK.PLATE_OK(instanceType)` allows it.
  - Matches `cc[Identify("nameplateN")]` against row keys.
  - A plate with unreadable guid and name yields `"target"`.
- **Clearing:**
  - `ClearGUID` (`Logic.lua:55-59`) deletes every row with `row.guid == guid`. Rows with a nil guid never match.
  - `ClearRow` (`Logic.lua:53`) has no caller.
  - NAME_PLATE_UNIT_REMOVED (`Core.lua:278-281`) clears only when the guid is readable and the unit is dead (trace `CLR_PLATE`).
  - The 0.5s ticker (`Core.lua:283-292`) clears by `Identify("target")` guid when the target is dead. A nil guid clears nothing. `CLR_TARGET` is traced once per guid change, whether or not rows matched.
  - PLAYER_REGEN_ENABLED calls `ClearAll` (`Core.lua:282`).
  - No UNIT_DIED or CLEU handler exists (comment `Core.lua:359`).
  - PLAYER_TARGET_CHANGED and RAID_TARGET_UPDATE only refresh (`Core.lua:239-240`).
- **Shared keys:**
  - All casts on one key live in one `casts` table and clear together.
  - `"target"` and `"name:"` rows have `guid == nil`, so only `ClearAll` (leaving combat) removes them.

## Q5: What does `/wck probe` report, and what tracing exists?

### Findings
- **Entry point:**
  - `/wck` (`Core.lua:392-396`); `probe` calls `WCK.Probe()`. Returns "warlocks only" if inactive.
  - `P(k,v)` prints a line and appends it to `WCK.db.lastProbe`; `Try` wraps a check in pcall (`Core.lua:301-304`).
- **Reported items, in order:**
  - `ctx`: build, `IsInInstance`, `InCombatLockdown` (308).
  - `unit <u>` for target, focus, mouseover, nameplate1 and nameplate2: guid, name, mark, dead, hostile, isTarget, each via `S()` so secrets print "SECRET" (311-319).
  - Shadow Bolt / Corruption usable, range, cooldown fields and castTime (321-332).
  - `C_Secrets.GetSpellAuraSecrecy` (334-337).
  - Player aura 17941 (339-342).
  - Assisted-combat info (344-357).
  - Nameplate texture test (361-368).
  - Loss of control (370-372).
  - Overlay events and alert hook (374-377).
  - `row <key>` with label, guid and spell ages, plus `target key` (378-386).
  - Trace dump (388-389).
- **What the probe established:** the probe-results.md runs listed in Q2, all open world. Also cited in comments at `Core.lua:129,151` and in `CHANGELOG.md:48-50` / `README.md:111`.
- **`WCK.Trace`** (`Core.lua:53-58`): always-on ring buffer of 40 entries. The comment at line 72 still says 20.
  - Events traced: SENT (spellID, tgt, castGUID) (65); SUCCEEDED / FAILED / INTERRUPTED (69); overlay SHOW / HIDE / GLOW (77); ALERT_* (93,95); GLOW_*_BTN (99-100); UNIT_ADDED / REMOVED (105); REGEN_* (107-108); CLR_PLATE (280); CLR_TARGET (289).
  - No trace records PickUnit's chosen token or the `Identify` key, label or guid per cast. The key is only visible in the probe's `row <key>` lines.

## Q6: What test coverage exists for identity and key selection, and how are secrets simulated?

### Findings
- **Runner:** `tests/run.lua` is plain Lua that loads only `Data.lua` and `Logic.lua` with a stub addon table (1-4).
  - Run with `lua5.1 WarlockCombatKit/tests/run.lua` (`README.md:126`).
  - CI runs it in `.github/workflows/package-wck.yml:18-21`.
  - The skill's wowmock harness is not used.
- **How secrets are simulated:** there is no `issecretvalue` mock. Logic tests use the convention "nil = secret" (`Logic.lua:15,21`); Core turns secrets into nil before calling Logic.
- **wowmock** has no secret support (`<skill>/scripts/wowmock/init.lua:3`, `references/testing.md:53`). It has no GetRaidTargetIndex, UnitIsUnit or nameplate stubs, and UnitGUID covers "player" only (`unit.lua:6-14`).
- **Covered:**
  - EnemyKey with guid, name-only and all-nil, which gives `"target"` (`run.lua:20-21`).
  - PickUnit: mouseover match, target match, same-name preference for target, and a nil sent name falling back to target (`run.lua:22-25`).
  - CastSent / Succeeded / Failed: nil guid, out-of-order events, failed-then-succeeded, unknown failure, stale prune (`run.lua:26-36`).
  - CastLanded and ClearGUID, plain path only (`run.lua:40-42`).
  - CooldownState with secret fields read as missing (`run.lua:116-125`).
- **Not covered:**
  - `Identify` and its pcall and secret branches.
  - The `names[]` construction in the SENT handler.
  - The pettarget path.
  - `RenderMarkers` and the panel label fallback.
  - Any real opaque secret value reaching Logic.

## Cross-Cutting Observations
- Hidden values are turned into nil at the Core boundary (`NonSecret`/`Clean`), and Logic treats nil as unknown. Tests rely on the same convention.
- Row identity rests entirely on readable GUID or name. With both nil, every cast collapses into the one `"target"` key, labelled "Target" (`Logic.lua:19`, `Panel.lua:206`), unless the SENT name supplies a label (`Core.lua:262`).
- Row clearing that targets one mob depends on a readable GUID. Rows without one persist until combat ends.
- `IsInInstance` is already read in two places: the probe `ctx` line (`Core.lua:308`) and the `WCK.PLATE_OK(instanceType)` gate (`Panel.lua:69`).
- Every recorded secrecy observation is from the open world. The skill's API docs have no secrecy annotations.

## Open Areas
- Which of UnitGUID, UnitName, the SENT `target` arg, castGUID and nameplate tokens are secret inside a dungeon (in and out of combat). This is unrecorded and the probe checklist item is open (`probe-results.md:197`).
- Semantics and signatures of `C_Secrets.ShouldUnitIdentityBeSecret`, `ShouldUnitComparisonBeSecret`, `CanCompareUnitTokens` and `HasSecretRestrictions`. The local index has names only, and the Blizzard `*Documentation.lua` files were not consulted.
- Whether UnitIsUnit or token comparison stays usable when identity is secret.
- `WCK.PLATE_OK` definition was not read in detail (referenced at `Panel.lua:69`).
