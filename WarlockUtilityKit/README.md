# Warlock Utility Kit

Warlock helper for WoW Forever. It tracks soul shards and stones, adds one-click stone, armor and pet buttons, queues summon requests, handles healthstone trades, and gives groups a shared curse/banish/soulstone assignment board.

- Client: WoW Forever (Interface 16001)
- Class: Warlock only. On other classes the addon stays idle, and `/wuk` replies "warlocks only".
- Language: English client. Items are matched by their enUS names.

## Install

1. Download `WarlockUtilityKit-X.Y.Z.zip` from the repo's GitHub releases (tag `wuk-vX.Y.Z`).
2. Extract it so that the folder `WarlockUtilityKit` sits in `_classic_beta_\Interface\AddOns\`.
3. Restart the game or `/reload`.

## The ring

The ring appears below the center of your screen.

```
            Healthstone
   Pet                     Soulstone
            [ Shards ]
  Armor                    Spellstone
            Firestone
   Soulstone: Bob  27:41
   Elements  Banish {skull}  SS: Bob
```

The core is your **Soul Shard** count. Six buttons orbit it clockwise from the top:

| Button | Left-click | Greyed out when | Pulses when |
|---|---|---|---|
| Healthstone | Use one if you have it, otherwise cast your best Create Healthstone | you have 0 | you have 0 and know the spell |
| Soulstone | Use it (see targeting below), otherwise cast your best Create Soulstone | you have 0 | you have 0 and know the spell |
| Spellstone | Use it, otherwise create one | you have 0 | — |
| Firestone | Use it, otherwise create one | you have 0 | — |
| Armor | Cast Demon Armor (or Demon Skin) | the buff is up | the buff is missing |
| Pet | Summon your preferred pet | that pet is out | that pet isn't out |

- **Counts** appear in the corner of each stone button. When a count goes from 0 to 1 or more, the button pops once.
- **Soulstone targeting:** if the assignment board gives you a soulstone target, the stone is used on that player. Otherwise it goes on your friendly target, or on yourself if you have none.
- **Soulstone timer:** the first line under the ring shows who holds your soulstone and how much of its 30 minutes is left. It starts when your Soulstone Resurrection cast succeeds.
- **Assignment line:** the second line under the ring shows your board assignment (see below).

### Motion

- **Spin:** the orbit turns once a minute.
- **Collapse:** the orbit folds into the core until you hover the ring. When the ring is collapsed and any hidden button needs attention, the core pulses for it.
- **In combat** the ring snaps fully open and stops moving, so every button stays where you expect it. Spin and collapse resume once combat ends.

Turn spin and collapse on or off with `/wuk spin`, `/wuk collapse`, or the Settings window.

### Moving and hiding

- **Shift+drag** the ring to move it. Positions are saved. This doesn't work while frames are locked or while you're in combat.
- `/wuk lock` toggles the lock. `/wuk reset` clears saved positions; `/reload` to apply.
- `/wuk hide` / `/wuk show` hide or show the ring. These don't work in combat.

## Preferred pet

Pick the pet the pet button summons:

- `/wuk pet imp | voidwalker | succubus | felhunter`
- or use the **Preferred pet** dropdown in Settings.

If you haven't learned the chosen pet, the button summons the Imp. The pet choice is saved per character.

## Summon queue

When someone in party, raid, guild, say or whisper writes a message containing the word `123`, `sum`, `summon` or `port`, they're added to the summon queue. The queue window appears automatically while anyone is waiting.

- Up to 10 people. Entries expire after 10 minutes.
- Each row shows the player's name, zone (in raids) and, in red, why a summon would fail right now: `not in group`, `offline`, `dead`, `already here`, `no shard` or `need 2 helpers`.
- **Click** a row to target the player and cast Ritual of Summoning.
- **Ctrl+click** to target only.
- **Right-click** to remove the player from the queue.
- After a ritual on someone succeeds, they're removed from the queue automatically.
- Shift+drag the window to move it.

Requires Ritual of Summoning. Queue changes made during combat show once combat ends.

## Healthstone trades

When someone whispers you a message containing `hs` or `healthstone`:

- If you have a healthstone, they get the reply *"Stone ready - open a trade with me."*
- If you don't, they get *"Out of stones right now, sorry."*

When that player opens a trade with you within 10 minutes, a healthstone is placed in the trade window for you. All you do is click **Trade**. Each player gets one automatic reply per 10 minutes.

## Assignment board (groups)

Open it with `/wuk board`, by right-clicking the minimap button, or with **Assignment board** in Settings.

The board lists every warlock in your group (up to 10). Each warlock has three dropdowns:

- **Curse:** Elements, Recklessness, Tongues, Weakness, Exhaustion, or Shadow (only listed if you know it).
- **Banish:** a raid target mark (Star … Skull).
- **Soulstone:** a group member to soulstone.

How sync works:

- One player is the **lead**. Only the lead can edit or announce.
- Click **Take lead** (or `/wuk lead`) to become the lead. If nobody leads yet, your first edit makes you the lead automatically.
- Edits are sent to every group member who runs WUK. **Sync** asks the lead for a full copy, for example after you join late.
- Each warlock sees their own assignment under the ring, and it's printed to chat whenever it changes. A soulstone assignment also retargets your soulstone button.
- **Announce** (lead only) posts every assignment to chat. It uses raid warning if you're raid leader or assistant, otherwise raid or party chat. Solo, the lines just print for you.
- The lead's board survives `/reload`. Leaving the group clears the board.

If addon messages are blocked or throttled, you see "board sync unavailable" once, and the board keeps working locally.

## Cooldown Manager dock

`/wuk dock` (or the **Dock Blizzard cooldown timers** checkbox in Settings) anchors Blizzard's Essential Cooldowns and Buff Icon viewers directly under the ring. It also puts them back there after Edit Mode moves them. Use this to see your DoT and curse timers next to your stones.

To undock, toggle the option again, then `/reload` to return the viewers to their Edit Mode position. Not available in combat.

## Minimap button

- **Click:** open Settings.
- **Right-click:** open the assignment board.
- **Drag:** move the button around the minimap.

## Settings window

`/wuk config` or click the minimap button.

- Show strip
- Lock frames (no Shift+drag)
- Dock Blizzard cooldown timers under strip
- Spin ring
- Collapse ring until hover
- Preferred pet
- **Reset positions** and **Assignment board** buttons

Escape closes the window.

## Slash commands

| Command | What it does |
|---|---|
| `/wuk config` | Open or close Settings |
| `/wuk board` | Open or close the assignment board |
| `/wuk lead` | Take the board lead |
| `/wuk dock` | Toggle the Cooldown Manager dock |
| `/wuk spin` | Toggle ring spin |
| `/wuk collapse` | Toggle collapse-until-hover |
| `/wuk show` / `/wuk hide` | Show or hide the ring |
| `/wuk lock` | Toggle the frame lock |
| `/wuk reset` | Reset frame positions (then `/reload`) |
| `/wuk pet <imp\|voidwalker\|succubus\|felhunter>` | Set the preferred pet |
| `/wuk probe` | Print diagnostics (for bug reports) |

`show`, `hide`, `dock`, `spin` and `collapse` are refused in combat.

## Notes

- All buttons are secure action buttons. Their click actions update only out of combat. A change that happens in combat (new stone, new soulstone target) takes effect when combat ends.
- Saved data: `WarlockUtilityKitDB` (account: positions, options, icons) and `WarlockUtilityKitCharDB` (character: pet, soulstone timer, lead board).

## Development

Pure logic lives in `Logic.lua` and is tested with plain Lua 5.1:

```bash
lua5.1 WarlockUtilityKit/tests/run.lua
```

CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).
