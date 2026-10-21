# Structure Outline

## Approach
No code. Get the research onto `main` so the issue's link works, then file one labelled umbrella issue. The issue pitches a future Forever fishing addon: Forever-only gaps first, reliability gaps second, and a checklist of things to verify at launch. Earlier QRSPI runs committed their `thoughts/qrspi/*` artifacts alongside the work (e.g. `90cb5a4`), so this run does the same through a docs PR.

Nothing here can be split vertically. Every step is a GitHub write. The phases are ordered so that each one stands on its own: if phase 2 never happens, the merged research still stands.

## Phase 1: Research artifacts on main
Commit `task.md`, `questions.md`, `research.md`, `design.md`, `structure.md` and later `plan.md` to a branch, open a PR, and merge it once the user approves. The issue can then link to `main` without a 404.

**Files**: `thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/*.md`. The untracked `WoW Forever Addon Ideas — PRD.md` is NOT included, because it is out of scope.
**Key changes**:
- branch `fishing-gap-research`, commit `Add Forever fishing addon gap research`
- PR into `main`, merged only after the user approves it

**Verify**: `gh pr view --json state` shows `MERGED`, and `https://github.com/madacgrav/wow-addons/blob/main/thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/research.md` resolves (`gh api repos/madacgrav/wow-addons/contents/thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/research.md` returns 200).

---

## Phase 2: Label and umbrella issue
Create the `addon: fishing` label, then file the issue. The body is drafted to a scratch file first so the user can read it before anything is posted.

**Files**: draft body in the scratchpad (`issue-fishing.md`); no repo files.
**Key changes**:
- `gh label create "addon: fishing" --description "Fishing addon (proposed)" --color <hex distinct from #9482c9 and #66ccff>`
- `gh issue create --title "Fishing addon for Forever: gaps existing addons leave (pursue later)" --label "addon: fishing" --label enhancement --body-file <draft>`
- Issue body skeleton (follows the PRD's Gap/Problem/Scope/Non-goals layout and #15's checklist style):
  1. Intro: what the gaps are, "as of 2026-10-21", and a link to `research.md`.
  2. **Gap:** about 18 Forever fishing addons exist and all cluster on casting, lures and logging, which are already covered.
  3. **Forever-only content (lead)**, as `- [ ]` items, each naming who covers it (none, or one addon):
     - campsite Fishing Rack and Fishing Hut
     - Uncommon/Rare/Unique fish and the Chef's Knife
     - Legacy fishing talents
     - STV tournament and Extravaganza coin
     - quest fish
     - water-walking helper
  4. **Reliability gaps in existing addons (secondary)**:
     - soft-target range and mis-targeting
     - no bite event
     - swap-back after combat
     - game-version detection (the BetterFishing TOC placeholders; the Fishing Buddy fork's `WOW_PROJECT_ID` check)
     - sound/CVar restore that survives a crash
     - Classic 1.12 and enUS-only data
  5. **Non-goals v1:** no one-key or double-click casting; it sits alongside BetterFishing instead.
  6. **Verify at launch (2026-11-04)** checklist:
     - soft-target range
     - spell IDs
     - `IsFishingLoot`
     - whether the cast and loot APIs hide values
     - catch tables
     - Rack/Hut unlock skills and Legacy point costs
     - player feedback sources
  7. Caveats: player demand is inferred, not quoted; Forever mechanics come from beta guides.

**Verify**:
- `gh issue view <n> --json labels,title,body` shows both labels.
- The body has the Forever-only section above the reliability section and contains the research link.
- Manual: open the issue and click the link, which should resolve to `main`.

## Testing Checkpoints
- **After Phase 1:** research artifacts are on `main` via a merged PR, and the link resolves. Nothing is posted to issues yet.
- **After Phase 2:** the `addon: fishing` label exists and one open issue exists, labelled `addon: fishing` + `enhancement`, linking research. The task is done.
- **Resume hint:** run `gh pr list --head fishing-gap-research --state all` and `gh issue list --label "addon: fishing"` to see which phase landed.
