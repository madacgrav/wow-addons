# Changelog — BusinessCard

All notable changes to this addon. Versions match `## Version` in `BusinessCard.toc`; each version is published as a `bcard-vX.Y.Z` GitHub release.

## [0.8.6] — 2026-11-17
- Card sharing no longer switches off for the whole session after one failed send. Throttle and lockdown errors wait and retry; other errors drop only that message. Trial accounts are detected up front.
- Each player's card and recipe requests are answered at most once per 30 seconds, so one sender can't flood your outgoing queue.
- Recipe names that hadn't loaded yet ("Recipe #1234") now fill in on their own.
- Right-clicking a Seen row also removes guildmates who only sent a card.
- Removed the `/bcard probe` and `/bcard ping` debug commands; their results are recorded.

## [0.8.5] — 2026-11-16
- Card detail: hover a recipe to see its materials (icon, quantity and how many you have in bags and bank). Shift-click a recipe to link it in chat.

## [0.8.4] — 2026-11-16
- Subtle motion: new ads flash gold once in the Seen list, available dots breathe, pills pop when clicked, cards and pills brighten their border on hover, and a gold sheen sweeps a card in the detail pane when it arrives or changes.

## [0.8.3] — 2026-11-16
- Card detail (shift-click) shows their business card, a row of profession icon tabs, a search box and a scrolling recipe list. Empty and loading states show an icon (the "Requesting..." one spins).

## [0.8.2] — 2026-11-16
- My card is now a real business card: your round portrait, name and zone, each profession with an icon, skill bar and status pill, your services as icons with status dots, and a big Available/Busy pill. Click any pill or service icon to change its status.
- Window background is fully opaque (nothing behind shows through).

## [0.8.1] — 2026-11-16
- Seen list scrolls, so every entry is reachable (no more 20-row cap). Taller rows show a status dot, the name in gold if they run BusinessCard, category icons, zone, age and a card badge, with stripes and a gold hover.

## [0.8.0] — 2026-11-16
- New ledger look: rock background, faint parchment, gold border and title, close button. Seen and My card are now tabs under the window. The card detail uses the same skin.

## [0.7.4] — 2026-11-16
- Ctrl-click /who closes Forever's group-finder who list (LFGParentFrame), which is where the results open.

## [0.7.3] — 2026-11-16
- Ctrl-click /who: keeps closing the Friends/Who window for 3 seconds after the lookup, since it opens late.

## [0.7.2] — 2026-11-16
- Ctrl-click /who closes the Who window once the result is read (unless you had it open already).

## [0.7.1] — 2026-11-16
- Ctrl-click a Seen row to run /who on that person: prints level, class and zone, and fills the zone column. Rows without a zone say so in the tooltip.

## [0.7.0] — 2026-11-16
- Seen shows where each person is: the zone their BusinessCard reports, else the zone of the channel they posted in (General, LocalDefense, Trade (Local)), or your zone for say and yell. Cross-city Trade posts have no zone. Cards now carry your zone and re-send to the guild when you change zones.

## [0.6.0] — 2026-11-16
- Card detail (shift-click a row): their status and services, a button per profession, and the full recipe list fetched on request with a search box. Shows when they have no card or have not opened that profession yet.

## [0.5.0] — 2026-11-16
- Card sharing: your card goes to your guild 10 s after login and after any status change. Advertisers you see in chat get a silent card request (once per session, never inside instances), and shift-click asks again. Rows show a green or red status dot and a letter icon when the person runs BusinessCard; the tooltip lists their card. Guildmates who never advertised appear from their card. Trial or Veteran accounts print one warning and keep the ad log.

## [0.4.0] — 2026-11-16
- My card tab: your professions with skill and your summon/portal services, each set to Available, Busy or Off by clicking; an Overall switch and `/bcard busy` / `/bcard avail`. Opening a profession window caches its learned recipes for later sharing.

## [0.3.1] — 2026-11-16
- Fix: the first `/bcard` now opens the window (it took two).

## [0.3.0] — 2026-11-16
- Window (`/bcard` or keybind): Seen list with a category filter, newest first. Click to whisper, right-click to remove, tooltip shows the last ad. Movable and closes with Esc; `/bcard lock` stops dragging.

## [0.2.2] — 2026-11-16
- Stricter ad filter: a post must show an offer (WTS, LFW, tips, services, a price like 5g, or a profession link) and contain no LF/LFM/WTB/recruiting words. Saved entries are re-checked at login.

## [0.2.1] — 2026-11-16
- Ad log keeps advertisers only: LF/WTB posts are no longer stored, and ones saved by 0.2.0 are removed at login.

## [0.2.0] — 2026-11-16
- Ad log: classifies profession, summon and portal ads from Trade, General, Services, TradeLocal, LookingForGroup, say, yell and whispers; stored per realm for 7 days (max 500). `/bcard seen` prints the newest 20.

## [0.1.0] — 2026-11-16
- Skeleton, SavedVariables, `/bcard probe` and `/bcard ping` for client fact-finding.
