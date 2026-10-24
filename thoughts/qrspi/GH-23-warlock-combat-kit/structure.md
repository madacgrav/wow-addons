# Structure Outline

## Approach
Build a new `WarlockCombatKit/` addon by copying the WUK/TackleBox skeleton. Phase 1 ships only the probe. After that, each phase adds one feature end to end: Core events, pure `Logic.lua` with tests, the panel/settings UI, then an in-game check. Every gate is hard-coded from `probe-results.md` and protected by runtime `pcall`/`Secret()` guards. Deploy after each phase with robocopy to `_classic_beta_\Interface\AddOns\WarlockCombatKit`.

## Phase 1: Skeleton + `/wck probe` + release pipeline
Delivers an addon that loads, persists its SavedVariables, and runs a probe whose output lands in chat and in `WarlockCombatKitDB.lastProbe`. CI packages it.

**Files**: `WarlockCombatKit/WarlockCombatKit.toc`, `Logic.lua`, `Core.lua`, `tests/run.lua`, `README.md`, `CHANGELOG.md`, `.github/workflows/package-wck.yml`, `thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md` (filled after the run).
**Key changes**:
- `.toc`:
  - `## Interface: 16001`, `## Version: 0.1.0`
  - SavedVariables `WarlockCombatKitDB`, SavedVariablesPerCharacter `WarlockCombatKitCharDB`
  - Load order: Logic, Core
- `WCK.MergeDefaults(sv, defaults): table` (a copy of `WarlockUtilityKit/Logic.lua:16-23`).
- `WCK.On(event, fn)`, `WCK.inits`, `WCK.refreshers`, `WCK.Secret(v): bool`, `WCK.Print(...)`.
- `WCK.Refresh()`: debounced at 0.1s like `TackleBox/Core.lua:42-50`, and only runs when `WCK.active`.
- `DEFAULTS = {locked, shown, frames={}, minimapAngle, lastProbe}`, `CHAR_DEFAULTS = {}`.
- `WCK.Trace(event, detail)`: a 20-entry ring that always records SENT, SUCCEEDED, FAILED, INTERRUPTED, OVERLAY_GLOW_SHOW/HIDE, NAME_PLATE_UNIT_ADDED/REMOVED and the REGEN events, with secret flags.
- `WCK.Probe()`:
  - Uses TB's `P`/`Try`/`S` shape (`TackleBox/Core.lua:160-165`).
  - Sections:
    - `ctx`: instance type, combat
    - `units`: `UnitGUID`/`UnitName`/`GetRaidTargetIndex`/`UnitIsDead`/`UnitExists` on `target` and the first two `nameplateN`
    - `spell`: `C_Spell.IsSpellUsable`/`IsSpellInRange`/`GetSpellCooldown` for Shadow Bolt and Corruption
    - `secrets`: `C_Secrets.GetSpellAuraSecrecy(17941)`
    - `assisted`: `C_AssistedCombat.IsAvailable`/`GetRotationSpells`/`GetNextCastSpell`
    - `cleu`: `pcall` around registering `COMBAT_LOG_EVENT_UNFILTERED`
    - `plate`: create and hide a texture on `C_NamePlate.GetNamePlateForUnit("target").UnitFrame`
    - `loc`: `C_LossOfControl` on the target
    - `trace`: dump
- `/wck` subcommands: `probe`, `lock`, `reset`. The slash handler refuses non-warlocks, like WUK at `Core.lua:221-223`.

**Verify**:
- `lua5.1 WarlockCombatKit/tests/run.lua` prints "all tests passed" (MergeDefaults cases).
- In game:
  - The addon loads with no errors.
  - Run `/wck probe` in six contexts: out and in combat, each in the open world, a dungeon and a BG.
  - Cast Shadow Bolt, Corruption and Fear on two mobs, then `/wck probe` again so the trace is captured.
- Record the results in `probe-results.md`. **Gate**: re-read Phases 2-6 against those results, and adjust key order, conditions and toggles before continuing.

---

## Phase 2: Panel + cast map
Delivers a movable panel. Each enemy you cast on gets a row of spell icons that fade with age. Rows clear on death or despawn, otherwise when combat ends. Also adds the minimap button and a minimal settings window (show/lock).

**Files**: `Logic.lua`, `Core.lua`, `Data.lua` (new), `Panel.lua` (new), `Settings.lua` (new), `.toc`, `tests/run.lua`.
**Key changes**:
- `Data.lua`: `WCK.DATA.tracked = {name -> {kind="dot"|"curse"|"cc", stale=s}}`, covering the DoTs, curses, Banes, Fear, Banish, Seduction, Death Coil and Howl. Spell names are resolved to IDs at login with `C_Spell.GetSpellInfo`.
- Logic (all pure):
  - `WCK.NewCastMap(): map` with shape `{pending={}, rows={}}`.
  - `WCK.CastSent(map, castGUID, spell, key, label, now)`
  - `WCK.CastSucceeded(map, castGUID, now)`
  - `WCK.CastFailed(map, castGUID)`
  - `WCK.ClearRow(map, key)`, `WCK.ClearAll(map)`
  - `WCK.RowsView(map, now, tracked): {{key, label, mark, icons={{spell, age, alpha, kind}}}}`, sorted by most recent.
  - `WCK.IconAlpha(age, stale): number`
  - `WCK.EnemyKey(mark, guid, name): key, label`. Callers pass nil for secret values; the function picks mark, then GUID, then name, then `"target"`.
- Core:
  - SENT `(unit,target,castGUID,spellID)` → resolve the key from non-secret `target`-token reads → `CastSent`.
  - SUCCEEDED, FAILED and INTERRUPTED handlers by `castGUID`.
  - `NAME_PLATE_UNIT_REMOVED` or `UnitIsDead` → `ClearRow`, whichever Phase 1 proved.
  - `PLAYER_REGEN_ENABLED` → `ClearAll`.
  - A 0.5s ticker refreshes only while rows exist.
- Panel:
  - `WCKPanel` is moved with a `MakeMovable(f, "panel", x, y)` copy (`WarlockUtilityKit/UI.lua:13-26`).
  - The header holds a rim/disc placeholder core (`UI.lua:53-59,119-125`).
  - 8 pooled rows (`TackleBox/Panel.lua:112-138`), each with a mark icon, a label and 8 icons.
- Settings:
  - `WCKSettings` uses `BasicFrameTemplateWithInset` with Show and Lock checkboxes (`WarlockUtilityKit/Settings.lua:8-36`).
  - Minimap button: left-click opens settings, right-click toggles the panel (`Settings.lua:73-110`).

**Verify**:
- Tests cover:
  - pending→succeeded pairing, and failed casts being dropped
  - two casts in flight on different keys
  - `EnemyKey` fallbacks
  - `IconAlpha` bounds
  - `RowsView` ordering
- In game: on a pack of 3 mobs, mark two and DoT all three. Expect three rows with correct icons and fade. Rows clear after a kill or when combat ends. Shift+drag and lock work. No errors in a dungeon.

---

## Phase 3: CC highlight (+ optional nameplate marker)
Delivers a purple glow on cast-map rows that hold a CC spell. Behind a settings toggle (off by default), it also adds a marker on the enemy nameplate.

**Files**: `Logic.lua`, `Panel.lua`, `Core.lua`, `Settings.lua`, `tests/run.lua`.
**Key changes**:
- `WCK.RowHasCC(row, now, tracked): bool`. CC counts only while `age < stale`.
- `WCK.AddGlow`/`WCK.SetAlert`, copied from `WarlockUtilityKit/UI.lua:96-110`, applied to the row frame.
- `WCK.PlateMarker(unit, on)`: `pcall` around the texture on the nameplate UnitFrame. It hides itself if the probe flagged instances as blocked. Toggle: `db.plateMarker=false`.

**Verify**:
- Tests: `RowHasCC` is true while the Fear is fresh and false once it is stale.
- In game: Fear one mob and its row pulses. With the toggle on in the open world, the plate marker shows. In a dungeon there are no errors, and the marker is either suppressed or works as the probe showed.

---

## Phase 4: Proc alerts
Delivers proc icons in the panel header that pulse, with an optional sound, while Nightfall or another listed proc is active.

**Files**: `Data.lua`, `Core.lua`, `Panel.lua`, `Settings.lua`, `Logic.lua`, `tests/run.lua`.
**Key changes**:
- `WCK.DATA.procs = {17941}`. Users can add more through `db.procs`.
- `WCK.ProcState(active, spellID, on): active`, a pure set update.
- Core handles `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` and `HIDE` with spellID filtered by `Secret()`, then updates `WCK.procs`, calls `Refresh`, and plays a `PlaySound` if `db.procSound`.
- Panel: the header proc strip uses `SetAlert` pulse plus shine.
- If Phase 1 showed the event never fires, ship the feature disabled with a README note (design Decision 8).

**Verify**:
- Tests: `ProcState` adds and removes entries, and is idempotent.
- In game: on a Nightfall proc, the icon pulses (and the sound plays if enabled). It hides when the proc is consumed.

---

## Phase 5: Rotation helper
Delivers the next-spell icon in the header core. It comes from a user-edited, ordered rule list, with an optional Assisted Combat fallback.

**Files**: `Logic.lua`, `Core.lua`, `Panel.lua`, `Settings.lua`, `tests/run.lua`.
**Key changes**:
- `WCK.char.rules = {{spell, cond="always"|"ready"|"notRecent"|"proc"|"marked"[|"usable"], n}}`. The default rules are a small Affliction list.
- `WCK.EvalRules(rules, state): spell|nil`. `state = {ready={[spell]=bool}, usable={}, lastOnTarget={[spell]=age}, procs={}, marked=bool}` (pure).
- `WCK.BuildRuleState(now)` in Core reads only non-secret values (cooldown `isActive`, the cast map for the current target key, `WCK.procs`, the mark).
- Fallback: `db.assistedFallback` → `pcall(C_AssistedCombat.GetNextCastSpell)`.
- Settings rule editor:
  - Pooled rows, each with a spell dropdown, a condition dropdown, an N edit box (for `notRecent`), and up/down/delete buttons, plus an Add button.
  - Writes `WCK.char.rules` and calls `Refresh`.
  - `WCK.MoveRule(rules, i, dir)` is pure.
- Core icon desaturates when no rule matches.

**Verify**:
- Tests: priority order, each condition passing and failing, `notRecent` boundary, an empty list returning nil, and `MoveRule` edge cases.
- In game: rule order changes the icon, the icon updates in combat, and nothing is cast automatically.

---

## Phase 6: Mouseover click-cast slots
Delivers 6 key-bindable slots in Blizzard's Key Bindings menu. Each slot casts its spell with `[@mouseover,harm,nodead]`, falling back to the target.

**Files**: `Bindings.xml` (new; auto-loaded, not listed in the `.toc`), `Actions.lua` (new), `Logic.lua`, `Settings.lua`, `.toc`, `tests/run.lua`.
**Key changes**:
- `Bindings.xml`: six `<Binding name="CLICK WCKCast<n>:LeftButton" header="WCK">` entries. Globals `BINDING_HEADER_WCK` and `_G["BINDING_NAME_CLICK WCKCast<n>:LeftButton"]` are set in `Actions.lua`.
- `WCK.CastMacro(spell): string` returns `"/cast [@mouseover,harm,nodead][] "..spell`, or `""` when there is no spell (pure).
- `Actions.lua`:
  - Hidden `WCKCast1..6` buttons using `SecureActionButtonTemplate`, parented to a plain `WCKActionHolder` (as in `TackleBox/Actions.lua:3,39-42`).
  - `type=macro`; `macrotext` is applied only when `not InCombatLockdown()` and is recomputed in a refresher.
- `WCK.char.slots = {[1..6]=spell}`. Settings show 6 spell dropdowns, each with its current key from `GetBindingKey`.

**Verify**:
- Tests: `CastMacro` with a spell, with nil, and with a spell name that has a rank or a space.
- In game: bind slot 1 to a key, set it to Corruption, and hover a nameplate that isn't your target. The key casts on that mob. Changing the slot spell in combat takes effect after combat ends.

---

## Phase 7: Release docs
Delivers README feature and usage docs, a CHANGELOG `## [0.1.0]` entry, and confirms the version. CI publishes `wck-v0.1.0`.

**Files**: `README.md`, `CHANGELOG.md`, `.toc`, root `README.md`.
**Verify**: tests pass. The CI run on the main push creates the `wck-v0.1.0` release with a zip that excludes `tests/`.

## Testing Checkpoints
1. **After Phase 1**: the addon loads, `/wck probe` output is saved, `probe-results.md` is written, the gate review is done, and CI is green.
2. **After Phase 2**: the multi-mob cast map works and clears correctly, and the panel can be moved and locked.
3. **After Phase 3**: CC rows pulse, and the nameplate marker is opt-in and error-free in instances.
4. **After Phase 4**: the Nightfall proc pulses, or the feature is documented as disabled.
5. **After Phase 5**: the rule list drives the core icon, and the editor saves per character.
6. **After Phase 6**: the bound keys cast on mouseover, and their attributes update only out of combat.
7. **After Phase 7**: `wck-v0.1.0` is released.

Phases 3-6 each depend only on Phase 2 (Phase 5's `notRecent` uses the cast map). They can be reordered once the Phase 1 results are in.
