# Research Findings

All paths relative to `WarlockUtilityKit/` unless noted. TOC load order (`WarlockUtilityKit.toc:9-18`): Logic, Core, UI, Prep, Summon, Trade, Comm, Board, Dock, Settings. Each file pushes into `WUK.inits` / `WUK.refreshers`; inits run in load order at PLAYER_LOGIN, warlocks only (`Core.lua:143-150`), then `WUK.Refresh()` (`Core.lua:149`). So the strip exists before Prep's buttons parent to it and before Dock anchors to it.

## Q1: How is `WUKStrip` built and sized, and how is each child anchored?

### Findings
- Frame: `CreateFrame("Frame","WUKStrip",UIParent,"BackdropTemplate")` (`UI.lua:31`).
- Size: `SetSize(4 + 7*40, 76)` = 284x76 (`UI.lua:33`). Literal `7`; comment "prep + pet + 5 stone buttons, 36px each with 4px gaps; soulstone line underneath" (`UI.lua:32`). Not derived from `#KINDS`. Never resized afterward.
- Backdrop WHITE8x8 bg+edge, edgeSize 1 (`UI.lua:34`); bg 0,0,0,0.6, border 0.58,0.51,0.79,1 (`UI.lua:35`).
- Children, all anchored to strip TOPLEFT (no button-to-button chaining):

| Child | Created | Size | Anchor |
|---|---|---|---|
| `WUKArmorButton` | `Prep.lua:5` | 36x36 (`Prep.lua:6`) | `TOPLEFT,4,-4` (`Prep.lua:6`) |
| `WUKPetButton` | `Prep.lua:22` | 36x36 (`Prep.lua:23`) | `TOPLEFT,44,-4` (`Prep.lua:23`) |
| `WUKStone_<kind>` x5 | `UI.lua:38` | 36x36 (`UI.lua:39`) | `TOPLEFT, 4+(i+1)*40, -4` (`UI.lua:39`) |
| `f.stone` FontString | `UI.lua:48` | none | `BOTTOMLEFT,6,20` (`UI.lua:49`) |
| `f.assign` FontString | `UI.lua:50` | none | `BOTTOMLEFT,6,6` (`UI.lua:51`) |

- `KINDS = {shard, healthstone, soulstone, spellstone, firestone}` (`UI.lua:3`), giving stone x = 84,124,164,204,244. Slot 0/1 for armor/pet are literals in another file (`Prep.lua:6,23`) — the `(i+1)` offset in `UI.lua:39` implicitly reserves them.
- Per-button parts: icon texture `ARTWORK` with `SetAllPoints()` (`UI.lua:42`, `Prep.lua:9,26`); highlight `ButtonHilight-Square` ADD (`UI.lua:45`, `Prep.lua:10,27`); stone `count` FontString `NumberFontNormal` at `BOTTOMRIGHT,-2,2` (`UI.lua:43-44`). Armor/pet have no count.
- Stone buttons stored `f.icons[kind]` (`UI.lua:46`); armor/pet are file locals `armorBtn`/`petBtn` (`Prep.lua:3,20`), not on the strip table.
- Label text: `f.stone` set by 1s ticker (`Prep.lua:44-47`); `f.assign` set by Board refresher (`Board.lua:186-187`).

## Q2: How is the set of visible buttons determined, and does count/order change?

### Findings
- Set is fixed: armor + pet always created (`Prep.lua:4-11,21-28`); all 5 KINDS always created (`UI.lua:37`). Nothing conditional on known spells, bag contents, or level.
- No per-button `Show`/`Hide` anywhere. Only whole-strip visibility: `WUK.ApplyShown` (`UI.lua:26-28`) on `db.shown`; called at init (`UI.lua:54`) and `/wuk show|hide` (`Core.lua:226`, combat-refused at `Core.lua:225`); Settings checkbox routes through same slash (`Settings.lua:28`).
- Unavailable states are expressed via desaturation/fallbacks, not hiding: stone desaturated at count 0 (`UI.lua:64`), fallback icons (`UI.lua:5-9,63`); armor icon 134400 if unknown (`Prep.lua:14`), desaturated when buff up (`Prep.lua:15`); pet desaturated when `PetFamily()` ≠ chosen pet (`Prep.lua:29-35`). Empty `macrotext` when nothing to do (`UI.lua:68`, `Prep.lua:16,34`; `StoneMacro` returns nil for shard, `Logic.lua:27`).
- Order fixed left→right: armor, pet, shard, healthstone, soulstone, spellstone, firestone.
- Other button groups:
  - Summon panel `WUKSummon` 300x220 fixed (`Summon.lua:67-68`), `MakeMovable(panel,"summon",0,-300)` (`Summon.lua:72`), hidden at init (`Summon.lua:85`). 10 pre-created rows `WUKSummonRow<i>` 288x18 at `TOPLEFT,6,-2-i*20` (`Summon.lua:73-84`). `UpdateSummonRows` shows rows for queue entries, hides the rest, panel shown iff `queue[1]` (`Summon.lua:38-56`). Row count/positions fixed; only visibility varies.
  - Minimap button `WUKMinimapButton` 31x31 on `Minimap` (`Settings.lua:70-71`); `Place()` positions on a circle: `r = Minimap:GetWidth()/2+8`, `SetPoint("CENTER",Minimap,"CENTER",cos(a)*r,sin(a)*r)` with `a = rad(db.minimapAngle)` (`Settings.lua:78-81`). Only existing polar/trig placement in the addon.

## Q3: How do `MakeMovable` and Dock position the strip, what is saved, what assumptions?

### Findings
- `WUK.MakeMovable(f,key,x,y)` (`UI.lua:11-24`):
  - Drag on LeftButton only if Shift held, `not db.locked`, not in combat (`UI.lua:14`).
  - On stop: `GetPoint()` first anchor, saves `db.frames[key] = {point, relPoint, x, y}` (`UI.lua:18-19`); relative frame discarded.
  - Restore: `ClearAllPoints`, then saved point relative to `UIParent`, else `CENTER,UIParent,CENTER,x,y` (`UI.lua:21-23`).
  - Users: strip (`"strip"`, 0,-220, `UI.lua:53`), summon (`"summon"`, 0,-300, `Summon.lua:72`). Board/Settings windows drag without saving (`Board.lua:99-100`, `Settings.lua:21-22`).
  - Assumes single anchor, always UIParent-relative, no scale handling (no `SetScale` anywhere).
- Saved vars: `DEFAULTS = {locked=false, shown=true, frames={}, icons={}, minimapAngle=220, dockViewers=false}`, `CHAR_DEFAULTS = {pet="imp"}` (`Core.lua:19-20`), merged at ADDON_LOADED via `MergeDefaults` (`Core.lua:22-28`, `Logic.lua:16-23`). Runtime extras: `char.soulstone` (`Prep.lua:40`), `char.board` (`Board.lua:15`).
- Dock (`Dock.lua`):
  - `VIEWERS = {EssentialCooldownViewer, BuffIconCooldownViewer}` (`Dock.lua:3`) — Blizzard Cooldown Manager frames.
  - `ApplyDock` no-op unless `db.dockViewers` and out of combat (`Dock.lua:7`); chains each existing viewer `TOPLEFT` to previous anchor's `BOTTOMLEFT`, 0,-4, starting at `WUK.strip` (`Dock.lua:8-13`).
  - `hooksecurefunc(v,"SetPoint")` re-applies via `C_Timer.After(0, ApplyDock)` guarded by `applying` flag (`Dock.lua:21`); also on `EDIT_MODE_LAYOUTS_UPDATED` (`Dock.lua:23`) and every refresh (`Dock.lua:26`).
  - Assumes strip's BOTTOMLEFT is the attach point, i.e. a rectangular strip whose bottom edge sits below everything; viewers follow strip moves.
  - Turning dock off doesn't restore viewers, prints "/reload to restore the Edit Mode position" (`Core.lua:239`).

## Q4: Secure-template constraints, combat checks, deferral

### Findings
- Secure buttons (all `SecureActionButtonTemplate`, created at PLAYER_LOGIN): stones (`UI.lua:38`), armor (`Prep.lua:5`), pet (`Prep.lua:22`), summon rows (`Summon.lua:74`). No SecureHandler templates, state drivers, or restricted snippets anywhere.
- Static attributes at creation: `type="macro"` (`UI.lua:41`, `Prep.lua:8,25`); rows `type1`/`ctrl-type1="macro"` (`Summon.lua:77`). `RegisterForClicks("AnyUp","AnyDown")` on all.
- Dynamic attributes only out of combat: stone `macrotext` (`UI.lua:66-69`), armor/pet (`Prep.lua:16,34`), rows `macrotext1`/`ctrl-macrotext1` (`Summon.lua:46-47`, whole function returns in combat at `Summon.lua:39`). Full `SetAttribute` list: `UI.lua:41,68`; `Prep.lua:8,16,25,34`; `Summon.lua:46,47,77`.
- Geometry of secure buttons (`SetSize`/`SetPoint`) only at creation (`UI.lua:39`, `Prep.lua:6,23`, `Summon.lua:75`). Strip `SetPoint` only in MakeMovable restore and user drag (combat-blocked, `UI.lua:14`). Strip `Show/Hide` via `ApplyShown`, guarded on the slash path (`Core.lua:225`), unguarded at login (`UI.lua:54`). Summon row/panel Show/Hide behind combat guard (`Summon.lua:39,50-55`).
- Non-protected per-refresh calls run regardless of combat: `SetTexture`, `SetDesaturated`, `SetText` (`UI.lua:62-65`, `Prep.lua:14-15,32-33`), label ticker (`Prep.lua:44-47`).
- `InCombatLockdown()` sites: `UI.lua:14,66`; `Prep.lua:16,34`; `Summon.lua:39`; `Dock.lua:7`; `Core.lua:175` (probe print), `225`, `236`.
- Deferral pattern: no queue/flag. Skip now; `PLAYER_REGEN_ENABLED -> WUK.Refresh` (`Core.lua:152`) re-runs all refreshers. Comment: "no-op in combat; PLAYER_REGEN_ENABLED -> Refresh applies it" (`Summon.lua:63`). PLAYER_REGEN_DISABLED not registered.

## Q5: State computed and how it reaches buttons/labels

### Findings
- `WUK.counts` from `ScanBags` (`Core.lua:30-44`): per-kind counts + `ids`, `slots`; kind via `ClassifyItem` (`Logic.lua:9-14`).
- `WUK.known` from `ScanSpells` (`Core.lua:87-93`) over `SPELLS` (`Core.lua:48-62`): armor, pets, ritual, stone-create spells, etc.
- Buffs: `ReadPlayerBuffs` (`Core.lua:95-104`); pet: `PetFamily` (`Core.lua:106-111`).
- Soulstone record `char.soulstone={target,expires}` on cast (`Prep.lua:37-41`); `SoulstoneRemaining` (`Logic.lua:79-84`).
- Assignment text `AssignmentText(rows[me], MarkIcon)` (`Board.lua:186`, `Logic.lua:104-113`).
- Summon queue + `Context`/`SummonFailure` (`Summon.lua:15-36`, `Logic.lua:69-77`).
- `WUK.Refresh` (`Core.lua:137-141`): rescans bags, runs refreshers in order: stones (`UI.lua:57`), armor (`Prep.lua:12`), pet (`Prep.lua:29`), summon (`Summon.lua:95`), assign label (`Board.lua:185`), dock (`Dock.lua:26`).
- Refresh triggers: PLAYER_LOGIN, BAG_UPDATE_DELAYED, PLAYER_REGEN_ENABLED, SPELLS_CHANGED, UNIT_AURA(player), UNIT_PET(player) (`Core.lua:149-155`), `/wuk pet` (`Core.lua:230`), soulstone cast (`Prep.lua:41`), board changes (`Board.lua:18-21`).
- Ticker `C_Timer.NewTicker(1)` (`Prep.lua:44-47`) only updates `strip.stone` text; touches no buttons.

## Q6: Geometry/animation APIs used or recorded as working

### Findings
- No `CreateAnimationGroup`, `SetScale`, `SetAlpha`, `SetRotation`, `SetTexCoord`, `UIFrameFade` anywhere in the addon.
- Only `OnUpdate`: minimap drag, set in OnDragStart and cleared in OnDragStop (`Settings.lua:85-94`), using `GetCursorPosition`, `Minimap:GetEffectiveScale()`, `atan2` → `db.minimapAngle`.
- Timers: `NewTicker(1)` (`Prep.lua:44`), `NewTicker(0.25)` (`Comm.lua:28`), `C_Timer.After` (`Dock.lua:21`, `Board.lua:80`, `Trade.lua:30`).
- Trig placement precedent: `Place()` cos/sin around Minimap (`Settings.lua:78-81`).
- `thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md` covers secrets/auras/Cooldown Manager only: spells ContextuallySecret (line 6), enemy aura read errors when tainted in combat (line 14), CDM viewer frames exist and are shown (line 23), "anchoring untested, Edit Mode may override SetPoint, taint possible" (line 25). Nothing recorded on animation, scale, alpha, or rotation APIs for Interface 16001.

## Q7: Layout options in settings/SVs; test coverage

### Findings

| Option | Storage | Slash (`Core.lua`) | Settings UI |
|---|---|---|---|
| show/hide strip | `db.shown` | `226`, combat-refused `225` | checkbox `Settings.lua:28` |
| lock | `db.locked` | `227` | checkbox `Settings.lua:29-30` |
| dock viewers | `db.dockViewers` | `235-240`, combat-refused | checkbox `Settings.lua:31-32` |
| reset positions | `wipe(db.frames)`, needs /reload | `228` | button `Settings.lua:48-50` |
| pet choice | `char.pet` | `229-230` | dropdown `Settings.lua:38-46` |

- No scale, orientation, spacing, or layout-shape option exists. `minimapAngle` only set by drag (`Settings.lua:90`); not reset by `/wuk reset`.
- Settings options all go through `Run(cmd)` → `SlashCmdList.WARLOCKUTILITYKIT` (`Settings.lua:6`); window 320x258 lazily built (`Settings.lua:19-20,64-67`).
- `tests/run.lua`: plain Lua, no WoW/frame stubs; loads only `Logic.lua` into an empty table (`tests/run.lua:3`). Covers ClassifyItem, MergeDefaults, FormatTime, SoulstoneRemaining, summon queue/failure, healthstone request, StoneMacro, AssignmentText, Encode/Decode, AnnounceLines (`tests/run.lua:10-86`). No layout code (UI, Prep, Dock, Summon frames, Settings) is covered.

## Cross-Cutting Observations
- Pattern: build all frames once at login, mutate only textures/text/attributes afterward; geometry is static. Layout math is inline literals split across `UI.lua` and `Prep.lua` (armor/pet slots in Prep, stone offset reserves them in UI).
- Visibility of "unavailable" actions is conveyed by desaturation, not by removing buttons.
- Out-of-combat-only work uses "guard + redo on next Refresh" rather than queuing.
- `WUK.strip` is a shared anchor/handle used by Prep (parent), Board (`strip.assign`), Dock (BOTTOMLEFT anchor), ApplyShown.
- Only polar positioning precedent: minimap button `Place()`.

## Open Areas
- Behaviour of animation/scale/alpha APIs on the Forever client (Interface 16001) is not recorded anywhere in the repo.
- Whether Blizzard CDM viewers accept anchoring to a non-rectangular or moving strip is noted as untested (`probe-results.md:25`).
- How ProfessionPlanner styles frames was not in the approved questions; not researched.
