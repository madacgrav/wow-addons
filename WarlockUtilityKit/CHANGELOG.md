# Changelog — Warlock Utility Kit

All notable changes to this addon. Versions match `## Version` in `WarlockUtilityKit.toc`; each version is published as a `wuk-vX.Y.Z` GitHub release.

## [0.3.0] — 2026-10-20

The icon strip becomes a ring.

### Added
- **Ring layout.** The soul shard count is the core (44px); healthstone, soulstone, spellstone, firestone, armor and pet buttons orbit it clockwise from 12 o'clock.
- **Summoning-circle backdrop.** A purple rim, dark disc and slowly counter-rotating shadow swirl sit behind the ring, replacing the square box. The circle shrinks with the ring when it collapses.
- **Alert pulse.** A purple glow pulses on buttons that need action:
  - Healthstone / Soulstone: you have none and know the Create spell.
  - Armor: your armor buff is missing.
  - Pet: your preferred pet isn't out.
- **Ready shine.** A stone button pops once when its count goes from 0 to 1 or more (not at login).
- **Ring spin.** The orbit turns slowly (one revolution per minute). Toggle with `/wuk spin` or Settings.
- **Collapse until hover.** The orbit folds into the core until you mouse over the ring. When the ring is collapsed and any hidden button is alerting, the core pulses for it. Toggle with `/wuk collapse` or Settings.
- **Combat freeze.** On entering combat the ring snaps fully open and stops moving, so the secure buttons stay clickable in a fixed spot.

### Fixed
- Ring collapse polls the mouse instead of using enter/leave events, which missed moves from a child button straight to outside the ring.
- Uses `frame:IsMouseOver()`; the global `MouseIsOver` is nil on the Forever client.

## [0.2.0] — 2026-10-19

Group play: warlock assignment board.

### Added
- **Assignment board** (`/wuk board`, or right-click the minimap button). Lists up to 10 warlocks in your group, each with a curse, a banish raid mark and a soulstone target.
- **Lead-authoritative sync.** Board edits are sent to the group over addon messages (prefix `WUKB`). The lead owns the board. Use **Take lead** (or `/wuk lead`) to claim it; your first edit claims it automatically. **Sync** asks the lead for a full copy. The lead's board is restored after `/reload`, and it clears when you leave the group.
- **Your assignment** shows under the ring and is printed to chat whenever it changes.
- **Soulstone button follows the board.** When the board assigns you a soulstone target, the soulstone button uses the stone on that player.
- **Announce.** The lead posts every assignment to chat: raid warning if you are raid leader or assistant, otherwise raid or party chat. Solo, the lines print locally.
- **Cooldown Manager dock** (`/wuk dock`). Anchors Blizzard's Essential Cooldowns and Buff Icon viewers under the ring, and keeps them there through Edit Mode layout changes.
- **`/wuk probe`** prints in-game diagnostics: secret values, chat lockdown, and Cooldown Manager reachability.

## [0.1.0] — 2026-10-19

First release.

### Added
- **Shard and stone counts.** Bags are scanned for Soul Shards, Healthstones, Soulstones, Spellstones and Firestones.
- **Clickable stone icons (36px).** Click a stone to use it if you hold one, or to cast the highest-rank Create spell you know if you don't. Icons are greyed out at 0, and each remembers its real item icon after the last stone is used.
- **Soulstone target and timer.** Casting Soulstone Resurrection records the target and shows a 30-minute countdown under the strip.
- **Armor button.** Casts Demon Armor (or Demon Skin). Greyed out while the buff is up.
- **Pet button.** Summons your preferred pet (Imp if that pet isn't learned yet). Greyed out while that pet is out. Choose the pet with `/wuk pet <name>` or the Settings dropdown.
- **Summon queue.** Party, raid, guild, say and whisper messages containing `123`, `sum`, `summon` or `port` add the sender to a queue (up to 10 people, 10-minute expiry). Each row shows the player's zone (raid only) and the reason a summon would fail. Click a row to target and cast Ritual of Summoning; Ctrl-click to target only; right-click to remove. A player is removed from the queue automatically after a successful ritual on them.
- **Healthstone trade helper.** A whisper containing `hs` or `healthstone` gets an automatic reply. When that player then opens a trade with you, a healthstone is placed in the trade window for you.
- **Minimap button.** Click to open Settings; drag to move it around the minimap.
- **Settings window** (`/wuk config`). Show/hide the strip, lock frames, preferred pet, reset positions.
- **Movable frames.** Shift+drag moves the strip and the summon queue, unless frames are locked.
- **Slash commands.** `/wuk show | hide | lock | reset | pet | config`.
- **CI packaging.** Tests run and a versioned release zip is built on every push to `main`.

### Changed
- The original combined "prep" button was replaced by separate armor and pet buttons.

### Fixed
- The prep button kept the chosen pet, and the pet check is ignored while mounted.
