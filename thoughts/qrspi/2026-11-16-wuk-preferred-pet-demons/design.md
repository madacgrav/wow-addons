# Design Discussion

## Current State
- Preferred pet keys `imp | voidwalker | succubus | felhunter` are hand-copied in five places, none derived from another:
  - `SPELLS` entries — `WarlockUtilityKit/Core.lua:51-52`
  - `CHAR_DEFAULTS = { pet = "imp" }` — `Core.lua:20`
  - slash `pet` literal check — `Core.lua:233`
  - usage string — `Core.lua:247`
  - Settings dropdown `PETS` — `Settings.lua:3`
- Dropdown saves through the slash handler (`Settings.lua:48`), so a name missing from `Core.lua:233` cannot be saved from either path.
- Pet button (`Prep.lua:31-39`) falls back to `"imp"` when the saved key isn't in `WUK.known`. It decides the pet is out with `WUK.PetFamily() == pet`, the lower-cased `UnitCreatureFamily("pet")` (`Core.lua:110-115`).
- WoW Forever has a fifth persistent demon, `Summon Incubus` (level 20 quest, guides list it as "Sayaad"). It is missing from every list. Its `UnitCreatureFamily` string is unprobed: it could be "Incubus" (family 302) or "Succubus".
- Tests load only `Logic.lua` (`tests/run.lua:1-3`). No pet logic is tested.
- `/wuk probe` (`Core.lua:~162-220`) does not print the pet family.

## Desired End State
- Incubus can be chosen through `/wuk pet incubus` and the Settings dropdown.
  - The pet button casts `Summon Incubus`, shows its icon, and glows when no Incubus is out.
  - The button greys out when the Incubus is out, whether Forever reports its family as "Incubus" or "Succubus".
- The pet keys are listed once (`WUK.PETS` in `Logic.lua`). The slash check, the usage string and the dropdown all read from that list.
- `/wuk probe` prints the current pet's raw `UnitCreatureFamily` so the Incubus string can be confirmed in game.
- Verification:
  - `lua WarlockUtilityKit/tests/run.lua` passes, including new asserts for `WUK.PETS` membership and the pet-out matcher.
  - In game on a warlock with Incubus learned:
    - choose Incubus with the dropdown and with `/wuk pet incubus`;
    - click the button and the Incubus is summoned;
    - the button greys out while it is out;
    - `/wuk probe` shows its family.
  - Existing choices (imp, voidwalker, succubus, felhunter) behave as before.

## Patterns to Follow
- **Pure data and helpers in `Logic.lua` so tests can reach them.**
  - `CURSES` data table: `Logic.lua:92`. Its comment "may not exist on Forever; listed only if known" is the same situation as Incubus.
  - The test harness loads Logic.lua only (`tests/run.lua:3`).
- **Ordered list plus `ipairs` for UI order.** The dropdown already builds its entries this way (`Settings.lua:44-50`). Keep the display order: imp, voidwalker, succubus, incubus, felhunter (trainer/quest level order).
- **One code path.** Settings calls the slash handler (`Settings.lua:2`, `Settings.lua:6`). Keep that, so the dropdown's validation is the slash check.
- **Spells resolve from the spellbook by name.** Add `incubus = { "Summon Incubus" }` to `SPELLS` (`Core.lua:48-61`). `ScanSpells` (`Core.lua:87-93`) leaves the key nil if the spell isn't learned, and the button already falls back to Imp in that case (`Prep.lua:32`).
- **Plain `eq` asserts** in `tests/run.lua:5-7`. No framework.
- **Don't follow:**
  - Literal enumerations in conditionals (`Core.lua:233`) and usage text (`Core.lua:247`). These copies caused the bug.

## Design Decisions
1. **Scope: add Incubus only.** It is the only missing persistent pet the research confirmed.
   - Infernal and Doomguard are reagent or ritual summons. They may not be normal `pet` units, and `UnitCreatureFamily` may return nil for them.
   - No source shows Felguard on Forever.
2. **One shared list: `WUK.PETS = { "imp", "voidwalker", "succubus", "incubus", "felhunter" }` in `Logic.lua`.**
   - The slash check becomes a membership test against `WUK.PETS`.
   - The usage string becomes `table.concat(WUK.PETS, "|")`.
   - `Settings.lua` uses `WUK.PETS` instead of its own local copy.
   - `SPELLS` keeps its own entry per pet, because it maps keys to spell names and holds non-pet keys too.
   - `CHAR_DEFAULTS` keeps `"imp"`.
3. **Incubus family tolerance: a `WUK.PetIsOut(choice, family)` helper in `Logic.lua`.**
   - It returns true when `family == choice`, or when `choice == "incubus"` and `family == "succubus"`.
   - `Prep.lua:35` calls it in place of the bare `==`.
   - Being pure, it can be tested.
4. **Probe line.** `/wuk probe` prints `pet family: <raw UnitCreatureFamily("pet") or none>`, so the user can confirm the Incubus string and remove the alias later if it isn't needed.
5. **Docs.** Update the README (`README.md:63`, `README.md:151`) and add a CHANGELOG entry so they list Incubus.

## What We're NOT Doing
- No Infernal, Doomguard, Felguard, Eye of Kilrogg or mounts.
- No validation or migration of saved `WUK.char.pet` values. An unknown key already falls back to Imp (`Prep.lua:32`).
- No change to how `SPELLS` or `ScanSpells` works, and no deriving `SPELLS` from `WUK.PETS`.
- No localisation of family strings beyond the Incubus/Succubus alias.
- No tests for Core, Settings or Prep (they need WoW API stubs). Only the new Logic.lua pieces are tested.

## Open Risks
- **Unconfirmed spell name.** `Summon Incubus` comes from guides, not an in-game probe. If Forever names it differently, `WUK.known.incubus` stays nil and the button falls back to Imp. The probe and spellbook will show the real name.
- **Wrong family string.** If the Incubus reports neither "incubus" nor "succubus" (for example "sayaad"), the button never greys out. The probe line exposes this.
- **Alias cross-match.** If the Incubus reports "succubus", choosing Succubus while an Incubus is out shows the button as out. Acceptable, since both are the same Sayaad pet.
- **Dropdown height.** A fifth radio entry makes the menu taller. The settings window is 320×314 (`Settings.lua:20`), and the menu opens as a popup, so it is probably fine. Check in game.
