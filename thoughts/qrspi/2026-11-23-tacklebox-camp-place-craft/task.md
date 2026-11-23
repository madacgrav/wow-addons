# Task

Extend **TackleBox** (WoW Forever fishing addon, 1.2.0) so the fishing camp items become one-click:
1. **Place button**: when a camp item (Fishing Rack, Fishing Hut, and the other fishing camp placeables such as Fish Bowl) is in your bags and its buff is not up, show a click-to-use button on the fishing bar, like the existing Water button.
2. **Craft button**: if a camp item comes from a recipe the character knows and the materials are in the bags, let a click craft it.

Why: the Camp tab only reports buff state today. The user wants the camp step of the fishing loop to be as quick as pole/lure/water.

Gap analysis verdict: **build** (extend own addon). Open feasibility risks: where camp items come from in Forever (boss drop vs recipe; which profession), whether the Rack/Hut aura IDs (1280341/1280342) are right (never confirmed at a real camp), and whether addon-triggered crafting works on Forever (protected / needs a hardware event). Research and a probe must settle these.

Target: World of Warcraft: Forever, Interface 16001 (skill `references/toc-format.md`). Library choice: vanilla, keep the existing embedded libs only.
