# Research Findings

Paths relative to repo root. Doc abbreviations:
- **WUKp** = `thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md`
- **TBp** = `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md`
- **R21** = `thoughts/qrspi/2026-10-21-warlock-combat-tooling/research.md`

## Q1: Addon lifecycle (WUK skeleton; TB/PP differences)

### Findings
- **TOC:** `WarlockUtilityKit/WarlockUtilityKit.toc:6-7` declares the SavedVariables `WarlockUtilityKitDB` (account) and `WarlockUtilityKitCharDB` (per-character). Load order is Logic, Core, UI, Prep, Summon, Trade, Comm, Board, Dock, Settings (`toc:9-18`).
- **Shared namespace:** every file opens `local ADDON, WUK = ...` (`Core.lua:1`, `Logic.lua:1`), so all files share one table.
- **Dispatcher:** `WUK.inits` and `WUK.refreshers` are lists (`Core.lua:3`).
  - `WUK.On(event, fn)` appends to `handlers[event]` and calls `RegisterEvent` on first use (`Core.lua:11-14`).
  - One frame's OnEvent calls each handler in registration order with positional args (`Core.lua:15-17`).
- **Secret helper:** `WUK.Secret(v) = issecretvalue ~= nil and issecretvalue(v)` (`Core.lua:7`).
- **ADDON_LOADED** (`Core.lua:22-28`):
  - Guarded on `name == ADDON`.
  - Merges `DEFAULTS` (`Core.lua:19`) and `CHAR_DEFAULTS` (`Core.lua:20`) via `WUK.MergeDefaults` (`Logic.lua:16-23`), which recurses into tables and fills only nil keys.
  - Aliases the results to `WUK.db` and `WUK.char`.
  - Comment: the Forever beta loader can leave the SavedVariables nil (`Core.lua:24`).
- **PLAYER_LOGIN** (`Core.lua:143-150`):
  - Class-gates on WARLOCK and sets `WUK.active`.
  - Calls `ScanSpells()`, runs every init, then calls `Refresh()`.
  - Most event handlers register inside inits, so they register only at login (Trade.lua:10-30, Comm.lua:29, Summon.lua:87-89, Board.lua:175, Dock.lua:23, UI.lua:151, Prep.lua:42).
- **`WUK.Refresh`** (`Core.lua:137-141`): returns unless `active`, sets `WUK.counts = ScanBags()`, runs all refreshers. No debounce.
- **Refresh triggers:**
  - PLAYER_LOGIN, BAG_UPDATE_DELAYED, PLAYER_REGEN_ENABLED (`Core.lua:149-152`).
  - SPELLS_CHANGED, which first runs `ScanSpells` (`:153`).
  - UNIT_AURA and UNIT_PET for `player` (`:154-155`).
  - Slash commands pet, spin and collapse (`:230`, `:242`).
  - Board.lua:20 and Prep.lua:45 (inside the SUCCEEDED handler).
- **Events that don't refresh:** UNIT_SPELLCAST_SENT (`:157-159`), GROUP_ROSTER_UPDATE (Summon.lua:88), EDIT_MODE_LAYOUTS_UPDATED (Dock.lua:23).
- **Inits and refreshers are added by `table.insert` across files:** Prep.lua:4,12,23,31,41; UI.lua:112,154; Summon.lua:66,95; Dock.lua:17,26; Settings.lua:73.
- **TackleBox** (`TackleBox/TackleBox.toc:6-14`): load order is Data, Logic, Core, Actions, Panel, CastBar. Same On/inits/refreshers/MergeDefaults pattern (`TackleBox/Core.lua:3-26`; own `MergeDefaults` copy at `TackleBox/Logic.lua:3`).
  - No class gate: PLAYER_LOGIN always sets `TB.active` (`Core.lua:52-56`).
  - `TB.Refresh` is debounced with `C_Timer.After(0.1)` and a `pending` flag, and reads `TB.skill` before running the refreshers (`Core.lua:42-50`).
  - More triggers (`Core.lua:57-63`, `:74`): skill, bag and bank events, zone change, UNIT_INVENTORY_CHANGED.
  - A 1s ticker refreshes only while an aura has `remaining` (`Core.lua:76-80`).
  - Channel and loot handlers register at file scope, not in inits (`Core.lua:92-156`).
- **ProfessionPlanner** (`ProfessionPlanner/ProfessionPlanner.toc:6-13`, `OptionalDeps: Auctionator, QuestieDB`):
  - No `active` flag and no class gate.
  - PLAYER_LOGIN only runs the inits, with no initial Refresh (`ProfessionPlanner/Core.lua:23`).
  - `PP.Refresh` is an unguarded loop (`Core.lua:14`). The panel has its own 0.1s debounced `Rerender` (`Panel.lua:137`).
  - All events register in inits (`Core.lua:182-193`). `ScanProfession` retries 5× on 0.5s timers (`Core.lua:78-84`).

## Q2: Probe commands

### Findings
- **`/wuk probe`, `WUK.Probe`** (`WarlockUtilityKit/Core.lua:170-219`; dispatched at `:232`, only when `active`)
  - **Output:** print-only through `P(k,v)` and `WUK.Print` (`:171`, `:8`). Nothing is persisted.
  - **Secret masking:** `S(v)` turns secret values into "SECRET" (`:172`).
  - **Tests:**
    - `IsInInstance`, `InCombatLockdown`, `C_ChatInfo.InChatMessagingLockdown` (`:173-176`).
    - `pcall(C_Secrets.GetSpellAuraSecrecy, name)` over 10 `PROBE_SPELLS` (`:166-167`, `:177-180`).
    - `C_CooldownViewer` presence, the CVar, and `IsCooldownViewerAvailable` (`:182-186`).
    - `GetCooldownViewerCategorySet` for categories 0-3 and per-id `GetCooldownViewerCooldownInfo`, all under pcall (`:188-199`).
    - The four viewer frames, shown state and child count (`:203-206`).
    - Target: `UnitCanAttack` and the raid mark, then `pcall(C_UnitAuras.GetUnitAuras,"target","HARMFUL|PLAYER")`; per aura `GetAuraDuration` with fields masked by `S` (`:207-217`).
  - **Runtime use:** none. The header says output is pasted back by hand (`:169`).
- **`/tb probe`, `TB.Probe`** (`TackleBox/Core.lua:161-235`; slash `:237-247`)
  - **Output:** resets `TB.db.lastProbe = {}`. `P` both prints and appends, so results persist in `TackleBoxDB` (`:160-164`).
  - **Error containment:** `Try(k, fn)` wraps each section in pcall and prints "ERROR …" (`:165`). `S` masks secrets (`:163`).
  - **Tests:**
    - Build info and `WOW_PROJECT_ID`, combat state (`:167-169`).
    - `GetProfessions` and `GetProfessionInfo` (`:171-179`); `C_TradeSkillUI.GetProfessionInfoBySkillLineID(356)` (`:180-183`).
    - `C_Spell.GetSpellInfo` for 7620 and 131474 (`:184-189`); `IsFishingLoot` existence and zone (`:190-191`).
    - Player HELPFUL auras through `GetAuraDataByIndex` and `GetPlayerAuraBySpellID` (`:193-205`).
    - Bag scan (`:207-222`).
  - **Snapshots from always-on handlers:**
    - `TB.lastChannelInfo` (`:92-97`).
    - `TB.lastLoot` (`:99-107`).
    - `TB.trace`, a ring of 12 events written by `Trace` (`:90-91`), printed with relative times (`:224-234`).
- **`/pp probe`, `PP.Probe`** (`ProfessionPlanner/Core.lua:197-271`; slash `:276`)
  - **Output:** a `log` table is saved as `PP.db.lastProbe` (`:198-200`). `P(k,v,quiet)` always logs and prints unless `quiet`; quiet lines stay in the saved log only (`:201-205`, `:241-244`).
  - **Error containment:** no `issecretvalue` use. Targeted pcall around `GetRecipeRequirements`, `GetRecipeSourceText` and the Auctionator price lookup (`:226`, `:246`, `:250`, `:263`).
  - **Tests:** `C_TradeSkillUI` recipe and schematic facts, gated on `IsTradeSkillReady` (`:206-258`). Auctionator, LibQuestieDB and bag-index enums run unconditionally (`:260-270`).
  - **Related:** `/pp debug` (`:277-297`) is a separate dump.
- **Reading results back:** no code in any addon reads `lastProbe` or other probe output to change behavior (grep: `lastProbe` appears only at TB `Core.lua:160-164` and PP `Core.lua:198-200`). Probe findings live in code comments instead (TB `Core.lua:67`, `:82`, `:109`; PP `Core.lua:70`) and in probe-results.md files. No capability-flag table exists in the repo.

## Q3: Own spellcast events, and the recorded secret-value behavior

### Findings — handlers
- **UNIT_SPELLCAST_SENT:** one handler, `WarlockUtilityKit/Core.lua:157-159`.
  - Reads `(unit, target)`.
  - For `player`, stores `WUK.lastCastTarget = target` only if the target is non-nil, non-secret and non-empty; otherwise nil.
  - `castGUID` and `spellID` are not read.
- **UNIT_SPELLCAST_SUCCEEDED, `(unit, _, spellID)`:** two handlers, both registered in inits.
  - `Prep.lua:42-47` (soulstone): when `WUK.SpellName(spellID) == "Soulstone Resurrection"`, sets `WUK.char.soulstone = {target = lastCastTarget or UnitName("player"), expires = time()+1800}`, then calls `Refresh`. A 1s ticker renders the remaining time (`Prep.lua:48-51`).
  - `Summon.lua:89-93`: when the spell name matches `WUK.known.ritual`, removes `Ambiguate(lastCastTarget,"none")` from the summon queue, then calls `UpdateSummonRows`.
- **`WUK.SpellName`** (`Core.lua:160-164`): returns nil for a nil or secret spellID, otherwise `C_Spell.GetSpellInfo(id).name`.
- **Correlation:** SENT and SUCCEEDED are linked by a single module variable (last target) and a spell-name match. No handler in the repo uses `castGUID` or `castBarID`.
- **TackleBox** registers no SENT or SUCCEEDED handlers. It uses CHANNEL_* events, gated on `unit=="player"` (`TackleBox/Core.lua`).
  - **CHANNEL_START handlers:**
    - `:92-97`: snapshots `UnitChannelInfo` returns 4-5 and their secret flags.
    - `:110-112`: stores `TB.lastChannel = {spellID, t}` when the spellID is non-secret.
    - `:119-124`: starts the cast bar, falling back to `now + DATA.castSeconds` if the times are secret or nil.
  - **CHANNEL_STOP handlers:** `:98` traces; `:113-115` sets `stopT`; `:125-136` stops the bar, then after a 1s timer checks `TB.IsMiss(stopT, lastLootT)` and records a miss.
  - **LOOT_READY** (`:140-156`): `TB.IsFishingCatch(isFishingLoot, lastChannel, GetTime(), spells)` links loot to the last channel.
- **Secret guards in code:**
  - WUK: aura names, pet family, unit names, SENT target, spellID (`Core.lua:101,109,122,158,161`); `UnitInRange` (`Summon.lua:30`); chat text and sender (`Summon.lua:59`).
  - TB: aura `expirationTime` (`Core.lua:71`); channel spellID and times (`:95,111,118,122`).

### Findings — recorded API behavior on Forever
Probed in-game:
- **`C_Secrets.GetSpellAuraSecrecy`** returns 2 (ContextuallySecret) for all 10 warlock names, in and out of combat (WUKp:6-7, 11-12). It also returns 2 for unknown names (WUKp:8).
- **`C_ChatInfo.InChatMessagingLockdown`** does not exist (WUKp:5).
- **`C_UnitAuras.GetUnitAuras("target","HARMFUL|PLAYER")` in combat** raises "Auras cannot be accessed when secret while tainted by 'WarlockUtilityKit'" (WUKp:14, 24). The recorded conclusion is that enemy DoT timers are not feasible (WUKp:27-30).
- **`GetRaidTargetIndex("target")` and `UnitCanAttack`** were readable in combat (WUKp:13).
- **`C_CooldownViewer` category sets and info** were readable in combat; the viewer frames exist (WUKp:17-23).
- **Player HELPFUL auras out of combat** are plain values (TBp:11). In-combat player aura reads are not recorded in any probe. TB's comment (`TackleBox/Core.lua:67`) attributes "combat aura reads error" to the WUK probe, but WUKp records only the enemy-debuff error.
- **`UnitChannelInfo("player")`** returns plain ms numbers. The CHANNEL_START spellID is not secret (TBp:19-24, 30, 51). CHANNEL_STOP can arrive more than 1s after the nominal end (TBp:34).
- **Loot:** `LOOT_READY` arrives about 10ms after CHANNEL_STOP; `IsFishingLoot` works (TBp:10, 41-44).
- **Combat coverage:** all TB probes ran out of combat.

Documented in R21 but not probed (R21 marks these UNVERIFIED where noted):
- **Secret value rules:** secrets may be stored, passed, concatenated and formatted. Comparison, arithmetic, `#`, indexing and use as table keys error (R21:162-166).
- **Auras:** the `UNIT_AURA` payload is fully secret (R21:170). No warlock spells are whitelisted (R21:172, 436).
- **Player and pet spellcast events** are non-secret even in combat, per the 12.0.0 notes (R21:176, 268).
- **SENT payload** is `unit, target, castGUID, spellID`. `target` is tagged ConditionalSecret, and the in-combat case is unverified (R21:262-265, 452).
- **SUCCEEDED payload** is `unit, castGUID, spellID, castBarID`, with no target. The castGUID is shared with SENT (R21:266-267).
- **Target/focus `UnitCastingInfo`** is secret (R21:179).
- **`UnitGUID` and `UnitName`** are secret for non-player units under restriction. `UnitIsUnit` comparisons are restricted. `UnitExists` and `UnitIsDead` in combat are unverified (R21:275-280).
- **`C_Spell.GetSpellCooldown`:** `isEnabled`, `isActive`, `isOnGCD` and `maxCharges` are non-secret; the timing fields are secret. `IsSpellUsable` and `IsSpellInRange` in combat are unverified (R21:182-183).
- **Resources:** primary resources are secret (R21:173-174).

## Q4: Ring/disc/strip UI, glow, drag/lock, settings, minimap

### Findings
- **Constants:** `R=58`, `CORE=44`, `BTN=36`, `LABELS=30` (`WarlockUtilityKit/UI.lua:10`). Orbit order is healthstone, soulstone, spellstone, firestone, armor, pet, clockwise from 12 o'clock (`:11`).
- **Frame hierarchy:**
  - `WUKStrip` is a plain Frame on UIParent, size `SIZE × (SIZE+LABELS)` (`UI.lua:113-117`). Its state fields `angle`, `radius` and `targetRadius` start at 0, R, R (`:117`).
  - The 5 stone buttons are `WUKStone_<kind>` with `SecureActionButtonTemplate` (`:127-143`).
    - The core button is 44px at frame level +3; orbit buttons are +1, so collapsed buttons sit under the core (`:131`).
    - Each has an `icon` texture, a `count` FontString and a `ButtonHilight-Square` highlight in ADD blend (`:134-141`).
  - Prep adds `WUKArmorButton` and `WUKPetButton` to `strip.icons` (`Prep.lua:5-10`, `24-29`).
  - The label band has two FontStrings, `f.stone` and `f.assign` (`UI.lua:144-147`).
- **Disc backdrop:** `Disc()` makes a texture masked with `Interface\CharacterFrame\TempPortraitAlphaMask` (`UI.lua:53-59`).
  - Rim is color (0.58,0.51,0.79,0.55) (`:119`).
  - Disc is color (0.04,0,0.07,0.7) (`:120`).
  - Swirl uses `Interface\Icons\Spell_Shadow_Twilight`, ADD blend, alpha 0.35, and rotates 360° over 90s on repeat (`:121-125`).
- **Icons:**
  - Stone fallbacks are listed at `UI.lua:5-9`. Icons come from `C_Item.GetItemIconByID` and are cached in `db.icons` (`:158-160`).
  - Armor and pet icons come from `C_Spell.GetSpellTexture`, with 134400 as fallback (`Prep.lua:14,34`).
- **Orbit math:** `WUK.RingPoint(i,n,radius,offsetDeg)` is pure (`Logic.lua:163-166`).
- **`LayoutRing`** (`UI.lua:33-50`) returns in combat.
  - Places each button, sets alpha to `radius/R`, enables mouse only while `radius>0`, and resizes rim, disc and swirl with the radius.
  - Pulses the core when a hidden orbit icon is alerting.
- **Animation:**
  - `Target` returns 0 when collapse is on, out of combat, and the mouse is not over the strip (`:64-66`).
  - `Step` is the OnUpdate: spins at 6°/s and blooms over 0.2s, and removes itself in combat or when idle (`:61`, `:68-80`).
  - `WUK.Animate` attaches `Step` only out of combat (`:83-85`).
  - `WUK.CombatFreeze` runs on PLAYER_REGEN_DISABLED. It clears OnUpdate, opens the ring fully and lays it out once (`:87-93`, `:151`).
  - The icon "pop" is a Scale animation, 1.3× over 0.15s then back, played on a 0 to >0 count change (`:135-138`, `:164`).
- **Glow and pulse:**
  - `WUK.AddGlow(b)` adds an OVERLAY texture `Interface\Buttons\UI-ActionButton-Border`, ADD blend, color (0.7,0.3,1), 1.8× the button size. Its Alpha animation goes 0.15 to 1 over 0.6s with BOUNCE looping (`UI.lua:96-103`).
  - `WUK.SetAlert(b,on)` is idempotent through `b.alerting` (`:105-110`). The comment calls it texture-only and combat-safe (`:95`).
  - Alert triggers are at `UI.lua:162` and `Prep.lua:17,37`.
- **Desaturation:**
  - WUK: zero-count stone (`UI.lua:161`); armor up (`Prep.lua:16`); pet not out (`Prep.lua:36`).
  - TB: unusable action, with alpha 0.5 (`TackleBox/Actions.lua:67`); inactive tabs, with alpha 0.6 (`TackleBox/Panel.lua:169`).
- **Shift+drag:** `WUK.MakeMovable(f,key,x,y)` (`UI.lua:13-26`).
  - Drags only when `IsShiftKeyDown() and not db.locked and not InCombatLockdown()`.
  - On stop, saves `db.frames[key] = {point, relPoint, x, y}` and restores it on build. The strip uses `"strip", 0, -220` (`:149`).
  - `/wuk lock` toggles `db.locked`; `/wuk reset` wipes `db.frames` (`Core.lua:227-228`).
- **DEFAULTS** (`Core.lua:19`): `{locked=false, shown=true, frames={}, icons={}, minimapAngle=220, dockViewers=false, spin=true, collapse=true}`.
- **Settings window** (`WarlockUtilityKit/Settings.lua`):
  - Every control routes through the slash handler, `Run(cmd)` calling `SlashCmdList.WARLOCKUTILITYKIT` (`:6`).
  - Built lazily by `WUK.ToggleSettings` (`:68-71`); `/wuk config` opens it (`Core.lua:231`).
  - The window is `WUKSettings`, a 320×314 `BasicFrameTemplateWithInset` in DIALOG strata. It is draggable and listed in `UISpecialFrames` (`:19-25`).
  - `Check()` builds a `UICheckButtonTemplate` that re-syncs from a getter (`:8-16`).
  - Five checks, 28px apart: show, lock, dock, spin, collapse (`:28-36`).
  - Pet choice is a `WowStyle1DropdownTemplate` with radio items (`:42-50`).
  - Two `UIPanelButtonTemplate` buttons: reset and board (`:52-58`).
  - `Sync` runs on OnShow (`:60-64`).
  - There are no sliders or list editors.
- **Minimap button** (`Settings.lua:73-110`):
  - A 31px Button with an icon, `MiniMap-TrackingBorder` and the zoom highlight (`:74-80`).
  - Placed from `db.minimapAngle` at radius `Minimap:GetWidth()/2+8` (`:82-85`). Dragging uses an OnUpdate `atan2` of the cursor position (`:88-98`).
  - Left-click opens settings; right-click opens the board (`:100-102`).
- **TackleBox panel** (`TackleBox/Panel.lua`):
  - No settings window; `/tb` subcommands only (`Core.lua:237-247`).
  - `TBDock` is a 1×1 movable anchor that both the panel and the secure bar attach to, so the panel never anchors to a secure frame (`Panel.lua:18-26`). `TB.DockDrag` applies the same Shift/lock/combat guard (`:29-40`).
  - `TBPanel` is a BackdropTemplate frame skinned from `TB.THEME` (`:8-12`, `:43-60`).
  - 30 pooled rows (`:112-138`), lazily built tabs (`:142-160`), a `TB.sections` list (`:217-276`) and a `RenderPanel` that sizes the panel by row count (`:179-215`).
  - The minimap button is the same construction as WUK's (`:289-326`).

## Q5: Secure action buttons, combat deferral, bindings

### Findings
- **WUK stone buttons:** `type=macro` (`UI.lua:132`). `macrotext` comes from `WUK.StoneMacro(...)`, a pure function (`Logic.lua:26-36`), and is set in the refresher only when `not InCombatLockdown()` (`UI.lua:166-169`).
- **Armor and pet buttons:** `macrotext = "/cast "..spell` or `""`, inside the same combat guard (`Prep.lua:18,38`). Icon, desaturation and glow still update in combat.
- **Summon rows** (`Summon.lua:74-77`): `type1` and `ctrl-type1` are both `macro`.
  - `UpdateSummonRows` returns at once in combat (`:38-56`). Otherwise it sets `macrotext1 = "/target NAME\n/cast <ritual>"` and `ctrl-macrotext1 = "/target NAME"`, and shows or hides rows.
  - Right-click removal is a non-secure `HookScript("OnClick")` (`:80-82`).
- **Deferral model:** there is no pending queue. Each combat-gated block is skipped in combat and recomputed from current state when PLAYER_REGEN_ENABLED fires `Refresh` (`Core.lua:152`; comment at `Summon.lua:63`).
- **Other combat gates:** drag (`UI.lua:16`), `LayoutRing` (`:35`), `Target` (`:65`), `Step` (`:69`), `Animate` (`:84`), Dock (`Dock.lua:7`), and slash show/hide/dock/spin/collapse (`Core.lua:225,236,241`).
- **`WUK.CombatFreeze`:** see Q4 (`UI.lua:87-93`). It is the last placement of secure buttons before lockdown.
- **TackleBox `TBAction_<key>` buttons** (`TackleBox/Actions.lua:10-36`): `SecureActionButtonTemplate` buttons in `TBActionBar`, a plain UIParent frame anchored to `TB.Dock()`. The comment says this keeps the panel unprotected (`:3`, `:39-42`).
  - `Apply()` returns in combat (`:47-77`). Attributes per key:
    - pole: `macro "/equip item:ID"`
    - lure: `macro "/use item:ID\n/use 16"`
    - water: `type=item`
    - cast: `type=spell`
    - unusable: `type=nil`, with a greyed icon
  - It also sets the bar size and visibility.
  - The refresher builds `TB.actions` and calls `Apply()` (`:100-126`). The debounced Refresh on PLAYER_REGEN_ENABLED replays it (`Core.lua:58`; comment `Actions.lua:46`).
  - TB has no PLAYER_REGEN_DISABLED handler and no CombatFreeze equivalent.
- **Key bindings:** a repo-wide grep for `binding`, `SetOverride` and `Bindings` over `*.lua`, `*.xml` and `*.toc` finds nothing. There is no `Bindings.xml`. All secure buttons are mouse-click only (`RegisterForClicks("AnyUp","AnyDown")`).

## Q6: Logic.lua, tests, CI packaging

### Findings
- **Pure modules:** each `Logic.lua` opens `local ADDON, X = ...` and defines only `X.Fn` functions, with no frames or `C_*` calls.
  - WUK examples: `ClassifyItem` (`:9`), `MergeDefaults` (`:16-23`), `StoneMacro` (`:26-36`), `FormatTime` (`:38-40`), `RingPoint` (`:163-166`).
  - Helpers such as `MergeDefaults` and `FormatTime` are copied into each addon, not shared.
  - API callers pass game data in as arguments, for example `TackleBox/Panel.lua:237,262` passes `GetRealZoneText()` and a callback.
- **Runners:** the three `tests/run.lua` files share one skeleton.
  - Line 1 derives the addon dir from `arg[0]`.
  - A fresh table is created, and `assert(loadfile(dir.."/Logic.lua"))("WarlockUtilityKit", WUK)` passes the vararg namespace (`WarlockUtilityKit/tests/run.lua:2-3`). TB loads `Data.lua` first (`TackleBox/tests/run.lua:3-4`).
  - `eq(got,want,label)` raises an error with expected and got values (`run.lua:5-7`). WUK adds `near()` for floats (`WarlockUtilityKit/tests/run.lua:89-91`).
  - Tests are straight-line statements under `-- Phase N` comments; there is no framework and no WoW stubs.
  - Each ends `print("all tests passed")` (WUK:98, TB:90, PP:107). A failure throws, so the exit code is non-zero.
- **CI** (`.github/workflows/package-{wuk,tb,pp}.yml`):
  - Triggers on push to `main` filtered to the addon folder and the workflow file, plus `workflow_dispatch`. Permission is `contents: write`.
  - Steps:
    1. Checkout.
    2. Install lua5.1 via apt and run `lua5.1 <Addon>/tests/run.lua`.
    3. `sed` the `## Version:` from the TOC, failing if empty.
    4. `zip -r <Addon>-<ver>.zip <Addon> -x '<Addon>/tests/*'`. PP also excludes `tools/*` (`package-pp.yml:31`).
    5. `gh release upload --clobber` if the release exists, otherwise `gh release create <prefix>-v<ver> --generate-notes` (`package-wuk.yml:40-44`).
  - Tag prefixes are `wuk-v`, `tb-v` and `pp-v`. There are no tag triggers.
- **Current TOC versions:** WUK 0.3.0, TB 1.0.0, PP 0.2.1.
- **Changelogs:** `CHANGELOG.md` is hand-edited (`## [x.y.z] — date`, with Added and Changed sections). CI does not read it (`WarlockUtilityKit/CHANGELOG.md:3`).
- **READMEs:**
  - Install path is `_classic_beta_\Interface\AddOns\` (`WarlockUtilityKit/README.md:12`).
  - Test command: `README.md:166`.
  - CI note: bump `## Version` to cut a release (`:169`). TB (`README.md:74-77`) and PP (`README.md:111-115`) match.
  - Root `README.md:3` says one folder per addon, each with its own README, changelog and tag.
- **Deploy:** no robocopy command appears in code or READMEs. A robocopy deploy convention appears only in `thoughts/qrspi/2026-10-19-profession-leveling-planner/design.md:48`.

## Cross-Cutting Observations
- **One skeleton, three copies:** `On`, `inits`, `refreshers`, `Secret`, `MergeDefaults`, `<Name>DB`/`<Name>CharDB`, `Logic.lua` plus `tests/run.lua`, and a per-addon CI workflow. Nothing is shared at runtime; each addon has its own global namespace.
- **Combat model:** state is recomputed instead of queued.
  - Secure attribute writes are skipped under `InCombatLockdown()` and redone on the PLAYER_REGEN_ENABLED Refresh.
  - Texture and animation changes (glow, desaturation, counts) run freely in combat.
  - WUK also freezes its layout on PLAYER_REGEN_DISABLED.
- **Secret handling:** values are checked with `Secret()` before any compare. Risky APIs run under pcall. Probe output masks secrets as "SECRET".
- **Probe knowledge** is recorded in markdown files and code comments, not read at runtime.
- **Correlating casts with outcomes** uses module-level "last" variables plus a name or time match (WUK `lastCastTarget`, TB `lastChannel` and `lastLootT`). No GUID-based pairing exists.
- **Secure buttons are kept apart from movable/skinned UI:** TB parents them to a separate plain frame anchored to a dock; WUK parents them to the strip.

## Open Areas
- In-combat secrecy of the SENT `target`, `UnitGUID`/`UnitName`/`UnitIsDead` on enemy tokens, and `IsSpellUsable`/`IsSpellInRange`: R21 marks these unverified and no probe covers them.
- In-combat reads of player auras: no probe line records one, despite the TB comment at `Core.lua:67`.
- The repo has no examples of nameplate events, `SPELL_ACTIVATION_OVERLAY_GLOW_*`, `C_AssistedCombat`, `COMBAT_LOG_EVENT_UNFILTERED`, key or override bindings, or `castGUID` use, so their behavior on Forever cannot be answered from the codebase.
- `WarlockUtilityKit/Logic.lua` lines 41-162 were not read line by line; the claim that the file is pure rests on grep showing no API calls.
