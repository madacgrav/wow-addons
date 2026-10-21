# Implementation Plan

## Overview
No code. Two GitHub writes:
1. Merge this run's research artifacts to `main` with a docs PR.
2. File one umbrella issue labelled `addon: fishing` + `enhancement`. It proposes a future Forever fishing addon: Forever-only gaps first, reliability gaps second, a verify-at-launch checklist, and a link to `research.md`.

Repo is `madacgrav/wow-addons`. Earlier PRs used merge commits ("Merge pull request #19").

## Phase 1: Research artifacts on main

### Changes

#### 1. Branch, commit, PR
**Files**: `thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/{task,questions,research,design,structure,plan}.md`. Do NOT stage `WoW Forever Addon Ideas — PRD.md`.

```bash
git switch -c fishing-gap-research
git add thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/
git commit -m "Add Forever fishing addon gap research

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -u origin fishing-gap-research
gh pr create --base main --head fishing-gap-research \
  --title "Forever fishing addon gap research (QRSPI artifacts)" \
  --body "QRSPI question/research/design/structure/plan for a possible Forever fishing addon. No code. The follow-up issue links to research.md on main.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

#### 2. Merge (only after user says yes)
```bash
gh pr merge fishing-gap-research --merge --delete-branch
git switch main && git pull
```

### Verification
#### Automated
- [x] `git diff --cached --name-only` before the commit lists only the 6 files under `thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/`.
- [ ] `gh pr view fishing-gap-research --json state -q .state` prints `MERGED`.
- [ ] `gh api repos/madacgrav/wow-addons/contents/thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/research.md -q .name` prints `research.md`.

#### Manual
- [ ] The user approves the merge in chat before step 2.

---

## Phase 2: Label and umbrella issue

### Changes

#### 1. Draft the issue body
**File**: `<scratchpad>/issue-fishing.md` (create; not in the repo). Show it to the user before posting.

```markdown
Proposal for a third Forever addon in this repo. It is based on a survey of existing fishing addons **as of 2026-10-21** (last beta day). Full findings, sources and addon matrix: [research.md](https://github.com/madacgrav/wow-addons/blob/main/thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/research.md).

**Gap:** about 18 fishing addons list Forever (BetterFishing, Fishing Mode, Fishing Buddy (Crusade), CFC, FishFry, Forever Fishing, The Fishing Log, Luredon, …). Nearly all cluster on the same core: one-key or double-click cast, auto-lure, gear swap, louder splash, catch log, 1-300 guide. Forever's *new* fishing content is mostly untouched.

### Forever-only content (lead, v1 candidates)
- [ ] **Campsite Fishing Rack / Fishing Hut:** buffs that allow Uncommon/Rare catches. Show unlock skill, whether a buff is active, and where. Partly covered only by FishFry (Campsite Assist) and Forever Fishing (camp crafting).
- [ ] **Uncommon / Rare / Unique fish + Chef's Knife:** a collection tracker for the new fish tiers and what the knife turns Unique Fish into. No addon found.
- [ ] **Legacy fishing talents:** progress toward Luremaster (extra fish with a lure), Working Overtime and Dedicated Study in the account-wide Professions tree. No addon found.
- [ ] **Stranglethorn tournament:** next-contest timer, qualifying catch progress, and what the Extravagant Extravaganza Coin buys. Only Luredon has a timer.
- [ ] **Quest fish:** e.g. the four Artisan quest fish (Feralas Ahi, Misty Reed Mahi Mahi, Sar'theris Striker, Savage Coast Blue Sailfin): where to catch them and how many you have. No Forever addon documents this.
- [ ] **Water-walking helper:** Surfer Shoes and Draught of Waterwalking as a fishing-mode reminder or button. No Forever addon found.

### Reliability gaps in existing addons (secondary, only if we ever own casting)
- [ ] **Soft-target range and mis-targeting:** the interact key misses far bobbers or grabs a nearby NPC or player (BetterFishing, EzFishing, Fishing Mode, Angler pages).
- [ ] **No bite event:** addons can only boost the splash sound. Any cue must stay player-driven.
- [ ] **Weapon swap blocked in combat:** players re-equip by hand. A swap-back queued for `PLAYER_REGEN_ENABLED` is missing in most addons.
- [ ] **Game-version detection:** BetterFishing's `X-Family`/`X-Game` TOC fields ship as unfilled `[Family]`/`[Game]` placeholders, so it runs its retail code path. The Fishing Buddy fork treats `WOW_PROJECT_ID ~= MAINLINE` as Classic (Forever is 18).
- [ ] **Crash-safe sound/CVar restore:** BetterFishing keeps its snapshot only in memory. Fishing Buddy persists it to SavedVariables and restores at next login.
- [ ] **Data:** several addons ship Classic 1.12 or enUS-only zone and skill data, missing Forever's fish and zones.

### Non-goals (v1)
- One-key or double-click casting; about 15 addons do it. The new addon would run alongside BetterFishing or similar.
- Anything that reacts to a bite on the player's behalf.

### Verify at launch (2026-11-04)
- [ ] Soft-target interact default and maximum range on Forever (`SoftTargetInteractRange`).
- [ ] Fishing spell IDs on Forever (7620 / 131474 / rank IDs).
- [ ] Whether `IsFishingLoot()` exists (the wiki lists it for 1.60.1; the Fishing Buddy fork says modern WoW removed it).
- [ ] Whether `UNIT_SPELLCAST_CHANNEL_*`, `LOOT_READY` and `GetLootSlotInfo` return secret values for the player.
- [ ] Catch tables and pool names per zone.
- [ ] Fishing Rack/Hut unlock skills, Luremaster %, and Legacy point costs.
- [ ] Player feedback: CurseForge comments on FishFry, Forever Fishing and Fishing Mode, plus Reddit.

### Caveats
- "Players want" claims are inferred from author-reported limits, not player quotes.
- Forever mechanics come from third-party beta guides and may change at launch.
- The field moves fast: about 15 addons were updated in the two weeks before this survey.
```

#### 2. Create label, file issue (after user approves the draft)
```bash
gh label create "addon: fishing" --description "Fishing addon (proposed)" --color 1f9e89
gh issue create --repo madacgrav/wow-addons \
  --title "Fishing addon for Forever: gaps existing addons leave (pursue later)" \
  --label "addon: fishing" --label enhancement \
  --body-file "<scratchpad>/issue-fishing.md"
```
If the label already exists, `gh label create` fails; skip it and continue.

### Verification
#### Automated
- [ ] `gh issue list --label "addon: fishing" --json number,title` returns exactly one issue.
- [ ] `gh issue view <n> --json labels -q '.labels[].name'` prints `addon: fishing` and `enhancement`.
- [ ] `gh issue view <n> --json body -q .body | grep -n -E "Forever-only content|Reliability gaps|research.md"` shows the Forever-only line before the Reliability line, and the link present.

#### Manual
- [ ] The user approves the draft body before posting.
- [ ] Clicking the research.md link in the issue opens the file on `main`.
