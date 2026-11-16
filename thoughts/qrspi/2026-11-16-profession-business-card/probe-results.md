# Probe Results

Client: 1.60.1 build 70938 (Forever live). The lines come from the `/bcard probe` output captured in a chat screenshot on 2026-11-16, run in Orgrimmar.

## Run 1: Orgrimmar, out of combat, open world (warlock)

- **ctx:** `combat false inst none trial false vet false`.
- **Channels** (`GetChannelList`):
  - 1 General
  - 2 Trade
  - 3 LocalDefense
  - 4 Services
  - 5 TradeLocal
  - None disabled. LookingForGroup was not joined.
- **Chat secrecy (gate):** `chan msg: Trade - English 53#2 text ok sender ok guid ok combat false inst none`, seen twice.
  - Public channel text, sender and guid are **not secret** out of combat in the open world. **The ad log gate passes.**
- **`channelBaseName` is NOT the short name.** Argument 9 arrived as `Trade - English 53`, not `Trade`. General shows as `General - Orgrimmar`.
  - The short name `GetChannelList` gives (`Trade`) is the text before the first space-dash.
  - `channelIndex` (argument 8) is `2`, matching the `GetChannelList` id.
  - **Impact on Phase 2:** filter on `base:match("^(%S+)")` (the first word), never on the full base name.
- **Spells:** `spell S: Ritual of Summoning id 698 player true byName 698`.
  - ID 698 is confirmed on Forever, and lookup by name works when the spell is known.
  - The mage IDs resolve to the right names (Teleport: Orgrimmar 3567, Portal: Orgrimmar 11417, Teleport: Undercity 3563, Portal: Undercity 11418, Teleport: Thunder Bluff 3566, Portal: Thunder Bluff 11420, Teleport: Stormwind 3561, Portal: Stormwind 10059, Teleport: Ironforge 3562, Portal: Ironforge 11416, Teleport: Darnassus 3565, Portal: Darnassus 11419).
  - Mage IDs show `player false byName nil` on a warlock, as expected. They are **not yet confirmed known on a mage**.
- **Professions:** the 7th return of `GetProfessionInfo` is the skill line.
  - prof 1: Tailoring 197, 124/150
  - prof 2: Enchanting 333, 150/225
  - prof 3: First Aid 129, 63/75
  - prof 4: Fishing 356, 161/225
  - prof 5: Cooking 185, 211/225
  - The skill-line IDs match `BC.PROF_NAMES`.
- **Unknown recipe:** `recipe 7418: Enchant Bracer - Inferior Stamina spellName Enchant Bracer - Inferior Stamina`.
  - `C_TradeSkillUI.GetRecipeInfo` resolves a recipe name with the window closed, for a recipe this character doesn't know.
  - Forever renamed this recipe (Classic: Minor Health).
  - **Phase 6 can rely on `GetRecipeInfo`. The `GetSpellName` fallback also works.**

## Pending

- In-combat probe in the open world. If chat is secret in combat, ads are skipped by the existing guard, so this does not block Phase 2.
- Dungeon probe.
- `/bcard ping` to a stranger (different guild, not grouped) and to a guildmate. This gates the Phase 5 whisper path.
- A mage character confirming `player true` for the teleports and portals.
