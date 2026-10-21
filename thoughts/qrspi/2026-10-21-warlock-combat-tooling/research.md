# Research Findings

Date: 2026-10-21. Sources are mostly external web pages; citations are URLs. Several pages (Icy Veins, Mobalytics, Wowhead article bodies, Patreon) returned 403/404/502 to fetches. Items sourced only from search snippets are marked UNVERIFIED. Shorthand: `W:` = `https://warcraft.wiki.gg/wiki/`, `CF:` = `https://www.curseforge.com/wow/addons/`.

Local prior findings: `thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md:6` (all warlock curses/Banes/DoTs/Banish secrecy 2), `:14` (`C_UnitAuras.GetUnitAuras("target","HARMFUL|PLAYER")` errors in combat), `:18-25` (CDM category sets readable in combat; viewer frames reachable), `:28-29` (addon DoT timers infeasible).

## Q1: Which warlock-specific combat addons exist, and what does each do?

### Findings

**WoW Forever builds (interface 16001)**
- **Necrosis "all version"**: CF:necrosis-tbc-classic-bcc. Updated 2026-10-17, file "v160001-fix5", 834k downloads. Flavors: Retail, Forever, MoP, Titan, Classic.
  - Features: shard count, buff/curse/demon menus, stone creation, DoT timers and optional buff timers, unfearable/Banish/Trance/Backlash icons, Shadow Trance/Backlash activation lights, drag-to-arrange buttons.
  - PvE utility. Its 481 comments were unreadable, so there is no secrets-breakage evidence.
- **Dark Ritual**: CF:dark-ritual. Created about 3 days ago, updated 2026-10-21, 28 downloads, game version 1.60.1.
  - Features: DoT timers (icons and bars), spell wheel for demons and stones, Demon Skin/Armor reminder, shard excess limit, spell Codex (known/trainable/upcoming), Demon Trainer tracker, Soulstone alert, movable modules.
  - PvE leveling focus. No statement on secrets.
- Neither page says how its DoT timers behave in combat, given the probe at `probe-results.md:14`.
- Forever UI bundles (not warlock-specific, not examined): CF:forever-ui, CF:vuloforeverui, CF:forevertools.

**Retail / Midnight 12.x (all Demonology PvE, all tiny download counts)**
- **Demolock** (CF:demolock, 2026-10-15, 12.1.5): Demonic Core cards, Dreadstalkers countdown, Wild Imp count and Implosion prompt, Tyrant timing, missing-pet alert.
- **HoG Tyrant** (CF:hogtyrant, 2026-09-25):
  - Counts Hand of Gul'dan casts in a 20s Tyrant window; warns on missing, wrong or passive pet.
  - States it reads only the player's own casts, with no combat log, so it keeps working under Midnight restrictions.
  - States Demonic Core and Burning Rush buffs are unreadable in combat inside instances, and defers those to the Cooldown Manager.
- **ChayDemonicCore** (CF:chaydemoniccore, 2026-09-24): Demonic Core stack icons, proc tracking by spell ID, glow and sound.
  - Its page does not address secrets. Contradiction: HoG Tyrant says those stacks are unreadable in instances.
- **Advanced Combat Tracker** (CF:advanced-combat-tracker) calls itself a "taint-free" Midnight tracker for player/target/focus debuffs. Not fetched in detail.
- Not found: a Hekili-style warlock rotation helper; Affliction- or Destruction-specific Midnight addons; Midnight warlock WeakAura packs on Wago. Icy Veins still recommends WeakAuras/Gnosis for Affliction timers (https://www.icy-veins.com/wow/affliction-warlock-resources).

**Classic-era (TBC Anniversary, SoD, Era); these do not load on Forever**
- **WarlockTools** (CF:warlocktools, 2026-05-07, TBC 20505): HUD for shards and stones, X-shaped popup menu, Healthstone panel, trade helper, Masque support.
- **WarlockQol (TBC)** (CF:warlockqol-tbc, v0.27, 2026-08-03): summon/ritual chat lines, Soulstone/Banish announcements, party/raid HUDs.
- **Logroño's Warlocks** (CF:logronos-warlocks): Fear DR tracking on players; manual trinket timer, because trinket cooldowns are not exposed.
- Others:
  - Necrosis TBC Anniversary (CF:necrosis-tbc-anniversary)
  - Necrosis Classic (CF:necrosis-classic)
  - Soul Ledger / Dark Ledger (TBC)
  - HoneyLock (SoD)
  - WarlockUtilities (Era, stale since 2023-09)
- Every Classic-era warlock addon found is PvE utility (shards, stones, menus, summons, announcements). Logroño's Fear DR tracker is the only PvP-specific feature found.

## Q2: Which general combat addons do warlocks rely on, and Midnight/Forever status?

### Findings
Platform: Forever runs the Midnight restriction set. Sources:
- `W:Patch_1.60.1/API_changes/notes` (2026-09-15): "addon disarmament changes... including secrets, will also be active in Forever".
- CF:forever-cooldown-manager: "Forever applies the same restrictions as Midnight".
- CF:whyhidden: `C_Secrets` identical on both live clients.

**DoT, aura and cooldown trackers**

| Addon | Last update | Forever flavor | Status |
| --- | --- | --- | --- |
| TellMeWhen (CF:tellmewhen) | 12.1.5, 2026-10-12 | yes | Midnight-aware; secret-cast and cooldown-ready conditions added in 12.0.3 (UNVERIFIED snippet) |
| WeakAuras (CF:weakauras-2) | retail 5.21.1, 2026-01 (11.2.7) | no | no Midnight build; Classic flavors updated 2026-10-10. Unofficial port m4tjz/WeakAuras2-for-Midnight: "EXPECT NO SUPPORT", CLEU disabled, secret comparisons fail silently |
| Raven, NeedToKnow | none found | — | UNVERIFIED |
| ClassicAuraDurations | 2024-12 | no | Classic only |
| Dread Plague Tracker (DK) | — | — | uses `auraInstanceID` with fallbacks; author says "not perfect" |

**Nameplates, cast bars, cooldown text**

| Addon | Last update | Forever flavor | Notes |
| --- | --- | --- | --- |
| Plater (CF:plater-nameplates) | v661, 2026-10-15 | yes | Forever support since v656/v658; pandemic glow and dispel glow (v661); "base support for new aura API (12.1)"; IMPORTANT filter removed |
| Threat Plates (CF:tidy-plates-threat-plates) | 13.3.1, 2026-10-18 | yes | 13.0.2 disabled status text and target name (secrets); scripting "restricted to a high degree" |
| Kui Nameplates | — | — | UNVERIFIED |
| Quartz Midnight fork (CF:quartz-midnight) | 3.8.10, 2026-10-10 | yes | player cast bar, swing timer; "updated for Forever and Midnight" |
| OmniCC original | 11.2.8, 2025-12 | no | — |
| OmniCC GODMODE (CF:omnicc-godmode-midnight-forever) | 1.4.4, 2026-10-21 | yes | game versions 12.1.x and 1.60.1; says features differ between Midnight and Forever |
| tullaCTC (CF:tullactc) | — | — | OmniCC rewrite for secrets |
| Details! (CF:details) | 2026-10-16 | yes | reduced feature set (UNVERIFIED) |

- Threat APIs conditionally return secrets (12.0.1, 2026-02-19). `UnitThreatLeadSituation` is new.

**PvP**

| Addon | Last update | Forever flavor | Notes |
| --- | --- | --- | --- |
| Gladius (CF:gladius) | 2020-10 | no | a Reddit snapshot (2026-01) claims it still works; contradicts CF dates |
| sArena original | 2021-04 | no | abandoned |
| sArena Reloaded (CF:sarena-reloaded) | 2.6.7, 2026-10-15 | no | "Midnight ready"; castbar secret fix 2.5.4c; "Cast on me" and "CC" highlights mutually exclusive "due to restrictions" |
| Gladdy | 2026-07-29 | no (MoP/TBC only) | — |
| DRTracker (CF:drtracker) | 2.7.3, 2026-03-21 | no | reads Blizzard's native arena-frame DR icons, current target only, 18s reset; arena only, not BGs |
| ArenaDR Nameplates | 2026-08-23 | no | mirrors native arena DR onto nameplates |
| OmniBar (CF:omnibar) | v34, 2025-08 | no | "pretty much bricked" (Reddit, UNVERIFIED) |
| BigDebuffs (CF:bigdebuffs) | v68, 2026-07-16 | no | Reddit says replaced by Blizzard UI (UNVERIFIED). Skill-Capped lists it as Midnight-ready; the two conflict |

- **Khorium.pro** (CF:khorium-pro) documents what is unreadable in instances:
  - aura reads are refused;
  - CLEU gives secret GUIDs and spell IDs;
  - `UNIT_SPELLCAST_SUCCEEDED` hides the spell;
  - addon messages are blocked.
  - Readable: `C_LossOfControl` on yourself (spell, duration, DR); interrupt school lockout; enemy spec.
  - This is one author's testing, not official.
- 12.0.1 (2026-02-19) closed the exposure of other players' CC spell IDs, durations and arena PvP-trinket cooldowns (`W:Patch_12.0.1/API_changes/notes`).
- No dedicated Midnight-era healer-detection or kill-target addon was found.

## Q3: What does a warlock track in combat on Classic-era / Forever content?

### Findings
**Classic mechanics** (Wowhead Classic, warcraft.wiki.gg)

| Spell | Duration / cooldown | Source / note |
| --- | --- | --- |
| Corruption | 18s | spell=25311 |
| Curse of Agony | 24s; ramping, "2/3 of damage in last 1/3" | spell=11713; Warcraft Tavern |
| Improved Shadow Bolt | +20% debuff, 4 charges, 12s; periodic damage does not consume charges | `W:Improved_Shadow_Bolt_(Classic)` |
| Shadow Trance (Nightfall) | 10s instant Shadow Bolt | spell=17941; proc 2% or 3%/4%, UNVERIFIED which |
| Fear | 20s, 1.5s cast | — |
| Banish | 30s | — |
| Howl of Terror | 15s, 40s cooldown | — |
| Seduction | 15s | — |
| Death Coil | 3s horrify, 120s cooldown | horrify is its own DR category, separate from Fear (Warcraft Tavern PvP) |
| Spell Lock | Wowhead 6s / 30s cooldown vs Tavern 3s silence plus 8s lockout | conflict, UNVERIFIED |
| Devour Magic | 8s cooldown | — |
| Soulstone | 30 min | — |
| Soul Link | 30% of damage to pet, +3% damage; purgeable from pet | — |

- Raid curse assignment (Classic): CoR, CoS and CoE each get a dedicated warlock; extras use CoA or CoD (https://www.warcrafttavern.com/wow-classic/guides/warlock-rotation---wow-classic-season-of-mastery/).
- Rotation notes: Shadowburn consumes ISB charges; Siphon Life snapshots ISB; Imp positioning matters for Blood Pact (https://warcrafttavern.com/wow-classic/guides/pve-warlock-rotation).
- PvP priorities (https://warcrafttavern.com/wow-classic/guides/warlock-pvp):
  - Fear is the main defensive tool; Death Coil is the emergency button and works on fear-immune targets; Howl of Terror pulls Rogues out of stealth.
  - Curse of Tongues against casters; Felhunter against casters (Spell Lock, Devour Magic).
  - Warriors can reflect Fear and CoR.
  - Fear DR 100/50/25/immune per noobtoboss (not clearly Era; the wiki DR page returned 502).

**Forever changes** (beta notes https://us.forums.blizzard.com/en/wow/t/wow-classic-forever-beta-patch-notes/2360696; https://www.zockify.com/forever/warlock/; https://accountshark.net/blog/wow-forever-rogue-warlock-changes-guide-mutilate-banes-talents)
- **Banes:** CoA and CoD become Banes. One Bane plus one Curse per warlock per target; a second Bane replaces the first.
  - Bane of Havoc (Destruction 21-point talent): for 5 min, 15% of damage dealt to other targets is copied to the Bane target.
  - Curse of Shadows is removed. CoE covers all magic schools.
  - Curse of Recklessness can no longer stack on one target (Oct 16).
- **Talents:**
  - Pandemic adds up to +100% crit damage on DoTs and drains.
  - Affliction capstone Wrack: +10% to the warlock's other Shadow DoTs for 6s.
  - Demonic Pact (Demonology capstone): keep a Demonic Sacrifice buff with another demon out.
  - Decimation: Soul Fire cooldown cut against low-health targets.
  - Destruction: Incinerate +25% with Immolate up; Conflagrate can preserve Immolate; Shadowburn refunds its shard immediately.
  - Grim Reach and Destructive Reach add range. Shadow Mastery is 2–10%.
- **Pets:** Imp, Voidwalker, Succubus/Incubus and Felhunter. No Felguard and no Metamorphosis.
  - Soul Link can be cast on the pet again.
  - The current pet is stunned while a new one is summoned.
  - Aggressive Mode is restored.
  - Voidwalker Sacrifice scales with spell healing.
- **Resources:**
  - Life Tap scales with Spirit, not spell damage.
  - Drain Soul has a per-tick shard chance and a guaranteed shard on kill.
  - Firestone gives fire damage and crit; Spellstone gives shadow damage and haste. Both coexist with weapon oils.
- **Legacy:** "Reagent Economy" removes vendor reagents from class abilities. The interaction with Summon Incubus shards is ambiguous (Oct 16 note). There are no warlock-specific Legacy perks. Campsites are non-combat.
- **Cooldown Manager on Forever:**
  - Off by default (Gameplay Enhancement setting). Warlock supported from Sep 24.
  - Healthstone, pet and item-enhancement cooldowns cannot be tracked (known issue).
  - Known issue: "Banes and Curses don't track correctly if you drop and re-acquire a target" (https://www.warcrafttavern.com/forever/news/wow-forever-beta-update-bug-fixes-class-changes-gamepad-support/).
  - Multiple spell ranks count as one entry (Oct 16).
  - CF:forever-cooldown-manager says Blizzard's CDM "has no spell data for most Forever classes", which conflicts with the beta notes.
- Not found: Forever DR changes for Fear, Death Coil, Howl or Seduction; durations of Tongues, Weakness, Exhaustion, Immolate and Siphon Life; Healthstone cooldown; shard cap.

## Q4: What combat data is readable by addon code on Forever, and how?

### Findings
Rules (`W:Secret_Values`, `W:Patch_12.0.0/API_changes`):
- Tainted code can store, pass, concatenate and format secrets. Arithmetic, comparison, boolean tests, `#`, indexing and table keys error.
- Restriction states: combat, encounter, M+, PvP match (12.0.1), restricted maps (12.0.5).
- Per-spell, per-power and per-totem NeverSecret/AlwaysSecret flags override the state rules.
- The 12.0.7 note "secret system entirely disabled on Classic builds" covers Mists, TBC and Vanilla, not Forever. The 1.60.1 notes and the local probes confirm Forever enforces secrets.

| Data | Readable in combat by addon? | Source |
| --- | --- | --- |
| Own debuffs on enemy (auras) | No: index/slot/instance aura APIs raise errors while secret (12.1.0 PTR3); UNIT_AURA payload fully secret | probe `:14`; `W:Patch_12.1.0/API_changes/notes` |
| Aura non-secret fields | `isHelpful`, `isHarmful`, `isRaid`, `isNameplateOnly`, `isFromPlayerOrPlayerPet`, `auraInstanceID` (re-randomized on encounter, M+ or PvP entry) | 12.0.5 notes |
| Whitelisted non-secret spells | rogue poisons, shaman imbues, raid buffs, some HoTs, GCD 61304, combat res. **No warlock spells.** | 12.0.1 notes (2026-02-24) |
| Player primary resources (mana, health) | Secret | 12.0.0 Beta 3 notes |
| Player secondary resources | Non-secret on Mainline. Forever shards may be bag items, not a power type: UNVERIFIED | 12.0.0 notes |
| `UnitHealthMax`/`UnitPowerMax` (player) | Non-secret | 12.0.0 Alpha 6 |
| Player and pet spellcasts | Non-secret even in combat | 12.0.0 notes (Nov 4) |
| Pet identity | Exempt (player, pet, group) | 12.0.7 notes |
| Pet health | UNVERIFIED (`ShouldUnitHealthBeSecret` can test) | — |
| Target/focus `UnitCastingInfo` | Secret except `isTradeskill`, `castBarID`, `delayTimeMs`; `UnitCastingDuration` returns a duration object; secret instants don't fire `UNIT_SPELLCAST_SUCCEEDED` for others | `W:API_UnitCastingInfo`; 12.0.7 |
| Nameplates | compound tokens rejected; token comparison blocked; identity secret on instanced maps; private auras unsupported | 12.0.0, 12.0.5 notes |
| `COMBAT_LOG_EVENT_UNFILTERED` | Mainline: registering errors (`ADDON_ACTION_FORBIDDEN`). Forever: UNVERIFIED; `C_CombatLog.IsCombatLogRestricted` exists on 1.60.1 | `W:COMBAT_LOG_EVENT_UNFILTERED` |
| `C_Spell.GetSpellCooldown` | `isEnabled`, `isActive`, `isOnGCD`, `maxCharges` non-secret; timing secret; `GetSpellCooldownDuration` returns a duration object | 12.0.1 notes (2026-03-21) |
| `C_Spell.IsSpellUsable`, `IsSpellInRange` | AllowedWhenTainted, no SecretReturns tag; in-combat behavior UNVERIFIED | wiki API pages |
| `C_LossOfControl` (self) | Readable: spell, duration, DR on self | Khorium.pro |

**Blizzard surfaces**
- **Cooldown Manager:**
  - `C_CooldownViewer.GetCooldownViewerCategorySet` was readable in combat (probe `:18`).
  - `GetCooldownViewerCooldownInfo` is tagged AllowedWhenUntainted; untested from addon code.
  - Categories Essential, Utility, TrackedBuff and TrackedBar are confirmed on Forever (probe). Mainline adds GroupBuff and later categories; the Forever enum is UNVERIFIED.
- **Assisted Combat:** `C_AssistedCombat.GetNextCastSpell` is listed for 1.60.1 and tagged AllowedWhenUntainted. Blizzard calls it "non-optimal by design". Whether addon code can call it is UNVERIFIED.
- **12.1.0 AuraContainer/AuraButton:** in Forever per the 1.60.1 notes. Buttons are forbidden while auras are secret, and addons cannot reparent them (PTR 6/7).
- **Edit Mode:** present on Forever, with separate mouse and gamepad layouts (1.60.1 notes, 2026-10-08).

**Secret-safe display sinks** (`W:Secret_Values`, 12.0.x notes)
- StatusBar: `SetValue` and `SetMinMaxValues` accept secrets; `SetTimerDuration(durationObj)`.
- Cooldown: `SetCooldownFromDurationObject` is "the only way" to pass secrets (12.0.1). Its wiki page is tagged protected; whether tainted code can call it is UNVERIFIED.
- FontString: `SetText` accepts secrets; `DurationTextBinding` (12.0.7).
- Formatters: `SecondsFormatter`, `AbbreviatedNumberFormatter`. `Cooldown:SetCountdownFormatter` (12.0.5).
- `C_CurveUtil` color and number curves; `Region:SetAlphaFromBoolean` and `SetVertexColorFromBoolean`.
- `C_Secrets.*Secrecy` and `Should*BeSecret`; `C_RestrictedActions.IsAddOnRestrictionActive`; `ADDON_RESTRICTION_STATE_CHANGED`.
- Testing CVars: `addon{Combat,Encounter,Map,PvPMatch,ChallengeMode}RestrictionsForced`.

## Q5: How do major combat addons implement displays despite secrets?

### Findings
- **WeakAuras:** the team quit retail Midnight; it said recreating the CDM is impractical (https://www.icy-veins.com/wow/news/weakauras-to-end-support-in-midnight/). The unofficial port has 300+ secret checks, and its triggers fail silently.
- **Enhanced CDM** (CF:enhanced-cdm, https://github.com/sonterix/enhanced-cmd):
  - Creates no frames. It "hooks and repositions Blizzard's existing ones":
    - per-frame `SetPoint` hooks;
    - `CooldownViewerItemDataMixin` hooks (`OnAcquireItemFrame`, `SetCooldownID`);
    - a `Layout()` override;
    - `CooldownViewerSettings.OnDataChanged` for relayout.
  - Re-hooks after loading screens. Defers layout while `InCombatLockdown` and flushes on `PLAYER_REGEN_ENABLED`.
  - 0.14.0 fixed secret-value taint by replacing EventRegistry callbacks with per-viewer hooks, and `MenuUtil` replacement with `hooksecurefunc`.
- **Better Tracked Bars v10:** removed size hooks and mouse mutations on viewer children (both caused taint); projected anchors onto UIParent (UNVERIFIED snippet).
- **Ayije CDM:** v3.88 (2026-06-18); author reportedly discontinuing (UNVERIFIED).
- **Clean Cooldown Manager** (CF:clean-cooldown-manager): restyle only, no added features. Also MCDM, Cooldown Manager Tweaks and Centered.
- **tullaCTC / OmniCC:**
  - OmniCC 12.0.0-beta1 was a "HACK: workaround for secrets".
  - tullaCTC rewrote it: cooldown durations generated on refresh; moved to `SetCountdownFormatter` in 12.0.5.
  - nugsCooldownPulse measures from cast time against the base cooldown (UNVERIFIED).
- **Plater:** adopted the 12.1 aura API and dropped the IMPORTANT filter. No explicit taint notes.
- **DodoNameplate:** intersects `HARMFUL|PLAYER` with Blizzard's curated set.
- **sArena Reloaded:** cast-bar secret fix; some highlights made mutually exclusive "due to restrictions"; uninterruptible texture unsolved.
- **DRTracker / ArenaDR Nameplates:** read Blizzard's native arena DR UI instead of computing DR.
- **HoG Tyrant:** reads only the player's own casts; points to the CDM for buffs.
- Recurring patterns across these:
  1. Hook and re-anchor Blizzard frames instead of building aura logic.
  2. Pass duration objects and secrets straight to Blizzard widgets, with no arithmetic.
  3. Use only non-secret fields and own-cast events.
  4. Avoid mutating Blizzard frames from shared callbacks (taint source).
  5. Defer layout until out of combat.

## Q6: What do warlock players say they want or miss?

### Findings
- EU forum, "Cooldown manager and Nameplates tracking for warlocks" (https://eu.forums.blizzard.com/en/wow/t/cooldown-manager-and-nameplates-tracking-for-warlocks/603595), retail, paraphrased:
  - Tongues, Weakness and Satyr curses are not trackable on nameplates (Exhaustion is).
  - Demonic Healthstone is missing from the CDM.
  - Darglare duration shows the cooldown instead.
  - Seed of Corruption lacks the Nightfall glow and the no-shard grey-out.
  - Stale spells are still listed.
- US forum, "Feedback: Warlocks" (404, search snippet only):
  - An Affliction player calls the class unplayable without tracked debuffs in the CDM, and wants a pandemic indicator.
  - Blizzard removed Wild Imp energy because Demonology relied on addons for it.
- Reddit snapshot (2026-01, https://reddit.sentinel-team.org/posts/1qenu4e/...):
  - "Healing without Omnibar to track enemy kicks is going to be just awful".
  - The warlock kick has no audio or visual cue.
  - Burnout over rebuilding the UI.
  - Unanswered question whether nameplate DoT tracking works.
- Blizzard said PvP DR tracking would come "in a future update" (https://us.forums.blizzard.com/en/wow/t/pvp-changes-in-midnight/2175957, snippet).
- Forever: Blizzard said addons are supported with the Midnight restrictions (Icy Veins snippet, 403). The Warcraft Tavern claim that retail addons load is disputed by commenters.
- All-in-one UI replacements are emerging for Forever: EllesmereUI (includes CDM and a "Forever Essentials" threat meter), Classic UI Forever, Forever UI.
- Minimalism signal: the many CDM restyle-only addons, such as Clean Cooldown Manager. No shared warlock-specific minimalist raid or PvP layout was found.
- No Forever warlock-specific complaint threads were found. r/classicwow, Forever subreddits, Wago and Wowhead comments were not reached.

## Q7 (follow-up): What can addon code learn about which spell the player cast on which enemy?

### Findings
**Cast events** (`W:UNIT_SPELLCAST_SENT`, `W:UNIT_SPELLCAST_SUCCEEDED`, `W:Secret_Values`)
- **`UNIT_SPELLCAST_SENT`** fires for `player` only. Payload is `unitTarget, target, castGUID, spellID`.
  - `target` is tagged `ConditionalSecret`; `castGUID` and `spellID` have no secrecy tag.
  - The event's predicate is `SecretWhenUnitSpellCastRestricted`, which applies only when the unit is not the player or their pet. By inference, the player's own SENT payload is non-secret; UNVERIFIED in combat.
  - `target` is a name string, not a GUID, so two same-named mobs cannot be told apart from it.
- **`UNIT_SPELLCAST_SUCCEEDED`** payload is `unitTarget, castGUID, spellID, castBarID`. There is no target argument. `castBarID` is NeverSecret (12.0.0).
- `castGUID` (`Cast-3-...`) is shared between SENT and SUCCEEDED, so the two can be paired per cast.
- Player and pet casts are documented non-secret in combat (12.0.0 notes, Nov 4). Repeated from Q4.
- The 12.0.7 claim that secret instant casts no longer fire for other units was not found on the 12.0.7 API-changes page (UNVERIFIED).

**Identifying the target unit**

| API | Wiki tags | Notes |
| --- | --- | --- |
| `UnitGUID` | AllowedWhenUntainted, `SecretWhenUnitIdentityRestricted` | Forever obfuscates server/spawn IDs but keeps them stable and unique per session (`W:Patch_1.60.1/API_changes`, 2026-10-16) |
| `UnitName` | `SecretWhenUnitNameIdentityRestricted` | secret for non-player/pet units in combat; exception: enemy players in PvP |
| `UnitIsUnit` | `RequiresComparableUnitTokens`, `SecretWhenUnitComparisonRestricted` | — |
| `UnitTokenFromGUID` | `SecretWhenUnitIdentityRestricted` | wiki: "inherently unstable" |
| `GetRaidTargetIndex` | "SecretReturns" label, conditions unstated | probe found it readable on target (`probe-results.md:13`) |
| `UnitExists`, `UnitIsDead`, `C_NamePlate.GetNamePlateForUnit` | AllowedWhenUntainted only | no secret-return predicate; in-combat behavior UNVERIFIED |

**Target death or departure**
- No CLEU-free death event was documented. `UnitIsDead` and `UnitExists` on a token are not secret-tagged.
- The `NAME_PLATE_UNIT_REMOVED` page returned 502.
- DreadPlagueTracker README: it "ignores spurious removal events from nameplate slot reassignment" and follows its debuff when the host mob dies; the mechanism is not described.
- Forever 1.60.1 hides non-target nameplates on units far above or below the player (`nameplateMaxVerticalDistance*` CVars; 0 disables the check).

**Blizzard per-enemy debuff display**
- 12.1.0 AuraContainer and AuraButton intrinsics are present in Forever (`W:Patch_1.60.1/API_changes`, 2026-09-15). Usage excerpt: `CreateFrame("AuraContainer")`, `:SetUnit(...)`, `:AddAuraFilter(...)`.
  - Filter strings, nameplate-unit support and styling limits are UNVERIFIED; the wiki pages returned 502 or are marked work-in-progress.
- `AuraData.nameplateShowPersonal` flags auras applied by the player, pet or vehicle; this appears to be the basis of the native "your debuffs" nameplate category.
- The `DISPELLABLE` aura filter was added and `IMPORTANT` was removed.

**Existing per-enemy displays**
- **DreadPlagueTracker** (https://github.com/tuukkadk/DreadPlagueTracker), Unholy DK:
  - Tracks one debuff across multiple enemies via `auraInstanceID` plus "layered fallbacks".
  - Needs the enemy nameplate visible; "about 95%" accurate per its README.
  - Detects applications from the player's own cast list (Outbreak, Epidemic, etc.).
- **DodoNameplate** (CF:dodonameplate, 12.1.x): a secret-safe icon row mirroring Blizzard's nameplate categories (your debuffs, shared CC, important debuffs, enemy buffs, purgeable). Limited to Blizzard's server-side categories, with no per-spell whitelists.
- **ThreatPlates:** rebuilt its Auras widget on the 12.1.0 AuraContainer because the old scanning "no longer works reliably" (https://github.com/Backupiseasy/ThreatPlates/releases).
- **Plater:** "base support" for the 12.1 aura API.
- No Midnight or Forever multi-target "my DoTs" panel (Affliction multi-dot style) was found. TellMeWhen was not checked.

## Q8 (follow-up): How are WUK's visuals and interactions built?

### Findings
All paths are under `WarlockUtilityKit/`.

**Module and test pattern**
- Modules share the `WUK` table and register through `WUK.inits` and `WUK.refreshers`.
- `Core.lua:10-17` is the event dispatcher: `WUK.On(event, fn)`.
- `Core.lua:143-150` runs the init chain on PLAYER_LOGIN, warlocks only.
- `Core.lua:137-141` is `WUK.Refresh`.
- `Core.lua:7` is `WUK.Secret` (wraps `issecretvalue`).
- Logic and tests:
  - `Logic.lua` holds pure functions, tested by `tests/run.lua`.
  - The test runner loads Logic.lua with a fresh table and uses `eq`/`near` asserts (`run.lua:1-7,89-98`).
  - UI, Core, Dock and Settings are untested.

**Strip: the "summoning circle" ring** (`UI.lua:10-152`)
- Constants: radius R=58, core 44px, orbit buttons 36px, 30px label band (`UI.lua:10`).
- Background: three masked discs (`UI.lua:53-59,119-125`):
  - `rim`: purple (0.58,0.51,0.79,0.55);
  - `disc`: dark (0.04,0,0.07,0.7);
  - `swirl`: `Spell_Shadow_Twilight`, ADD blend, alpha 0.35, 90s rotation.
- Orbit buttons are placed clockwise from 12 o'clock with `WUK.RingPoint` (`Logic.lua:163-166`, `UI.lua:11,39-40`).
- Spin is 6°/s. Collapse to radius 0 unless the strip is hovered or the player is in combat; bloom takes 0.2s (`UI.lua:61-85`).
- On `PLAYER_REGEN_DISABLED`, `WUK.CombatFreeze` snaps the ring fully open, because layout is blocked in lockdown (`UI.lua:87-93,151`).
- Labels under the ring: `f.stone` (GameFontNormalSmall) and `f.assign` (GameFontHighlightSmall) (`UI.lua:144-147`).

**Buttons**
- Built from `SecureActionButtonTemplate` (`UI.lua:128`, `Prep.lua:4-11,23-30`).
- Parts: ARTWORK icon; NumberFontNormal count text at the bottom-right; `ButtonHilight-Square` highlight (`UI.lua:134-141`).
- States:
  - Desaturated when the count is 0, the buff is up, or the pet is out (`UI.lua:161`, `Prep.lua:16,36`).
  - Scale "shine" (1.3x) when a count goes from 0 to above 0 (`UI.lua:135-138,164-165`).
- Glow (`UI.lua:96-110`):
  - `WUK.AddGlow` is an `UI-ActionButton-Border` texture, ADD blend, purple (0.7,0.3,1), 1.8x size, pulsing alpha 0.15 to 1 over 0.6s.
  - `WUK.SetAlert(b,on)` toggles it, idempotently.
  - When the ring is collapsed, the core pulses for any alerting orbit button (`UI.lua:44-46`).
- No cooldown frames or swipes. No button tooltips (only the minimap button has one). No `PlaySound` anywhere.

**Clicks**
- Every strip button uses `type=macro` with `RegisterForClicks("AnyUp","AnyDown")` (`UI.lua:132-133`). There is no left/right or modifier split on the strip.
- `macrotext` is rewritten only out of combat (`UI.lua:166-169`, `Prep.lua:18,38`). It is built by the pure `WUK.StoneMacro` (`Logic.lua:26-36`).
- Summon rows (`Summon.lua:74-82`):
  - Left click: `macrotext1` targets and casts.
  - Ctrl+left: `ctrl-macrotext1` targets only.
  - Right click: an insecure HookScript removes the row.
- Spell names come from a spellbook scan of ranked lists (`Core.lua:48-93`).

**Combat lockdown**
- Every secure change returns early under `InCombatLockdown()`: `UI.lua:35,69,84,166`, `Summon.lua:39`, `Dock.lua:7`.
- `PLAYER_REGEN_ENABLED` calls `Refresh`, which re-applies everything (`Core.lua:152`). Nothing is queued.

**Movement and docking**
- `WUK.MakeMovable(f,key,x,y)`: Shift+drag, respects `db.locked`, blocked in combat. Positions save to `db.frames[key]` (`UI.lua:13-26`).
- Dock (`Dock.lua:3-26`):
  - Chains `EssentialCooldownViewer` and `BuffIconCooldownViewer` under the strip.
  - A `hooksecurefunc(v,"SetPoint")` hook re-applies the dock on the next frame, and `EDIT_MODE_LAYOUTS_UPDATED` re-applies it too.

**Settings, minimap and storage**
- Settings window (`Settings.lua:1-71`):
  - `BasicFrameTemplateWithInset`, 320x314, closes on Escape.
  - `UICheckButtonTemplate` checks, and a `WowStyle1DropdownTemplate` dropdown built with `SetupMenu`/`CreateRadio`.
  - Every control routes through `SlashCmdList.WARLOCKUTILITYKIT` and re-syncs from the DB.
- Minimap button: polar position at `db.minimapAngle`; left click opens settings, right click opens the board (`Settings.lua:73-110`).
- Saved variables:
  - Account DEFAULTS: `{locked, shown, frames, icons, minimapAngle, dockViewers, spin, collapse}` (`Core.lua:19`).
  - Character: `{pet, soulstone, board}`.
  - Merged with `WUK.MergeDefaults` (`Logic.lua:16-23`).
- `/wuk` subcommands: show, hide, lock, reset, pet, config, probe, board, lead, dock, spin, collapse (`Core.lua:221-244`).

## Q9 (follow-up): Proc alerts, rotation help, nameplate glow/CC, mouseover and click-cast on Forever

### Findings
**Proc alerts**
- `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` (payload `spellID`) and `SPELL_ACTIVATION_OVERLAY_SHOW` are both listed for Forever 1.60.1 with no restrictions section.
  - SHOW payload: `spellID, overlayFileDataID, locationType, scale, r, g, b`.
  - Sources: `W:Event:SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`, `W:Event:SPELL_ACTIVATION_OVERLAY_SHOW`.
  - No documentation marks them secret. In-combat behavior is UNVERIFIED.
- The global `IsSpellOverlayed` is gone in 12.0.0; the replacement is `C_SpellActivationOverlay.IsSpellOverlayed`. Its page returned 502.
- Own-buff secrecy can be queried per spell with `C_Secrets.GetSpellAuraSecrecy(17941)` (Shadow Trance); Forever value unknown.
  - Midnight's whitelisted procs (Maelstrom Weapon, Ebon Might) include no warlock spells.
  - The `PLAYER|HELPFUL|RAID_IN_COMBAT` filter returns only Blizzard-flagged auras (https://spiritbloom.pro/blog/tracking-buffs-in-midnight).
- Whether Forever fires a Nightfall overlay at all is UNVERIFIED.
- Midnight addons reacting to Blizzard's glow:
  - GlowWatcher (CF:glowwatcher) is "read-only" and reacts to action-button glows, default bars only.
  - ClassUIEnhanced offers Blizzard or custom proc glow.

**Rotation help**
- Hekili: "not compatible with the Midnight (12.0) expansion"; last file 11.2.5, 2025-11 (CF:hekili).
- Replacements built on `C_AssistedCombat`: HekiLight, Just Assisted Combat, Simple Assisted Combat Icon, NextGCD.
- `C_AssistedCombat` (`W:Category:API_systems/AssistedCombat`):
  - `GetNextCastSpell`, `GetRotationSpells`, `IsAvailable`, `GetActionSpell`, and the event `ASSISTED_COMBAT_ACTION_SPELL_CAST`.
  - All are listed for 1.60.1; returns are not documented secret.
  - Blizzard calls it "non-optimal by design" (12.0.0 notes).
  - Whether Forever has a populated warlock rotation is UNVERIFIED.
- MaxDps and ConRO: status not found.
- Custom priority-list inputs readable in combat:
  - `GetSpellCooldown` `isEnabled`, `isActive`, `isOnGCD` and `maxCharges` (NeverSecret).
  - Player and pet cast events.
  - `IsSpellUsable` and `IsSpellInRange` returns are untagged (UNVERIFIED).
  - `UnitHealthPercent` returns are SecretWhenCurveSecret only with a curve. DodoNameplate shows enemy health as percent only in combat.
- Secret values cannot be compared or branched on: they raise a Lua error (`W:Secret_values`).

**Nameplate glow and CC**
- `C_NamePlate.GetNamePlateForUnit(unit, includeForbidden)`: forbidden plates are friendly plates in instances; enemy behavior is undocumented.
- TargetNameplateIndicator 1.64 disabled itself on Retail "due to new restrictions on C_NamePlate.GetNamePlateForUnit"; it no longer works in dungeons or raids (https://wowinterface.com/downloads/info21391-TargetNameplateIndicator.html).
- Threat Plates bundles an updated LibCustomGlow on Midnight. Whether addon glows on enemy plates are allowed is UNVERIFIED.
- 12.1.0 changed `SetScript`/`HookScript` `SecretArguments` to NotAllowed and added forbidden-aspect checks; the effect on hooking nameplates is UNVERIFIED.
- CC data:
  - The `CROWD_CONTROL` aura filter (stuns, fears, silences, slows) was added in 12.0.1 (`W:API_C_Secrets.ShouldUnitAuraIndexBeSecret`, Forever-listed).
  - DodoNameplate shows a "shared crowd control" category drawn from Blizzard's server-side categories.
  - 12.0.1 closed addon access to other players' CC spell IDs and durations.
- Knowing a mob is feared without auras:
  - Own Fear casts are non-secret: spell, time and the SENT target name (Q7).
  - `C_LossOfControl.GetActiveLossOfControlDuration(unitToken, idx)` was added in 12.0.1; whether it works on non-player units is UNVERIFIED.
  - CLEU is blocked on Mainline.

**Mouseover and click-cast**
- Combat lockdown blocks attribute changes, Show/Hide and re-anchoring of protected frames, and macro/binding changes (`W:API_InCombatLockdown`).
  - Secure state drivers and SecureHandler snippets switching actions in combat on 12.x: UNVERIFIED.
  - Insecure code cannot swap a button's spell in combat.
- 12.x secure changes:
  - The SecureActionButtonTemplate arbitrary-function exploit was fixed.
  - 12.1.0 removed `IsMouseoverCastSupported` from FrameXML; `MouseIsOver` became `InputUtil.IsMouseOver`; `CreateSecureDelegate` gained options (`W:Patch_12.1.0/API_changes`).
- `UnitIsUnit` with `mouseover` is non-secret; compound tokens stay secret (12.0.0 notes).
- Clique claims Midnight support (v4.9.5, 2026-04-22). Target and menu actions must be bound explicitly after Blizzard's unit-frame changes (CF:clique). Its Forever status and nameplate click-binding are UNVERIFIED.

## Cross-Cutting Observations
- **Forever is a Midnight-restricted client with Classic-era warlock content.** Classic-era addons (Necrosis Classic, WarlockTools, Gladdy, Logroño's) target interfaces that do not load. Forever-flavored addons are few: Necrosis all-version, Dark Ritual, Plater, Threat Plates, TellMeWhen, Quartz fork, OmniCC GODMODE, Details, Forever Cooldown Manager.
- **The dividing line is own-player vs enemy data.**
  - Readable in combat: own casts, pet casts, cooldown flags, CDM category sets, self loss-of-control, enemy spec.
  - Secret or erroring in combat: enemy auras (including your own DoTs on them), enemy casts, primary resources, threat, the combat log on Mainline.
  - No warlock spell is whitelisted non-secret.
- **Blizzard surfaces carry the combat data:** CDM viewers, 12.1.0 aura containers, nameplate debuffs, native arena DR. The surviving addons skin or anchor those surfaces, or feed duration objects to Blizzard widgets.
- **Forever's CDM has warlock gaps:** Healthstone, pet and imbue cooldowns are untracked, and there is a Bane/Curse re-target bug.
- **Forever spell changes alter the tracking model:** one Bane plus one Curse per warlock, Bane of Havoc, no Curse of Shadows, CoR no-stack, Pandemic as a crit bonus, Shadowburn shard refund.
- **Local precedent:** `WarlockUtilityKit/` already uses `UNIT_AURA` for the player only (`Core.lua:154`), defers combat changes on `PLAYER_REGEN_DISABLED` (`UI.lua:151`), and anchors via `EDIT_MODE_LAYOUTS_UPDATED` (`Dock.lua`). It has no CLEU usage and no cast bars.

## Open Areas
- Forever runtime checks not yet probed:
  - CLEU registration;
  - `GetPowerTypeSecrecy(Mana)`, and whether shards are a power type or bag items;
  - `UnitHealth("pet")`;
  - `IsSpellUsable` and `IsSpellInRange` in combat;
  - calling `SetCooldownFromDurationObject`, `GetCooldownViewerCooldownInfo` and `C_AssistedCombat.GetNextCastSpell` from addon code;
  - `C_LossOfControl` on Forever;
  - the Forever `Enum.CooldownViewerCategory`.
- Q7 runtime checks:
  - whether SENT `target` is secret in combat;
  - `UnitGUID`, `GetRaidTargetIndex`, `UnitIsDead` and `UnitName` on target/nameplate tokens in combat, open world vs dungeon vs BG;
  - `NAME_PLATE_UNIT_REMOVED` payload;
  - whether an addon-created AuraContainer on a nameplate unit with a `HARMFUL|PLAYER` filter works in combat on Forever.
- Q9 runtime checks:
  - Do the overlay events fire for Nightfall, and fire in combat?
  - `C_Secrets.GetSpellAuraSecrecy(17941)`.
  - `C_AssistedCombat.IsAvailable()` and `GetRotationSpells()` for a warlock.
  - `IsSpellUsable` and `IsSpellInRange` in combat.
  - Can an addon texture or glow be attached to an enemy nameplate's `UnitFrame`, in the open world and in a dungeon?
  - `GetActiveLossOfControlDuration` on enemy tokens.
  - Clique on Forever.
- Restriction contexts in Forever's open world, dungeons and BGs vs Midnight. Arena existence on Forever is unconfirmed.
- How Necrosis and Dark Ritual DoT timers behave in combat on Forever.
- Classic numbers not confirmed: Spell Lock (conflicting), Nightfall proc rate, curse durations, Healthstone cooldown, Era DR categories and reset time.
- Status unknown: Raven, NeedToKnow, Kui, Gladius (conflicting), OmniCD, DRList, CooldownManagerCentered.
- Player sentiment for Forever specifically: Reddit, Wago and Wowhead comments were not reached.
