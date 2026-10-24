# Research Findings

Paths are relative to the repo root. Web findings carry URLs instead of `file:line`.

## Q1: How do the existing addons read auras, on which units, with which filters, and what do the probe results record about aura fields on this client?

### Findings
- Every aura call site in the repo:
  - `WarlockUtilityKit/Core.lua:100` (`WUK.ReadPlayerBuffs`) calls `C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")` for i = 1..40, under `pcall`.
  - `WarlockUtilityKit/Core.lua:214` (probe) calls `C_UnitAuras.GetUnitAuras("target", "HARMFUL|PLAYER")`, under `pcall`.
  - `WarlockUtilityKit/Core.lua:219` (probe) calls `C_UnitAuras.GetAuraDuration("target", a.auraInstanceID)`, under `pcall`.
  - `TackleBox/Core.lua:68` (`TB.ReadAura`) calls `C_UnitAuras.GetPlayerAuraBySpellID(spellID)`, under `pcall`.
  - `TackleBox/Core.lua:196,202` (probe) reads player HELPFUL auras by index, then by spell ID, inside `Try` (a pcall, `:193`).
  - `WarlockCombatKit/Core.lua:285` (probe) calls `GetPlayerAuraBySpellID(17941)`.
- No code calls `UnitAura`, `UnitBuff`, `UnitDebuff`, `AuraUtil` or `GetDebuffDataByIndex`. No code reads auras on party, raid or nameplate units. The only non-player unit is `"target"`, and only in the WUK probe.
- In combat, both runtime readers return a cache instead of calling the API:
  - `WarlockUtilityKit/Core.lua:97` returns `WUK.buffCache` when `InCombatLockdown()`.
  - `TackleBox/Core.lua:67` returns `TB.auraState[spellID]`, with the comment "combat aura reads error on Forever".
  - The caches are refreshed out of combat on `PLAYER_REGEN_ENABLED` (`WarlockUtilityKit/Core.lua:156`, `TackleBox/Core.lua:58`).
- Aura fields the code reads:
  - `name`: `WarlockUtilityKit/Core.lua:103`, only when `not WUK.Secret(name)`.
  - `expirationTime`: `TackleBox/Core.lua:70`. If the value is secret, nil or 0, the function returns `{active=true}` with no remaining time (`:71`). Otherwise it returns remaining = `exp - GetTime()` (`:72`).
  - `spellId`: probe-only (`WarlockUtilityKit/Core.lua:220`, `TackleBox/Core.lua:198`).
  - `auraInstanceID`: probe-only (`WarlockUtilityKit/Core.lua:219`).
  - No code reads `duration`, `sourceUnit` or `applications`.
- WCK registers `UNIT_AURA` for the player only as a refresh trigger. `WarlockCombatKit/Core.lua:146` has the comment "event only; the aura payload is never read". WCK detects its proc through `C_Spell.GetSpellInfo(...).castTime` instead (`WarlockCombatKit/Core.lua:129-140`).
- Probe results:
  - Out of combat:
    - `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md:11`: `GetAuraDataByIndex` gave `1086 Demon Armor exp 717156.77`. spellId, name and expirationTime were plain values, not secret. `GetPlayerAuraBySpellID(1086)` returned the same expiration.
  - In combat:
    - Reading the player's own buffs (`GetAuraDataByIndex("player",…,"HELPFUL")`) raised the error "Auras cannot be accessed when secret while tainted by 'WarlockUtilityKit'" (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:46`).
    - Reading the player's own debuffs on an enemy (`GetUnitAuras("target","HARMFUL|PLAYER")`) raised the same error. This was in the open world (`thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md:14,24,28`).
    - `thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md:28` says "The API errors rather than returning secret values."
    - `GetPlayerAuraBySpellID(17941)` did not error, but it returned nil while the proc was apparently up. It also returned nil out of combat (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:170-185,203`).
  - Spell secrecy:
    - `C_Secrets` reported secrecy 2 (ContextuallySecret) for every probed warlock spell (`thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md:6`).
    - The probe probably returns 2 for any name, known or not (`thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md:8`).
    - `secrecy 17941: 2` (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:17`).
  - Not probed: auras on party or raid units, and the `duration`, `sourceUnit` and `applications` fields. The `GetAuraDuration` result was never recorded.

## Q2: How do the existing addons build party/raid unit lists and react to roster changes, and what events/throttling patterns refresh state?

### Findings
- Unit lists:
  - `WUK.GroupUnits` (`WarlockUtilityKit/Core.lua:117-122`) returns `raid1..N` (N = `GetNumGroupMembers`) when `IsInRaid()`. Otherwise it returns `party1..N` (N = `GetNumSubgroupMembers`). It does not add `"player"`. In a raid, the player's own raid slot is included.
  - `WUK.GroupWarlocks` (`WarlockUtilityKit/Core.lua:130-139`) filters that list by `select(2, UnitClass(u)) == "WARLOCK"`. The comment at `:134` says classFilename is never secret. It reads names through `UnitFull` (`:124-128`), which returns nil for a secret name and applies `Ambiguate(...,"none")`.
  - `RosterZone` (`WarlockUtilityKit/Summon.lua:7-13`) gets the zone from `GetRaidRosterInfo` in a raid only. The comment at `:8` says the zone is unknown for party members.
  - `Context` (`WarlockUtilityKit/Summon.lua:15-36`) reads `UnitIsConnected`, `UnitIsDeadOrGhost` and `UnitInRange`. If `UnitInRange` returns a secret value, the helper count becomes nil (`:30`).
- Chat channel choice:
  - `WarlockUtilityKit/Comm.lua:5-7` picks RAID, then PARTY.
  - `WarlockUtilityKit/Board.lua:76-77` uses RAID_WARNING when the player is leader or assistant.
- `GROUP_ROSTER_UPDATE` handlers:
  - `WarlockUtilityKit/Board.lua:175-182` tracks the `wasInGroup` transition. On leaving a group it clears the board. On joining it requests a sync. Otherwise it re-syncs the window if it is shown.
  - `WarlockUtilityKit/Summon.lua:88` calls `UpdateSummonRows`, which returns immediately in combat (`:39`).
- Every `UNIT_AURA` handler filters to `"player"` and only triggers a refresh:
  - `WarlockUtilityKit/Core.lua:158`
  - `TackleBox/Core.lua:74`
  - `WarlockCombatKit/Core.lua:146`
- WCK, TackleBox and ProfessionPlanner never call `IsInRaid`, `IsInGroup` or `GetNumGroupMembers`.
- Event plumbing (the same in every addon):
  - Each addon has one hidden frame, a `handlers[event]` list, and `X.On(event, fn)`.
  - `WarlockUtilityKit/Core.lua:10-17`, `TackleBox/Core.lua:8-15` and `ProfessionPlanner/Core.lua:7-12` follow this shape.
  - `WarlockCombatKit/Core.lua:9-20` also wraps `RegisterEvent` in `pcall` and returns false for unknown events.
- Refresh throttling:
  - WCK and TB debounce through a `pending` flag plus `C_Timer.After(0.1)` (`WarlockCombatKit/Core.lua:34-42`, `TackleBox/Core.lua:41-50`).
  - WUK `Refresh` is not debounced (`WarlockUtilityKit/Core.lua:141-145`).
- Tickers (`C_Timer.NewTicker`, created in inits and never cancelled):
  - WUK Comm flush, 0.25 s (`WarlockUtilityKit/Comm.lua:28`). Backoff on send failure: `min(30, 2^failures)`. Queue capped at 64.
  - WUK soulstone label, 1 s (`WarlockUtilityKit/Prep.lua:48`).
  - TB camp countdown, 1 s, refreshes only while a remaining time exists (`TackleBox/Core.lua:77-78`).
  - WCK dead-target sweep, 0.5 s (`WarlockCombatKit/Core.lua:229-236`).
- OnUpdate scripts:
  - `WarlockUtilityKit/UI.lua:68-80`: ring animation. It removes itself in combat.
  - `TackleBox/CastBar.lua:47-51`: cast bar.
  - Drag-only minimap-button OnUpdates: `WarlockUtilityKit/Settings.lua:90`, `WarlockCombatKit/Settings.lua:179`, `TackleBox/Panel.lua:306`.
- TTL patterns:
  - Summon and trade queues: 600 s (`WarlockUtilityKit/Summon.lua:2`, `WarlockUtilityKit/Trade.lua`).
  - Soulstone: `expires = time()+1800`, set from `UNIT_SPELLCAST_SUCCEEDED` (`WarlockUtilityKit/Prep.lua:42-47`).

## Q3: How is a typical addon structured end to end, and how are tests and packaging set up?

### Findings
- .toc: `WarlockCombatKit/WarlockCombatKit.toc:1-14` contains:
  - `## Interface: 16001`, Title, Notes, `## Version`, IconTexture.
  - `## SavedVariables: WarlockCombatKitDB` and `## SavedVariablesPerCharacter: WarlockCombatKitCharDB`.
  - Load order: `Data.lua Logic.lua Core.lua Actions.lua Panel.lua Settings.lua`.
  - `Bindings.xml` is not listed. The client loads it by file name.
- Other load orders: TackleBox `Data, Logic, Core, Actions, Panel, CastBar` (`TackleBox/TackleBox.toc:9-14`). WUK `Logic, Core, UI, Prep, Summon, Trade, Comm, Board, Dock, Settings` (`WarlockUtilityKit/WarlockUtilityKit.toc:9-18`).
- File roles:
  - `Data.lua`: static tables on `X.DATA`, no WoW calls (`WarlockCombatKit/Data.lua:1-25`).
  - `Logic.lua`: pure functions. It is the only tested code.
  - `Core.lua`: event dispatch, SavedVariables init, debounced refresh, game-state readers, probe and slash command.
  - `Actions.lua`: hidden secure buttons.
  - `Panel.lua`: non-secure visible UI.
  - `Settings.lua`: settings window and minimap button.
- Namespace:
  - Every file starts with `local ADDON, WCK = ...` (`WarlockCombatKit/Core.lua:1`).
  - Files add to `WCK.inits` (run once at PLAYER_LOGIN) and `WCK.refreshers` (run on each refresh) with `table.insert` (`WarlockCombatKit/Core.lua:3`, `WarlockCombatKit/Actions.lua:7,17`, `WarlockCombatKit/Panel.lua:112,231`).
  - Shared helpers: `Secret(v) = issecretvalue ~= nil and issecretvalue(v)` (`WarlockCombatKit/Core.lua:5`) and a coloured `Print` (`WarlockCombatKit/Core.lua:6`).
- SavedVariables:
  - `ADDON_LOADED` merges `DEFAULTS` and `CHAR_DEFAULTS` with `X.MergeDefaults` (`WarlockCombatKit/Core.lua:22-32`). The merge is recursive and replaces any non-table value with `{}` (`WarlockCombatKit/Logic.lua:3-10`).
  - Comment at `WarlockCombatKit/Core.lua:27`: "nil-safe: the Forever beta loader bug can leave these nil every session".
  - The same code exists in `TackleBox/Core.lua:17-26`, `WarlockUtilityKit/Core.lua:19-28` and `ProfessionPlanner/Core.lua:19-20`.
  - Lists are not merged. WCK sets rules only when `rules == nil` (`WarlockCombatKit/Core.lua:195-197`).
- Login gate:
  - WCK and WUK check `UnitClass` for WARLOCK, set `X.active`, then run the inits (`WarlockCombatKit/Core.lua:44-50`, `WarlockUtilityKit/Core.lua:147`).
  - TB has no class gate (`TackleBox/Core.lua:52-56`).
- Slash commands:
  - WCK: `SLASH_WARLOCKCOMBATKIT1="/wck"` with subcommands probe, lock, reset, config, show and hide (`WarlockCombatKit/Core.lua:337-347`).
  - TB: `/tb` (`TackleBox/Core.lua:237-247`).
  - WUK: `/wuk`. Some subcommands refuse in combat (`WarlockUtilityKit/Core.lua:225-248`). The settings window routes every option through the slash handler (`WarlockUtilityKit/Settings.lua:6`).
- Bindings (WCK only):
  - `WarlockCombatKit/Bindings.xml:1-8` declares `CLICK WCKCast1..6:LeftButton`.
  - Binding globals: `WarlockCombatKit/Actions.lua:3-4`.
  - Settings shows the bound key through `GetBindingKey` (`WarlockCombatKit/Settings.lua:116`).
- Frames:
  - `WCK.MakeMovable(f, key, x, y)` provides Shift+drag, gated by `db.locked` and `InCombatLockdown()`. It saves `{point, relPoint, x, y}` to `db.frames[key]` (`WarlockCombatKit/Panel.lua:8-21`). WUK has a copy at `WarlockUtilityKit/UI.lua:13-26`.
  - TB uses one movable dock anchor shared by the panel and the secure bar (`TackleBox/Panel.lua:18-40`).
  - Secure frames are never anchored to the non-secure panel, so the panel does not become protected in combat (`TackleBox/Panel.lua:16-17`, `WarlockCombatKit/Actions.lua:2`).
  - No addon has a scale option (no `SetScale`).
- Settings UI:
  - No addon uses `Settings.RegisterCanvasLayoutCategory` or `InterfaceOptions_AddCategory`.
  - WCK and WUK build a `BasicFrameTemplateWithInset` window, created lazily and added to `UISpecialFrames` (`WarlockCombatKit/Settings.lua:123-160`).
  - Checkboxes come from `WCK.Check` (`WarlockCombatKit/Settings.lua:6-14`).
  - Dropdowns use `WowStyle1DropdownTemplate` and `SetupMenu` (`WarlockCombatKit/Settings.lua:33-40`).
  - Extra sections plug in through `WCK.settingsSections`.
  - The minimap button saves `db.minimapAngle` (`WarlockCombatKit/Settings.lua:162-199`).
- Combat lockdown:
  - Secure attributes are set only out of combat, and `PLAYER_REGEN_ENABLED` re-runs Refresh (`WarlockCombatKit/Core.lua:51`, `WarlockCombatKit/Actions.lua:17-19`, `TackleBox/Actions.lua:46-48`).
  - WUK uses `PLAYER_REGEN_DISABLED` to place its secure buttons one last time before lockdown. The comment says the event "fires before lockdown" (`WarlockUtilityKit/UI.lua:87-93`).
  - The non-secure panel redraws freely in combat (`WarlockCombatKit/Panel.lua:3`).
- Tests:
  - Each addon has its own `<Addon>/tests/run.lua`. There are no WoW API stubs.
  - The test loads only `Data.lua` and `Logic.lua` through `loadfile(dir.."/X.lua")(ADDON, ns)` (`WarlockCombatKit/tests/run.lua:1-4`).
  - Helpers are `eq` and `near`. The file ends with `print("all tests passed")` (`WarlockCombatKit/tests/run.lua:78`).
  - Run as `lua5.1 WarlockCombatKit/tests/run.lua`.
- CI (`.github/workflows/package-wck.yml`, with identical siblings for wuk, tb and pp):
  - Trigger: a push to main that touches the addon's folder or its workflow file, plus `workflow_dispatch`.
  - Steps:
    1. Install lua5.1 and run the tests.
    2. Read `## Version` from the .toc with sed.
    3. Zip the folder, excluding `tests/*`.
    4. Run `gh release create` or `gh release upload --clobber` with tag `<prefix>-v<version>` (wck-, wuk-, tb- or pp-).
- Repo README lists each addon with its release tag prefix (`README.md:5-8`).

## Q4: How do WCK and WUK handle spell data, cooldowns, secure buttons/click-casting, and cast or combat-log events?

### Findings
- Neither addon stores spell IDs by rank. Both refer to spells by enUS name.
- WCK name lookups:
  - `WarlockCombatKit/Data.lua:3` has the comment "enUS names; … unknown ones are skipped at login".
  - Tables: `tracked` (`WarlockCombatKit/Data.lua:5-17`), `rotation` and `defaultRules` (`WarlockCombatKit/Data.lua:20-28`) and `procs` (`WarlockCombatKit/Data.lua:34-36`).
- WUK name lookups:
  - The `SPELLS` table lists names highest rank first, and the first known name wins (`WarlockUtilityKit/Core.lua:46-62`).
  - Ranks that share a name are cast as `/cast Name`, which uses the highest rank (`WarlockUtilityKit/Core.lua:47`).
- Resolving whether a spell is known:
  - WUK scans the spellbook through `C_SpellBook.GetSpellBookItemName`, with a fallback to `GetSpellTabInfo` (`WarlockUtilityKit/Core.lua:64-85`). `ScanSpells` runs at PLAYER_LOGIN and on `SPELLS_CHANGED` (`WarlockUtilityKit/Core.lua:87-93,151,157`).
  - WCK uses `WCK.Known(name)`, which calls `pcall(C_Spell.GetSpellInfo, name)` and then `IsPlayerSpell(info.spellID)` (`WarlockCombatKit/Core.lua:153-156`).
  - ID to name: `X.SpellName(id)` returns nil for a secret ID (`WarlockCombatKit/Core.lua:113-117`, `WarlockUtilityKit/Core.lua:164-168`).
- Cooldown and usability (WCK only):
  - `pcall(C_Spell.GetSpellCooldown, name)`. The ready flag is `not cd.isActive or cd.isOnGCD == true`, used only when neither value is secret (`WarlockCombatKit/Core.lua:163-166`).
  - `C_Spell.IsSpellUsable` is gated by `WCK.USABLE_OK` (`WarlockCombatKit/Core.lua:151,167-170`).
  - Probe:
    - `isActive` and `isEnabled` are non-secret.
    - `isOnGCD` is plain nil.
    - `startTime` is SECRET (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:42`).
    - `IsSpellUsable` and `IsSpellInRange` are non-secret in the open world (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:41,205`).
  - Refresh events: `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_USABLE`, `PLAYER_TALENT_UPDATE`, `PLAYER_TARGET_CHANGED` (`WarlockCombatKit/Core.lua:147-148,185-187`).
- Secure buttons (all `SecureActionButtonTemplate`, `type="macro"`, `macrotext` set only out of combat):
  - WCK: six hidden `WCKCast1..6` buttons on a `UIParent` holder (`WarlockCombatKit/Actions.lua:8-13`). Their macrotext comes from `WCK.CastMacro`: `/cast [@mouseover,harm,nodead][] <Spell>` (`WarlockCombatKit/Logic.lua:135-140`).
  - WUK armor and pet buttons: `WarlockUtilityKit/Prep.lua:5-8,18,24-38`.
  - WUK stone buttons: `WarlockUtilityKit/UI.lua:128-133,166-168` and `WarlockUtilityKit/Logic.lua:26-36`. The macro uses `/use [@<target>] item:<id>` or `[help]` conditionals.
  - WUK summon rows set `type1` and `ctrl-type1` to `"macro"`, with `macrotext1 = "/target X\n/cast Ritual"` (`WarlockUtilityKit/Summon.lua:39-47,74-77`).
  - No `unit` or `spell` attribute is used anywhere. No addon has unit-frame click-casting. The only unit targeting is through macro conditionals.
- Cast events:
  - WCK `UNIT_SPELLCAST_SENT` reads target, castGUID and spellID, which are all non-secret (`WarlockCombatKit/Core.lua:199-208`, `thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:37`).
  - SENT and SUCCEEDED are paired by castGUID (`WarlockCombatKit/Core.lua:210`, `thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:38`).
  - Self-cast SENT has target nil (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:70`).
  - Instant casts deliver SENT and SUCCEEDED in the same frame (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:97`).
  - One interrupt can fire INTERRUPTED up to 4 times (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:39-40`).
  - WUK stores `lastCastTarget` from SENT (`WarlockUtilityKit/Core.lua:161-163`). It uses SUCCEEDED for the soulstone TTL (`WarlockUtilityKit/Prep.lua:42-47`) and for summon completion (`WarlockUtilityKit/Summon.lua:89-93`).
- Combat log:
  - No addon registers `COMBAT_LOG_EVENT_UNFILTERED`.
  - Registering it brings up the client's blocked-action prompt ("disable addon?"), even though `pcall` returns ok (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:6,206`, `WarlockCombatKit/Core.lua:304`).
- Other probe facts:
  - `GetRaidTargetIndex` is secret in combat when a mark is set (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:128`).
  - `C_CooldownViewer` exists, and its frames (`BuffIconCooldownViewer` and the others) exist and are shown (`thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md:17-25`).

## Q5: What community priest/healer addons exist for classic-era / Forever clients, which work on Forever, and what does each cover or miss?

### Findings
- Platform:
  - Forever runs on the Midnight retail client with Interface 16001. Classic-era addons do not load.
  - Retail secret-value restrictions apply: the combat log is closed, and auras, health and threat are secret in combat (https://kami-labs.fr/en/addons-wow-forever/).
  - The PRD says the same (`WoW Forever Addon Ideas — PRD.md:7,15-16`).
- Compatibility per the kami-labs aggregator (single source; per-addon pages not checked):
  - **Reported working:**
    - VuhDo ("same file as Retail").
    - Grid2 (4.1.7-forever).
    - HealBot Continued (26.10.16).
    - Healium.
    - Danders Frames, Aptechka and Decursive.
    - Details! (meter only).
  - **Contradicted:** the same page's ClickMend entry quotes its author saying VuhDo and HealBot "did not yet work on Forever".
  - **Partial:** Clique (alpha builds only).
  - **Broken:**
    - Cell ("No Forever flavor").
    - WeakAuras (no Forever or Midnight version). The page suggests alternatives: ForeverAuras (no page found), Musca Auras, or the native Cooldown Manager.
    - OmniBar and BigDebuffs.
  - **Forever ports:**
    - X-Perl Forever unit frames (https://www.curseforge.com/wow/addons/x-perl-unitframes-forever).
    - SharedForeverUI2 library (https://www.curseforge.com/wow/addons/sharedforeverui2).
- Built into the Blizzard client:
  - Click Casting, in the key-binding options (per kami-labs; verify in game).
  - The Cooldown Manager, which tracks cooldowns and buffs (https://warcraft.wiki.gg/wiki/Cooldown_Manager). No source showed it tracking Weakened Soul or other debuffs on group members.
- Not found for Forever or classic-era clients:
  - A dedicated Weakened Soul or Power Word: Shield tracker.
  - Buffomat, SmartBuff and ClassicRaidBuffs.
  - Trackers for Power Infusion, Fear Ward, Inner Fire, Fortitude, Divine Spirit and Shadow Protection.
  - FiveSecondRule or another mana-regen tracker.
  - Spirit Tap, Inspiration and Renew trackers.
  - LibHealComm.
  - One unrelated CurseForge priest addon surfaced: HealingPriorityMouse (Atonement counting). It has no Forever evidence.
- The PRD's existing gap survey covers no priest or healer addons (`WoW Forever Addon Ideas — PRD.md:133-138,210-211`).

## Q6: What priest mechanics apply on Forever, and how do the spell IDs show up via the client's APIs?

### Findings
- Forever-specific (Blizzard deep dive, beta numbers: https://worldofwarcraft.blizzard.com/news/24301514):
  - **Soul Warding:** a new 16-point talent. It reduces the cooldown and mana cost of Power Word: Shield and requires Improved PW:S. One guide gives −4 s cooldown and −15% mana (https://www.warcrafttavern.com/forever/news/rage-will-benefit-from-crit-priest-warrior-deep-dive-for-wow-forever/).
  - **Renewed Hope:** requires Soul Warding. It adds crit chance to several heals, including Penance, on targets that have Weakened Soul. Those heals also *shorten* Weakened Soul on the target.
  - **Penance:** a 21-point talent. 2 s channel, 12 s cooldown, heals or damages each second.
  - **Improved PW:S:** a guide gives +7% absorb per rank.
  - **Divine Spirit:** baseline at level 30. Improved Fortitude and Improved Divine Spirit became baseline.
  - **Inner Fire:** higher armor and more charges.
  - **Fear Ward:** baseline for all priests at level 20. 3 min duration and 3 min cooldown (https://www.warcrafttavern.com/forever/news/priest-racials-in-world-of-warcraft-forever-fear-ward-is-baseline/).
  - **Racials:**
    - Human Divine Grace: heals an ally below 50% health and removes Weakened Soul. Cannot be cast on self.
    - Dwarf: Chastise and Desperate Prayer.
    - Gnome: Confounding Flash and Contingency Plan.
  - **Beta fix:** "Power Word: Shield can now always overwrite an existing Power Word: Shield on a target that does not have Weakened Soul" (https://www.warcrafttavern.com/forever/news/wow-forever-beta-update-bug-fixes-class-changes-gamepad-support/).
  - **Other changes:** Renew can crit, Inner Focus no longer boosts periodic crit, and Dual Specialization unlocks at level 40.
  - **Level cap:** 30 during the beta (https://www.pcgames.de/World-of-Warcraft-Spiel-42971/News/WoW-Forever-Patch-Notes-Level-30-Update-1555574/). Launch per the PRD: 2026-11-04 (`WoW Forever Addon Ideas — PRD.md:7`).
  - **Runes:** no source mentions SoD-style runes. Penance is a talent here.
- Classic-era reference values (may not match Forever):
  - Weakened Soul: spell 6788, 15 s (https://www.wowhead.com/classic/spell=6788/weakened-soul).
  - PW:S rank 1: spell 17, 45 mana, 44 absorb, 30 s duration, 4 s cooldown (https://www.wowhead.com/classic/spell=17/power-word-shield).
  - Other rank IDs (592, 600, 3747, 6065, 6066, 10898-10901) are unverified.
- Not found:
  - The Weakened Soul duration on Forever.
  - Forever spell IDs.
  - Details on Inner Focus, Power Infusion, Spirit Tap and Shadow Protection.
- API behaviour for priest spells:
  - Not probed in this repo.
  - Spell-secrecy probes on other classes returned 2 for every name (`thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md:6-8`).
  - Name lookup through `C_Spell.GetSpellInfo` plus `IsPlayerSpell` is the working pattern (`WarlockCombatKit/Core.lua:153-156`).

## Q7: What do the root PRD and README say about planned addons, conventions or constraints?

### Findings
- The PRD lists 7 ideas: the warlock utility kit, the profession planner, a Legacy tracker, a campsite helper, a craft order board, guild inventory (integrate GuildStock rather than build) and a gathering log (`WoW Forever Addon Ideas — PRD.md:25-160`). No priest or healer idea appears.
- Platform constraints (`WoW Forever Addon Ideas — PRD.md:13-21`):
  - Retail-style APIs.
  - Midnight secrets: combat-time values such as aura durations may be opaque. The PRD's guidance is to "favor out-of-combat, planning, inventory and coordination features".
  - The SavedVariables loader bug (ForeverSVFix).
  - Trial accounts cannot send addon messages.
- Warlock non-goals: "execute-range alerts, rotation helpers, anything needing enemy health or cast timing" (`WoW Forever Addon Ideas — PRD.md:40`). DoT timers depend on beta confirming aura data is not secret (`WoW Forever Addon Ideas — PRD.md:38`).
- The build order calls for a shared core library: addon-message transport, whisper parser, queue model, options panel, SavedVariables wrapper (`WoW Forever Addon Ideas — PRD.md:178`). Packaging: one CurseForge project per idea, with the core embedded as a lib (`WoW Forever Addon Ideas — PRD.md:185`). In the repo today, no shared lib exists. Each addon is standalone (no `Libs/`, no LibStub).
- Open question: "Which unit and aura values are secret in Forever" (`WoW Forever Addon Ideas — PRD.md:191`).
- README: one folder per addon, each with a README, a CHANGELOG and a release tag prefix (`README.md:3-8`).

## Cross-Cutting Observations
- Aura access is the main recorded platform limit:
  - Out of combat, player auras return plain fields.
  - In combat, addon-tainted reads of the player's buffs and of the target's debuffs *error*.
  - `GetPlayerAuraBySpellID` returns nil instead of erroring.
  - Every runtime reader caches out of combat and serves the cache in combat.
  - Party and raid aura reads have never been probed.
- Signals recorded as non-secret in combat:
  - `UNIT_SPELLCAST_SENT` and `UNIT_SPELLCAST_SUCCEEDED` payloads (target name, castGUID, spellID).
  - `C_Spell.IsSpellUsable` and `IsSpellInRange`.
  - The cooldown fields `isActive` and `isEnabled`.
  - `UnitClass`.
  - `UnitIsDead` on nameplate removal.
- Signals recorded as secret or blocked:
  - The cooldown field `startTime`.
  - A set raid mark.
  - CLEU registration.
  - Aura payloads in combat.
- Every addon uses the same conventions:
  - `local ADDON, X = ...` namespace.
  - `inits` and `refreshers` lists.
  - `X.On` event table.
  - `MergeDefaults` SavedVariables.
  - Secure buttons out of combat only, re-applied on REGEN_ENABLED.
  - Non-secure panels.
  - `MakeMovable` with Shift+drag.
  - Hand-built settings window plus minimap button.
  - Lua 5.1 tests on `Logic.lua` only.
  - Per-addon CI release tag.
- Every addon has a `/x probe` slash command. Probe output becomes `thoughts/qrspi/<id>/probe-results.md` with run numbers.

## Open Areas
- Whether `C_UnitAuras` reads on `party`, `raid` or `mouseover` units error, return secrets, or work, both in and out of combat. Specifically, whether a HARMFUL read of another player's Weakened Soul is allowed.
- Whether `UNIT_AURA` fires for group units on this client, and whether its `updateInfo` payload is readable.
- Weakened Soul and Power Word: Shield spell IDs and durations on Forever, and how Renewed Hope's shortening shows up.
- Whether Blizzard default raid frames, the Cooldown Manager or Click Casting already display Weakened Soul or group debuffs.
- Per-addon compatibility evidence on Forever, beyond the kami-labs aggregator. The ClickMend quote contradicts it on VuhDo and HealBot.
- How `UnitPower(…, Enum.PowerType.Mana)` behaves in combat. No addon reads mana.
