# Task

Update the TackleBox addon (`TackleBox/`) so that equipping a fishing pole from its action bar remembers the weapons that were in the main-hand and off-hand slots, and the bar shows a re-equip button that puts both back. Also change casting so one click on the cast button casts when no line is out and reels in (interacts with the bobber) when one is, so the player no longer has to mouse over and click the bobber.

This reverses two non-goals in `thoughts/qrspi/GH-22-forever-fishing-addon/design.md` ("no one-key cast", "no automatic weapon swap"); the weapon swap stays player-clicked. Gap-analysis verdict: extend existing addon (many CurseForge addons do one-key cast and gear swap, but the user wants it inside TackleBox).

Added during design: the panel's tab area collapses behind an expand button (state remembered), the always-shown header gains a line with the current zone's fishing status (skill range, here / too low / outgrown), and tab rows (notably Catch) scroll inside a capped-height area instead of growing the panel.
