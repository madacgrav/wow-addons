# Research Questions

## Context
Research is mostly external: CurseForge, Wago (addons and WeakAuras), WoWInterface, GitHub, warcraft.wiki.gg, Icy Veins / Wowhead class guides, and Reddit/forum threads. WoW Forever is interface 16001: a Mainline 12.x API base with Midnight "secret values" restrictions and Classic-era content; launch 2026-11-04. Prior Forever API findings live in `thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md` and `research.md` (own DoT/curse auras on enemies error in combat; `C_CooldownViewer` categories and Blizzard viewer frames are readable); extend that, don't repeat it. The existing `WarlockUtilityKit/` addon (strip UI, soulstone timer, summon queue, assignment board, dock) is the local reference for current UI and code patterns.

## Questions
1. Which warlock-specific combat addons exist, and what does each do?
   - Classic-era: Necrosis, WarlockTools, DotTimer-style addons, Warlock Curse Power, Shard/Soul counters, Felguard/pet bars;
   - retail and Midnight-era: class-resource displays, demon/imp trackers (e.g. Demonology imp counters), Hekili-style rotation helpers, warlock WeakAura packs on Wago;
   - WoW Forever builds (interface 16001), if any;
   - per addon: URL, last update, downloads, feature list, PvE vs PvP focus, open issues about breakage under Midnight secrets.
2. Which general combat addons do warlocks rely on for combat, and which of their features matter most to the class?
   - DoT/debuff trackers (e.g. TellMeWhen, Raven, NeedToKnow, ClassicAuraDurations), enemy cast bars and interrupt/fear trackers, nameplate addons (Plater, Threat Plates) with DoT display, threat meters, swing/cast timers, OmniCC-style cooldown text;
   - PvP-specific: Gladius / sArena / Gladdy arena frames, diminishing-return trackers (DRTracker, DiminishingReturns), enemy cooldown trackers (OmniBar), BigDebuffs, fear/CC duration displays, healer-spotting and kill-target callouts;
   - which still work on Midnight-era / Forever clients and which were disabled or reduced by secrets.
3. What does a warlock actually need to track in combat on Classic-era / Forever content, for PvE and PvP?
   - DoTs and curses (durations, refresh windows, curse assignment), Shadow Trance / Nightfall procs, Improved Shadow Bolt debuff, shard and mana/life-tap state, pet health/mana and pet abilities (Spell Lock, Seduction, Devour Magic), Fear/Banish/Death Coil/Howl of Terror durations and DR, healthstone/soulstone cooldowns, Soul Link, threat;
   - any Forever changes to warlock spells, talents or resources (new spells, "Bane" naming, Legacy-related mechanics) documented in patch notes or guides.
4. Under Forever's 1.60.x / Mainline 12.x API, which combat data are readable by addon code in and out of combat, and through what mechanisms?
   - player buffs/procs, player resources (mana, health, shards), pet unit data, target/focus cast info, nameplate unit data, combat log availability (`COMBAT_LOG_EVENT_UNFILTERED` restrictions), spell cooldowns/charges, `IsSpellUsable` / range checks;
   - Blizzard-provided surfaces: Cooldown Manager / `C_CooldownViewer`, built-in aura containers and nameplate debuffs, Edit Mode-anchorable frames, Blizzard's own Assisted Combat / rotation highlight if present;
   - which values are flagged NeverSecret vs ContextuallySecret, and how existing addons display secret values (e.g. passing them to StatusBar/Cooldown widgets without reading them).
5. How do the most-used combat addons on Midnight-era clients implement their displays despite secrets?
   - read source or changelogs of WeakAuras (Midnight status), TellMeWhen, Plater, OmniCC, Enhanced Cooldown Manager / CDM skinners, sArena/Gladius Midnight builds;
   - patterns used: reskinning or re-parenting Blizzard frames, secret-safe widget APIs, `C_CooldownViewer` hooks, taint pitfalls reported in changelogs and issues.
6. What do warlock players say they want or miss from combat addons, especially on Forever/Midnight-era clients?
   - Reddit (r/classicwow, r/wow, r/warlock, Forever subreddits), class Discord public guides, CurseForge/Wago comments, Wowhead comments;
   - recurring complaints (clutter, setup complexity, broken WeakAuras), most-requested features, and minimalist UI setups people share for PvE raiding and PvP (world PvP, battlegrounds, arenas if present).
