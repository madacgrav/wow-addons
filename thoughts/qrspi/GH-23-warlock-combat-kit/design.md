# Design Discussion

Prior direction: `thoughts/qrspi/2026-10-21-warlock-combat-tooling/design.md`. This doc keeps that design's direction and records five decisions made 2026-10-22 (Q1 A, Q2 B, Q3 A, Q4 A, Q5 B).

## Current State
- **Repo skeleton.** Three addons share one copied skeleton:
  - `On` dispatcher, `inits` and `refreshers` (`WarlockUtilityKit/Core.lua:3,11-17`).
  - `ADDON_LOADED` calls `MergeDefaults` for `<Name>DB` and `<Name>CharDB` (`Core.lua:19-28`, `Logic.lua:16-23`).
  - Warlock-gated `PLAYER_LOGIN` runs the inits, then `Refresh` (`Core.lua:143-150`).
  - Pure `Logic.lua` with a plain `tests/run.lua` (`WarlockUtilityKit/tests/run.lua:1-7`).
  - Per-addon CI zip and release (`.github/workflows/package-wuk.yml:40-44`).
- **Probes are reports only.** `/wuk probe` prints. `/tb probe` and `/pp probe` also save `lastProbe`. Nothing reads results back (research Q2). Findings live in `probe-results.md` files and code comments (`TackleBox/Core.lua:67,109`).
- **Own casts.**
  - WUK reads SENT `(unit, target)` into a single `lastCastTarget` (`Core.lua:157-159`).
  - SUCCEEDED `(unit,_,spellID)` is matched by spell name (`Prep.lua:42-47`, `Summon.lua:89-93`).
  - No code uses `castGUID` (research Q3).
- **Known on Forever.**
  - Enemy aura reads error in combat (WUKp:14).
  - Raid mark and `UnitCanAttack` are readable in combat (WUKp:13).
  - `GetSpellAuraSecrecy` returns 2 for everything (WUKp:6-8).
  - Everything else WCK needs is unverified: SENT target, enemy GUID/name/dead, `IsSpellUsable`/`IsSpellInRange`, overlay-glow events, nameplates, `C_AssistedCombat` (research Open Areas).
- **Secure buttons.**
  - Attributes are written only out of combat. There is no queue: state is recomputed on the `PLAYER_REGEN_ENABLED` Refresh (`Core.lua:152`, `UI.lua:166-169`, `TackleBox/Actions.lua:47-77`).
  - The repo has no binding code and no `Bindings.xml` (research Q5).
- **Settings.** WUK settings have checkboxes and a dropdown only, with no list editor (`WarlockUtilityKit/Settings.lua:8-58`).

## Desired End State
A new addon, `WarlockCombatKit/` (global `WCK`), interface 16001, version 0.1.0, released as `wck-v<ver>` by `package-wck.yml`. It contains:

1. **`/wck probe`**, built and deployed first.
   - Prints, and saves to `WarlockCombatKitDB.lastProbe`, every unverified API from the issue's probe list, with in and out of combat state and instance type.
   - Results are recorded in `thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md` before any feature phase starts.
2. **One movable panel** (Q5 B).
   - **Header:** next-spell icon in a WUK-style rim/disc (`UI.lua:53-59,119-125`), plus a strip of proc icons.
   - **Body:** cast-map rows.
3. **Cast map.**
   - Pairs SENT and SUCCEEDED by `castGUID` for the tracked spell list.
   - One row per enemy, keyed by raid mark, then GUID, then name, then "target", whichever is non-secret.
   - Icons fade with age, with no countdowns.
   - Rows clear on detected death or despawn, otherwise on `PLAYER_REGEN_ENABLED`.
4. **CC highlight.**
   - Rows with Fear, Banish, Seduction, Death Coil or Howl get the `AddGlow` pulse.
   - Nameplate marker is a settings toggle, off by default.
5. **Rotation helper** (Q3 A).
   - Ordered rule rows in settings: spell, one condition, and up/down/delete controls.
   - `Logic.lua` evaluates the list and the header shows the first match.
   - Optional `C_AssistedCombat` fallback toggle.
6. **Proc alerts.**
   - `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE` for a spell list (default 17941).
   - The header proc icon pulses, with an optional `PlaySound`.
7. **Click-cast** (Q4 A).
   - `Bindings.xml` with 6 slots, `CLICK WCKCast<n>:LeftButton`.
   - Each slot is a hidden `SecureActionButtonTemplate` with macrotext `/cast [@mouseover,harm,nodead][] <spell>`.
   - You choose each slot's spell in WCK settings; keys are bound in Blizzard's Key Bindings menu.

**Verification**
- `lua5.1 WarlockCombatKit/tests/run.lua` passes. It covers cast-map pairing, keying and aging, rule evaluation, macro building and MergeDefaults.
- CI builds the zip.
- In-game checklist per phase (deploy with robocopy to `_classic_beta_\Interface\AddOns\WarlockCombatKit`):
  - An open-world pack, a dungeon and a BG.
  - No Lua errors and no `ADDON_ACTION_BLOCKED`.

## Patterns to Follow
- **Module skeleton:**
  - `local ADDON, WCK = ...`, `WCK.inits`, `WCK.refreshers`, `WCK.On` (`WarlockUtilityKit/Core.lua:3,11-17`).
  - Warlock gate and `WCK.active` (`Core.lua:143-150`).
- **Debounced Refresh:** 0.1s `C_Timer.After` with a `pending` flag (`TackleBox/Core.lua:42-50`). Cast events can fire in bursts, so use TackleBox's debounced Refresh, not WUK's undebounced one (`WarlockUtilityKit/Core.lua:137-141`).
- **Secret guard:** `WCK.Secret(v)` before every compare, index or arithmetic (`Core.lua:7`). Wrap risky APIs in `pcall`.
- **Probe:** the TackleBox shape (`TackleBox/Core.lua:160-235`):
  - `P` prints and appends to `db.lastProbe`.
  - `Try` wraps each section in pcall.
  - `S` masks secrets.
  - A `Trace` ring of recent events (`:90-91`) for SENT, SUCCEEDED and OVERLAY_GLOW timing.
- **Pure logic and tests:**
  - All decisions live in `Logic.lua` and take game data as arguments (`TackleBox/Panel.lua:237,262`).
  - Tests use `eq`/`near` straight-line asserts, loaded with `loadfile(...)(ADDON, WCK)` (`WarlockUtilityKit/tests/run.lua:1-7,89-91`).
- **Secure split:**
  - Secure cast buttons are parented to a plain frame, never to the skinned or movable panel (`TackleBox/Actions.lua:3,39-42`).
  - Attributes are set only when `not InCombatLockdown()`, and recomputed on the REGEN_ENABLED Refresh (`TackleBox/Actions.lua:46-47`).
- **Visuals:**
  - `AddGlow`/`SetAlert` (`UI.lua:96-110`).
  - Desaturate for unavailable icons (`UI.lua:161`).
  - Shine pop (`UI.lua:135-138`).
  - Rim and disc colors (`UI.lua:119-122`).
- **Movable:** `MakeMovable(f, key, x, y)`, using Shift, `db.locked`, combat lock and `db.frames[key]` (`UI.lua:13-26`).
- **Settings and minimap:**
  - Lazy `BasicFrameTemplateWithInset`, `Check()` re-sync, and `WowStyle1DropdownTemplate` (`Settings.lua:8-50`).
  - Minimap button with angle in `db.minimapAngle`: left-click opens settings, right-click toggles the panel (`Settings.lua:73-110`).
- **Pooled rows:** pre-create N row frames and show or hide them (`TackleBox/Panel.lua:112-138`).
- **Release:** copy `package-wuk.yml` to `package-wck.yml` with tag `wck-v`. Keep a hand-written `CHANGELOG.md` and `README.md` matching WUK's sections (`WarlockUtilityKit/README.md:166-169`).

**Do NOT follow**
- WUK's single `lastCastTarget` with spell-name matching (`Core.lua:157-159`). The cast map needs per-`castGUID` pairing, because several casts can be in flight at once.
- WUK's ring orbit and spin code (`UI.lua:33-93`). Q5 B drops the ring.
- Probe results that are never used. The results feed `probe-results.md` and hard-coded gates (Q2 B), but they are still never read at runtime.
- Settings that route everything through slash strings (`Settings.lua:6`). The rule-list editor writes `WCK.char` directly and calls `Refresh`. Simple toggles may still use the slash path.
- `C_UnitAuras` on enemies (WUKp:14).
- Registering CLEU without pcall.

## Design Decisions
1. **Probe-only first phase (Q1 A).**
   - Phase 1 is the skeleton plus `/wck probe`, deployed for an in-game run.
   - Results go into `probe-results.md`. Feature phases are designed against them.
   - Why: every core API is unverified, and building fallbacks blind risks dead code.
2. **Probe is a report; gating is hard-coded plus guarded (Q2 B).**
   - No `db.caps` table.
   - Each feature hard-codes the path the probe proved.
   - Each risky call keeps a runtime `pcall`/`Secret()` guard that degrades quietly: skip the icon, fall back to "target".
   - Nameplate marker and Assisted Combat fallback are settings toggles.
   - Why: matches all three existing addons. No stale-cache problem when Blizzard hotfixes the rules.
3. **Rule-row editor (Q3 A).**
   - Rules are stored per character: `WCK.char.rules = {{spell=, cond=, n=}, ...}`.
   - Conditions: `always`, `ready` (`C_Spell.GetSpellCooldown` `isActive` false), `notRecent` (N seconds, from the cast map), `proc` (overlay glow active), `marked`.
   - `usable` is included only if the probe shows `IsSpellUsable` is readable in combat.
   - `WCK.EvalRules(rules, state)` is pure and tested.
   - Settings get a pooled list of rule rows.
   - Why: the issue asks for a user-defined list, and it stays testable.
4. **Bindings.xml click slots (Q4 A).**
   - 6 slots, with `BINDING_HEADER_WCK` and `BINDING_NAME_CLICK WCKCast<n>:LeftButton` globals.
   - Slot spells live in `WCK.char.slots`.
   - Macrotext comes from pure `WCK.CastMacro(spell)` and is applied out of combat.
   - Why: Blizzard's Key Bindings menu already handles conflicts, modifiers and saving, so WCK builds no key-capture UI and overrides none of the user's keys.
5. **Single panel (Q5 B).**
   - Placed by `MakeMovable(panel, "panel", ...)`. The default is offset away from WUK's strip at CENTER 0,-220 (`UI.lua:149`).
   - **Header:** rim/disc next-spell icon, proc strip.
   - **Body:** pooled cast-map rows, about 8 maximum.
   - Why: one frame, one anchor, and no orbit code.
6. **Cast map state in Logic.**
   - SENT stores `pending[castGUID] = {spell, targetName, key, t}`.
   - SUCCEEDED moves the entry into `map[key].casts[spell] = t`.
   - FAILED or INTERRUPTED drops it.
   - Ageing, the "stale after" setting and row ordering are pure functions.
   - The identity key is resolved in Core from non-secret reads and passed into Logic.
7. **Panel rows are not secure.** Click-to-target on a row is not in v1.
   - Rows appear mid-combat, when secure attributes cannot be set. `/target <name>` also fails when names are secret.
   - This is a scope cut from the issue. Mouseover click-cast covers nameplates and unit frames instead.
8. **Proc alerts are hard-coded to the overlay events if the probe confirms they fire.** Otherwise the alert feature ships disabled behind its toggle, with a note in the README.
9. **Separate addon.** No WUK dependency, no shared SavedVariables (`WarlockCombatKitDB` and `WarlockCombatKitCharDB`), and it can run beside WUK.

## What We're NOT Doing
- **Anything WUK covers:** stones, armor, pet, soulstone timer, summon queue, healthstone trade, assignment board, CDM dock. Fear and Banish buttons belong to #20.
- **Timers and enemy reads:**
  - Exact DoT or CC timers, pandemic windows, duration math.
  - Reading enemy auras, health or casts.
- **PvP tracking:** enemy cooldowns, trinkets, DR.
- **Automation:** auto-cast, one-button rotation.
- **Bindings:** override bindings and key-capture UI (Q4 A).
- **Probe gating:** a runtime `db.caps` gating system (Q2 B).
- **Ring layout:** a ring or orbit layout for WCK (Q5 B).
- **Row targeting:** secure click-to-target on panel rows (Decision 7).
- **Out of scope:** cross-player sync, Retail and Classic flavors, a shared library between addons.

## Open Risks
- **SENT target secret in combat:** the cast map shrinks to the current-target key plus raid mark.
- **Instance identity secret:** GUID and name are secret in dungeons and BGs, so rows collapse to mark or "target" only.
- **Overlay events:** `SPELL_ACTIVATION_OVERLAY_GLOW_*` may not fire for Nightfall. Proc alerts then ship off (Decision 8).
- **Death detection:**
  - `UnitIsDead` on nameplate tokens or CLEU may be unavailable, so rows linger until combat ends.
  - The `NAME_PLATE_UNIT_REMOVED` payload is unverified.
- **Mouseover macros:** `[@mouseover]` on Forever nameplates in a `CLICK` binding is unverified. The `[]` fallback casts on the target.
- **Spell names:**
  - Rule conditions use cooldown flags only if `IsSpellUsable` and `IsSpellInRange` are secret.
  - Forever rank and spell names (Banes, no Curse of Shadows) may differ from Classic. Spell lists resolve by `C_Spell.GetSpellInfo` at login.
- **Rule changes:** Blizzard may change the secret rules after the 2026-11-04 launch. The runtime guards keep WCK error-free, but features may go dark.
