# /pp probe results (2026-10-20, Phase 1)

## Run 1 — profession window closed
- `tradeskill ready: false`. No unlearned-recipe lines, because the window was not open.
- `Auctionator API: true`
  - `AH price 2589: true 18`: the pcall succeeded, and Linen Cloth costs 18c on the AH. The v1 API works on Forever with callerID `ProfessionPlanner`.
- `LibQuestieDB: true contract3=true`. QuestieDB is loaded and supports contract 3.
- `CharacterBankTab_1: 6 slots=0` (bank not opened this session). `ReagentBag: 5`.

## Run 2 — Tailoring open (full log from `ProfessionPlannerDB.lastProbe`)
- Tailoring 197 at skill 95/150: 471 recipes, 40 learned, 431 unlearned. No API errors.
- **The game gives no learnability signal for unlearned recipes:**
  - `sourceType = nil` for all 431.
  - `GetRecipeSourceText` returns nil for all 431 (the function exists and does not error).
  - `disabled = false` and `disabledReason = nil` for all 431.
- **`relativeDifficulty` on unlearned recipes** is a color derived from thresholds at the current skill, not from learnability.
  - Counts: diff 0 ×397, 1 ×9, 2 ×4, 3 ×26.
  - Example: Mooncloth (grey 300) reads orange at 95; Red Linen Bag reads green.
  - `maxTrivialLevel` is populated (= grey).
- **`GetRecipeRequirements` returns crafting stations** (`type=0`), not learn requirements:

  | Station | Recipes |
  |---|---|
  | Spinning Wheel | 74 |
  | Loom | 43 |
  | Crusader's Loom | 8 |
  | Moonwell | 1 |
  | Cooking Fire (`met=true`) | 1 |

  These are Forever crafting-station requirements. Learned recipes may have them too; not checked.
- **Forever-only station recipes** appear as unlearned: Loom 1263080, Spinning Wheel 1263032, plus a second Faction Banner 1263425.

## Trainer rule
**Rule B**: no trainer signal. Unlearned recipes are planned only when the seed has `learnAt` (pattern-taught) and a pattern price is known. Unlearned trainer recipes are counted in the footer only.
