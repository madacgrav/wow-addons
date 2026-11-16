# Research Findings

Paths relative to repo root. WCK = `WarlockCombatKit/`, WUK = `WarlockUtilityKit/`.

## Q1: Where does `WCK.DATA.rotation` come from, and who consumes it?

### Findings
- Source: hard-coded literal array of 24 enUS names, `WCK/Data.lua:20-23`. Comment `Data.lua:19`: "spells offered in the rule editor (filtered to known spells when the menu opens)". `Data.lua:3`: names from beta notes, unknown ones skipped. No IDs, no metadata. Not derived from `DATA.tracked` (`Data.lua:5-17`), `defaultRules` (`:24-28`) or `procs` (`:34-36`).
  - Contents: Shadow Bolt, Incinerate, Searing Pain, Soul Fire, Shadowburn, Conflagrate, Drain Life, Drain Soul, Life Tap, Haunt, Chaos Bolt, Corruption, Immolate, Siphon Life, Unstable Affliction, Curse of Agony, Bane of Agony, Curse of Doom, Bane of Doom, Curse of the Elements, Curse of Recklessness, Fear, Death Coil, Howl of Terror. **Wrack not present.**
- Consumer 1: `KnownSpells()` `WCK/Settings.lua:19-23`. Filters rotation by `WCK.Known`, keeps rotation order. Used by:
  - Rule spell dropdown `Settings.lua:33-40`. One `CreateRadio` per name. The selection sets `WCK.char.rules[i].spell`. The menu is rebuilt on `GenerateMenu()` in `SyncRules` (`Settings.lua:79`).
  - Mouseover slot dropdown `Settings.lua:100-111`. Has a "(none)" radio, then one radio per known name. The selection sets `WCK.char.slots[i]` (`:103`).
- Consumer 2: `WCK.BuildRuleState` `WCK/Core.lua:158-180`. Loops rotation (`:160`), and for known names sets `s.known` (`:162`), `s.ready` from `C_Spell.GetSpellCooldown` (`:163-166`) and `s.usable` from `C_Spell.IsSpellUsable` (`:167-170`). So `known/ready/usable` keys are a subset of rotation. Refresher `Core.lua:182-184` sets `WCK.next = EvalRules(char.rules, BuildRuleState(GetTime()))`.
  - `s.lastOnTarget` (`:177`) is keyed by cast-map spells, which are gated by `DATA.tracked` (`Core.lua:202`), not rotation.
- Non-consumers:
  - `Logic.lua` `EvalRules` (`:114-119`) reads only the state it is passed.
  - `Actions.lua` reads `char.slots` only (`:19`).
  - `Panel.lua` reads `WCK.next` (`:136`, `:196-199`) and `DATA.tracked`-derived rows (`:215`).
  - `tests/run.lua` never references rotation.

## Q2: How does `WCK.Known(name)` decide a spell is known?

### Findings
- `WCK/Core.lua:153-156`: `pcall(C_Spell.GetSpellInfo, name)`, then `IsPlayerSpell(info.spellID)`. Returns false on any failure. No spellbook scan, no `IsSpellKnown`, no override/base handling.
- Same pattern inline in the proc refresher `Core.lua:136-138`. `BusinessCard/Core.lua:148` uses the looser `IsPlayerSpell(s.id) or C_Spell.GetSpellInfo(s.name)`.
- Recorded behaviour on Forever:
  - By-name `GetSpellInfo` works for "Shadow Bolt" and "Corruption". `.castTime` is non-secret in combat and reflects talents/procs (`thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md:169-186`; Corruption reads 0 "instant through the talent", `:177`).
  - Not probed:
    - `IsPlayerSpell` secrecy.
    - Behaviour for talent-granted or capstone spells.
    - Name lookup for override spells.
- Notes:
  - `IsSpellKnown` is deprecated 11.2.0 in favour of `C_SpellBook.IsSpellInSpellBook`. Its Forever status is UNVERIFIED. The same notes say "Passive spells: use `IsPlayerSpell`" (`thoughts/qrspi/2026-10-19-warlock-utility-kit/research.md:91`).
  - Talent API on Forever is listed as an open question (`.../research.md:157`).
- Overrides: Curse to Bane is recorded only as a game rule change (`thoughts/qrspi/2026-10-21-warlock-combat-tooling/research.md:130`). The code covers it by listing both names in `tracked` (`Data.lua:8-9`), `rotation` (`:21-22`) and `defaultRules` (`:25-26`).
- WUK uses a different mechanism: spellbook name scan (see Q4). `WUK/Core.lua:48-62` holds candidate name lists ("first known wins"), and `WUK.ScanSpells` is at `:87-93`.

## Q3: What Warlock spell metadata is recorded for Forever?

### Findings
- `WCK/Data.lua` records names only.
  - `tracked` (`:5-17`) maps name to `{kind=dot|curse|cc, stale=seconds}`.
  - `rotation` (`:20-23`).
  - `procs` (`:34-36`): Nightfall, keyed to Shadow Bolt.
  - Harmful/helpful and passive/active flags are not recorded anywhere.
- Spell IDs in code:
  - Only 17941 (Shadow Trance), in the probe at `WCK/Core.lua:280-285`.
  - WUK has no IDs: names only (`WUK/Core.lua:48-62`, `WUK/Logic.lua:103`).
- Spell IDs in notes:
  - `combat-tooling/research.md:107-110`: Corruption 25311, CoA 11713, Shadow Trance 17941.
  - Probe traces (`probe-results.md`): 6217 CoA (`:80`), 1086 Demon Armor, 8288 Drain Soul, 712 Summon Succubus, 6358 Seduction, 1106 Shadow Bolt (inferred). 6223, 5782 and 709 are not annotated.
- Capstones and talents (`thoughts/qrspi/2026-10-21-warlock-combat-tooling/research.md:129-150`, sourced from beta notes, zockify and accountshark):
  - `:136`: "Affliction capstone Wrack: +10% to the warlock's other Shadow DoTs for 6s."
    - No ID recorded.
    - No castable/passive or harmful/helpful info.
    - No code references Wrack.
  - `:137`: Demonic Pact (Demonology capstone). Also `:131` Bane of Havoc (Destruction 21-pt talent), `:135` Pandemic, `:138` Decimation.
  - `thoughts/qrspi/2026-10-19-warlock-utility-kit/research.md:75` also lists capstones "Wrack, Demonic Pact, Incinerate".
- Secrecy:
  - `GetSpellAuraSecrecy` returns 2 for 17941 (`probe-results.md:17-18`).
  - "All warlock curses/Banes/DoTs/Banish secrecy 2" (`combat-tooling/research.md:5`).
  - No warlock spells are on the non-secret whitelist (`:172`).

## Q4: What APIs can enumerate the player's spellbook, and what do they return?

### Findings
- Only scanner in the repo: `WUK/Core.lua:64-85` `SpellbookNames()`.
  - Walks `C_SpellBook.GetNumSpellBookSkillLines()`, then `GetSpellBookSkillLineInfo(i)` and slots `itemIndexOffset+1..+numSpellBookItems`, calling `C_SpellBook.GetSpellBookItemName(j, Enum.SpellBookSpellBank.Player)` (`:66-74`).
  - Falls back to Classic `GetNumSpellTabs/GetSpellTabInfo/GetSpellBookItemName(j,"spell")` (`:75-82`).
  - Collects names only.
  - Runs at PLAYER_LOGIN and `SPELLS_CHANGED` (`thoughts/qrspi/2026-10-19-warlock-utility-kit/plan.md:318-372`).
  - Used in production by WUK (Prep, Summon, UI, Board), so the `C_SpellBook` path works on Forever for names. No recorded output listing passive or talent entries.
- No other addon calls `C_SpellBook`, `GetSpellBookItemInfo`, `IsSpellHarmful/Helpful`, `GetOverrideSpell` or `GetRotationSpells` outside the WCK probe (repo-wide grep).
- `C_AssistedCombat` in combat, open world (`probe-results.md:19-21,43,206`):
  - `IsAvailable()` = false.
  - `GetRotationSpells()` = empty list (not secret).
  - `GetNextCastSpell()` = nil.
  - Recorded conclusion: unavailable for warlocks. The probe code is at `WCK/Core.lua:289-302`.
- Wiki signatures (warcraft.wiki.gg). Each page lists Retail 11.0.0+ and Forever 1.60.1:
  - `C_SpellBook.GetSpellBookSkillLineInfo(i)` returns `{name, iconID, itemIndexOffset, numSpellBookItems, isGuild, shouldHide, specID?, offSpecID?}`.
  - `C_SpellBook.GetSpellBookItemInfo(slot, bank)` returns `{actionID, spellID?, itemType, name, subName, iconID, isPassive, isOffSpec, skillLineIndex?}`.
    - `actionID` is the base ID. `spellID` is the override if overridden.
    - Flags: AllowedWhenUntainted, MayReturnNothing.
  - `C_SpellBook.GetSpellBookItemType(slot, bank)` returns `itemType, actionID, spellID?`. Enum `SpellBookItemType`: None 0, Spell 1, FutureSpell 2, PetAction 3, Flyout 4.
  - `C_SpellBook.IsSpellBookItemPassive(slot, bank)` returns a boolean.
  - `C_Spell.IsSpellHarmful(id)` / `IsSpellHelpful(id)` return booleans (hostile vs friendly/self targetable).
  - `C_Spell.GetOverrideSpell(id, ...)` returns the active override spellID.
  - URLs: https://warcraft.wiki.gg/wiki/API_C_SpellBook.GetSpellBookItemInfo , .../API_C_SpellBook.GetSpellBookSkillLineInfo , .../API_C_SpellBook.GetSpellBookItemType , .../API_C_SpellBook.IsSpellBookItemPassive , .../API_C_Spell.IsSpellHarmful , .../API_C_Spell.IsSpellHelpful , .../API_C_Spell.GetOverrideSpell , .../API_C_AssistedCombat.GetRotationSpells
- Secrecy recorded for `C_Spell` in combat (`probe-results.md:41-42,179,186`):
  - Non-secret: `GetSpellInfo().castTime`, `IsSpellUsable`, `IsSpellInRange`, and `GetSpellCooldown` `isActive/isEnabled`.
  - Secret: `startTime`.
  - `isOnGCD` returns plain nil.
  - None of the `C_SpellBook` item-info calls, `isPassive`, harmful/helpful or `GetOverrideSpell` have been probed.

## Q5: How are saved rules and slots stored, and how is a name outside `DATA.rotation` handled?

### Findings
- Storage:
  - `WCK/WarlockCombatKit.toc:6-7`: `SavedVariables: WarlockCombatKitDB` and `SavedVariablesPerCharacter: WarlockCombatKitCharDB`.
  - `Core.lua:24` `CHAR_DEFAULTS = { slots = {} }`, merged at ADDON_LOADED (`Core.lua:26-32`) via `MergeDefaults` (`Logic.lua:3-10`).
- Rules:
  - Created at PLAYER_LOGIN only if nil: `WCK.char.rules = CopyRules(DATA.defaultRules)` (`Core.lua:195-197`). MergeDefaults is deliberately avoided.
  - Rule shape is `{spell, cond, n?}`. `CopyRules` (`Logic.lua:129-133`) copies those three fields.
  - Defaults button `Settings.lua:71`. Add rule inserts `{spell="Shadow Bolt", cond="ready"}` (`:68`).
  - Max 10 rules, enforced by the UI only (`Settings.lua:18`, `:83`).
- Slots: `char.slots[i] = name|nil`, with i in 1..`WCK.SLOTS`=6 (`Logic.lua:136`).
- No version field and no migration. Saved names are never validated.
- A name not in rotation:
  - Load: kept as-is.
  - Dropdown: no radio matches it, and this code does not set fallback text (`Settings.lua:37`, `:109`). The same happens for a rotation name that is currently unknown.
  - Evaluation: `EvalRules` requires `state.known[r.spell]` (`Logic.lua:117`), so the rule is skipped silently. Test "unknown skipped" is at `tests/run.lua:63`.
  - Panel: `WCK.next` is always a known rule spell. With no match the tooltip reads "No rule matches" (`Panel.lua:136`) and the icon shows desaturated Death Coil (`:196-197`).
  - Secure slots (`Actions.lua:7-20`):
    - `SecureActionButtonTemplate` named `WCKCast<i>`, `type="macro"`.
    - The refresher sets `macrotext = WCK.CastMacro(char.slots[i])`.
    - `CastMacro` (`Logic.lua:137-140`) builds `/cast [@mouseover,harm,nodead][] <spell>` for any non-empty string. It does not check rotation or known status.
    - The refresher skips while `InCombatLockdown()` (`Actions.lua:18`). Changes reapply on PLAYER_REGEN_ENABLED via `WCK.Refresh` (`Core.lua:51`, debounced `:34-42`).
    - Settings prints "slot change applies after combat" (`Settings.lua:104`).

## Q6: How does `tests/run.lua` work?

### Findings
- No WoW API stubs. Loads only `Data.lua` and `Logic.lua` via `loadfile(...)("WarlockCombatKit", WCK)` (`tests/run.lua:1-4`). Core, Settings, Panel and Actions (including `Known` and `BuildRuleState`) are untested.
- Helpers `eq`, `near` (`:6-11`). Straight-line asserts per phase, ending with `print("all tests passed")` (`:78`).
- Phases:
  - 1: MergeDefaults (`:14-17`).
  - 2: cast map, `RowsView` with `DATA.tracked` (`:20-42`).
  - 3: `RowHasCC` (`:45-47`).
  - 4: procs (`:50-54`).
  - 5: `EvalRules` with a hand-built state table (`:57-67`), plus `MoveRule` and `CopyRules` (`:68-71`).
  - 6: `CastMacro` (`:74-76`).
- `DATA.rotation` is never referenced. The only `DATA` use is `tracked` (`:38`).
- Run: `lua5.1 WarlockCombatKit/tests/run.lua` (`WCK/README.md:115`). On this machine, `lua` (not `lua5.1`) on PATH runs it from the repo root and passes.

## Cross-Cutting Observations
- Two "known spell" strategies coexist:
  - WCK checks a fixed name list one name at a time (`GetSpellInfo` + `IsPlayerSpell`).
  - WUK scans the spellbook by name (`C_SpellBook`), then matches against candidate lists.
- WCK keeps all spell data as enUS names. Rules, slots, state tables, macros and cooldown/usable calls are all keyed by name strings.
- Pure logic lives in `Logic.lua`/`Data.lua` and is unit tested. WoW-facing glue (`Core.lua`, `Settings.lua`) is not.
- Secure attribute changes are always deferred out of combat, through the refresher plus PLAYER_REGEN_ENABLED.

## Open Areas
- Whether Wrack is castable or passive on Forever, its spell ID, and whether `GetSpellInfo("Wrack")` / `IsPlayerSpell` return it: no record in the repo.
- What `C_SpellBook.GetSpellBookItemInfo` returns on Forever (`isPassive`, `isOffSpec`, override `spellID`), and whether any of it is secret in combat: not probed.
- Secrecy of `IsPlayerSpell`, `IsSpellHarmful`/`IsSpellHelpful` and `GetOverrideSpell` in combat: not probed.
- How the `WowStyle1DropdownTemplate` button text renders when no radio is checked: not determinable from the repo.
