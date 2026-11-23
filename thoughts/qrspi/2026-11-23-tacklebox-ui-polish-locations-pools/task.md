# Task

Extend **TackleBox** (existing WoW Forever fishing addon, vanilla, no libs) with four things: (1) a style/polish review of the existing panel UI (`Panel.lua`: dock, panel, custom tabs, skill bar, minimap button) and fixes for what it finds; (2) a new panel tab listing the best-loot fishing locations for the player's current Fishing skill; (3) fishing pool / school locations marked on the world map; (4) a "scan for fishing pools near me" feature.

Why: the addon currently tells you *how* to fish (skill bands, lures, one-key cast) but not *where* — the best spots and pools are the missing piece, and the panel could look more finished.

Gap analysis verdict: **build** (extend own addon). Open feasibility risk for (3)/(4): Forever may not expose game-object positions to addons, so "scan" may have to mean static pool data near the player's map position, or minimap Find Fish tracking — research must settle what the client actually allows.

Target: World of Warcraft: Forever, Interface per skill `references/toc-format.md`. Library choice: vanilla (keep TackleBox lib-free unless map pins force a library).
