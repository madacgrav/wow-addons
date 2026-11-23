# Research Findings

## Q1: How does the rotation bar refresher decide each button's visual state, and what does `WCK.ButtonLook` take and return?

### Findings
- Two refreshers in `WarlockCombatKit/Rotation.lua`:
  - Secure layout refresher `Rotation.lua:57-77`: runs only out of combat (`Rotation.lua:58`); assigns `b.spell`, `macrotext`, icon texture, and position per entry from `WCK.BarSpells` (`Rotation.lua:59-73`).
  - Highlight refresher `Rotation.lua:80-89`: runs every refresh, in combat too ("textures only", `Rotation.lua:79`).
- Per bar button in the highlight refresher:
  - `look = WCK.ButtonLook(b.spell, WCK.next, WCK.procs, WCK.DATA.procs)`, or `{dim=false, fel=false}` when the button has no spell (`Rotation.lua:84`).
  - `b.icon:SetDesaturated(look.dim)` and `b.icon:SetAlpha(look.dim and 0.6 or 1)` (`Rotation.lua:85`). The comment there says buttons are never `Disable()`d, so grey buttons still cast.
  - Purple pulse glow: `WCK.SetAlert(b, b.spell ~= nil and b.spell == WCK.next)` (`Rotation.lua:86`).
  - Fel-green proc glow on the child frame `b.fel`: `WCK.SetAlert(b.fel, look.fel and WCK.db.procAlerts)` (`Rotation.lua:87`).
- The core Life Tap button glows when `WCK.next == WCK.DATA.core` (`Rotation.lua:82`). Its icon is never desaturated by this refresher.
- `WCK.ButtonLook(spell, nextSpell, procs, procList)` is at `Logic.lua:175-179`:
  - `fel` is true if any `procList` entry has `p.spell == spell` and `procs[p.key]` is truthy.
  - It returns `{ dim = spell ~= nextSpell and not fel, fel = fel }`.
  - It's a pure function with no WoW API calls, no cooldown input, and no usable input.
- Button construction (`Rotation.lua:38-53`):
  - `b.rim` is a BACKGROUND colour texture.
  - `b.icon` is ARTWORK.
  - `WCK.AddGlow(b)` adds the purple glow.
  - `b.fel` is a child frame with its own `AddGlow`, tinted `(0.45, 1, 0.3)`.
- `WCK.AddGlow` / `WCK.SetAlert` are at `Panel.lua:29-43`. The glow is an OVERLAY texture at 1.8× size with an `ADD` blend, plus a looping alpha bounce. `SetAlert` early-outs when the state is unchanged (`Panel.lua:40`).

## Q2: How is per-spell cooldown/usability data gathered, which spells are covered, how is GCD treated, and what happens on secret/erroring values?

### Findings
- `WCK.BuildRuleState(now)` is at `Core.lua:179-200`. It returns `{known, ready, usable, lastOnTarget, proc, marked}`.
- Coverage: it loops only over `WCK.RuleSpells(WCK.char.rules)` (`Core.lua:181`), and only spells present in `WCK.spellSet` (`Core.lua:182`).
  - The fixed tail spells `WCK.DATA.tail = {"Shadow Bolt","Fear","Banish"}` (`Data.lua:20`) appear on the bar via `BarSpells` (`Logic.lua:162-173`) but get no `ready`/`usable` entry unless a rule also names them.
  - The default rules include Shadow Bolt (`Data.lua:26`) but not Fear or Banish.
- Cooldown:
  - `pcall(C_Spell.GetSpellCooldown, name)` (`Core.lua:184`).
  - It's only stored if `cd.isActive` and `cd.isOnGCD` are both non-secret (`Core.lua:185`).
  - `s.ready[name] = not cd.isActive or cd.isOnGCD == true` (`Core.lua:186`). The comment says "GCD alone does not block", so a spell that is only on the GCD counts as ready.
  - On a pcall error, a nil `cd`, or secret fields, `ready[name]` stays `nil`.
- Usable:
  - Gated by `WCK.USABLE_OK = true` (`Core.lua:151`). The comment there says probe run 1 found `IsSpellUsable` non-secret in combat in the open world.
  - `pcall(C_Spell.IsSpellUsable, name)`. Only the first return is stored, when it isn't secret (`Core.lua:189-190`).
- Consumer: `WCK.EvalRules` (`Logic.lua:114-119`) treats `state.ready[r.spell] ~= false` as passing, so `nil` (unknown or secret) does not block a rule.
- Results are stored globally as `WCK.ruleState` and `WCK.next` by the refresher at `Core.lua:202-205`. The comment there says it runs after the proc refresher and before the panel's.
- Secret helper: `WCK.Secret(v)` = `issecretvalue ~= nil and issecretvalue(v)` (`Core.lua:5`).
- Debug probe `Core.lua:290-299` prints `IsSpellUsable` (usable/noMana), `IsSpellInRange`, and cooldown `isActive`/`isOnGCD`/`isEnabled`/`startTime` for Shadow Bolt and Corruption.

## Q3: What triggers `WCK.Refresh`, and does anything refresh when a cooldown expires?

### Findings
- `WCK.Refresh` (`Core.lua:35-42`) is debounced. One `C_Timer.After(0.1)` runs all `WCK.refreshers` in registration order, and it's inactive until `WCK.active` (warlock only, `Core.lua:44-50`).
- Event triggers:
  - `PLAYER_LOGIN` (`Core.lua:49`)
  - `PLAYER_REGEN_ENABLED` (`Core.lua:51`)
  - `UNIT_AURA` (player) (`Core.lua:146`)
  - `SPELL_UPDATE_USABLE` (`Core.lua:147`)
  - `PLAYER_TALENT_UPDATE` (`Core.lua:148`)
  - `SPELL_UPDATE_COOLDOWN` (`Core.lua:207`)
  - `PLAYER_TARGET_CHANGED` (`Core.lua:208`)
  - `RAID_TARGET_UPDATE` (`Core.lua:209`)
  - `SPELLS_CHANGED` (`Core.lua:221`)
  - `UNIT_SPELLCAST_SUCCEEDED` (player) (`Core.lua:234`, `239`)
  - `NAME_PLATE_UNIT_REMOVED` (dead) (`Core.lua:249`)
- Settings changes also call it (`Settings.lua:33,55,105,134-143,193`) and the `/wck show|hide` command does too (`Core.lua:369`).
- Timer: `C_Timer.NewTicker(0.5)` at `Core.lua:253-261` calls `WCK.Refresh()` every 0.5 s, but returns early when `WCK.map.rows` is empty (`Core.lua:254`). So it only ticks while the cast map holds rows.
- There is no handler or timer keyed to a specific cooldown's end time.
  - In the Blizzard client, `SPELL_UPDATE_COOLDOWN` generally fires on cooldown start and on GCD changes. Whether it fires on expiry in Forever is not verified in this repo.
  - The 0.5 s ticker covers expiry only while cast-map rows exist.
  - `PLAYER_REGEN_ENABLED` clears the map (`Core.lua:251`), so after combat the ticker idles.

## Q4: How do the offline tests exercise `ButtonLook`, `BuildRuleState` and the rotation bar, and how are cooldown/usable APIs stubbed?

### Findings
- `tests/run.lua` (116 lines) loads only `Data.lua` and `Logic.lua` (`tests/run.lua:3-4`). It doesn't use wowmock or WoW API stubs, and it doesn't load `Core.lua`, `Rotation.lua` or `Panel.lua`.
- `ButtonLook` cases at `tests/run.lua:110-114`:
  - suggested → `dim=false`
  - non-suggested → `dim=true` ("others grey")
  - proc on Shadow Bolt → `fel=true, dim=false`
  - proc doesn't apply to Fear
  - no suggestion → `dim=true` ("no suggestion: all grey")
- `BarSpells` cases at `tests/run.lua:98-105`.
- `BuildRuleState` is untested: it lives in `Core.lua` and calls `C_Spell` directly.
- `C_Spell.GetSpellCooldown` / `IsSpellUsable` aren't stubbed anywhere in the tests.
- `EvalRules` gets its `state` table built by hand in the tests (the earlier phases of `run.lua`). The exact lines weren't re-read for this question.

## Q5: What patterns elsewhere in WCK and WUK express "unavailable" vs. "suggested" on icons, and are they documented?

### Findings
- WCK panel proc orbs (`Panel.lua:193-199`): `SetAlpha(on and 1 or 0.3)`, `SetDesaturated(not on)`, plus `SetAlert(b, on)`, and a `shine` pop on the off→on edge.
- WCK panel core icon is desaturated when the core spell isn't in the spellbook: `f.core:SetDesaturated(not WCK.spellSet[WCK.DATA.core])` (`Panel.lua:193`).
- WUK ring stones: `b.icon:SetDesaturated(c[kind] == 0)` means grey when you hold none (`WarlockUtilityKit/UI.lua:360`).
  - The glow (`WUK.SetAlert`) means "missing and you can make it" (`UI.lua:361`).
  - `shine` plays on the 0→>0 edge (`UI.lua:363`).
- WUK armor/pet buttons:
  - grey when the buff or pet is already up, glow when it's missing (`WarlockUtilityKit/Prep.lua:16-18`, `39-42`).
  - So grey means "nothing to do", and glow means "do this".
- WUK view spell buttons (`Prep.lua:58-80`): texture and macro only, with no desaturation or glow.
- WUK `AddGlow`/`SetAlert` (`WarlockUtilityKit/UI.lua:253-267`) are identical in shape to WCK's (`Panel.lua:29-43`).
- Docs:
  - `WarlockCombatKit/README.md:75` says the suggested button pulses purple and stays in colour, every other button is greyed, and grey buttons still cast.
  - `README.md:76` covers the fel glow during Nightfall.
  - `README.md:53-57` says a rule passes when the spell is known and off cooldown.
  - `CHANGELOG.md:12` (0.2.0) has the same greyed-out wording.
  - The TOC is at `## Version: 0.2.0` (`WarlockCombatKit.toc:4`).

## Cross-Cutting Observations
- Refreshers run in file/TOC order. The `WCK.next` producer (`Core.lua:202`) runs before the Rotation highlight refresher, so `ButtonLook` sees the current `WCK.next`.
- The split between secure and texture-only work is consistent:
  - Secure attributes and layout change only out of combat (`Rotation.lua:58`, `Actions.lua:16`).
  - Icon desaturation, alpha and glow change any time.
- WoW API reads are guarded the same way everywhere: `pcall`, then `WCK.Secret` checks, with a fall back to `nil`/"keep last good" (`Core.lua:169`, `184-190`, `111`).
- The project tests pure `Logic.lua` functions offline and leaves WoW API glue in `Core.lua`/UI files untested.

## Open Areas
- Whether `SPELL_UPDATE_COOLDOWN` fires on cooldown expiry in the Forever client: there's no probe result recorded in the repo.
- Whether `C_Spell.GetSpellCooldown` fields are secret in combat inside instances. The guard exists, but the probe notes cover only the open world (`Core.lua:151`, usable only).
- Behaviour when a rule spell isn't in `spellSet`: it's absent from `BuildRuleState`, but it can still appear on the bar? `BarSpells` adds rule spells without a `known` check (`Logic.lua:165-167`); only tail spells are filtered by `known`.
