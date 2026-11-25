# Design Discussion

## Current State
- `TB.Flash()` (`TackleBox/CastBar.lua:54`) plays a fixed blue full-screen vignette. The colour is set once at creation (`CastBar.lua:29`), and the texture is a closure local, so callers cannot change it.
- Two callers, both gated by `TB.db.flash`:
  - Got-away miss: `Core.lua:236-241`, 1s after a fishing `CHANNEL_STOP` with no loot. Increments `TB.session.misses` and flashes.
  - Pool detector: `Core.lua:152-158`, never in combat, once per pool per 60s through `TB.ShouldAlert`.
- Lure state is read only as `(GetWeaponEnchantInfo())`, the 1st return "main hand has temp enchant", inside the fishing-bar refresher (`Actions.lua:195-196`). Nothing remembers the previous state, so nothing notices a lure disappearing.
- Pole check exists as a file-local `PoleEquipped()` (`Actions.lua:166-171`): slot 16 item, class 2 / subclass 20.
- `TB.Refresh()` (`Core.lua:44-53`) runs on `UNIT_INVENTORY_CHANGED` (player) (`Core.lua:69`), `UNIT_AURA`, bag events and others. Debounced 0.1s.
- TackleBox has no sound and no centre-screen text. Its only output is `TB.Print` chat (`Core.lua:6`).
- The repo sound pattern is in WarlockCombatKit: `PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")` on a newly appeared proc only (`WarlockCombatKit/Core.lua:145-146`).

## Desired End State
1. A fish getting away no longer flashes the screen. The "got away" counter and panel text stay (`Core.lua:238`, `Panel.lua:252`).
2. When a lure on the equipped fishing pole wears off, and the same pole is still in the main hand, TackleBox:
   - shows big centre text through `RaidNotice_AddMessage(RaidWarningFrame, "Lure expired: reapply", ...)`;
   - prints a `TB` chat line;
   - flashes the screen edge **amber** (only if `/tb flash` is on), clearly different from the blue pool flash;
   - plays `SOUNDKIT.RAID_WARNING` (fallback 8959) on the "Master" channel.
3. `/tb lure` toggles the whole alert (default on). `/tb flash` still governs any flash, now only pool alerts and the lure alert.
4. The alert fires once per expiry. Swapping the pole off, equipping a different pole, or logging in without a lure does not fire it.

Verify:
- `tests/run.lua` cases for the pure expiry predicate.
- In game:
  - apply Shiny Bauble, wait out its duration (or right-click cancel is not available, so wait), and see text, amber flash and sound once;
  - miss a fish and see no flash, but the count still goes up;
  - swap to weapons with a lure up and see no alert;
  - `/tb lure` off gives no alert.

## Patterns to Follow
- **Pure logic in `Logic.lua` plus tests in `tests/run.lua`**: an `eq(...)` case for each branch (`tests/run.lua:6-8`). WoW calls stay in Core/Actions. Model on `TB.ShouldAlert` (`Logic.lua:295-299`) and `TB.IsMiss` (`Logic.lua:147`).
- **Edge detection with stored previous state**: WCK `NewProcs(WCK.procs, up)`, then `WCK.procs = up` (`WarlockCombatKit/Core.lua:145-148`).
- **Event bus**: `TB.On(event, fn)` (`Core.lua:9-12`). Lure-check hook goes through `TB.Refresh`/refreshers, which already fire on `UNIT_INVENTORY_CHANGED`.
- **Init pattern**: frames and tickers are created in `TB.inits` (`Core.lua:55-59`, `CastBar.lua:5`).
- **Settings**: a new key in `DEFAULTS` (`Core.lua:19`) is filled by `MergeDefaults`, so no `version` bump is needed (comment `Core.lua:17`). Toggle style is `TB.db.x = not TB.db.x; TB.Print(...)` (`Core.lua:432-434`). Help line uses `||` (`Core.lua:451`).
- **Forever value guards**: `TB.Secret(v)` before using values that may be secret (`Core.lua:5`). Wrap `GetWeaponEnchantInfo` reads defensively.
- **Sound**: `PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")` exactly as WCK does (`WarlockCombatKit/Core.lua:146`).
- **Docs**: README feature section and slash table (`README.md:64-66`, `:94`), CHANGELOG `## [x.y.z] — date` / `### Added` / `### Changed` (`CHANGELOG.md:3-12`), TOC `## Version` bump.

Do NOT follow:
- Don't add a WCK-style Settings checkbox panel (`WarlockCombatKit/Settings.lua:50-53`). TackleBox is slash-only.
- Don't build a parallel unconditional ticker that calls `TB.Refresh()` every second. Existing tickers are state-gated (`Core.lua:83-87, 221-223`).

## Design Decisions
1. **Detection = on/off edge, not expiry timer**:
   - Remember `{ item = slot-16 itemID, lure = hasMainHandEnchant }`. Fire when the previous state had a lure and the current one does not, on the same item, and that item is a pole.
   - Why: needs only the 1st return of `GetWeaponEnchantInfo`, which is already used on Forever (`Actions.lua:196`). The expiry-ms return and secret status are unverified (research Open Areas).
2. **Pure predicate `TB.LureExpired(prev, cur)` in `Logic.lua`**:
   - `prev`/`cur` = `{ item, pole, lure }`. Returns true only when `prev.lure and not cur.lure and cur.pole and prev.item == cur.item`.
   - A nil `prev` (first read after login) returns false.
   - Tested in `tests/run.lua`.
3. **When it is checked**:
   - In the existing refresher path (`TB.Refresh`), which already runs on `UNIT_INVENTORY_CHANGED` (`Core.lua:69`).
   - Also register `WEAPON_ENCHANT_CHANGED` (`TB.On`) as a cheap extra trigger. It is in the Forever index; registering an event that never fires is harmless.
   - Backup: a 5s ticker that only reads state while the last-known state has a lure on a pole. Reading costs one `GetWeaponEnchantInfo` + `GetInventoryItemID` call, with no full Refresh. It covers the case where no event fires on expiry.
4. **Pole still equipped, combat allowed**: the alert fires in combat. `RaidNotice_AddMessage`, `PlaySound` and the flash animation are not protected. The alert does not wait for combat to end.
5. **Notification = raid-warning text + chat line**:
   - `RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])` plus `TB.Print(msg)`.
   - `ChatTypeInfo` and `RaidWarningFrame` are present in Forever std (research Q5).
6. **Flash colour per call**:
   - Keep the texture as `flash.tex`. `TB.Flash(r, g, b)` sets `SetVertexColor(r or 0.3, g or 0.6, b or 1)` and plays.
   - Pool alert keeps the default blue. Lure alert passes amber `(1, 0.65, 0.1)`. Desaturation already handles the red base art (`CastBar.lua:28-29`).
7. **Remove got-away flash**: delete the `if TB.db.flash then TB.Flash() end` line at `Core.lua:239`. Keep the miss counting and `TB.Refresh()`.
8. **Settings**:
   - `DEFAULTS.lureAlert = true`; `/tb lure` toggles it.
   - The flash part also requires `TB.db.flash`. Text, chat and sound depend only on `lureAlert`.
   - `/tb flash` help and README text change to "pool and lure alerts".
9. **Release**: minor bump to 1.4.0, with CHANGELOG Added (lure alert) and Changed (got-away no longer flashes).

## What We're NOT Doing
- No "expiring soon" warning or countdown. That needs the expiry return, which is unverified.
- No lure-ID check (any temp enchant on the pole counts, matching the current `PickLure` behaviour at `Logic.lua:198`).
- No auto-reapply. The lure button stays player-clicked (secure, `Actions.lua:2`).
- No separate sound toggle, no options panel, no configurable colour or sound.
- No off-hand enchant tracking.
- No change to pool-alert behaviour beyond keeping its blue flash.

## Open Risks
- **Unequip read glitch**: during a pole swap, `GetWeaponEnchantInfo` may briefly report no enchant while slot 16 still reports the pole (or the reverse). The same-item check and debounced Refresh should absorb it. Confirm in game.
- **Event coverage**: if neither `UNIT_INVENTORY_CHANGED` nor `WEAPON_ENCHANT_CHANGED` fires on expiry, the 5s ticker catches it, so the alert can lag up to 5s.
- **Secret values**: `GetWeaponEnchantInfo` 1st return could be secret in some state (e.g. combat). Guard with `TB.Secret` and treat a secret value as "unknown". Skip the update and keep the previous state.
- **`RaidNotice_AddMessage` signature** is not documented in the skill. If it errors on Forever, fall back to `UIErrorsFrame:AddMessage(msg, 1, 0.65, 0.1)`. Wrap the call in pcall.
- **`SOUNDKIT.RAID_WARNING`** may be nil on Forever. The `or 8959` fallback covers it, the same as in WCK.
