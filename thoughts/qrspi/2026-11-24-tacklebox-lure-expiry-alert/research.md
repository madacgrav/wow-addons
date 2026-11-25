# Research Findings

## Q1: Call sites of `TB.Flash()`, gating, and how `TBFlash` is built

### Findings
- `TB.Flash()` defined `TackleBox/CastBar.lua:54`: `flash.anim:Stop(); flash.anim:Play()`. Takes no arguments.
- Two call sites, both gated by `TB.db.flash`:
  - Pool detector `TackleBox/Core.lua:152-158` (`Alert(name)`): returns early unless `TB.active`, `TB.db.detect`, and not `InCombatLockdown()`. `TB.ShouldAlert(TB.alerts, name, GetTime(), 60)` limits it to once per pool per 60s. Prints `<name> nearby`, then `if TB.db.flash then TB.Flash() end` (`Core.lua:156`). Callers: `GameTooltip` OnShow hook `Core.lua:159-163` and `PLAYER_SOFT_INTERACT_CHANGED` `Core.lua:165-168`.
  - Got-away miss `TackleBox/Core.lua:230-242`: on `UNIT_SPELLCAST_CHANNEL_STOP` for a fishing spell, stops the cast bar and reel mode, then `C_Timer.After(1, ...)`. Inside it, `TB.IsMiss(stopT, TB.lastLootT)` (`Logic.lua:147`), `TB.session.misses + 1`, `if TB.db.flash then TB.Flash() end` (`Core.lua:239`), `TB.Refresh()`. No combat check on this path.
- `TBFlash` frame built in an init `TackleBox/CastBar.lua:24-34`:
  - Frame `TBFlash` covers all of `UIParent`, strata `FULLSCREEN_DIALOG`, mouse disabled (`:25-26`).
  - One texture (`:27-29`): `Interface\FullScreenTextures\LowHealth`, `SetDesaturated(true)`, blend `ADD`, `SetVertexColor(0.3, 0.6, 1)` (blue). Comment `:28` notes the art is red, so it is desaturated before tinting.
  - Frame alpha starts at 0 and stays shown (`:30`).
  - Animation group `:31-34`: alpha 0 to 0.8 over 0.15s, then 0.8 to 0 over 0.6s.
- Texture is a local inside the init closure. Only `flash` (file-local `CastBar.lua:2`) and `flash.anim` are reachable from outside. Color is fixed at creation. No per-call color parameter exists today.
- `/tb flash` toggles `TB.db.flash` (`Core.lua:432`). Default `flash = true` (`Core.lua:19`). Help text `Core.lua:451`. README `TackleBox/README.md:64-66` and `:94` say the setting covers both got-away and pool alerts.
- Panel shows the miss count: `TackleBox/Panel.lua:252` (`"got away: " .. misses`), label and icon `Panel.lua:116-119`.

## Q2: Lure detection and application

### Findings
- Lure table `TackleBox/Data.lua:30-37`, sorted by bonus. Fields `id, name, bonus, req`: Shiny Bauble 6529 (+25), Nightcrawlers 6530 (+50, req 50), Aquadynamic Fish Lens 6811 (+50, req 50), Bright Baubles 6532 (+75, req 100), Flesh Eating Worm 7307 (+75, req 100), Aquadynamic Fish Attractor 6533 (+100, req 100). No duration field.
- Detection `TackleBox/Actions.lua:193-197`, inside a `TB.refreshers` entry (`Actions.lua:178`):
  - Counts each lure in bags with `C_Item.GetItemCount(l.id)`.
  - `(GetWeaponEnchantInfo())`: the extra parentheses keep only the 1st return (main hand has a temp enchant). Comment `:195`.
  - Calls `TB.PickLure(...)` and sets `A.lure = { item, usable, need }` only when a lure comes back.
- `TB.PickLure` `TackleBox/Logic.lua:197-211`: returns nil when `lureActive` is truthy. Otherwise returns the highest-bonus lure the skill allows (`id, true`), or the lowest-requirement locked one (`id, false, req`).
- Apply: lure button macro `TackleBox/Actions.lua:105-107` = `/use item:<id>` then `/use 16` (main-hand slot). Player-clicked secure button; comment `Actions.lua:2` says nothing fires on its own.
- Read vs ignored: only the first return of `GetWeaponEnchantInfo` is used. Expiration, charges, enchant ID and off-hand returns are never read anywhere in the repo.
- Any temp enchant counts as "lure active". The code does not check the enchant ID against the lure items.
- Lure bonus also shows in the Where tab and zone line through `WhereRows`/`ZoneStatus` (`Logic.lua:44-86`). These compare `skill.modifier` with the zone's `lure` threshold, not with the enchant state.

## Q3: Events and polling

### Findings
- Event bus `TackleBox/Core.lua:8-15`: `TB.On(event, fn)` registers on one hidden frame and keeps a list of handlers per event.
- `TB.Refresh()` `Core.lua:44-53`: debounced 0.1s through `C_Timer.After`. Re-reads skill, then runs every `TB.refreshers` fn. No-op until `TB.active` (set on `PLAYER_LOGIN`, `Core.lua:55-59`).
- Events that call `TB.Refresh`: `SKILL_LINES_CHANGED`, `PLAYER_REGEN_ENABLED`, `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `UNIT_INVENTORY_CHANGED` (player, comment "pole/gear changes the skill modifier") (`Core.lua:60-69`), `UNIT_AURA` (player) `:80`, `BAG_UPDATE_COOLDOWN` `:81`.
- Fishing-cycle events: `UNIT_SPELLCAST_CHANNEL_START`/`STOP` (`Core.lua:109-116, 128-133, 187-197, 223-242`), `LOOT_READY`/`LOOT_CLOSED` (`:117-125, 244-...`), `UNIT_SPELLCAST_SUCCEEDED` `:138`, `PLAYER_SOFT_INTERACT_CHANGED` `:108, 165`.
- Periodic tickers (created in `TB.inits` after login):
  - 1s `C_Timer.NewTicker` `Core.lua:83-87`: calls `TB.Refresh()` only while some `TB.auraState` entry has `remaining` (camp buff countdown).
  - 2s ticker `Core.lua:221-223`: refreshes only while the panel is shown, expanded and on the Spots tab.
- `OnUpdate` scripts: cast bar while fishing (`CastBar.lua:47-51`, removed in `StopCastBar` `:53`); panel drag (`Panel.lua:432-440`).
- One-shot timers: `C_Timer.After(0.1)` debounce `Core.lua:48`; `C_Timer.After(1)` miss check `Core.lua:236`.
- No ticker runs unconditionally. Both tickers are gated by state.
- `TB.ReadAura` `Core.lua:72-79` reads auras through `C_UnitAuras.GetPlayerAuraBySpellID` with pcall. In combat it returns cached `TB.auraState`. When expiration is secret or 0 it returns `{active=true}` with no remaining time.

## Q4: Temp weapon enchant signals on Forever

### Findings
- Forever API index (`...\wow-forever-addon\1.0.0\skills\wow-forever-addon\references\forever-api-index.md`, from wow-ui-source@forever build 1.60.1.70959) lists names only, no signatures:
  - `GetWeaponEnchantInfo` (global function), index line 646.
  - `WEAPON_ENCHANT_CHANGED` (C_Item event), line 2867.
  - `WEAPON_SLOT_CHANGED` (C_PaperDollInfo), line 2868.
  - `PLAYER_EQUIPMENT_CHANGED` (C_PaperDollInfo), line 2254.
  - `UNIT_INVENTORY_CHANGED` (Unit), line 2695.
- The skill's `references/events.md` does not mention any of these. No payload is documented for `WEAPON_ENCHANT_CHANGED`. Whether it fires on expiry on Forever has not been checked in game.
- `GetWeaponEnchantInfo` returns are not documented in the skill. Repo comment `Actions.lua:195` documents only the 1st return (main-hand enchant present). The 2nd return (main-hand expiration in ms) and later returns are general Classic API knowledge and have not been checked on Forever.
- Repo use: only TackleBox touches these names. It uses `UNIT_INVENTORY_CHANGED` (`Core.lua:69`) and the 1st return of `GetWeaponEnchantInfo` (`Actions.lua:196`). `WEAPON_ENCHANT_CHANGED` and `PLAYER_EQUIPMENT_CHANGED` are unused repo-wide.
- No addon in the repo detects enchant expiry. No probe result in `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md` covers it (not referenced by any grep hit).

## Q5: On-screen notification and sound APIs and patterns

### Findings
- Present in Forever globals (luacheck std `...\templates\luacheck\forever-std.lua`):
  - `RaidNotice_AddMessage` (:15390), `RaidWarningFrame` (:15422), `UIErrorsFrame` (:18744), `SOUNDKIT` (:15927), `ChatTypeInfo` (:3752), global `PlaySound` (:13942).
  - Plain `RaidBossEmoteFrame` is not listed; only the `RaidBossEmoteFramePrivate`/`PrivateRaidBossEmoteFrame*` variants are.
- `PlaySound`/`PlaySoundWithOptions` under `C_Sound` (index :898). `PlaySoundFile` is listed as "C globals not in the docs" (index :1065). `forever-api-notes.md:31` says it was checked in game on build 70959. `SOUNDKIT_FINISHED` event exists (index :2512).
- Signatures of `RaidNotice_AddMessage` and `UIErrorsFrame:AddMessage` are not in the skill.
- Only repo sound use: `WarlockCombatKit/Core.lua:145-146`:
  ```lua
  if WCK.db.procAlerts and WCK.db.procSound and #WCK.NewProcs(WCK.procs, up) > 0 then
    PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")
  ```
  - Runs in a refresher (`Core.lua:137`) driven by `UNIT_AURA`, `SPELL_UPDATE_USABLE`, `PLAYER_TALENT_UPDATE` (`:150-152`).
  - Fires only on a newly appeared proc; previous state is stored in `WCK.procs` (`:148`).
  - Numeric fallback ID 8959, "Master" channel.
- Gating pattern in WCK: defaults `procAlerts = true, procSound = true` (`WarlockCombatKit/Core.lua:24`). Separate checkboxes for each (`WarlockCombatKit/Settings.lua:50-53`). Sound requires both flags. Visual alert gated by `procAlerts` (`Rotation.lua:94`, `Panel.lua:195`).
- No use anywhere in the repo of `RaidNotice_AddMessage`, `RaidWarningFrame`, `UIErrorsFrame`, `PlaySoundFile`, `ChatTypeInfo`.
- TackleBox makes no `PlaySound` call. Its only user-facing text output is `TB.Print` to chat (`Core.lua:6`, prefix `|cff3fa7d6TB|r`).

## Q6: TackleBox settings, slash commands, docs, tests

### Findings
- SavedVariables `TackleBox/TackleBox.toc:6-7`: `TackleBoxDB` (account), `TackleBoxCharDB` (per character). TOC `Interface: 16001`, `Version: 1.3.0`.
- Defaults `Core.lua:17-21`: `version = 2`, `locked, shown, frames, minimapAngle, tab, flash = true, expanded, pools, pins = {map, minimap}, detect = true`. Char: `catches = {}`. Comment `:17` says bump `version` and migrate here on schema change. New keys are filled in by `MergeDefaults`.
- `TB.MergeDefaults` `Logic.lua:3-10`: recursive and nil-safe. Fills only nil keys. Called on `ADDON_LOADED` (`Core.lua:23-29`). Comment `:25` mentions the Forever beta loader bug that can leave SVs nil.
- No Ace or options panel; settings are slash-only. `/tb` parser `Core.lua:424-452`: `show|hide`, empty toggles shown, `lock`, `reset`, `probe`, `flash`, `camp`, `detect`, `pins map|minimap`, `bind <key>`, `unbind`. Boolean toggles follow `TB.db.x = not TB.db.x; TB.Print("x " .. (on and "on" or "off"))` (`:432, :434`). Help line `:451` uses `||` so chat prints a single pipe (comment there).
- WCK has a Settings.lua checkbox panel (`WarlockCombatKit/Settings.lua:50-53`); TackleBox has no equivalent.
- Docs: `TackleBox/README.md` has a section per feature ("Cast bar and 'got away' flash" `:64-66`), a slash-command table (`:94`) and a data-sources note (`:108`). `TackleBox/CHANGELOG.md` uses Keep-a-Changelog style `## [x.y.z] — date` with `### Added`. Versions match the TOC and are released as `tb-vX.Y.Z` (`CHANGELOG.md:3`). Got-away flash entry `CHANGELOG.md:61`, pool alerts `:28`.
- Tests `TackleBox/tests/run.lua`: plain Lua with no WoW mock. It loads only `Data.lua` and `Logic.lua` into a table `TB` (`:1-4`) and uses an `eq(got, want, label)` assert helper (`:6-8`). Sections are labelled by phase. It ends with `print("all tests passed")`. `Core.lua`, `CastBar.lua`, `Actions.lua` and `Panel.lua` are not loaded, so only pure `Logic.lua` functions are tested (e.g. `ShouldAlert`, `IsMiss`, `PickLure`).

## Cross-Cutting Observations
- Split: pure functions in `Logic.lua` (tested), WoW-touching code in `Core/Actions/CastBar/Panel` (untested, verified in game through `/tb probe`-style dumps `Core.lua:269, 374`).
- Init pattern: `table.insert(TB.inits, fn)` runs after `PLAYER_LOGIN` (`Core.lua:55-59`); UI frames and tickers are created there.
- Alert dedupe pattern: `TB.ShouldAlert(last, key, now, cooldown)` (`Logic.lua:295-299`). Edge detection with stored previous state appears in WCK (`WCK.NewProcs` + `WCK.procs`).
- Comments cite in-game probe runs as the source of truth for Forever behaviour (`Core.lua:73, 81, 127, 146`).
- Secret-value guarding (`TB.Secret`, `Core.lua:5`) wraps reads of timing and name values that may be secret on Forever.

## Open Areas
- `GetWeaponEnchantInfo` return values beyond the 1st, and whether expiration is readable (not secret) on Forever: undocumented, unverified.
- Whether `WEAPON_ENCHANT_CHANGED`, `UNIT_INVENTORY_CHANGED` or `PLAYER_EQUIPMENT_CHANGED` fire when a temp enchant expires on Forever: unverified.
- Signatures and in-game behaviour of `RaidNotice_AddMessage` / `UIErrorsFrame:AddMessage` on Forever: names present, not exercised in repo.
- Whether `SOUNDKIT` keys (e.g. `RAID_WARNING`) resolve on Forever: WCK uses one with a numeric fallback, but the repo has no probe confirming the key exists.
