# Research Questions

## Context
Focus on the `WarlockCombatKit/` addon: `Core.lua` (event handlers, `WCK.Identify`, `NonSecret`/`WCK.Secret`), `Logic.lua` (`WCK.EnemyKey`, `WCK.PickUnit`, cast map functions), `Panel.lua` (row rendering), and `tests/run.lua`. Also relevant: the Forever API docs/index in the `wow-forever-addon` skill covering secret values (`issecretvalue`, `C_Secrets`) and unit/nameplate APIs.

## Questions
1. Trace how an enemy is identified from a spell cast to a tracker row: starting at the `UNIT_SPELLCAST_SENT` / `SUCCEEDED` handlers in `Core.lua`, through `WCK.Identify`, `WCK.PickUnit`, `WCK.EnemyKey`, `WCK.CastSent`/`CastLanded`, to the `key` and `label` stored on each row. What inputs determine the key, and what fallback values are used at each step when inputs are missing?
2. How does the addon detect and filter "secret" values (`WCK.Secret`, `NonSecret`, `Clean`, `pcall` wrappers), and which specific API returns (UnitGUID, UnitName, raid marks, SENT event `target` arg, castGUID) pass through those filters? Are there any code comments, probe notes, or CHANGELOG entries recording which values were observed secret and in what context (open world, combat, instance)?
3. What does the Forever API documentation (the `wow-forever-addon` skill's API index and any references to `C_Secrets`, `issecretvalue`, secret aura/unit restrictions) say about when unit identity values (GUID, name, raid target index, nameplate unit tokens) become secret — e.g. by instance type, combat state, or unit relationship — and what non-secret identity alternatives exist?
4. How does `Panel.lua` render rows from the cast map: how are rows ordered, merged, labelled (including the `"Target"` literal), and cleared? How do row-clearing paths (dead target, `UNIT_DIED`-style handling, `CLR_TARGET` trace) behave when multiple casts share the same key?
5. What does the `/wck` debug/probe command in `Core.lua` (the `P(...)`/`Try(...)` diagnostics around lines 300–390) report, and what has it been used to establish? What tracing (`WCK.Trace`) exists that would show the key chosen per cast?
6. What test coverage exists in `tests/run.lua` and the mock WoW API harness for identity/key selection under secret inputs, and how does the harness simulate secret values?
