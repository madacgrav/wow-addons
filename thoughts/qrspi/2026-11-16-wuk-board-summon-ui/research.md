# Research Findings

Addon root: `WarlockUtilityKit/`. All paths below are relative to it unless prefixed. Load order (`WarlockUtilityKit.toc:9-18`): Logic, Core, UI, Prep, Summon, Trade, Comm, Board, Dock, Settings. Every module opens with `local ADDON, WUK = ...`.

## Q1: How is the `WUKBoard` frame built?

### Findings
- **Frame**:
  - Built lazily by local `Build()` (`Board.lua:96-162`) on the first `WUK.ToggleBoard()` (`Board.lua:164-167`).
  - Created as `CreateFrame("Frame", "WUKBoard", UIParent, "BasicFrameTemplateWithInset")` (`Board.lua:97`).
- **Size and anchor**:
  - Size is `470 x (90 + MAX_ROWS*28)`, which is 470x370 with `MAX_ROWS = 10` (`Board.lua:2`, `:98`).
  - Anchored `SetPoint("CENTER")` with strata `DIALOG` (`Board.lua:98`).
- **Movement**:
  - Plain left-drag through its own `SetMovable`, `StartMoving` and `StopMovingOrSizing` scripts (`Board.lua:99-100`).
  - It does **not** use `WUK.MakeMovable`. Its position is not saved in `WUK.db.frames`, and Shift and the lock setting do not apply to it.
- **Escape**: registered in `UISpecialFrames` (`Board.lua:101`).
- **Header**:
  - Title "Warlock Assignments", `GameFontHighlight`, at `TOP 0,-5` (`Board.lua:102-103`).
  - `win.leadText`, `GameFontNormal`, at `TOPLEFT 16,-30` (`Board.lua:104-105`).
  - Its text is `"Lead: " .. (lead or me.." (local)")` (`Board.lua:156`).
  - There are **no column header labels** for the dropdown columns.
- **Rows**: 10 pre-built row frames (`Board.lua:108-134`).
  - Each row is 440x26, placed at `TOPLEFT 14, -50-(i-1)*28` (`:110`).
  - `row.name` is a `GameFontHighlightSmall` FontString, width 100, left-justified (`:111-112`).
- **Dropdowns**:
  - Built by the local `Dropdown(row, x, width, build)` helper (`Board.lua:89-94`).
  - Each is a `CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")`, using `SetWidth` and `SetPoint("LEFT", x, 0)` with a `SetupMenu` callback.
  - Items are added through the local `Radio(root, label, row, field, val)` (`Board.lua:83-87`). Its getter compares `WUK.board.rows[warlock][field]`, and its setter calls `WUK.SetAssignment`.

  | Column | x | Width | Default item | Items |
  |---|---|---|---|---|
  | Curse | 106 | 120 | "No curse" | `WUK.CURSES` `short` names; Shadow only if `WUK.known.curseshadow` (`:114-119`) |
  | Banish mark | 232 | 90 | "No banish" | 8 raid-mark icon+label radios (`MARKS` at `:3`, `MarkIcon` at `:8`) (`:120-123`) |
  | Soulstone | 328 | 110 | "No soulstone" | `me` plus every `WUK.GroupUnits()` name (`:124-131`) |

  - The dropdowns have no explicit default text. The shown text is the selected radio's label, which `WowStyle1DropdownTemplate` truncates to the button width.
  - `x + width` for the last column is 438, inside the 440 row.
- **Buttons**:
  - Local `Button(label, x, onClick)` makes a `UIPanelButtonTemplate`, 110x22, at `BOTTOMLEFT x,14` (`Board.lua:136-141`).
  - "Take lead" is at x=16, "Sync" at 132 and "Announce" at 248 (`:142-144`).
- **Rebuild/refresh (`win:Sync`)** (`Board.lua:146-159`):
  - Assigns `WUK.GroupWarlocks()` (sorted, self included; `Core.lua:130-139`) to rows in order and hides the unused rows.
  - Calls `dd:GenerateMenu()` and `dd:SetEnabled(WUK.IsLead())` on every dropdown (`:153`).
  - Shows `leadBtn` only when `lead ~= me`, and `announceBtn` only when `IsLead()` (`:157-158`).
  - `Sync` runs `OnShow` (`:160`), from `WUK.BoardChanged()` when shown (`:18-21`), and on `GROUP_ROSTER_UPDATE` when shown (`:175-182`).
- **Relation to `WUKSettings`**:
  - Both frames anchor `CENTER` of UIParent with `DIALOG` strata (`Board.lua:98`, `Settings.lua:18`). There is no relative anchoring or offset between them.
  - Settings is 320x314 and Board is 470x370, so when both are open at default positions they overlap at the center.
  - The frame created later gets the higher frame level within the same strata. Nothing raises either frame on click; neither uses `SetToplevel`.
  - The Settings "Assignment board" button runs `/wuk board`, which toggles the board without moving or hiding Settings (`Settings.lua:54-56`, `Core.lua:256`).

## Q2: How is the `WUKSettings` frame built?

### Findings
- **Frame**:
  - Built lazily in `Build()` (`Settings.lua:17-64`) and toggled by `WUK.ToggleSettings()` (`:66-69`).
  - Created as `CreateFrame("Frame","WUKSettings",UIParent,"BasicFrameTemplateWithInset")`, 320x314, `CENTER`, `DIALOG` (`:18-19`).
  - Plain left-drag (`:20-21`) and Escape to close (`:22`).
  - Title "Warlock Utility Kit" at `TOP 0,-5` (`:23-24`).
- **Option routing**: all options go through the slash handler via `Run(cmd)`, which calls `SlashCmdList.WARLOCKUTILITYKIT(cmd)` (`Settings.lua:5`). The comment at `:2` describes this as the one code path.
- **Checkbox helper** (`Settings.lua:7-15`):
  - A `UICheckButtonTemplate` at `TOPLEFT 16,y` with a `GameFontHighlight` label to its right.
  - `OnClick` calls `onClick(checked)`, then re-reads `get()`. `cb.Sync` sets the box from `get()`.
- **Checkboxes**, at y = -36, -64, -92, -120 and -148 (`Settings.lua:26-36`). All except "Show strip" toggle only when the new state differs from the saved one.

  | Label | Reads | Writes via |
  |---|---|---|
  | Show strip | `WUK.db.shown` | `show`/`hide` (`Core.lua:249`) |
  | Lock frames (no Shift+drag) | `WUK.db.locked` | `lock` (`Core.lua:250`) |
  | Dock Blizzard cooldown timers under strip | `WUK.db.dockViewers` | `dock` (`Core.lua:258-262`) |
  | Spin ring | `WUK.db.spin` | `spin` (`Core.lua:263-265`) |
  | Collapse ring until hover | `WUK.db.collapse` | `collapse` (`Core.lua:263-265`) |

- **Preferred pet**:
  - A `GameFontNormal` label at `TOPLEFT 20,-188` (`Settings.lua:38-39`).
  - Below it, a `WowStyle1DropdownTemplate` dropdown, width 160, at `TOPLEFT 18,-206` (`:41-49`).
  - The dropdown has a radio per `WUK.PETS` entry with the first letter capitalized (`Logic.lua:87`). Its getter is `WUK.char.pet == pet`, and its setter runs `pet <key>` (`Core.lua:252-253`).
- **Buttons**:
  - "Reset positions": `UIPanelButtonTemplate` 130x22 at `BOTTOMLEFT 16,16`, runs `reset` (`Settings.lua:51-53`).
  - "Assignment board": `BOTTOMRIGHT -16,16`, runs `board` (`Settings.lua:55-57`).
- **Grouping**: none beyond vertical order. There are no section headers or dividers, and only the dropdown has a label.
- **`win:Sync`** (`Settings.lua:59-62`) re-syncs the checkboxes and calls `dd:GenerateMenu()`. It runs `OnShow` (`:63`).
- **Minimap button**:
  - `WUKMinimapButton`, built in an init (`Settings.lua:71-108`), 31x31.
  - Icon `INV_Misc_Gem_Amethyst_02`, border `MiniMap-TrackingBorder` (`:73-79`).
  - Placed by angle at `WUK.db.minimapAngle` (`:81-85`); dragging updates the angle (`:87-96`).
  - Left-click calls `WUK.ToggleSettings()` and right-click calls `WUK.ToggleBoard()` (`:98-101`). The tooltip text is at `:102-107`.

## Q3: How is the `WUKSummon` panel constructed and laid out?

### Findings
- **Constants**: `MAX, TTL = 10, 600` (`Summon.lua:2`). The module state is local `queue, rows, panel` (`:3`).
- **Panel**: built at init, not lazily (`Summon.lua:66-85`).
  - Created as `CreateFrame("Frame","WUKSummon",UIParent,"BackdropTemplate")`, size `300 x (20 + MAX*20)` = 300x220 (`:67-68`).
  - Backdrop is `bgFile = WHITE8x8` only, with no edge, at color `(0,0,0,0.6)` (`:69`).
  - Title: a `GameFontNormalSmall` FontString at `TOPLEFT 6,-4` with the literal text `"Summon queue (click: summon, ctrl: target, right: remove)"` (`:70-71`).
  - Movable through `WUK.MakeMovable(panel, "summon", 0, -300)`: Shift+drag, respects lock, saves to `db.frames.summon` (`:72`, `UI.lua:13-26`).
- **Rows**: 10 pre-built rows (`Summon.lua:73-84`).
  - Each is a `CreateFrame("Button","WUKSummonRow"..i,panel,"SecureActionButtonTemplate")`, 288x18, at `TOPLEFT 6, -2-i*20` (`:74-75`).
  - `RegisterForClicks("AnyUp","AnyDown")` (`:76`).
  - `type1 = "macro"` and `ctrl-type1 = "macro"` (`:77`). There is no right-button type attribute.
  - Each row has one `row.text` FontString, `GameFontHighlightSmall`, anchored `LEFT` (`:78`).
  - Highlight texture is `Interface\QuestFrame\UI-QuestTitleHighlight` (`:79`).
- **Click behaviours**:
  - Left-click: `macrotext1 = "/target NAME\n/cast <Ritual>"` (`Summon.lua:46`).
  - Ctrl+left: `ctrl-macrotext1 = "/target NAME"` (`:47`).
  - Right-click: `HookScript("OnClick")` on `RightButton` up removes `self.name` from the queue and calls `UpdateSummonRows` (`:80-82`).
- **Row text** is `name .. "  " .. grey(zone or "?") .. "  " .. red(SummonFailure(ctx) or "")` (`Summon.lua:49`).
  - `zone` comes from `RosterZone`, which works in raid only, so a party shows "?".
  - The failure text is one of: "not in group", "offline", "dead", "already here", "no shard" or "need 2 helpers" (`Logic.lua:69-77`).
- **Show, hide and refresh: `WUK.UpdateSummonRows`** (`Summon.lua:38-56`):
  - Returns immediately under `InCombatLockdown()` (`:39`).
  - Prunes entries older than TTL (`:40-41`).
  - Fills row i from `queue[i]` **only if `WUK.known.ritual`** is set. Otherwise it hides the row (`:44-53`).
  - Shows the panel if `queue[1]` exists and hides it otherwise (`:55`). If the ritual is unknown, a non-empty queue shows the panel with every row hidden.
- **Callers of `UpdateSummonRows`**:
  - `OnChat` (`Summon.lua:63`)
  - right-click (`:81`)
  - `GROUP_ROSTER_UPDATE` (`:88`)
  - the ritual success handler (`:91`)
  - the `WUK.refreshers` entry (`:95`), which runs on every `WUK.Refresh()`: `BAG_UPDATE_DELAYED`, `PLAYER_REGEN_ENABLED`, `SPELLS_CHANGED`, player `UNIT_AURA` and player `UNIT_PET` (`Core.lua:141-159`)
- **Combat**: secure attributes are only set out of combat. The comment at `Summon.lua:63` notes that `PLAYER_REGEN_ENABLED` triggers `Refresh`, which re-applies the rows after combat.

## Q4: How does the summon queue decide whether a requester is in the group?

### Findings
- **Accepted channels**: `CHAT_MSG_PARTY`, `_PARTY_LEADER`, `_RAID`, `_RAID_LEADER`, `_GUILD`, `_SAY` and `_WHISPER`, all routed to `OnChat` (`Summon.lua:86-87`). `CHAT_MSG_INSTANCE_CHAT` is not registered.
- **`OnChat(text, sender)`** (`Summon.lua:58-64`):
  1. Drops secret text or senders and non-matching text (`:59`).
  2. Sets `name = Ambiguate(sender, "none")` (`:60`) and ignores self (`:61`).
  3. Calls `WUK.QueueAdd(queue, name, MAX)` and sets `.at = time()` (`:62`).
  - **There is no group-membership check before adding.** Guild, say and whisper senders outside the group are queued.
- **`IsSummonRequest`** matches whole `%w+` words, lowercased, against `{123, sum, summon, port}` (`Logic.lua:42-50`).
- **`QueueAdd`** dedupes by exact `name` and caps at `max`. Membership is not considered (`Logic.lua:55-60`).
- **`QueuePrune`** is only called with the TTL predicate (`Summon.lua:41`). Group membership is never a prune condition.
- **Membership test (display only)**: `Context(name)` (`Summon.lua:15-36`).
  - Loops `GroupUnits()` and sets `target` where `UnitFull(unit) == name` (`:17-19`).
  - If there is no match, it returns `ctx` without `inGroup`, so `SummonFailure` returns "not in group" and the row shows a red label (`Logic.lua:70`). The entry remains queued and clickable.
- **`GroupUnits()`** (`Core.lua:117-122`):
  - In a raid it returns `raid1..raidN` from `GetNumGroupMembers()`, which includes the player.
  - In a party it returns `party1..partyN` from `GetNumSubgroupMembers()`, which excludes the player.
  - Solo, it returns an empty list.
- **`UnitFull(unit)`** (`Core.lua:124-128`): `UnitName` plus `"-realm"` when realm is non-empty, then `Ambiguate(..., "none")`. It returns nil when the name is secret.
- **Name normalization**:
  - The sender side and the roster side both pass through `Ambiguate(x, "none")`. The `"none"` context keeps the realm suffix for other-realm names and strips it for same-realm names.
  - Case is not normalized; comparison is exact string equality.
  - `RosterZone` compares `Ambiguate(GetRaidRosterInfo name, "none")` the same way (`Summon.lua:7-13`).
- **Roster APIs used**:
  - `IsInRaid`, `GetNumGroupMembers`, `GetNumSubgroupMembers` (`Core.lua:119-120`)
  - `GetRaidRosterInfo` for zone, raid only (`Summon.lua:10`)
  - `UnitName`, `UnitIsConnected`, `UnitIsDeadOrGhost`, `UnitInRange` (`Summon.lua:22-31`)
  - `UnitInParty` and `UnitInRaid` are not used anywhere in WUK.
  - `IsInGroup` is used in Board, Comm and Announce, not in Summon.
- **Re-evaluation on roster change**: `GROUP_ROSTER_UPDATE` calls `UpdateSummonRows` (`Summon.lua:88`). That re-runs `Context` for the labels, and prunes only by TTL.
- **`ctx.here`**: true when `RosterZone(name) == GetRealZoneText()` (`Summon.lua:25`). In a party `RosterZone` returns nil (the ponytail comment at `:8`), so `here` is always false there.
- **Helpers count**: counts connected group units other than the target where `UnitInRange` is true. It becomes nil (unknown) if `UnitInRange` returns a secret (`Summon.lua:26-34`). In a party the player is not in `GroupUnits`, so the player is not counted.

## Q5: Trace a summon end to end

### Findings
1. **Request**: chat event, then `OnChat`, which adds `{ name, at }` (`Summon.lua:58-63`).
   - `QueueAdd` writes `at = os.time()` when available (`Logic.lua:58`), and `OnChat` overwrites it with `time()` (`Summon.lua:62`).
2. **Row**: `UpdateSummonRows` sets `row.name = r.name` and the macro attributes (`Summon.lua:46-48`).
3. **Click**: the secure macro runs `/target NAME` then `/cast Ritual of Summoning`. The spell name is from `WUK.known.ritual`, resolved from `SPELLS.ritual` (`Core.lua:53`, `:87-93`).
4. **`UNIT_SPELLCAST_SENT`** (`Core.lua:161-163`): for `unit=="player"`, stores the second argument (`target` name string) in `WUK.lastCastTarget`. It stores nil when the value is secret or empty.
   - This handler fires for **every** player spell, so `lastCastTarget` holds the target of whatever spell was sent last.
5. **`UNIT_SPELLCAST_SUCCEEDED`** (`Summon.lua:89-93`): if `unit=="player"`, `SpellName(spellID) == WUK.known.ritual` and `lastCastTarget` is set, it runs `QueueRemove(queue, Ambiguate(lastCastTarget,"none"))` and then `UpdateSummonRows`.
   - `SpellName` resolves through `C_Spell.GetSpellInfo(spellID).name` (`Core.lua:164-168`).
   - The `UpdateSummonRows` call is a no-op in combat.
- **Other `UNIT_SPELLCAST_SUCCEEDED` handler**: `Prep.lua:42`, for armor and pet.
- **Other queue functions**:
  - `QueueRemove(list, name)` removes all entries with an equal `name` (`Logic.lua:61-63`). It is called from the right-click (`Summon.lua:81`) and the success handler (`:91`).
  - `QueuePrune(list, keep)` removes entries where `keep` is false (`Logic.lua:64-66`). It is called only from `UpdateSummonRows` (`Summon.lua:41`).
  - `SummonFailure(ctx)` is a pure function that returns the first failing label or nil (`Logic.lua:68-77`). It is called only for row text (`Summon.lua:49`).
- **Events not used anywhere in WUK**: `UNIT_SPELLCAST_FAILED`, `_INTERRUPTED`, `_CHANNEL_START`, `_CHANNEL_STOP`, `_STOP`, `C_IncomingSummon`, `CONFIRM_SUMMON` and `ZONE_CHANGED*`. Only `SENT` and `SUCCEEDED` are used.
- **`WUK.Probe`** (`Core.lua:174-242`) prints instance state, pet family, combat, chat lockdown, aura secrecy, cooldown viewer, bag and target-aura details. It has nothing about summoning or the roster.
- **`probe-results.md`** (`thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md`) contains no summon or roster entries.
- Earlier research recorded Ritual of Summoning as learned at level 20, ID 698, marked unverified (`thoughts/qrspi/2026-10-19-warlock-utility-kit/research.md:73`). It also recorded the queue behaviour of the Logroño's Warlocks reference addon (`:133`).
- **Not answerable from the codebase**: when exactly `UNIT_SPELLCAST_SUCCEEDED` fires for Ritual of Summoning on the Forever client, at portal placement or at summon completion, and whether a summoned player's acceptance or arrival is observable. See Open Areas.

## Q6: What visual styling exists across WUK frames?

### Findings
- **Templates**:
  - `BasicFrameTemplateWithInset`: Board (`Board.lua:97`) and Settings (`Settings.lua:18`).
  - `BackdropTemplate`: Summon panel (`Summon.lua:67`).
  - `WowStyle1DropdownTemplate`: Board (`:90`) and Settings (`:41`).
  - `UIPanelButtonTemplate`: Board (`:137`) and Settings (`:51`, `:55`).
  - `UICheckButtonTemplate`: Settings (`:8`).
  - `SecureActionButtonTemplate`: Summon rows and strip stones (`Summon.lua:74`, `UI.lua:128`).
- **Backdrops**: only one, `WHITE8x8` with black at 0.6 alpha and no edge file (`Summon.lua:69`).
- **Colors**:
  - Chat prefix `|cff9482c9` (purple) (`Core.lua:8`).
  - Strip rim `SetColorTexture(0.58,0.51,0.79,0.55)` (lavender) and disc `(0.04,0,0.07,0.7)` (near-black purple) (`UI.lua:119-120`).
  - Glow vertex color `(0.7,0.3,1)` (`UI.lua:99`).
  - Summon row zone `|cffaaaaaa`, failure `|cffff6060` (`Summon.lua:49`).
- **Strip "summoning circle"** (`UI.lua:112-152`):
  - Masked round `Disc` textures using `TempPortraitAlphaMask` (`:53-59`).
  - Swirl texture `Interface\Icons\Spell_Shadow_Twilight` with ADD blend at alpha 0.35, rotating 360° every 90 s (`:121-125`).
- **Glow**: `WUK.AddGlow` uses an `UI-ActionButton-Border` texture with ADD blend, purple, and a bouncing alpha animation (`UI.lua:96-103`). `SetAlert` toggles it (`:105-110`).
- **Fonts**: stock only (`GameFontHighlight`, `GameFontNormal`, `GameFontNormalSmall`, `GameFontHighlightSmall`, `NumberFontNormal`). There are no custom font files.
- **Media**: the addon has no media folder (directory listing: `.lua` files, `.toc`, `README.md`, `CHANGELOG.md`, `tests/`). All textures are Blizzard paths.
- **Warlock-themed Blizzard textures referenced**:
  - `INV_Misc_Gem_Amethyst_02` (shard, minimap, TOC icon)
  - `Spell_Shadow_SoulGem`
  - `Spell_Shadow_Twilight`
  - `INV_Stone_04`, `INV_Misc_Gem_Sapphire_01`, `INV_Ammo_FireTar` (`UI.lua:6-9`, `Settings.lua:76`, `WarlockUtilityKit.toc:6`)
  - No atlases (`SetAtlas`) are used anywhere.
- **`MakeMovable(f, key, x, y)`** (`UI.lua:13-26`):
  - Shift+left-drag, only when `not WUK.db.locked` and not in combat.
  - Saves `{point, relPoint, x, y}` to `WUK.db.frames[key]` and restores it, falling back to `CENTER x,y`.
  - Used by the strip (`"strip"`, `UI.lua:149`) and the summon panel (`"summon"`). Not used by Board or Settings.
- **"Reset positions"** runs `wipe(WUK.db.frames)` and prints that a `/reload` is needed (`Core.lua:251`). It does not re-anchor any live frame.
- **Lock**: `WUK.db.locked` is toggled by `/wuk lock` (`Core.lua:250`). It is read only in `MakeMovable` (`UI.lua:16`).
- **Local helpers, not shared**:
  - `Board.lua`: `Radio` (`:83`), `Dropdown` (`:89`), `Button` (`:136`).
  - `Settings.lua`: `Check` (`:7`); the dropdown and buttons are built inline.
  - No shared widget module exists.

## Q7: How is board and queue state stored and synced?

### Findings
- **SavedVariables** (`WarlockUtilityKit.toc:7-8`):
  - `WarlockUtilityKitDB` (account), with defaults `{locked, shown, frames={}, icons={}, minimapAngle=220, dockViewers, spin, collapse}` (`Core.lua:19`).
  - `WarlockUtilityKitCharDB` (character), with defaults `{pet="imp"}` (`Core.lua:20`).
  - Both are merged with `MergeDefaults` on `ADDON_LOADED` (`Core.lua:22-28`, `Logic.lua:16-23`).
- **Board state**:
  - In memory as `WUK.board = {lead, rev, rows={[warlock]={curse,mark,ss}}}` (`Board.lua:6`).
  - Persisted to `WUK.char.board = {rev, rows}` only while self is lead (`SaveIfLead`, `:13-16`).
  - Cleared when another player's lead claim is accepted (`:61`) or when leaving the group (`:178`).
  - Restored at init if in a group (`:171-172`).
- **Wire format** (`Logic.lua:128-151`): `1|L|rev`, `1|A|rev|warlock|curse|mark|ss`, `1|R` and `1|E|rev`, with `"-"` for nil.
  - `Decode` validates the field count, numeric rev and mark, and a non-nil warlock.
- **Send**:
  - `SendRow` sends `A` (`Board.lua:42-45`).
  - `SendFullBoard` sends `L`, then all `A`s, then `E` (`:47-52`).
  - `RequestSync` sends `R` (`:54`).
  - Messages are queued through `WUK.Send`, which allows at most 64 and only when in a group (`Comm.lua:24`).
  - Messages are flushed every 0.25 s, one per 0.5 s, on prefix `WUKB` to RAID or PARTY (`Comm.lua:5-22`, `:28`). Failures back off exponentially and the queue is dropped after 3 failures (`:17-21`).
- **Receive**: `CHAT_MSG_ADDON` filters on the prefix and secret values, `Ambiguate`s the sender, ignores self, then calls `Decode` and `OnBoardMessage` (`Comm.lua:29-35`).
  - `OnBoardMessage` (`Board.lua:56-70`):
    - accepts `L` from the current lead or a newer rev (`AcceptLead`, `Logic.lua:153`)
    - accepts `A` from the lead at a rev at least as new as the current one (`AcceptRow`, `:154`)
    - answers `R` with a full board when self is lead
  - `E` is decoded but not handled.
- **Summon queue**: module-local `queue` (`Summon.lua:3`).
  - It is not in SavedVariables, is not encoded, and has no addon messages.
  - It is **local to each client** and is lost on `/reload`.
- **Healthstone requests**: a separate local `hsQueue` keyed by name with a 600 s TTL (`Trade.lua:2-3`).
- **Tests**: `tests/run.lua` (112 lines) uses the local `eq` assert helper (`:5`).
  - **Summon/queue**:
    - `IsSummonRequest` positives and negatives (`:29-30`)
    - `QueueAdd` dedupe and max, `QueueRemove` order, `QueuePrune` (`:31-35`)
    - `SummonFailure` for each branch, plus unknown helpers (`:36-46`)
  - **Board**:
    - `AssignmentText` (`:61-64`)
    - soulstone `StoneMacro` (`:65`)
    - `Encode`/`Decode` round-trips and rejects (`:69-76`)
    - `AcceptRow`/`AcceptLead` (`:77-80`)
    - `AnnounceLines` (`:83+`)
  - **Not covered**: `Context`, `GroupUnits`, `UnitFull`, `RosterZone`, `OnChat`, `UpdateSummonRows` and the UI builders. These depend on WoW APIs.
  - **How tests run**: plain Lua; the file loads `Logic.lua` with a stub `WUK` table. The exact run command is in the README or the header of `tests/run.lua`, and was not re-read here.

## Cross-Cutting Observations
- **Two frame conventions**:
  - HUD frames (strip, summon panel) are built at init and use `MakeMovable` with Shift+drag, lock and saved position.
  - Dialog frames (board, settings) are built lazily on toggle, use `BasicFrameTemplateWithInset`, plain drag, close on Escape, have no saved position, and both start at `CENTER` with `DIALOG` strata.
- **Settings routing**: every settings mutation goes through the `/wuk` slash handler (`Core.lua:245-267`). The board's edit path is `WUK.SetAssignment` rather than slash commands.
- **Pure logic and tests**: pure logic lives in `Logic.lua` and is unit-tested. Modules that depend on WoW APIs hold UI and event wiring, and have no tests.
- **Secret values**: guarded via `WUK.Secret` at every name and text input (`Core.lua:7`).
- **Combat lockdown**: secure-attribute writes are skipped in combat and replayed via `PLAYER_REGEN_ENABLED` and `Refresh` (`Summon.lua:39`, `UI.lua:166`).
- **Purple/shadow palette**: limited to the strip, the glow and the chat prefix. The dialog frames use stock Blizzard chrome.

## Open Areas
- **Ritual of Summoning events on Forever**:
  - Whether `UNIT_SPELLCAST_SUCCEEDED` fires when the portal is placed or when the summon completes.
  - Whether a cancelled ritual (helpers never click, the target declines) produces `UNIT_SPELLCAST_SUCCEEDED` anyway.
  - The codebase has no probe or test for this.
- **Summoned player arrival**: whether the arrival or acceptance is observable, through `C_IncomingSummon` on the target's side or through a roster or zone change on the warlock's side. Nothing in the repo records this.
- **`UNIT_SPELLCAST_SENT` target**: whether the `target` argument includes a realm suffix for other-realm targets on this client. The code `Ambiguate`s it either way.
- **Zone in a party**: `RosterZone` is raid-only by design (ponytail comment at `Summon.lua:8`). No party zone source is implemented.
- **Test run command**: not re-verified in this pass.
