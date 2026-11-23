# Design Discussion

## Current State
- Rotation bar highlight refresher greys every button that is not `WCK.next`: `SetDesaturated(look.dim)` + `SetAlpha(0.6)` (`WarlockCombatKit/Rotation.lua:85`).
- `WCK.ButtonLook(spell, nextSpell, procs, procList)` returns `{dim = spell ~= nextSpell and not fel, fel}` — no cooldown input (`Logic.lua:175-179`).
- Suggested spell already gets purple pulse via `SetAlert(b, b.spell == WCK.next)` (`Rotation.lua:86`); Nightfall fel glow on `b.fel` (`Rotation.lua:87`).
- Cooldown reads exist only for rule spells in `BuildRuleState` (`Core.lua:179-200`); tail spells Shadow Bolt/Fear/Banish (`Data.lua:20`) get none unless a rule names them.
- `ready` = `not isActive or isOnGCD` — GCD alone counts as ready (`Core.lua:186`); secret/error leaves `nil` (`Core.lua:185`).
- No refresh scheduled at cooldown end; 0.5 s ticker only runs while cast map has rows (`Core.lua:253-254`).
- Tests: pure `Logic.lua` only (`tests/run.lua:3-4`); `ButtonLook` cases assert grey-when-not-suggested (`tests/run.lua:110-114`).
- Docs describe greying: `README.md:75`, `CHANGELOG.md:12`; version 0.2.0 (`WarlockCombatKit.toc:4`).

## Desired End State
- Bar buttons show full colour by default.
- A button greys (desaturate + 0.6 alpha, same look as today) only while its spell is on a real cooldown (not GCD-only).
- Suggested spell marked by purple pulse only; fel glow for Nightfall unchanged.
- Covers every bar button, including tail spells.
- Button returns to colour when the cooldown ends, without needing another unrelated event.
- Secret/unknown cooldown = normal colour.

Verify:
- Offline: `ButtonLook` tests updated — not-suggested + ready = colour; on cooldown = grey; on cooldown + suggested still grey with glow? (see Decision 5); unknown = colour. New pure helper test for cooldown-end computation.
- In game: cast Fear/Death Coil/Howl — button greys for the cooldown, returns at expiry; Shadow Bolt never greys from GCD; suggested spell pulses while others stay coloured.

## Patterns to Follow
- Pure logic in `Logic.lua`, tested in `tests/run.lua` without WoW stubs (`tests/run.lua:3-4`, `Logic.lua:175`).
- WoW API reads in `Core.lua` guarded by `pcall` + `WCK.Secret`, falling back to `nil` (`Core.lua:184-190`, `Core.lua:5`).
- Texture-only changes in the highlight refresher, safe in combat; secure attributes only out of combat (`Rotation.lua:57-58`, `79-89`).
- Refresh through debounced `WCK.Refresh()` (`Core.lua:35-42`), never call refreshers directly.
- Producer refresher before consumer: cooldown map built in `Core.lua` file scope, consumed by `Rotation.lua` refresher (TOC order, `Core.lua:202`).
- Never `Disable()` bar buttons — grey still casts (`Rotation.lua:85` comment).
- Don't follow: `BuildRuleState`'s GCD-as-ready is fine for rules but the map must keep the same GCD rule explicitly, not reuse `ruleState.ready` (rule-only coverage).

## Design Decisions
1. **Grey rule**: real cooldown only — `isActive and not isOnGCD`. Mana, range, reagents ignored. User asked for "cannot be used (on cooldown)".
2. **Data source**: new cooldown map `WCK.onCD[spell] = true` built over every bar spell (rules + known tail), separate from `BuildRuleState`. Rule state untouched. Keeps `ButtonLook` pure: takes `onCD` boolean (or map).
3. **Expiry refresh**: when a read gives non-secret `startTime`/`duration` for an active non-GCD cooldown, schedule one `C_Timer.After(remaining + small pad, WCK.Refresh)`. Debounce means duplicate timers are cheap; track earliest scheduled end to avoid piling timers. Secret timing = no timer, rely on events.
4. **Unknown = colour**: secret or pcall error leaves spell out of `onCD`, so it draws normally. Mirrors `EvalRules` `ready ~= false` (`Logic.lua:117`).
5. **Suggested-but-on-cooldown**: can't really happen (`EvalRules` skips `ready == false`), but if it does, grey + glow both apply — cooldown wins the colour, glow still shows. No special case.
6. **Release**: bump to 0.2.1 (behaviour change, no new feature), update `README.md:75` and add CHANGELOG entry.

## What We're NOT Doing
- No cooldown swipe/spiral (`Cooldown` frame) or countdown text.
- No mana/range/reagent greying.
- No change to rule evaluation, `BuildRuleState`, or `EvalRules`.
- No change to Life Tap core button, panel proc orbs, or WUK.
- No option toggle for old "grey others" behaviour.
- No new events beyond what's registered; no permanent ticker.

## Open Risks
- `C_Spell.GetSpellCooldown` `startTime`/`duration` may be secret in combat or instances; then expiry relies on `SPELL_UPDATE_COOLDOWN` firing on end (unverified on Forever). Worst case: button stays grey until next refresh event (cast, aura, target change) — common in combat.
- `isOnGCD` may be nil on some clients; treat `isOnGCD == true` as GCD, else real cooldown — a short CD equal to GCD length could flicker grey briefly.
- Bar spell list is built out of combat (`Rotation.lua:58`); cooldown map must iterate the same list each refresh — use `b.spell` of shown buttons or `BarSpells` output, not rules alone.
