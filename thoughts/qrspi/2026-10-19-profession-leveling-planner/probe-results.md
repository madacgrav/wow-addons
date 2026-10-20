# /pp probe results (2026-10-20)

## Profession window
- **Tailoring: professionID 197**, skill 93/150. 471 recipes in total, 40 learned.

  | Recipe | diff | maxTrivial | Reagent |
  |---|---|---|---|
  | Faction Banner | 3 | 25 | 2996 ×1 |
  | Bolt of Woolen Cloth | 3 | 85 | 2592 ×3 |
  | Bolt of Linen Cloth | 3 | 50 | 2589 ×2 |
  | Woolen Bag | 2 | 110 | 2997 ×3 |
  | Linen Bag | 3 | 65 | 2996 ×3 |

  `GetItemCount(2996)` bags/bank: 25/25.
- **Enchanting: professionID 333**, skill 116/150. 261 recipes, 26 learned.

  | Recipe | diff | maxTrivial | qtyMin |
  |---|---|---|---|
  | Enchanted Lute | 3 | 25 | — |
  | Dust to Motes | 3 | 15 | 3 |
  | Runed Silver Rod | 0 (orange) | 170 | — |
  | Runed Copper Rod | 3 | 10 | — |
  | Minor Wizard Oil | 3 | 65 | — |
- **Cooking: professionID 185**, skill 1/75. Its recipes are mostly diff=0 with maxTrivial=85; Basic Campfire is diff=1 with maxTrivial=5. Cooking is not one of the v1 professions.
- **Leatherworking and Alchemy:** not probed (the character doesn't have them). The Classic IDs 165/171 stay unverified.
- **Every reagent slot read reports `type=1`,** which is `Enum.CraftingReagentType.Basic`, as the scan assumes.
- **`numSkillUps` = 1 everywhere.**

## Key finding
- **`maxTrivialLevel` is populated on Forever and equals the grey threshold.** Every recipe at or above its `maxTrivial` reads diff=3 (grey), and those below don't, e.g. Woolen Bag is green at 93 with maxTrivial 110.
- **Grey thresholds are therefore known up front for every learned recipe,** with no need to learn them from play. Yellow and green thresholds still have to be learned (Phase 4).

## Bank
- `Enum.BagIndex.CharacterBankTab_1` = 6. It reported 48 slots once the bank had been opened in the session, and it still reports 48 after the bank closes.
- `ReagentBag` = 5.
- `C_Item.GetItemCount(id, true)` counts the bank, though the sample item had none in the bank.
