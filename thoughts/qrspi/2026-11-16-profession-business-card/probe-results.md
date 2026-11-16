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


## Run 2: Ragefire Chasm (party dungeon), out of combat

- **ctx:** `combat false inst party trial false vet false`.
- On entry the client left Trade, Services and TradeLocal: `channel: 2 Trade disabled true`, `4 Services disabled true`, `5 TradeLocal disabled true`. General and LocalDefense switched to the dungeon zone (`General - Ragefire Chasm`).
  - **In dungeons only General and LocalDefense deliver messages**, so the ad log goes quiet there by design.
  - No `chan msg` lines were captured, so instance chat secrecy is still unknown. The secret guard covers it either way.
- **The channel display names show that the first word is ambiguous.** The leave messages read `Trade - English 53`, `Trade (Services) - English 53` and `Trade (Local) - Orgrimmar`.
  - All three start with `Trade`.
  - **Fix:** the channel key is the text before ` - ` (`Trade`, `Trade (Services)`, `Trade (Local)`, `General`, `LookingForGroup`). This assumes `channelBaseName` for Services and TradeLocal follows the same pattern as Trade did in Run 1. To verify, watch `/bcard seen` sources in Phase 2.
- Spells, professions and the recipe result match Run 1.

## Still pending
- An in-combat probe in the open world.
- `/bcard ping` to a stranger and to a guildmate. This gates Phase 5.
- A mage character.
