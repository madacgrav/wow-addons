# Design Discussion

## Current State
- The repo has two Forever addons, WarlockUtilityKit and ProfessionPlanner. Both use interface 16001 (`WarlockUtilityKit/WarlockUtilityKit.toc:1`), a pure `Logic.lua` file kept apart from the WoW-API files (`WarlockUtilityKit/Logic.lua`, `ProfessionPlanner/Logic.lua`), `tests/` per addon, and a packaging workflow per addon (`.github/workflows/package-wuk.yml`, `package-pp.yml`). The repo has no fishing code.
- Deferred work is tracked as GitHub issues. Each carries a per-addon label (`addon: wuk`, `addon: profession-planner`) plus `enhancement`, `verification` or `question`. Issue #15 shows the house style: a short intro, then a `- [ ]` checklist with bold item names and one line of rationale each.
- The fishing field on Forever, from `research.md` Q1/Q2:
  - About 18 Forever-flagged addons, almost all first published Sep–Oct 2026. BetterFishing has 6.0M downloads across all game versions; the Forever-first addons range from 41 to 16.6K.
  - The commonly covered features are one-key or double-click casting, auto-lure, gear swap, splash/sound boost, catch logs, 1-300 guides and auction-house value.
- Forever-only content is barely covered (research.md Cross-Cutting):
  - Campsite Fishing Rack/Hut and Uncommon/Rare fish: only FishFry Campsite Assist and Forever Fishing camp crafting.
  - STV tournament: only Luredon has a timer.
  - Legacy fishing talents (Luremaster etc.), Chef's Knife / Unique Fish, quest fish, rafts and water-walking, Edit Mode: no addon found.
- Reliability problems reported on Forever (research.md Q4/Q5/Q6):
  - The soft-target range is too short for far bobbers, and the interact key mis-targets a nearby NPC or player.
  - The game gives addons no bite event.
  - Weapons can't be swapped in combat, so players re-equip by hand afterwards.
  - Version detection is broken:
    - BetterFishing's `X-Family`/`X-Game` TOC fields (BetterFishing.toc:8-9) ship unsubstituted, so `SetGameInfo` (BetterFishing.lua:271-290) never detects Forever.
    - The Fishing Buddy fork branches on `WOW_PROJECT_ID` (LibFishing:39-56), so Forever (18) lands in its Classic branch.
  - BetterFishing's sound/CVar restore lives only in memory (BetterFishing.lua:374-399), so it doesn't survive a crash. The Fishing Buddy fork persists it to SavedVariables (FishingBuddy.lua:1741-1793).
  - Zone data is Classic 1.12 or enUS-only (Smart Fishing, EzFishing, Angler).

## Desired End State
One GitHub issue in `madacgrav/wow-addons` proposes a future fishing addon for this repo. It is built from this research, and nobody writes code now. Verify by checking that:
- the issue exists, is labelled, and links to `thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/research.md` on `main`;
- it leads with the Forever-only content gaps, each tied to evidence (which addons cover it, if any);
- it has a secondary section on reliability gaps in existing addons;
- it has a checklist of items to verify at launch (2026-11-04);
- a reader who has not seen this session can tell from the issue alone why the addon is worth building and what it would not do.

## Patterns to Follow
- **Issue style of #15:** a short intro, then `- [ ] **Name:** one-line why` items. Keep it scannable and avoid long prose.
- **Labels:** add a new per-addon label `addon: fishing`, matching `addon: wuk` / `addon: profession-planner`, plus `enhancement`. The verify-at-launch checklist lives inside the same issue, so it gets no separate `verification` label (one umbrella issue, as decided).
- **Positioning toward the PRD (`WoW Forever Addon Ideas — PRD.md`):** each idea is stated as Gap, Problem, Scope v1/v2, Non-goals. The issue body follows that skeleton so the idea can be moved into the PRD later.
- **Patterns from research the future addon should copy:**
  - Persist CVar/sound snapshots to SavedVariables before changing them, as the Fishing Buddy fork does (FishingBuddy.lua:1741-1793).
  - Use the Blizzard Equipment Manager (`C_EquipmentSet`) for gear sets rather than hand-rolled swaps (FishingGearManager.lua:11-40).
  - Pack zone keys as `uiMapID*1000+subzone`, not names (FishingDatabase.lua:233-241), since it is locale-safe.
- **Patterns from research the future addon should not copy:**
  - Detecting the game version from TOC metadata fields that the packager may leave unsubstituted (BetterFishing.toc:8-9).
  - Treating `not IsRetail` as "Classic" (LibFishing:39-56).
  - Shipping Classic 1.12 zone/skill tables as truth for Forever.
  - Assuming a hardcoded fishing spell ID: Forever's IDs are unverified.

## Design Decisions
1. **Deliverable:** one umbrella GitHub issue, and no child issues. "Pursue later" doesn't need tracking granularity yet.
2. **Positioning:** a future new addon in this repo, the third alongside WUK and ProfessionPlanner. It is not a gap list for other authors, and it is not a ProfessionPlanner module.
3. **Lead with Forever-only content:**
   - Campsite Fishing Rack/Hut buffs and their unlock skills.
   - Uncommon/Rare catches and Unique Fish with the Chef's Knife.
   - Legacy fishing talent progress.
   - STV tournament timer and Extravaganza Coin rewards.
   - Quest-fish tracking (e.g. the four Artisan quest fish).
   - Water-walking (Surfer Shoes, Draught of Waterwalking) as a fishing-mode helper.

   Each of these has zero or one existing addon covering it.
4. **Casting is a non-goal for v1:** don't rebuild one-key or double-click casting. About 15 addons already do it, and BetterFishing is the default. The proposed addon sits alongside a caster like BetterFishing and does not compete with it. Reliability gaps are listed as a secondary section ("if we ever own casting, do these right"), not as v1 scope.
5. **Verify-at-launch checklist inside the issue:**
   - soft-target range and max range;
   - fishing spell IDs;
   - `IsFishingLoot` presence (the wiki and the Fishing Buddy fork disagree);
   - whether the `UNIT_SPELLCAST_CHANNEL_*` and loot APIs are secret-gated;
   - catch tables and pool names;
   - Rack/Hut unlock skills and Legacy point costs;
   - CurseForge comments and Reddit as player-feedback sources.
6. **Evidence style:** the issue links to `research.md` for detail and cites addon names and URLs inline only for claims about who covers a gap. It does not paste the feature matrix.
7. **Labels:** create `addon: fishing` (color picked to match the per-addon label set) and apply it along with `enhancement`.

## What We're NOT Doing
- No addon code, TOC, workflow, or folder for a fishing addon.
- No PRD edit, and no CHANGELOG/README changes.
- No child issues, milestones or project-board entries.
- No contact with other addon authors and no upstream bug reports (e.g. the BetterFishing placeholder bug). The issue may note this as a possible courtesy, but nothing is filed.
- No further web research. Open areas move into the verify-at-launch checklist instead.
- No commit of the `thoughts/` artifacts unless asked. The research link needs them on `main`, so that is flagged as a step for structure/plan to decide (commit the artifacts, or paste a short summary into the issue).

## Open Risks
- **Fast-moving field:** about 15 addons were updated in the last two weeks. A gap may be filled by launch, so the issue should say "as of 2026-10-21".
- **Weak player-feedback evidence:** Q6 is inferred only, so "players want X" claims must be worded as author-reported friction, not demand.
- **Unverified Forever mechanics:** Rack/Hut unlock skills, Luremaster %, "first 50" tournament winners and lure durations come from third-party beta guides.
- **Research link:** `research.md` is untracked (git status shows only the PRD untracked at session start, and `thoughts/` content may or may not be committed). A link to `main` 404s until it is committed.
- **Label creation** is a write to the GitHub repo. It is low-risk but outward-facing, so it is done only as part of the approved issue step.
