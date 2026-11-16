# Changelog

## 0.5.0
- Card sharing: your card goes to your guild 10 s after login and after any status change. Advertisers you see in chat get a silent card request (once per session, never inside instances), and shift-click asks again. Rows show a green or red status dot and a letter icon when the person runs BusinessCard; the tooltip lists their card. Guildmates who never advertised appear from their card. Trial or Veteran accounts print one warning and keep the ad log.

## 0.4.0
- My card tab: your professions with skill and your summon/portal services, each set to Available, Busy or Off by clicking; an Overall switch and `/bcard busy` / `/bcard avail`. Opening a profession window caches its learned recipes for later sharing.

## 0.3.1
- Fix: the first `/bcard` now opens the window (it took two).

## 0.3.0
- Window (`/bcard` or keybind): Seen list with a category filter, newest first. Click to whisper, right-click to remove, tooltip shows the last ad. Movable and closes with Esc; `/bcard lock` stops dragging.

## 0.2.2
- Stricter ad filter: a post must show an offer (WTS, LFW, tips, services, a price like 5g, or a profession link) and contain no LF/LFM/WTB/recruiting words. Saved entries are re-checked at login.

## 0.2.1
- Ad log keeps advertisers only: LF/WTB posts are no longer stored, and ones saved by 0.2.0 are removed at login.

## 0.2.0
- Ad log: classifies profession, summon and portal ads from Trade, General, Services, TradeLocal, LookingForGroup, say, yell and whispers; stored per realm for 7 days (max 500). `/bcard seen` prints the newest 20.

## 0.1.0
- Skeleton, SavedVariables, `/bcard probe` and `/bcard ping` for client fact-finding.
