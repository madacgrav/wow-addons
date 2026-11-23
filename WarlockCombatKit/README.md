# Warlock Combat Kit

An in-combat helper for warlocks on WoW Forever. It shows what you have cast on each enemy, highlights mobs you have crowd-controlled, suggests your next spell, flashes Nightfall and gives you mouseover cast keys.

It is separate from [Warlock Utility Kit](../WarlockUtilityKit/), which handles stones, pets, summons and the assignment board. The two can run side by side.

## Install

1. Download `WarlockCombatKit-X.Y.Z.zip` from the repo's GitHub releases (tag `wck-vX.Y.Z`).
2. Extract it so that the folder `WarlockCombatKit` sits in `_forever_\Interface\AddOns\`.
3. Restart the game. A `/reload` is not enough on first install, because key bindings load at startup.

The addon only loads for warlocks.

## The panel

One movable panel shaped like a summoning circle, with the rotation buttons docked to its right and your enemies hanging below it as soul bands. **Shift+drag** the circle or the bar to move them together; `/wck lock` or the settings checkbox locks them in place.

- **Core** (centre of the circle): **Life Tap**. Click it to cast; **right-click** opens the options. It pulses purple when a rule suggests Life Tap. Hover it to see the current suggestion.
- **Proc orb** (lower-right edge of the circle): glows fel green and pulses while Nightfall is up.
- **Cast map** (rows below): one row per enemy you have cast on, up to 8 rows.
  - Each row shows the mob's name and icons for your DoTs, curses, banes and crowd control on that mob. The newest icon is on the left.
  - Icons fade as the cast gets older. They are not timers: an icon at its faintest means "cast a while ago, may have expired".
  - Rows show what you **cast**, not what landed. A resisted Fear still shows.
  - Each enemy is keyed by its GUID, so two mobs with the same name get separate rows.
  - Seduction from your succubus lands on the pet's target.
- **Clearing:**
  - A row clears when its mob dies. Mid-fight clearing needs **enemy nameplates turned on (V)**; with them off, a row only clears mid-fight while the dead mob is still your target.
  - A mob that leashes or evades keeps its row.
  - All rows clear when you leave combat.

## CC highlight

A row pulses purple while it holds a recent crowd control from you: Fear, Banish, Seduction, Death Coil or Howl of Terror.

**Nameplate marker** (settings, off by default): puts a Fear icon above the nameplate of each CC'd mob.
- Open world only, because instances are untested.
- Needs enemy nameplates on.

## Proc alerts

Nightfall on Forever only shows a buff icon: no button glow, no screen overlay. WCK detects it a different way: while Nightfall is up, Shadow Bolt becomes instant, and WCK watches for that.

- When it procs, the icon lights up, pulses and pops, and a raid-warning sound plays once.
- It greys out again when you cast the instant Shadow Bolt.
- Backlash, if present, makes Shadow Bolt instant too, so it lights the same icon.
- Settings: "Proc alerts (Nightfall)" and "Proc sound".

## Rotation helper

The first rule in your list that passes is the suggestion: its button on the rotation bar pulses purple (or the Life Tap core, if the rule is Life Tap). Nothing casts on its own: you click or press your own keys.

A rule passes when you know the spell, it is off cooldown, and its condition holds:

| Condition | Passes when |
|---|---|
| off cooldown | always (only the cooldown check applies) |
| not cast on target in N s | you haven't cast this spell on your current target in the last N seconds (from the cast map) |
| proc up | Nightfall is up |
| target has a mark | your target has any raid mark |
| usable (mana/range) | the game says the spell is usable right now |

- Edit rules in `/wck config` > Rotation: pick a spell and condition, set N, reorder with the arrow buttons, delete with the red X.
- Up to 10 rules. "Restore defaults" restores the starter list:
  - Corruption, Agony and Immolate on refresh timers;
  - Shadow Bolt on proc;
  - Shadow Bolt.
- Rules are saved per character.

## Rotation buttons

A bar of round buttons docked to the right of the circle, one per spell in your rules (in rule order, except Life Tap, which is the circle's core), then a fixed group after a gap: Shadow Bolt, Fear and Banish (when you know them). Shadow Bolt always sits in that group, even if a rule uses it.

- Click a button to cast its spell on your target.
- **Right-click** or **Shift+click** a button to cast a situational spell instead. Pick them per spell in `/wck config` > Alt clicks tab. With none picked, the button casts its own spell. Alternates follow the spell when you reorder rules and also work on Shadow Bolt, Fear and Banish. A change made in combat applies when combat ends.
- Buttons stay in colour. A button greys out only while its spell is on cooldown (the global cooldown does not count) and comes back when it is ready. The suggested spell (first passing rule) pulses purple. Grey buttons still cast when clicked.
- The Shadow Bolt button glows fel green (and stays in colour) while Nightfall is up.
- Shift+drag the bar's edge or the circle to move the whole kit (out of combat).
- A rule edit you make in combat updates the bar when combat ends.
- Turn the bar off with "Show rotation buttons" in `/wck config` (the Life Tap core stays).

## Mouseover cast slots

Six key-bindable slots. Each casts its spell on the hostile mob under your mouse (nameplate, unit frame or the mob itself), or on your target when nothing hostile is under the mouse.

1. `/wck config` > Cast slots tab: choose a spell for each slot you want.
2. Esc > Options > Keybindings > AddOns > Warlock Combat Kit: bind keys to "Mouseover cast slot 1–6". Shift and Ctrl modifiers work.

A slot change you make in combat takes effect when combat ends. Slots are saved per character.

## Minimap button

- Left-click: settings window.
- Right-click: show or hide the panel.
- Drag: move it around the minimap.

## Settings window

`/wck config`, a left-click on the minimap button or a right-click on the Life Tap core opens the settings window. It remembers where you put it and which tab you were on. Tabs:
- **General:** Show panel, Show rotation buttons, Lock panel, Mark CC'd mobs on nameplates, Proc alerts, Proc sound, and the Reset positions button.
- **Rotation:** the rule editor.
- **Cast slots:** the mouseover cast slots.
- **Alt clicks:** right-click and Shift+click spells for each bar button.

Hover any control for a tip.

## Slash commands

| Command | What it does |
|---|---|
| `/wck config` | Open or close the settings window. |
| `/wck show`, `/wck hide` | Show or hide the panel. |
| `/wck lock` | Toggle the panel lock (no Shift+drag). |
| `/wck reset` | Reset the panel position; `/reload` to apply. |
| `/wck probe` | Print diagnostics: in-combat API facts, cast-map rows and the last 40 cast, proc and nameplate events. Also saved to `WarlockCombatKitDB.lastProbe`. |

## Notes

- **Forever restrictions.** Forever runs Midnight's "secret value" rules, so addons cannot read your DoTs or curses on an enemy in combat. Everything here comes from your own cast events and readable spell data, which is why there are no exact timers.
  - Raid marks become unreadable in combat once set. Rows are therefore keyed by GUID, not mark, and the rotation's mark condition only knows whether a mark is set.
- **Not tracked:** exact DoT or CC timers, enemy auras, health or casts, and PvP cooldowns, trinkets or DR.
- **Dungeons.** In dungeon combat Forever hides enemy GUIDs and names from addons, and even the name of the mob you cast on. Each target you switch to gets its own row, labelled with the mob's name (the game displays it; the addon never reads it), or "Enemy N" if no name is available. Casts by mouseover land on your current target's row, because the addon can't tell which mob they hit. Tabbing back to a mob you already dotted starts a second row. Seduction gets its own "Pet target" row. A dead target's row clears; other dead mobs' rows clear when combat ends. The nameplate marker stays off in instances.
- **Battlegrounds are untested.**
- **Saved data:** `WarlockCombatKitDB` (account: panel position, options, last probe) and `WarlockCombatKitCharDB` (character: rules, cast slots).

## Development

Pure logic lives in `Logic.lua` (spell data in `Data.lua`) and is tested with plain Lua 5.1:

```bash
lua5.1 WarlockCombatKit/tests/run.lua
```

CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).

The [addon site](https://madacgrav.github.io/wow-addons/) reads this README and CHANGELOG live from `main`. A brand-new addon also needs a line in `ADDONS` in `docs/index.html`.
