# Research Findings

## Q1: Where are demon/pet identifiers defined or enumerated, and how do the lists relate?

### Findings
- Five independent, hand-written enumerations of the same four keys (`imp`, `voidwalker`, `succubus`, `felhunter`); none is derived from another:
  - `WarlockUtilityKit/Core.lua:51-52` — `SPELLS` table entries `imp = { "Summon Imp" }`, `voidwalker = { "Summon Voidwalker" }`, `succubus = { "Summon Succubus" }`, `felhunter = { "Summon Felhunter" }`. Local to Core.lua; not exported.
  - `WarlockUtilityKit/Settings.lua:3` — `local PETS = { "imp", "voidwalker", "succubus", "felhunter" }`, iterated for the dropdown radios at `Settings.lua:44-50`. Display label = key with first letter upper-cased (`Settings.lua:46`).
  - `WarlockUtilityKit/Core.lua:233` — slash handler accepts `pet` only when `arg` equals one of the four literals; anything else falls through to the usage line.
  - `WarlockUtilityKit/Core.lua:247` — usage string `pet <imp|voidwalker|succubus|felhunter>`.
  - `WarlockUtilityKit/Core.lua:20` — `CHAR_DEFAULTS = { pet = "imp" }`.
- Hard-coded fallback key `"imp"` also in `WarlockUtilityKit/Prep.lua:32`.
- Settings dropdown routes selection through the slash handler: `Run("pet " .. pet)` (`Settings.lua:48`, `Run` at `Settings.lua:6`), so a dropdown entry the slash handler rejects prints usage instead of saving.
- Docs list the same four: `WarlockUtilityKit/README.md:63`, `README.md:151`; `CHANGELOG.md:52`.
- `WUK.known` keys are shared across features: pet keys sit in the same `SPELLS` namespace as `armor`, `detect`, `soullink`, `ritual`, stones, `curseshadow` (`Core.lua:48-61`).

## Q2: How is `WUK.known` built from the spellbook?

### Findings
- `SpellbookNames()` (`Core.lua:63-85`) builds a set of spell names from the player spellbook: modern `C_SpellBook` skill-line iteration (`Core.lua:65-72`), fallback to classic `GetNumSpellTabs`/`GetSpellBookItemName` (`Core.lua:73-80`).
- `WUK.ScanSpells()` (`Core.lua:87-93`): for each `SPELLS` key, walks its name list in order and stores the first name present in the spellbook: `known[key] = n; break`. Result replaces `WUK.known` wholesale.
- Ranked spells: per comment `Core.lua:46-47`, Classic-era stone ranks have distinct names and are listed highest-first; same-name ranked spells (e.g. Demon Armor) rely on `/cast Name` casting the highest rank. Pet summons are single-name lists.
- Missing spell: key is simply absent from `WUK.known` (nil).
- Triggers: `PLAYER_LOGIN` (`Core.lua:147-153`, warlocks only) and `SPELLS_CHANGED` (`Core.lua:157`).

## Q3: How does the pet button choose spell, icon, and "out" state? What must a key match?

### Findings
- Button created in an init (`Prep.lua:23-30`): `SecureActionButtonTemplate`, `type = "macro"`, registered as `WUK.strip.icons.pet`.
- Refresher (`Prep.lua:31-39`):
  - `pet = WUK.known[WUK.char.pet] and WUK.char.pet or "imp"` — saved choice if its spell is known, else `"imp"` (`Prep.lua:32`).
  - `spell = WUK.known[pet]` (`Prep.lua:33`); icon = `C_Spell.GetSpellTexture(spell)` or question-mark texture `134400` (`Prep.lua:34`).
  - `out = WUK.PetFamily() == pet` (`Prep.lua:35`); desaturated when not out, alert glow when spell known and not out (`Prep.lua:36-37`).
  - Macro `/cast <spell>` set only out of combat (`Prep.lua:38`).
- `WUK.PetFamily()` (`Core.lua:110-115`): nil if no `pet` unit; else `UnitCreatureFamily("pet")`, nil if secret, else `:lower()`.
- So the key string must equal the lower-cased localized creature family name exactly (e.g. `"Felhunter"` → `"felhunter"`). Keys double as `SPELLS` keys and as family comparison strings; no separate mapping exists.
- Refresh triggers relevant to pets: `UNIT_PET` for player (`Core.lua:159`), plus `UNIT_AURA`, bag, regen, spells events (`Core.lua:154-158`).

## Q4: Which warlock demon summons/families exist on WoW Forever?

### Findings (local notes)
- Forever client: 1.60.1 build 70532 (beta) — `thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:3`; Interface 16001 on Midnight-era retail client — `thoughts/qrspi/2026-10-24-disc-priest-kit/research.md:193`.
- Succubus confirmed in-game: `Summon Succubus` (712) cast and pet Seduction (6358) casts — `probe-results.md:90,92,98,103`. `pet` unit works on Forever.
- No local probe of `UnitCreatureFamily("pet")` output exists for any demon.

### Findings (web — community guides, secondary sources)
- Forever: vanilla-framework, permanent level-60 cap, new content within 1-60; no TBC content found ([warcrafttavern roadmap](https://www.warcrafttavern.com/forever/news/world-of-warcraft-forever-roadmap-beta-launch-date-raids/)).
- Roster per [conquestcapped](https://conquestcapped.com/guides/wow-forever/wow-forever-warlock-overview/), [wclbox levels](https://wowforever.wclbox.com/en/fashu/warlock/levels), [theforeverguides](https://theforeverguides.com/classes/warlock/pets/), [warcrafttavern warlock](https://www.warcrafttavern.com/forever/guides/warlock/):

| Spell | Obtained | Persistent `pet` | Family (wiki ID) |
|---|---|---|---|
| Summon Imp | L1 | yes | Imp (23), unconfirmed on Forever |
| Summon Voidwalker | L10 quest | yes | Voidwalker (16) |
| Summon Succubus | L20 quest | yes (confirmed locally) | Succubus (17) |
| **Summon Incubus** | L20 quest (separate) | yes | Incubus (302, added 9.2.0) — guides list "Sayaad (Succubus/Incubus)" |
| Summon Felhunter | L30 quest | yes | Felhunter (15) |
| Inferno | L50 quest, Infernal Stone reagent | unconfirmed; described as temporary guardian | Infernal (108) |
| Ritual of Doom | L60, 5-player ritual | unconfirmed; Doomguard must be enslaved or turns hostile | Doomguard (19) |
| Summon Felsteed / Dreadsteed | L40 / L60 | no — mounts | n/a |
| Eye of Kilrogg | L22 | unconfirmed; channeled possession | not in family list |
| Felguard | not found on Forever | n/a | Felguard (29) generic API only |

- [API_UnitCreatureFamily](https://warcraft.wiki.gg/wiki/API_UnitCreatureFamily): returns localized family name; "Returns nil if the creature doesn't belong to a family that includes a tameable creature" — documented risk for Infernal/Doomguard.

## Q5: How are per-character settings loaded and validated?

### Findings
- `ADDON_LOADED` (`Core.lua:22-28`): `WarlockUtilityKitCharDB = WUK.MergeDefaults(WarlockUtilityKitCharDB, CHAR_DEFAULTS)`; `WUK.char` aliases it.
- `WUK.MergeDefaults` (`Logic.lua:16-23`): non-table SV becomes `{}`; fills only nil keys; recurses tables. No value validation.
- A saved `pet` not among recognized keys is kept as-is. At use time `Prep.lua:32` treats any key not in `WUK.known` as `"imp"`; Settings radio shows none selected (`Settings.lua:47`).
- `SavedVariablesPerCharacter: WarlockUtilityKitCharDB` — `WarlockUtilityKit.toc:7`. Char DB also holds `soulstone` (`Prep.lua:44`) and `board` (`Board.lua:15`).

## Q6: What test coverage exists, and how does the harness stub WoW APIs?

### Findings
- Single file `WarlockUtilityKit/tests/run.lua`; loads only `Logic.lua` via `loadfile(dir .. "/Logic.lua")("WarlockUtilityKit", WUK)` (`tests/run.lua:1-3`). Plain `eq` assert helper (`tests/run.lua:5-7`).
- No WoW API stubs: tests cover pure functions only — `ClassifyItem`, `MergeDefaults`, `FormatTime` (`tests/run.lua:10-21`), `SoulstoneRemaining` (`:24-26`), `IsSummonRequest`, `SummonFailure` (`:29-46`), `StoneMacro` (`:~50-57`), `AssignmentText` (`:~64`).
- No coverage of `SPELLS`, `ScanSpells`, `PetFamily`, slash parsing, or Settings — all live in Core.lua/Settings.lua/Prep.lua, which the harness does not load.

## Cross-Cutting Observations
- Pure logic lives in `Logic.lua` (testable); WoW-API-touching code in Core/Prep/Settings (untested). `Logic.lua:92` already holds a data table (`CURSES`) with a "may not exist on Forever; listed only if known" pattern consumed by `Board.lua:117` via `WUK.known.curseshadow`.
- Settings UI deliberately routes every option through the slash handler — "one code path" (`Settings.lua:2`).
- Pet key string serves three roles: saved value, `SPELLS`/`WUK.known` key, and lower-cased `UnitCreatureFamily` match.

## Open Areas
- Actual `UnitCreatureFamily("pet")` strings on Forever for Imp/Voidwalker/Felhunter/Incubus/Infernal/Doomguard — unprobed. `WUK.Probe()` exists (`Core.lua:~162-220`) but prints no pet family.
- Whether Incubus reports family "Incubus" or "Succubus" on Forever.
- Whether Inferno / Ritual of Doom leave a controllable `pet` unit, and whether their families return nil.
- Felguard absence based on secondary sources only.
