# Task

Rework the UI of three Warlock Utility Kit (WUK) frames: the "Warlock Assignments" board, the summon queue panel, and the config/settings menu. Give all three a consistent warlock look (fel-green and shadow-purple tones, demonic/void styling) instead of stock Blizzard panels. Today the board is cramped: the settings panel opens on top of the per-warlock dropdown row, and the dropdowns have no labels and cut off their text ("No soulsto..."). The summon queue panel is a bare backdrop with a long instructional title. The settings menu is a plain checkbox list.

Fix two summon-queue behaviours as well:
- After a successful summon, remove the summoned player from the queue automatically.
- The queue's "is this player in my group" check doesn't work properly. It should only queue, or keep, players who are actually in the party/raid.
