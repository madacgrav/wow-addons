# Design Discussion

## Current State
- Rotation bar: 13 secure buttons `WCKRotation1..13` (`Rotation.lua:38-40`), `RegisterForClicks("AnyUp","AnyDown")`, `type=macro`, one unsuffixed `macrotext` set from `WCK.CastMacro(e.spell)` (`Rotation.lua:66`). Every mouse button and modifier therefore casts the same spell.
- Button→spell mapping is positional and recomputed each out-of-combat refresh from `WCK.BarSpells(rules, tail, known, core)` (`Logic.lua:178-188`, `Rotation.lua:59-73`). Only `b.spell` identifies a button's content.
- Secure writes guarded by `InCombatLockdown()` (`Rotation.lua:58`, `Actions.lua:18`); caught up via `PLAYER_REGEN_ENABLED → WCK.Refresh` (`Core.lua:52`).
- Per-char SV `WarlockCombatKitCharDB` merged with `CHAR_DEFAULTS = { slots = {} }` (`Core.lua:25-32`); `char.rules` is `{spell,cond,n}` list seeded separately (`Core.lua:254`).
- Settings window composes `WCK.settingsSections` (`Settings.lua:4`, `148`); spell pickers use `SpellMenu` + `WowStyle1DropdownTemplate` + `(none)` radio (`Settings.lua:20-27`, `102-111`).
- Tooltip on bar button shows only `self.spell` (`Rotation.lua:47-50`).
- Tests: plain-Lua `tests/run.lua` over `Data.lua` + `Logic.lua` only (`tests/run.lua:1-4`).
- No Ace3 / LibStub in the addon.

## Desired End State
- Each rotation bar button (rule spells and the Shadow Bolt/Fear/Banish tail) can carry two optional situational spells:
  - **Right-click** casts the "right" spell.
  - **Shift+left-click** casts the "shift" spell.
  - Plain left-click unchanged. Shift+right-click falls back to the right spell (or main if none).
  - Unset alternate: that click casts the button's main spell (today's behaviour).
- Alternates are stored per spell name, so they follow the spell when rules are reordered or edited.
- New "Alt clicks" settings section lists the spells currently on the bar, each with Right and Shift dropdowns (`(none)` + spellbook).
- Tooltip on a bar button lists configured alternates ("Right: X", "Shift: Y").
- Alternates cast with the same mouseover-harm macro as the main spell.
- Edits made in combat apply after combat (same as every other secure setting).

### Verification
- Offline: new pure function in `Logic.lua` producing the attribute set for a button is covered in `tests/run.lua` (main only; right only; shift only; both; empty/invalid alt names ignored).
- Lint clean via skill `lint.sh`.
- In-game (Forever): left / right / shift+left / shift+right on a configured and an unconfigured button cast the expected spell; reorder rules and confirm alternates follow the spell; change an alt in combat, confirm it applies after leaving combat with no `ADDON_ACTION_BLOCKED`; Shift+drag on bar still moves the kit and does not cast.

## Patterns to Follow
- **Secure write in guarded refresher** — set the new attributes inside the existing Rotation secure refresher next to `macrotext` (`Rotation.lua:57-77`), never in combat.
- **Pure logic in `Logic.lua`, tested in `tests/run.lua`** — mirrors `CastMacro`/`BarSpells` (`Logic.lua:178-211`, `tests/run.lua:99-130`).
- **Defaults via `MergeDefaults`** — add `alts = {}` to `CHAR_DEFAULTS` (`Core.lua:25`); a map (not a list) is safe to merge, unlike rules (`Core.lua:253` comment).
- **Settings section** — append to `WCK.settingsSections`, push a `{Sync=fn}` into `win.syncs`, call `WCK.Refresh()` on change and print "applies after combat" when in combat (`Settings.lua:92-121`, `106`).
- **Spell picker** — reuse `SpellMenu` with a `(none)` radio (`Settings.lua:109-110`).
- **Spell identity by English name** (`Data.lua:3`).
- **Do NOT follow**: the core button's insecure `OnMouseUp` right-click handler (`Rotation.lua:31-32`) — right-click on bar buttons must go through secure attributes, or it can't cast in combat. The core keeps its right-click = options behaviour.
- **Do NOT** key data by bar button index — indices shift (`Rotation.lua:61-66`).

## Design Decisions
1. **Storage keyed by spell**: `char.alts[mainSpell] = { right = "Spell"|nil, shift = "Spell"|nil }` — stable across rule reorder, covers tail buttons, rule schema/`CopyRules` untouched.
2. **Secure attribute names**: `macrotext2` (right, any modifier unless more specific) and `shift-macrotext1` (shift+left). Unsuffixed `macrotext` stays the main spell. `type=macro` stays unsuffixed so all variants use the macro type. Unset alternates are cleared to `nil` so lookup falls back to `macrotext`.
3. **Fallback = main spell**: relies on the template's attribute fallback; no explicit empty macros.
4. **Shift scope = shift+left only**: shift+right resolves via `macrotext2` (right alternate) then `macrotext`.
5. **Config UI = new "Alt clicks" section**: rows are pooled to `WCK.BAR_MAX` (13) and rebuilt on sync from `BarSpells(...)`; hidden rows for unused slots. Row label = main spell, two dropdowns Right/Shift.
6. **No Ace3**: vanilla secure attributes and existing settings UI suffice (task.md Ace3 check).
7. **Same macro form**: alternates use `WCK.CastMacro(alt)` — consistent targeting.
8. **One pure helper**: e.g. `WCK.AltAttrs(spell, alts)` → `{ macrotext, macrotext2, ["shift-macrotext1"] }` (values `nil` when unset); Rotation refresher applies it. Keeps the logic testable offline.
9. **Stale alts kept**: entries for spells no longer on the bar remain in SV (cheap, reappear if spell returns); no cleanup pass.

## What We're NOT Doing
- No alternates on the Life Tap core button (right-click stays = options) or the hidden Actions keybind slots.
- No ctrl/alt modifiers, middle/extra mouse buttons.
- No cooldown dim / proc glow / suggestion pulse for alternate spells — visuals stay on the main spell.
- No per-rule or per-button-index storage; no SV migration code.
- No Ace3, no new libraries, no wowmock frame tests.
- No profile/account-wide alternates (per character only, like slots).
- No ScrollBox for the settings window.

## Open Risks
- **Attribute resolution on Forever unverified**: `macrotext2` / `shift-macrotext1` semantics come from Retail FrameXML (research Q3 open area). First in-game check must confirm; fallback is `type2`/`shift-type1` with explicit `type` variants.
- **Shift+drag vs shift-click**: `WCK.MakeMovable(bar, …, {panel})` (`Rotation.lua:36`) moves the kit on Shift+drag. Buttons sit on the bar; a shift-press on a button could cast on mouse-down (`AnyDown` registered, `ActionButtonUseKeyDown`). Verify in-game; if it conflicts, document that dragging must start from bar background/panel.
- **Settings window height**: +13 rows × 26 px ≈ +340 px on a window already sized by sections (`Settings.lua:149`). May exceed small screens. Mitigation: only show rows for current bar spells (usually 6-9); defer ScrollBox (existing `ponytail:` note `Settings.lua:17`).
- **Duplicate spell on bar** isn't possible (`RuleSpells` dedups, tail excluded) — so per-spell keying is unambiguous.
- **Combat edits** to alts show in tooltip immediately but cast old attributes until combat ends; tooltip may read from SV vs applied state mismatch — acceptable, same as slots (`Settings.lua:106`).
