# Task: Warlock Combat Kit (GH-23)

Build a new Forever (interface 16001) addon, **WarlockCombatKit (WCK)**, separate from WarlockUtilityKit, that helps a warlock *during* combat in PvE and PvP: a `/wck probe` capability gate built first, a cast map (what I cast on which enemy, from own `UNIT_SPELLCAST_SENT`/`SUCCEEDED`), a CC'd-mob highlight, a display-only rotation helper driven by a user priority list, proc alerts (Nightfall via overlay-glow events), and mouseover click-cast via override bindings on hidden secure buttons. It must work within Midnight-style "secret value" restrictions (no reading enemy auras/health/casts), match WUK's look and code patterns (`On` dispatcher, inits/refreshers, pure `Logic.lua` + `tests/run.lua`, `issecretvalue` guards, combat-lockdown deferral), and avoid anything WUK already covers.

Source: https://github.com/madacgrav/wow-addons/issues/23. Prior survey: `thoughts/qrspi/2026-10-21-warlock-combat-tooling/` (research.md, design.md).
