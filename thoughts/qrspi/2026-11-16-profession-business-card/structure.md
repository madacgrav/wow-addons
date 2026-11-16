# Structure Outline

## Approach
Build a new standalone `BusinessCard/` addon by copying the TackleBox/WUK skeleton (`X.On`, `X.Secret`, `MergeDefaults`, `inits`).
- Phase 1 ships only the probe, which acts as a hard gate on the risky APIs (channel secrecy, whisper addon messages to strangers, channel names, spell IDs).
- Each later phase is one end-to-end feature: pure `Logic.lua` with tests, Core events, then panel UI, then an in-game check.
- Deploy after each phase by robocopy to `_forever_\Interface\AddOns\BusinessCard`.

## Phase 1: Skeleton + `/bcard probe` + release pipeline
Delivers an addon that loads, persists its SavedVariables, and runs a probe that writes to chat and to `BusinessCardDB.lastProbe`. CI packages it.

**Files**: `BusinessCard/BusinessCard.toc`, `Logic.lua`, `Core.lua`, `tests/run.lua`, `README.md`, `CHANGELOG.md`, `.github/workflows/package-bcard.yml`, `thoughts/qrspi/2026-11-16-profession-business-card/probe-results.md` (filled after the run).

**Key changes**:
- `.toc`:
  - `## Interface: 16001`.
  - SavedVariables `BusinessCardDB`, SavedVariablesPerCharacter `BusinessCardCharDB`.
  - Load order: Logic, Core (later phases append Comm, Panel).
- Helpers copied from WUK:
  - `BC.MergeDefaults(sv, defaults): table`.
  - `BC.On(event, fn)`, `BC.inits`, `BC.Secret(v): bool`, `BC.Print(...)`.
- `BC.Probe()`, using the `P`/`Try`/`S` shape from `TackleBox/Core.lua:160-165`. Sections:
  - **`ctx`**: instance type, combat state, `IsTrialAccount`/`IsVeteranTrialAccount` if present.
  - **`chan`**: `GetChannelList()` dump, giving the name and index of each joined channel.
  - **`chat`**: arms a capture of the next 5 `CHAT_MSG_CHANNEL` events. Records `channelBaseName`, `channelIndex`, and whether `text`, `playerName` and `guid` are secret, then prints them.
  - **`spell`**: `C_Spell.GetSpellInfo` for "Ritual of Summoning" and for each mage Teleport and Portal name, giving spellID and known-state.
  - **`prof`**: `GetProfessions()` and `GetProfessionInfo(i)`, giving name, skillLine, rank and max.
  - **`recipe`**: `C_TradeSkillUI.GetRecipeInfo(id)` for a recipe the player does not know, to check whether a name resolves.
- `/bcard ping <name>`: sends `SendAddonMessage("BCARD","ping","WHISPER",name)` and logs the result code. The receiver prints any ping it gets.
- `/bcard` subcommands: `probe`, `ping`, `lock`, `reset`.

**Verify**:
- `lua5.1 BusinessCard/tests/run.lua` passes (MergeDefaults).
- In game:
  - Run `/bcard probe` in Orgrimmar with Trade busy, both out of combat and in combat.
  - Run `/bcard ping` between two accounts that are not in the same guild or group, then again between guildmates.
- Record the results in `probe-results.md`.
- **Gate**: if channel text or sender is secret in the open world, stop and go back to Design. If stranger whisper fails, drop Phase 5's whisper path (guild only). Hardcode the confirmed spell IDs and channel names.

---

## Phase 2: Ad log (chat intake, classifier, persistence)
Delivers chat monitoring end to end: channel events are classified and stored per realm, then pruned. `/bcard seen` prints the log. No window yet.

**Files**: `BusinessCard/Data.lua` (keyword sets), `Logic.lua`, `Core.lua`, `tests/run.lua`.

**Key changes**:
- `BC.CATS`: an ordered list of category keys (profession names, `summon`, `portal`, `other`), plus `BC.WORDS[cat] = set`, `BC.REQUEST_WORDS`, `BC.PORTAL_DEST`.
- `BC.Classify(text): {cats = {cat=true}, request = bool, dest = string?}` or nil.
  - Uses whole-token matching as in `WarlockUtilityKit/Logic.lua:42-46`.
  - Extracts IDs from links with `|H(%a+):(%d+)`.
- `BC.SeenAdd(seen, name, result, text, now)`: updates `{cats={cat=at}, text, at, req}`. Text is truncated to 120 characters.
- `BC.SeenPrune(seen, now, maxAge, cap)`: drops entries older than 7 days and keeps at most 500, removing the oldest first.
- `OnChat(text, sender, ..., channelBaseName)`: secret guard, then `Ambiguate`, then skip self, then the channel filter `BC.db.channels[base]`, then Classify, then SeenAdd.
- Events: `CHAT_MSG_CHANNEL`, `_SAY`, `_YELL`, `_WHISPER`.
- Storage:
  - `DEFAULTS` gains `seen = {}` (keyed per realm), `channels = {...}`, `maxAgeDays = 7`.
  - Pruning runs at `PLAYER_LOGIN` and is skipped while `InCombatLockdown()`.

**Verify**:
- Tests cover:
  - Classify on about 15 sample ads: WTS enchant, LF summon, "port to UC", "portal" vs "port", a request vs an offer, an item link.
  - SeenAdd dedupe and merging of categories.
  - Prune by age and by cap.
- In game: idle in a capital for 10 minutes, then check that `/bcard seen` lists advertisers with sensible categories, and that `/reload` keeps them.

---

## Phase 3: Seen window
Delivers the movable window with the Seen tab: category filter tabs, rows sorted by most recent, and the click, shift-click and right-click actions.

**Files**: `BusinessCard/Panel.lua`, `Core.lua`, `Bindings.xml`, `.toc`.

**Key changes**:
- `BC.SeenRows(seen, filter, showRequests, now): {{name, cats, age, text, card}}`. Pure and tested.
- `BC.FormatAge(secs): string`.
- Window:
  - `BC.BuildPanel()`: `BasicFrameTemplateWithInset`, drag, `UISpecialFrames` (as in `WarlockUtilityKit/Board.lua:97-101`).
  - Fixed row pool with `MAX_ROWS = 20`.
  - Filter tabs as in `TackleBox/Panel.lua:142-176`.
- `BC.RenderPanel(rows, tabs, active)`.
- Row actions:
  - **Left-click**: `ChatFrame_OpenChat("/w "..name.." ")`.
  - **Right-click**: remove the row.
  - **Shift-click**: placeholder detail pane, wired in Phase 5.
  - **Tooltip**: the last ad text.
- Refresh, debounced at 0.1 s, on SeenAdd while the window is shown.
- `/bcard` with no argument toggles the window. There is also a keybind.

**Verify**:
- Tests: SeenRows filter, sort and request toggle; FormatAge.
- In game:
  - The window opens, drags and closes with Esc.
  - The tabs filter rows, and clicking a row opens a whisper to that person.

---

## Phase 4: My card + status (local)
Delivers your own card, built from the profession API and known spells, with per-entry and global status. It shows in the window's My card tab. Not sent anywhere yet.

**Files**: `BusinessCard/Logic.lua`, `Core.lua`, `Panel.lua`, `tests/run.lua`.

**Key changes**:
- `BC.BuildCard(profs, svcs, status, rev): Card`, where:
  - `Card = {rev, g = "a"|"b", profs = {{id, skill, st}}, svcs = {{key, st}}}`.
  - `st` is one of `a` (available), `b` (busy) or `o` (off).
- `BC.ReadProfessions(): {{id, name, skill}}`, from `GetProfessions` and `GetProfessionInfo`.
- `BC.ReadServices(): {key...}`, from the spell IDs hardcoded after Phase 1.
- Recipe cache:
  - `BC.ScanRecipes()` runs on `TRADE_SKILL_SHOW` and `TRADE_SKILL_LIST_UPDATE`, using the `IsTradeSkillReady` guard and `GetProfessionInfoByRecipeID` filter from `ProfessionPlanner/Core.lua:28-40`.
  - It stores learned IDs only, in `BusinessCardCharDB.recipes[profID] = {ids}`.
- `CHAR_DEFAULTS = {status = {g = "a", [key] = st}, recipes = {}, rev = 0}`.
- Every status change bumps `rev`.
- My card tab: one row per profession or service, each with a 3-state toggle button, plus a global Busy toggle.
- `/bcard busy|avail` sets the global status.

**Verify**:
- Tests: BuildCard from stub data; `rev` bump.
- In game:
  - The My card tab lists your real professions with skill levels, and the warlock or mage services if known.
  - Toggles persist through `/reload`.
  - Opening a profession window fills the recipe cache.

---

## Phase 5: Card exchange (guild + whisper on demand)
Delivers silent card exchange. Your card goes to the guild on login and on status change. Strangers who advertise are sent a `Q` request. Received cards attach to Seen rows (status badge, addon icon).

**Files**: `BusinessCard/Comm.lua` (new), `Logic.lua`, `Core.lua`, `Panel.lua`, `tests/run.lua`, `.toc`.

**Key changes**:
- Wire format:
  - `BC.Encode(kind, ...)` and `BC.Decode(msg): {kind, ...}?`, pipe-delimited with version `1` and `-` for nil, as in `WarlockUtilityKit/Logic.lua:117-139`.
  - Kinds: `C` (`1|C|rev|g|profs|svcs`), `Q` (`1|Q`).
  - `BC.EncodeCard(card): string` (≤255 bytes) and `BC.DecodeCard(f): Card`.
- Send queue:
  - `BC.Send(msg, chatType, target)`: a queue of `{msg, ch, to}` entries with a 0.25 s ticker.
  - Pacing is 1/s for WHISPER and 0.5 s otherwise.
  - Backoff copied from `WarlockUtilityKit/Comm.lua:10-22`.
  - On the first non-throttle failure, print one warning and set `BC.commOff = true`.
- Receive:
  - The `CHAT_MSG_ADDON` handler applies the secret guard, `Ambiguate` and skip-self.
  - `Q` triggers a reply with our `C` by WHISPER.
  - `C` stores the card into `seen[realm][name].card` if `rev` is newer.
- Triggers:
  - **First sighting** of an advertiser this session: `Q`. Not sent inside an instance (`IsInInstance`), and at most once per name via the `asked` set.
  - **Login, and a status change** (10 s debounce): `C` to GUILD if `IsInGuild()`.
- Rows show a status badge (green/red/grey) and an addon icon when a card is known.

**Verify**:
- Tests: EncodeCard/DecodeCard round trip; max-size card ≤255 bytes; Decode rejects bad field counts.
- In game, with two accounts:
  - Guildmates see each other's cards on login.
  - A stranger who advertises appears with a status badge.
  - Toggling Busy updates the other side within about 10 s.
  - A trial account prints one warning, and its ad log keeps working.

---

## Phase 6: Recipe list on request
Delivers the card detail pane (shift-click a row). It lists their professions, services and status, and fetches the full recipe list for a chosen profession over chunked whispers.

**Files**: `BusinessCard/Logic.lua`, `Comm.lua`, `Panel.lua`, `tests/run.lua`.

**Key changes**:
- New kinds:
  - `RQ` (`1|RQ|profID`).
  - `RL` (`1|RL|profID|seq|total|ids`), with recipe IDs in base 36, separated by commas, about 200 bytes per chunk.
- `BC.ChunkIDs(ids, maxBytes): {string}`.
- `BC.Reassemble(buf, sender, profID, seq, total, part, now): ids?`. It drops a partial set after 30 s.
- If no recipe cache exists, the reply is `total = 0`.
- Detail pane:
  - Profession buttons, each sending `RQ`.
  - A list of recipe names via `C_TradeSkillUI.GetRecipeInfo(id)`, falling back to `"Recipe #id"`.
  - A search box.
  - Received lists are cached for the session, per `name+profID`.

**Verify**:
- Tests:
  - ChunkIDs: each chunk ≤ the limit, and they concatenate back to the input.
  - Reassemble: out-of-order chunks, a missing chunk timing out, `total = 0`.
- In game: shift-clicking a guildmate or stranger with BusinessCard shows their Enchanting list after a few seconds.

## Testing Checkpoints
| After | True |
|---|---|
| P1 | The addon loads and its SavedVariables persist. `probe-results.md` answers whether channels are secret, whether a stranger whisper works, which channel names exist, and which spell IDs apply. The Design gate has been passed. CI zips the addon. |
| P2 | Ads from channels are classified, stored per realm, pruned, and survive `/reload`. `/bcard seen` prints them. |
| P3 | The Seen window filters and sorts. Click whispers, right-click removes. |
| P4 | My card shows real professions and services. Status toggles persist. The recipe cache fills when a profession window opens. |
| P5 | Cards are exchanged over guild and over whisper `Q`. Rows show status badges. Comms degrade cleanly. |
| P6 | Shift-click detail fetches and shows a chunked recipe list. |

Each phase ends with deploy (robocopy) and an in-game test. Phases 2–3 are useful even if Phase 5 fails at the probe gate: you still get a persistent ad log.
