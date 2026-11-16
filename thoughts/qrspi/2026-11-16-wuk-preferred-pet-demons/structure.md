# Structure Outline

## Approach
First collapse the five hand-copied pet lists into one `WUK.PETS` in `Logic.lua`, with no change in behaviour. Then add Incubus end to end: list entry, spell, an out check that also accepts "succubus", a probe line and docs.

## Phase 1: One shared pet list
After this phase, the slash check, the usage string and the Settings dropdown read one ordered list. Behaviour is identical to today: the same four pets in the same order.

**Files**: `WarlockUtilityKit/Logic.lua`, `WarlockUtilityKit/Core.lua`, `WarlockUtilityKit/Settings.lua`, `WarlockUtilityKit/tests/run.lua`
**Key changes**:
- `WUK.PETS = { "imp", "voidwalker", "succubus", "felhunter" }` — new, in Logic.lua (next to the `CURSES` data, `Logic.lua:92`).
- `WUK.IsPet(key: string?): boolean` — new pure membership test.
- `Core.lua:233`: the slash `pet` branch uses `WUK.IsPet(arg)` instead of four literals.
- `Core.lua:247`: the usage text builds `pet <...>` from `table.concat(WUK.PETS, "|")`.
- `Settings.lua:3`: the local `PETS` is removed. The dropdown loop (`Settings.lua:44-50`) iterates `WUK.PETS`.
- tests: `WUK.IsPet("imp") == true`, `WUK.IsPet("felguard") == false`, `WUK.IsPet(nil) == false`.

**Verify**:
- `lua WarlockUtilityKit/tests/run.lua` passes.
- In game:
  - `/wuk pet voidwalker` saves the choice.
  - `/wuk pet bogus` prints the usage text with all four names.
  - The dropdown still lists the 4 pets and the selection still sticks.

---

## Phase 2: Incubus end to end
After this phase, the Incubus can be chosen and summoned, and the button greys out while it is out whether the game reports its family as "incubus" or "succubus". The probe shows the raw family, and the docs list Incubus.

**Files**: `WarlockUtilityKit/Logic.lua`, `WarlockUtilityKit/Core.lua`, `WarlockUtilityKit/Prep.lua`, `WarlockUtilityKit/tests/run.lua`, `WarlockUtilityKit/README.md`, `WarlockUtilityKit/CHANGELOG.md`
**Key changes**:
- `WUK.PETS` gets `"incubus"` between succubus and felhunter.
- `WUK.PetIsOut(choice: string, family: string?): boolean` — new pure helper. It returns true when `family == choice`, or when `choice == "incubus"` and `family == "succubus"`.
- `Core.lua:51-52` `SPELLS`: add `incubus = { "Summon Incubus" }`.
- `Prep.lua:35`: `local out = WUK.PetIsOut(pet, WUK.PetFamily())`.
- `Core.lua:174+` `WUK.Probe`: add `P("pet family", UnitExists("pet") and S(UnitCreatureFamily("pet")) or "none")`. `S` is the probe's existing secret-safe formatter.
- tests:
  - `IsPet("incubus")` returns true.
  - `PetIsOut` returns true for incubus/incubus, incubus/succubus and imp/imp.
  - `PetIsOut` returns false for imp/nil, succubus/incubus and felhunter/imp.
- README (`README.md:63`, `:151`) and CHANGELOG list Incubus. Bump the version in the TOC (`0.3.1` to `0.3.2`).

**Verify**:
- `lua WarlockUtilityKit/tests/run.lua` passes.
- Deploy with robocopy to `_forever_\Interface\AddOns`.
- In game, on a warlock with Incubus learned:
  - Choose Incubus in the dropdown and with `/wuk pet incubus`.
  - The pet button shows the Incubus icon and glows. Clicking it summons the Incubus, and the button then greys out.
  - `/wuk probe` prints `pet family: …`. Note the actual string.
  - Switch back to Succubus and Imp. Their behaviour is unchanged.
  - Without Incubus learned, choosing Incubus falls back to the Imp.

## Testing Checkpoints
- **After Phase 1**: tests green. There is one pet list in Logic.lua, and Core and Settings hold no pet literals besides the `SPELLS` entries and `CHAR_DEFAULTS`. In-game behaviour is unchanged.
- **After Phase 2**: tests green. Incubus can be picked and summoned, and the button shows correctly whether it is out. The probe reports the real family string, which tells us whether the succubus alias can be dropped.
