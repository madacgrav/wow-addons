# Task

Survey existing warlock combat addons (PvE and PvP) across Classic-era, retail and WoW Forever, and identify the best features plus the gaps, with a clean, simple combat-assist UI as the target. The output is a research-backed feature analysis captured as a GitHub issue in this repo (madacgrav/wow-addons), to pursue later as a combat module or companion to `WarlockUtilityKit/`; no code now. This is a separate addon from WUK. Exclude anything WUK already covers: armor, pet and stone buttons, the soulstone timer, summon queue, healthstone trade, curse/banish assignment board and dock. Do not focus on exact timer lengths. The focus is what has been cast and where: which DoTs, curses, Banes and CC the player has on which enemies. Wanted combat features:
- same look and interaction style as WUK;
- spell rotation help, with the rotation customizable in settings;
- mark feared (and other CC'd) mobs visibly, such as a nameplate glow;
- mouseover view and click-cast on enemies;
- on-screen alerts for procs like Nightfall/Shadow Trance.

Findings must respect Forever's Midnight "secrets" limits already probed for WUK (own DoT/curse auras on enemies are unreadable by addon code in combat).
