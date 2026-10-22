# Warlock Combat Kit

An in-combat helper for warlocks on WoW Forever. It shows what you have cast on each enemy, highlights mobs you have crowd-controlled, suggests your next spell, flashes Nightfall and gives you mouseover cast keys.

It is separate from [Warlock Utility Kit](../WarlockUtilityKit/), which handles stones, pets, summons and the assignment board. The two can run side by side.

## Install

1. Download `WarlockCombatKit-X.Y.Z.zip` from the repo's GitHub releases (tag `wck-vX.Y.Z`).
2. Extract it so that the folder `WarlockCombatKit` sits in `_classic_beta_\Interface\AddOns\`.
3. Restart the game. A `/reload` is not enough on first install, because key bindings load at startup.

The addon only loads for warlocks.

## The panel

One movable panel. **Shift+drag** moves it; `/wck lock` or the settings checkbox locks it in place.

- **Core** (top left): the next spell from your rotation rules. It is grey when no rule matches. Hover it for the spell name.
- **Proc icon** (right of the core): lights up and pulses while Nightfall is up.
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

The core shows the first rule in your list that passes. It is **display only**: you press your own keys. A clickable core is not possible, because addons cannot change what a button casts during combat. The mouseover cast slots below are the closest thing.

A rule passes when you know the spell, it is off cooldown, and its condition holds:

| Condition | Passes when |
|---|---|
| off cooldown | always (only the cooldown check applies) |
| not cast on target in N s | you haven't cast this spell on your current target in the last N seconds (from the cast map) |
| proc up | Nightfall is up |
| target has a mark | your target has any raid mark |
| usable (mana/range) | the game says the spell is usable right now |

- Edit rules in `/wck config` > Rotation: pick a spell and condition, set N, reorder with ^ and v, delete with x.
- Up to 10 rules. "Defaults" restores the starter list:
  - Corruption, Agony and Immolate on refresh timers;
  - Shadow Bolt on proc;
  - Shadow Bolt.
- Rules are saved per character.

## Mouseover cast slots

Six key-bindable slots. Each casts its spell on the hostile mob under your mouse (nameplate, unit frame or the mob itself), or on your target when nothing hostile is under the mouse.

1. `/wck config` > Mouseover cast slots: choose a spell for each slot you want.
2. Esc > Options > Keybindings > AddOns > Warlock Combat Kit: bind keys to "Mouseover cast slot 1–6". Shift and Ctrl modifiers work.

A slot change you make in combat takes effect when combat ends. Slots are saved per character.

## Minimap button

- Left-click: settings window.
- Right-click: show or hide the panel.
- Drag: move it around the minimap.

## Settings window

`/wck config` or a left-click on the minimap button opens the settings window. It has:
- **Toggles:** Show panel, Lock panel, Mark CC'd mobs on nameplates, Proc alerts, Proc sound.
- **Sections:** the Rotation rule editor and the Mouseover cast slots.
- **Reset positions** button.

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
- **Dungeons and battlegrounds are untested.** If enemy names or GUIDs are unreadable there, rows fall back to a single "Target" row, and the nameplate marker stays off.
- **Saved data:** `WarlockCombatKitDB` (account: panel position, options, last probe) and `WarlockCombatKitCharDB` (character: rules, cast slots).

## Development

Pure logic lives in `Logic.lua` (spell data in `Data.lua`) and is tested with plain Lua 5.1:

```bash
lua5.1 WarlockCombatKit/tests/run.lua
```

CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).
