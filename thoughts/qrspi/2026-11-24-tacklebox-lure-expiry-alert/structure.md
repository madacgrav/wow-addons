# Structure Outline

## Approach
Stop flashing on a got-away miss and give `TB.Flash` a colour argument. Then add an edge-detected lure-expired alert: a pure predicate in `Logic.lua` with tests, state tracking in `Core.lua` on Refresh + `WEAPON_ENCHANT_CHANGED` + a gated 5s ticker, and an alert made of raid-warning text, chat line, amber flash and sound behind `/tb lure`. Docs and a 1.4.0 release last.

## Phase 1: Quiet misses, coloured flash
Got-away no longer flashes. `TB.Flash` takes an optional colour; pool alerts stay blue (default).

**Files**: `TackleBox/CastBar.lua`, `TackleBox/Core.lua`
**Key changes**:
- `CastBar.lua`: keep the vignette texture as `flash.tex` (was a closure local, `:27`).
- `TB.Flash(r?: number, g?: number, b?: number)`: modified. Sets `flash.tex:SetVertexColor(r or 0.3, g or 0.6, b or 1)`, then stops and plays as before (`:54`).
- `Core.lua:239`: delete `if TB.db.flash then TB.Flash() end`. `misses` increment and `TB.Refresh()` stay.
- `Core.lua:156` pool alert: unchanged call `TB.Flash()`, so blue.

**Verify**: `lua TackleBox/tests/run.lua` passes. luacheck is clean. In game:
- miss a cast: "got away" count goes up, no flash;
- hover a pool: blue flash still shows;
- the colour argument is checked in Phase 2, where the amber lure flash first uses it.

---

## Phase 2: Lure-expired alert
When the lure on the equipped pole wears off with the same pole still in hand, show centre text, a chat line, an amber flash (if `/tb flash`) and the raid-warning sound. `/tb lure` toggles it.

**Files**: `TackleBox/Logic.lua`, `TackleBox/tests/run.lua`, `TackleBox/Core.lua`, `TackleBox/Actions.lua`
**Key changes**:
- `LureState { item: number|nil, pole: boolean, lure: boolean }`: new shape (plain table).
- `TB.LureExpired(prev: LureState|nil, cur: LureState): boolean`: new, pure (`Logic.lua`). True only when `prev and prev.lure and not cur.lure and cur.pole and prev.item == cur.item`.
- `tests/run.lua`: new section "Lure alert" with cases:
  - nil prev;
  - lure on to off on the same pole (true);
  - off to off;
  - on to on;
  - item changed;
  - not a pole.
- `Actions.lua:166`: rename local `PoleEquipped` to `TB.PoleEquipped()` so Core can use it (the existing caller at `:179` is updated).
- `Core.lua`:
  - `DEFAULTS.lureAlert = true` (`:19`). No version bump (MergeDefaults fills it).
  - `TB.ReadLureState(): LureState|nil`: new. Reads slot 16 `GetInventoryItemID`, `TB.PoleEquipped()` and the 1st return of `GetWeaponEnchantInfo()`. Returns nil if that value is secret (`TB.Secret`), meaning unknown.
  - `TB.CheckLure()`: new. Reads the state; when it is nil, returns and keeps the old state. If `TB.db.lureAlert` and `TB.LureExpired(TB.lureState, cur)`, calls `TB.LureAlert()`. Then `TB.lureState = cur`.
  - `TB.LureAlert()`: new. Msg "Lure expired: reapply".
    - `pcall(RaidNotice_AddMessage, RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])`, falling back to `UIErrorsFrame:AddMessage(msg, 1, 0.65, 0.1)` on failure;
    - `TB.Print(msg)`;
    - `if TB.db.flash then TB.Flash(1, 0.65, 0.1) end`;
    - `PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")`.
  - Wiring:
    - `table.insert(TB.refreshers, TB.CheckLure)`;
    - `TB.On("WEAPON_ENCHANT_CHANGED", TB.CheckLure)`;
    - an init `C_Timer.NewTicker(5, ...)` that calls `TB.CheckLure()` only while `TB.lureState and TB.lureState.lure and TB.lureState.pole`.
  - Slash: `elseif cmd == "lure" then TB.db.lureAlert = not TB.db.lureAlert; TB.Print("lure alert " .. on/off)`. Add `lure` to the help line (`:451`).

**Verify**: `lua TackleBox/tests/run.lua` passes with the new cases. luacheck is clean. Deploy to `_forever_\Interface\AddOns`. In game:
- apply Shiny Bauble, let it expire: centre text, chat line, amber flash and sound, once;
- lure up, swap to weapons: no alert;
- `/tb lure` off, then expire: no alert;
- `/tb flash` off: text and sound but no flash;
- `/reload` with no lure: no alert.

---

## Phase 3: Docs and 1.4.0 release
**Files**: `TackleBox/README.md`, `TackleBox/CHANGELOG.md`, `TackleBox/TackleBox.toc`
**Key changes**:
- README:
  - rename "Cast bar and 'got away' flash" (`:64-66`) to describe the counter only;
  - add a "Lure expired alert" section;
  - slash table: add `/tb lure`, and `/tb flash` now reads "pool and lure alerts" (`:94`).
- CHANGELOG `## [1.4.0] — <date>`:
  - Added: lure-expired alert and `/tb lure`.
  - Changed: got-away no longer flashes; the flash is now amber for lures and blue for pools.
- TOC `## Version: 1.4.0`.

**Verify**: README, help text and slash parser agree (`/tb` with a bad argument prints a help line that includes `lure`). Tests still pass.

## Testing Checkpoints
- **After Phase 1**: misses count but don't flash; pool flash is blue; `TB.Flash(r,g,b)` exists. Tests pass.
- **After Phase 2**:
  - `TB.LureExpired` is tested;
  - the lure alert fires once on expiry with the pole still equipped, and is silent on a swap, a reload, or with `/tb lure` off;
  - `TB.lureState` holds the last known state.
- **After Phase 3**: docs and version say 1.4.0; ready for a `tb-v1.4.0` tag.
