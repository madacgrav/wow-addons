# Design Discussion

## Current State
- **WoW Forever** is a Mainline 12.x client with Classic-era warlock content. The Midnight "secrets" restrictions are active (`research.md` Q2, Q4).
  - Own debuffs on enemies error when read in combat (`thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md:14`).
  - No warlock spell is whitelisted as non-secret.
  - The combat log is blocked on Mainline; Forever status is unknown.
- **Readable in combat** (documented; Forever runtime partly unverified):
  - Player and pet casts.
  - Cooldown flags `isActive`/`isOnGCD`.
  - Cooldown Manager (CDM) category sets (probe `:18`).
  - `mouseover` comparisons.
  - Raid marks on target (probe `:13`).
- **Unverified on Forever** (`research.md` Open Areas):
  - Proc overlay events (`SPELL_ACTIVATION_OVERLAY_*`).
  - The SENT `target` name in combat.
  - `IsSpellUsable`/`IsSpellInRange` returns.
  - Nameplate decoration.
  - `C_AssistedCombat` warlock rotation.
  - Unit identity (GUID, mark, name) in instances.
- **Existing addons** (`research.md` Q1, Q2, Q5, Q7, Q9):
  - Forever warlock addons (Necrosis all-version, Dark Ritual) are utility-first and claim DoT timers with unknown in-combat behavior.
  - Hekili is dead on Midnight. Replacements only skin `C_AssistedCombat`.
  - No addon shows "my casts across multiple enemies" on Midnight or Forever. Nearest: DreadPlagueTracker (one debuff, about 95% accurate) and DodoNameplate (Blizzard categories only).
- **WUK** (`WarlockUtilityKit/`) already covers out-of-combat utility: stones, armor, pet, soulstone timer, summon queue, healthstone trade, curse/banish assignment board, CDM dock. It is the visual and code reference (`research.md` Q8).

## Desired End State
A separate addon, **Warlock Combat Kit (WCK)**, in `WarlockCombatKit/`, with interface 16001, that assists *during* combat:

1. **Cast map: "what I cast, and where".**
   - Built from the player's own cast events (SENT pairs with SUCCEEDED via `castGUID`).
   - Records spell, target identity, time and the player's cast sequence per enemy for DoTs, curses, Banes, Fear, Banish, Seduction, Death Coil and Howl.
   - Shown as a compact panel: one row per enemy, keyed by raid mark, then name, then "target".
   - Each row shows icons of what was cast on that enemy. Icons fade with age, with no exact countdowns (task: not timer length).
   - Rows clear on death/despawn when detectable, otherwise on leaving combat.
2. **Feared/CC'd mob highlighting.**
   - In the panel: CC rows get a distinct purple glow.
   - Optional nameplate glow or marker for feared mobs, enabled only when the probe proves decorating enemy nameplates is allowed in that context.
3. **Rotation helper.**
   - A next-spell icon at the ring core, chosen from a user-defined priority list in settings.
   - Rule conditions use only non-secret inputs: cooldown ready, usable (if the probe passes), "not cast on current target within N s" (from the cast map), proc active, target has mark.
   - Optional fallback: Blizzard's `C_AssistedCombat.GetNextCastSpell` when no rule matches.
   - Display only: the player presses their own key.
4. **Proc alerts.** On-screen alert (icon, pulse, optional sound) for Nightfall/Shadow Trance and other procs, from `SPELL_ACTIVATION_OVERLAY_*` or `GetSpellAuraSecrecy`-gated aura reads. The fallback is GlowWatcher-style reaction to Blizzard action-button glow.
5. **Mouseover click-cast.**
   - Settings map keys (and modifiers) to `/cast [@mouseover,harm,nodead][] <spell>` via override bindings, applied out of combat.
   - Works on nameplates, unit frames and the WCK panel.
   - Clicking a panel row targets that enemy (secure `/target`), rebuilt out of combat only.
6. **`/wck probe`** reports each gated API's pass/fail per context: open world, dungeon, BG, in and out of combat. Each feature reads the probe result to enable itself or fall back.

**Verification:**
- `lua tests/run.lua` passes for all pure logic: priority evaluation, cast-map keying and aging, macro building, probe-result gating.
- In-game checklist per feature on the beta realm: open-world mob pack, a dungeon, a BG.
- No Lua errors or `ADDON_ACTION_BLOCKED` with `addonCombatRestrictionsForced` set.

## Patterns to Follow
**Copy from WUK**
- **Module layout:** `local ADDON, WCK = ...`, `WCK.inits` / `WCK.refreshers`, and a single `WCK.On(event, fn)` dispatcher (`WarlockUtilityKit/Core.lua:10-17`, `:137-150`). Warlock-only gate at PLAYER_LOGIN (`Core.lua:143-150`).
- **Pure logic and tests:** pure logic in `Logic.lua`, tested by plain `tests/run.lua` with `eq`/`near` (`run.lua:1-7,89-98`). All decision logic goes here: priority rules, cast-map state, macro text.
- **Secret guard:** `WCK.Secret(v)` wrapping `issecretvalue` before any compare (`Core.lua:7`). Every read of a gated value goes through it.
- **Visual language:**
  - Purple rim and dark disc (`UI.lua:53-59,119-125`).
  - `AddGlow`/`SetAlert` pulse (`UI.lua:96-110`).
  - Desaturate for "not available" (`UI.lua:161`).
  - Shine pop (`UI.lua:135-138`).
  - Fonts: GameFontNormalSmall/HighlightSmall and NumberFontNormal.
- **Ring:** WCK reuses the ring idea at a smaller size. Core = next-spell icon; orbit = proc alerts. The cast-map panel docks under the ring the way WUK docks the CDM viewers (`Dock.lua:3-26`).
- **Combat safety:**
  - Every `SetAttribute`/layout/binding change returns early under `InCombatLockdown()` (`UI.lua:35,166`).
  - Snap layout on `PLAYER_REGEN_DISABLED` (`UI.lua:87-93`).
  - Re-apply everything in `Refresh` on `PLAYER_REGEN_ENABLED` (`Core.lua:152`).
- **Movable frames:** `MakeMovable` with Shift+drag, `db.locked` and `db.frames[key]` (`UI.lua:13-26`).
- **Settings:** `BasicFrameTemplateWithInset`, checkboxes plus `WowStyle1DropdownTemplate`, all routed through the slash handler and re-synced from the DB (`Settings.lua:1-71`). Minimap button: left = settings, right = toggle panel (`Settings.lua:73-110`).
- **Saved variables:** `MergeDefaults` for both levels (`Logic.lua:16-23`). Priority list and keybinds are per-character.

**From Midnight-era addons** (`research.md` Q5)
- Pass duration objects and secrets straight to Blizzard widgets. Never do arithmetic on them.
- Hook Blizzard frames with `hooksecurefunc` post-hooks. Never replace callbacks or `MenuUtil`, and never add size or mouse hooks on Blizzard viewer children: Enhanced CDM 0.14.0 and Better Tracked Bars v10 report these as taint sources.

**Do NOT follow**
- WUK's "any click = same macro" wiring (`UI.lua:132-133`). WCK needs explicit per-button and per-modifier attributes.
- Reading `C_UnitAuras` on enemies (errors in combat; probe `:14`).
- Registering `COMBAT_LOG_EVENT_UNFILTERED` without a pcall guard.
- Reparenting Blizzard AuraButtons (forbidden in 12.1.0).

## Design Decisions
1. **Probe first, features gated:** phase 1 is `/wck probe` plus a stored `db.caps` table. Each feature checks its cap and picks a primary or fallback path. This matches the WUK v2 approach, and most core APIs are unverified on Forever.
2. **Cast map from own casts, not auras:** own casts are documented non-secret; enemy auras error. The trade-off is inferred state: a resisted, dispelled or broken Fear still shows as "cast", visually marked as "cast" rather than "confirmed". DreadPlagueTracker shows this inferred approach is usable (about 95%).
3. **Enemy identity key order:** raid mark → GUID (if non-secret) → name (if non-secret) → "current target". Forever GUIDs are stable per session (1.60.1 notes). Instance identity may be secret; the probe decides.
4. **Age, not timers:** icons fade by elapsed time since cast against a coarse per-spell "stale after" setting. No countdown text. This follows the task direction and avoids needing accurate durations (Forever durations are partly unverified).
5. **Rotation = custom priority list + optional Assisted Combat fallback:** the list is editable in settings as ordered rows of spell plus conditions. Evaluation is pure Logic, so it is testable. Display-only, because insecure code cannot swap button spells in combat.
6. **Panel first, nameplates opt-in:** the panel is fully under WCK's control. Nameplate glow is off by default and auto-disabled when `caps.nameplateDecorate` is false or the context is instanced and restricted (TargetNameplateIndicator precedent).
7. **Click-cast via mouseover override bindings:** `SetOverrideBindingClick` to hidden secure buttons with `/cast [@mouseover,harm,nodead][]` macrotext, set out of combat. Works on nameplates and frames without hooking them. Clique is not required.
8. **Proc alerts from overlay events:** `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE` filtered to a configurable spell list (default Shadow Trance 17941, Backlash if present). Fallback is `GetSpellAuraSecrecy`-checked player aura reads out of restriction. Alerts are a WUK-style pulse at the ring orbit, plus an optional `PlaySound` (new; WUK has none).
9. **Separate addon:** no dependency on WUK and no shared SavedVariables. It may sit beside WUK (WUK's ring default is CENTER 0,-220; WCK defaults elsewhere).

## What We're NOT Doing
- Anything WUK covers: stones, armor, pet buttons, soulstone timer, summon queue, healthstone trade, curse/banish assignment board, CDM dock.
- Exact DoT/CC countdowns, pandemic windows or duration math.
- Reading enemy auras, enemy health thresholds (execute) or enemy casts for interrupts.
- PvP enemy tracking: enemy cooldowns, trinkets, DR on enemies (closed in 12.0.1). Fear DR on *your* casts is not tracked either.
- Auto-casting or one-button rotation (protected; also against ToS).
- Cross-player sync (WUK owns addon messaging).
- Retail or Classic flavors. Forever 16001 only.
- Any code before the issue is filed. The deliverable now is the GitHub issue (task.md); build phases come later.

## Open Risks
- **Proc events:** `SPELL_ACTIVATION_OVERLAY_*` may not fire for Nightfall on Forever, or may be gated. Then proc alerts depend on aura secrecy for 17941, which is likely ContextuallySecret.
- **Cast target name:** the SENT `target` name may be secret in combat. Then the cast map falls back to "current target at cast time" plus raid mark only.
- **Instance identity:** in dungeons and BGs, GUID, name and possibly mark may all be secret, leaving only "target" and "focus". The cast map then shrinks to a single-target view in instances.
- **Death/despawn detection:** without CLEU, rows may linger until combat ends.
- **Nameplate restrictions:** `GetNamePlateForUnit` restrictions (TargetNameplateIndicator 1.64) may block enemy nameplate glow everywhere.
- **Usable/range checks:** `IsSpellUsable`/`IsSpellInRange` returns may be secret in combat, weakening rotation conditions to cooldown plus cast recency only.
- **Override bindings:** these replace the user's keys while active; key conflicts must be shown in settings.
- **Forever changes:** Blizzard tightened rules repeatedly in 12.0.x hotfixes and could whitelist or re-protect spells after the 2026-11-04 launch.
