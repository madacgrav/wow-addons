# Design Discussion

## Current State
- The repo ships two addons, ProfessionPlanner (PP) and WarlockUtilityKit (WUK). Neither has any fishing code (research Q1, Q2).
- Both use the same skeleton:
  - `local ADDON, X = ...` namespace (`Core.lua:1`).
  - An `On()` dispatcher (`WUK/Core.lua:10-17`), plus `inits` and `refreshers` (`WUK/Core.lua:3`, `:137-141`).
  - Nil-safe `MergeDefaults` at ADDON_LOADED (`WUK/Core.lua:19-28`, `WUK/Logic.lua:16`).
  - Pure `Logic.lua`, tested by `tests/run.lua` under lua5.1 with no stubs (`WUK/tests/run.lua:2-3`).
  - A CI workflow per addon: test, zip, release tag `<prefix>-v<ver>` (`.github/workflows/package-wuk.yml:18-39`).
- WUK provides the UI pieces this design needs:
  - `MakeMovable` (`WUK/UI.lua:13-26`)
  - a hand-built minimap button (`WUK/Settings.lua:73-110`)
  - `SecureActionButtonTemplate` macro buttons (`WUK/UI.lua:128-133`)
  - combat guards with re-apply on `PLAYER_REGEN_ENABLED` (`WUK/Core.lua:152`, `Summon.lua:63`)
- Every repo addon ran an in-game `/x probe` before its data was written. Results went to SavedVariables, then `probe-results.md` (`PP/Core.lua:197`, `WUK/Core.lua:170`). Forever has differed from the wiki several times (research Cross-Cutting).
- Forever fishing facts so far:
  - The fishing mechanics come only from third-party beta guides, with no IDs (research Q4).
  - Fishing is SkillLine 356 (research Q6).
  - The wiki lists these on 1.60.1 with no secret predicates (research Q5): `IsFishingLoot`, `LOOT_READY`, `GetLootSlotInfo`, `GetProfessionInfoBySkillLineID`, `C_Item.GetItemCount`.
  - Aura APIs are restricted in combat (WUK probe, research Q2).

## Desired End State
A third addon, **TackleBox** (`TackleBox/`, namespace `TB`, slash `/tb`, CI tag `tb-v<ver>`), ships with four features:

1. **Camp buffs.** The panel shows whether a Campsite Fishing Rack / Fishing Hut buff is active and how long it has left. It also shows the current fishing skill against the unlock skill of each buff.
2. **Water-walking.** When a water-walking item is in the bags and its buff is not active, the panel shows a one-click secure button to use it. Covers Surfer Shoes and Draught of Waterwalking.
3. **Quest fish.** Each of the four Artisan quest fish shows have/need counts (bags + bank) and a zone hint.
4. **Fish collection.** Each fish catch is recorded per character, grouped by quality tier (Uncommon / Rare / Unique). The panel lists caught vs known fish and the Chef's Knife product for Unique fish.
5. **Where to fish.** Using the current fishing skill (including modifiers), the panel shows:
   - the recommended zones for that skill band
   - the skill at which each zone stops losing fish
   - whether a lure is needed, and which one
   - a "you've outgrown this zone" note when the current zone is below the band
   
   Zone and lure data comes from the prior survey's bands and lure values (research Q4).
6. **Cast timer bar and "got away" flash.**
   - **Cast bar.** A small movable bar counts down the current fishing cast.
   - **Flash.** When a cast ends with no loot, the screen edge flashes briefly and a per-session "got away" counter increments.
   - **Not a bite alert.** This is purely informational. It never fires on a bite, because there is no bite signal to fire on.

Shared shell:
- Movable panel with a minimap button and `/tb` toggle.
- `/tb probe` dumps the IDs and runtime facts the data needs to `TackleBoxDB.lastProbe`.

**Verification**
- `lua5.1 TackleBox/tests/run.lua` passes. It covers the Logic functions:
  - buff state and time formatting
  - collection merge and tier grouping
  - quest-fish progress
  - the water-walk "needs reminder" predicate
- A probe run on the current Forever client fills `probe-results.md` in this directory. Every ID in `Data.lua` traces to a probe line.
- In game:
  - The panel shows correct skill.
  - A camp buff appears when standing at a Rack.
  - Catching a fish adds it to the collection.
  - The water-walk button uses the item out of combat.
  - Nothing errors in combat.
- CI publishes `TackleBox-<ver>.zip` under tag `tb-v<ver>`.

## Patterns to Follow
- **Namespace and dispatcher.** Copy WUK's `On()`, `inits`/`refreshers`, `Refresh` and `Print` (`WUK/Core.lua:3-17`, `:137-141`). Gate `Refresh` on `TB.active`, which is set at PLAYER_LOGIN when the character has Fishing.
- **SavedVariables.**
  - `TackleBoxDB`: account-wide frames, minimap angle, `lastProbe`.
  - `TackleBoxCharDB`: per-character catches, plus skill last seen.
  - Both go through nil-safe `MergeDefaults` (`WUK/Core.lua:24-27`). Keep the "Forever beta loader bug" comment.
- **Pure Logic plus tests.** All decisions go in `Logic.lua` as pure functions over plain tables: buff-remaining text, collection grouping, quest progress, reminder predicate. `Core.lua` only gathers API values into those tables. Test with `loadfile(dir.."/Logic.lua")("TackleBox", TB)` (`WUK/tests/run.lua:2-3`).
- **Static data in `Data.lua`.** Hand-written for v1 (see decision 2), loaded before Logic like PP (`ProfessionPlanner.toc:10-13`). Each entry carries a `-- probe:` comment.
- **Secret guard.** `TB.Secret(v)` copied from `WUK/Core.lua:7`. Apply it to every aura field before comparing.
- **UI pieces.**
  - `MakeMovable` (`WUK/UI.lua:13-26`).
  - `BasicFrameTemplateWithInset` panel with pre-built rows rendered from a `{header, rows}` view (`PP/Panel.lua:5-37`, `:74-94`).
  - Minimap button (`WUK/Settings.lua:73-110`).
- **Secure button.** The water-walk button uses `SecureActionButtonTemplate` with `type=item` (`WUK/UI.lua:128-133`).
  - Its attributes are set only when `not InCombatLockdown()`.
  - `PLAYER_REGEN_ENABLED` then runs `Refresh` to re-apply (`WUK/Core.lua:152`).
- **Probe command.** Follows `/wuk probe` (`WUK/Core.lua:170-219`): a `P()` helper, pcall around uncertain calls, output saved to the DB.
- **CI.** Copy `package-wuk.yml` with the paths filter, tests step, `tb-v` tag, and a zip that excludes `tests/*`.
- **Docs.** `README.md` and `CHANGELOG.md` with the same sections as WUK (research Q1 Docs).

**Do NOT follow:**
- **PP's open-window-only skill read** (`PP/Core.lua:27-33`). Use `GetProfessions()` with `GetProfessionInfo(fishing)` instead, so the skill shows without the Professions window open.
- **WUK's unguarded aura loop by name** (`WUK/Core.lua:95-104`). Read by spell ID with `C_UnitAuras.GetPlayerAuraBySpellID`, and skip it entirely while `InCombatLockdown()`, since in-combat aura reads errored (research Q2).
- **The `UNIT_AURA` + always-on bag rescan on every event** (`WUK/Core.lua:137-141`, `:151-154`). Throttle with PP's pending-flag `C_Timer.After` debounce (`PP/Panel.lua:136-137`), because fishing triggers frequent bag updates.

## Design Decisions
1. **Scope: the readable-now subset.** v1 ships camp buffs, water-walking, quest fish and the fish collection. Each needs only buff, bag, skill and loot reads, all listed for 1.60.1. The tournament and the Legacy talents are deferred (see NOT Doing).
2. **IDs: probe, then hardcode.**
   - `/tb probe` scans for fishing-related data and writes it to `TackleBoxDB.lastProbe`:
     - player auras
     - bag items, with ID, name, quality, class and subclass
     - the fishing profession info
     - the fishing spell
     - the `IsFishingLoot` existence check
     - the last loot window's slots
   - IDs from the probe are pasted into `Data.lua`.
   - No DB2 generator for v1; the four lists are small. The current Forever client is available, so the probe runs before data is written.
3. **Catch detection.**
   - On `LOOT_READY`, read the slots with `GetLootSlotInfo` and `GetLootSlotLink` for the item ID.
   - Record only if:
     - `IsFishingLoot` exists and is true,
     - or, as a fallback, the player's last `UNIT_SPELLCAST_CHANNEL_START` was the fishing spell within ~30s.
   - The probe decides which path is real. Both are about 3 lines, so both get coded.
4. **Fish tiers.** Taken from the item quality the loot slot reports (Uncommon 2, Rare 3). "Unique" is a `Data.lua` list, since its quality is unknown. Known-fish lists come from `Data.lua`. Catches of fish not in the list still record and display as "other".
5. **Camp buffs.**
   - `Data.lua` maps buff spell ID → {name, unlockSkill}.
   - Read with `GetPlayerAuraBySpellID`, out of combat only, refreshed on `UNIT_AURA` (player) through the debounce.
   - Time left uses `expirationTime - GetTime()`. If the value is secret, show "active" with no timer.
6. **Water-walking.**
   - One secure button bound to the first water-walk item present (`Data.lua` list), using `type=item, item=item:<id>`.
   - Shown when the item is present, no water-walk aura is active and the player is out of combat.
   - The button is player-clicked only. Nothing auto-uses an item, consistent with Forever's "every cast needs player input" policy (prior survey).
7. **Quest fish.** `Data.lua` lists {itemID, need, zoneHint}. Counts use `C_Item.GetItemCount(id, true)`, which the PP probe confirmed counts the bank (research Q2).
8. **UI.**
   - One movable panel with four sections (Camp, Water, Quest fish, Collection).
   - Collapsible headers; the collapsed state is stored in the DB.
   - Minimap button: left-click toggles the panel, right-click prints the status line.
   - `/tb` takes `show|hide|lock|reset|probe`.
   - No settings window in v1. Slash commands cover the options.
9. **No shared library.** Copy the helpers per the repo convention (research Cross-Cutting). Extracting a lib touches two shipped addons for no v1 gain.
10. **Where to fish.**
   - **Data.** `Data.lua` holds a hand-written `zones` list with `{name, min, noLoss, max, lure?}`, plus a `lures` list with `{itemID, bonus}`. Sources are research Q4 (`gaps/research.md:71-73`).
   - **Skill.** Uses `skillLevel + skillModifier`, so lures, poles and gear count toward the band. Zone match uses `GetRealZoneText`.
   - **Catch logging.** Each catch also logs its zone/subzone into `catches[id].zones`. This builds our own catch-location data, which later can show "caught here" per fish.
   - **Verification.** The zone bands come from beta guides, so the probe phase checks them against observed get-away rates.
11. **Cast bar and got-away.**
   - **Cast bar.**
     - Driven by `UNIT_SPELLCAST_CHANNEL_START`/`STOP` for the player and the fishing spell. The spell ID comes from the probe.
     - Duration comes from `UnitChannelInfo("player")` `startTime`/`endTime`. If those values are secret, it falls back to a probed fixed duration.
     - The bar is a `StatusBar` with an `OnUpdate` that is removed when idle, as in WUK's animator (`WUK/UI.lua:68-85`). It is positioned with `MakeMovable`.
   - **Got-away detection.**
     - On `CHANNEL_STOP`, wait 1s with `C_Timer.After(1)`.
     - If no fishing `LOOT_READY` arrived since the stop, count it as a miss.
     - Interrupts by movement or jumping also count as misses. This is accepted, since they are still lost casts.
   - **Flash.**
     - A full-screen edge texture with an alpha animation group (`WUK/UI.lua:96-110`).
     - It plays no sound. The user's casting addon handles the splash.
     - Toggled with `/tb flash`; defaults on.
   - **Combat.** All of this is non-secure UI, so it is safe in combat.
12. **Name.** TackleBox / `TB` / `/tb`. Rename now if the name is taken on CurseForge; the risk is listed below.

## What We're NOT Doing
- **No automatic casting features:** no one-key or double-click cast, no auto-applied lure, no automatic weapon swap, no soft-target CVar changes, no bite or splash sound.
  - **Amended 2026-10-22 at the user's request:** a player-clicked fishing action bar was added. It has four buttons: equip pole, apply best lure, water-walk and cast.
  - Each click is one secure action.
  - It lives on its own UIParent frame, `TBActionBar`, which replaces the standalone water button.
- **No Stranglethorn tournament timer or coin vendor list.** The schedule is unverified on Forever and the calendar exposure was not found (research Q5). Revisit after launch.
- **No Legacy talent progress.** No API was found and the TraitTree rows are untitled (research Q5, Q6).
- **No published catch tables per pool.** "Where to fish" covers skill bands only. Per-fish location comes from the addon's own logged catches.
- **No bite alert of any kind, sound or visual.** The client exposes no bite event to addons (research Q4 `gaps/research.md:105`). The cast bar shows elapsed time only. It never claims a bite.
- **No DB2 generator script**, no localisation beyond the client's own names, no settings window, no LibDBIcon or other libs.
- **No changes to PP or WUK.**

## Open Risks
- **Probe could contradict the guides.** Rack/Hut may not be player auras. They could be an area effect or a hidden aura. Fallback: detect by `GetSubZoneText` or by a nearby object; this decision is revisited after the probe.
- **`IsFishingLoot` may be missing** (the wiki and the FB fork conflict). The channel-time fallback covers it but could misfile pool loot from other channels. Low impact.
- **Out-of-combat aura reads** could still return secret values (all spells reported secrecy 2 in the WUK probe). In that case only "active, no timer" is possible, or the camp-buff feature degrades to a skill/unlock display.
- **Unique fish and the Chef's Knife** may be absent from the current client, or named differently than the guides say. That section then ships empty until data exists.
- **Item use limits:** `type=item` secure buttons may be restricted under Midnight disarmament. The probe should test a secure item click on the Draught.
- **Name clash:** TackleBox may already exist on CurseForge or Wago; check before the first release.
- **Data drift:** IDs are pinned to the probed build. A launch build could change them; re-probe on launch day.
