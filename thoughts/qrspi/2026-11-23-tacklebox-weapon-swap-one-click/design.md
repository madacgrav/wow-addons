# Design Discussion

## Current State
- **Action bar:** four secure buttons in `ORDER = pole, lure, water, cast` (`TackleBox/Actions.lua:5`), each a `SecureActionButtonTemplate` registered for `AnyUp, AnyDown` (`Actions.lua:12-13`).
  - Every `TB.Refresh` rebuilds `TB.actions` from live API reads (`Actions.lua:100-126`).
  - `Apply()` sets attributes only when `not InCombatLockdown()` (`Actions.lua:48`). `PLAYER_REGEN_ENABLED -> TB.Refresh` re-applies them after combat (`Core.lua:58`).
- **Pole button:** `/equip item:<id>`. It is shown only while there is no pole in slot 16 (`Actions.lua:56, 93-105`).
  - Nothing reads slot 17.
  - Nothing remembers the weapons the pole replaced.
  - `BagItems()` returns `{id, classID, subID}` without bag, slot or link (`Actions.lua:79-91`).
- **Cast button:** `type=spell` Fishing (`Actions.lua:63`). Reeling in means mousing over the bobber and right-clicking it.
- **Channel state:** a line is in the water while `TB.lastChannel` is set and its `.stopT` is nil.
  - `TB.lastChannel` is set on a fishing `UNIT_SPELLCAST_CHANNEL_START` (`Core.lua:110-115`), and `.stopT` on `CHANNEL_STOP`.
  - The cast bar and miss logic hang off the same events (`Core.lua:119-136`).
- **SavedVariables:**
  - `TackleBoxDB` defaults (`Core.lua:17`).
  - `TackleBoxCharDB = {catches={}}` (`Core.lua:18`).
  - Both are merged with `TB.MergeDefaults` at `ADDON_LOADED` (`Core.lua:20-26`). There is no version field.
- **Tests:** `tests/run.lua` loads only `Data.lua` and `Logic.lua` and tests pure functions (`tests/run.lua:3-4`). It has no API stubs.
- **Panel:**
  - `TBPanel` (not secure) has a header: portrait, title, quip, skill bar and got-away counter (`Panel.lua:56-107`).
  - Below the header are a tab strip at y=-82 (`Panel.lua:142-160`) and a fixed pool of `MAX_ROWS = 30` rows starting at `TOP = 128` (`Panel.lua:3-4, 112-138`).
  - Height grows with the row count (`Panel.lua:213`).
  - Rows past 30 are dropped. The comment at `Panel.lua:2` already expects a ScrollBox to be needed.
  - The Where tab's `TB.WhereRows` flags the current zone as `here`, `too low` or `outgrown` and adds range, no-loss and lure text (`Logic.lua:49-71`). That status is visible only inside the Where tab.
- **History:** `GH-22-forever-fishing-addon/design.md:143` listed one-key cast and auto weapon swap as non-goals. This design deliberately reverses that. The weapon swap stays player-clicked.

## Desired End State
1. **Weapon memory.**
   - While the main hand holds anything other than a fishing pole, TackleBox keeps a per-character snapshot of the main-hand and off-hand items (ID and link).
   - Equipping a pole by any means leaves the snapshot alone.
   - The snapshot survives `/reload` and logout.
2. **Re-equip button.**
   - While a pole is equipped and a snapshot exists, the top slot of the bar (where "Equip pole" sits) becomes "Equip weapons".
   - One click puts the main hand back, and the off hand too if one was remembered.
   - If a remembered weapon is not in the bags, the button is greyed out with a red "not in bags" line in its tooltip. This matches the existing `usable=false` pattern.
3. **One-key cast and reel.**
   - `/tb bind <KEY>` saves a key, and `/tb unbind` clears it.
   - With no line out, the key casts Fishing through the existing Cast button.
   - While the line is out, the same key is the game's Interact action, which reels in the bobber via soft-target.
   - When the channel ends, the key goes back to casting.
   - The bar's Cast button stays click-to-cast. A mouse click on a button cannot interact (research Q5).
4. **Soft-target CVars.**
   - While the line is out and a key is bound, `SoftTargetInteract=3` and a larger `SoftTargetInteractRange` are set.
   - Previous values are restored on channel stop, on `PLAYER_LOGOUT`, and on login if a saved copy is left over from a crash.

5. **Collapsible tabs.**
   - The tab strip and rows are hidden by default.
   - A chevron button in the header toggles them, and the state persists in `TB.db.expanded` (default `false`).
   - When collapsed, the panel is just the header plus the zone line.
6. **Always-visible zone line.**
   - A line under the skill bar shows the current zone's fishing status, for example "Orgrimmar: skill 75-150 [here]", colored like the Where tab (`Panel.lua:234`).
   - It adds lure or no-loss text, for example "needs Shiny Bauble".
   - A zone missing from `TB.DATA.zones` shows "<zone>: no fishing data".
   - With no Fishing skill, the line is empty.
7. **Scrollable rows.**
   - Every tab's rows sit in one scroll frame at most 10 rows tall, with the mouse wheel enabled.
   - The row pool grows lazily to `#rows`, so long Catch lists are no longer cut off at 30.
   - The panel height is capped at the header plus 10 rows.

**Verify:**
- Offline:
  - `lint.sh TackleBox` is clean.
  - `tests/run.lua` passes, with new specs for snapshot, bag lookup and macro text.
- In game, swap with:
  - main hand only
  - main hand + off hand
  - a two-hander
  - a weapon moved to the bank (button greys out)
- In game, cast and reel:
  - cast and reel with the bound key, five times in a row
  - `/reload` mid-cast, then check the CVars are restored
  - start a channel in combat (no errors, and the key works again after combat)
- In game, panel:
  - collapse, expand and `/reload` (the state is kept)
  - the zone line updates when you cross a zone border
  - a Catch list with more than 10 rows scrolls with the wheel
  - switching tabs resets scroll to the top
  - toggle the panel in combat (no errors; the panel is not secure)

## Patterns to Follow
- **Rebuild-and-apply:**
  - Compute the action table in the refresher and set attributes only in `Apply()` outside combat (`Actions.lua:47-77, 100-126`).
  - The weapons action is just another entry in `A` (key `pole`, with a different payload). It is not a separate state machine.
- **Greyed-but-visible:**
  - `usable=false` gives `type=nil`, desaturated icon and red `need` text (`Actions.lua:53-54, 66-67`, tooltip `:27-32`).
- **Pure logic in `Logic.lua`, tested in `tests/run.lua`:**
  - Follows `TB.PickPole` / `TB.PickLure` (`Logic.lua:163-183`, `tests/run.lua:80-88`).
  - New functions go here, and the API glue stays in Actions/Core.
- **Event fan-out via `TB.On`** (`Core.lua:9-15`). The channel handlers sit next to the existing fishing-channel handlers and use the same `IsFishing(spellID)` check (`Core.lua:118`).
- **SavedVariables:**
  - Add keys only. `MergeDefaults` keeps extra keys and fills nil scalars (`Logic.lua:3-10`).
  - No migration is needed.
- **Combat:**
  - Gate every binding, CVar and attribute change on `InCombatLockdown()`.
  - Recover on `PLAYER_REGEN_ENABLED` (`refs/taint-and-secure.md:14, 23`).
- **Do NOT follow:**
  - The global `EquipItemByName`: deprecated, fallback removed in 12.1.5, and it picks the item up in combat (research Q2).
  - `PickupContainerItem`: never-emit (`refs/forever-api-notes.md:53`).
  - `Bindings.xml`: reported unsupported on current clients (research Q5).

## Design Decisions
1. **Reel method: keybind with an override swap (Fishing-OneKey pattern).**
   - The owner frame holds `SetOverrideBindingClick(owner, true, key, "TBAction_cast")` out of combat.
   - On a fishing `CHANNEL_START` outside combat, it switches to `SetOverrideBinding(owner, true, key, "INTERACTTARGET")`.
   - On `CHANNEL_STOP` (or `PLAYER_REGEN_ENABLED` if the stop happened in combat), it switches back to the click binding.
   - Why: a secure button has no interact type and there is no `/interact` macro, so the Interact binding action is the only route (research Q5). The user picked this over double right-click.
2. **Soft-target CVars: set temporarily, then restore.**
   - On swap-to-interact, save the current `SoftTargetInteract` and `SoftTargetInteractRange` to `TB.db.cvarBackup`, then set `3` and a larger range.
   - On swap-back, restore them and clear the backup.
   - Also restore on `PLAYER_LOGOUT`, and at `PLAYER_LOGIN` if a backup still exists.
   - Only active when a key is bound.
   - Why: the defaults (0 and 10) make reeling fail silently. This is the BetterFishing pattern (research Q5). The user chose this.
3. **Snapshot: any pole equip, stored per character.**
   - In the Actions refresher, when the main hand is not a pole, write `TB.char.weapons = {mh={id,link}, oh={id,link} or nil}`.
   - Leave it unchanged when a pole is equipped.
   - The existing `UNIT_INVENTORY_CHANGED -> Refresh` (`Core.lua:63`) already covers equip changes, so no new event is needed.
   - Why: the user wants it to cover every way of equipping, and the refresher already runs on each change.
4. **Re-equip by bag/slot, located at refresh time.**
   - Extend `BagItems()` to return `bag, slot, link`.
   - The pure function `TB.FindWeapon(items, want)` prefers an exact link match, then falls back to an ID match.
   - The macro is `/equipslot 16 <bag> <slot>`, then `/equipslot 17 <bag> <slot>` if there is an off hand.
   - Why: the bag/slot form is documented (wiki **verified**, research Q2), avoids the ambiguity between duplicate copies, and the refresher runs on `BAG_UPDATE_DELAYED`, so positions stay current.
   - After equipping, the old snapshot stays valid: the main hand is a non-pole again, and the next refresh re-snapshots it.
5. **Button placement: the pole slot toggles.**
   - Key `pole` shows either "Equip pole" (no pole equipped) or "Equip weapons" (pole equipped and a snapshot exists), with a matching icon and tooltip.
   - Why: the user's choice. The bar stays four buttons tall and acts as a toggle.
6. **Key storage: account-wide `TB.db.castKey`.**
   - Set with `/tb bind <KEY>`. The key name is validated as a non-empty string and normalized to upper case.
   - No capture UI.
   - Why: matches the slash-only settings model (`Core.lua:236-247`). The smallest working setup.
7. **Zone line reuses `WhereRows`.**
   - New pure function `TB.ZoneStatus(zones, lures, skill, zone)` in `Logic.lua` returns `{text, sub, flag}` for the current zone, or a "no fishing data" row.
   - Extract the per-zone `row()` logic from `TB.WhereRows` (`Logic.lua:52-65`) so both share it.
   - Why: one source of truth for the flags. Testable in `tests/run.lua`.
8. **Collapse is a plain show/hide on non-secure frames.**
   - The tab buttons and the scroll frame call `SetShown(TB.db.expanded)` in `RenderPanel`. Height is computed from the state.
   - Why: the panel is deliberately not secure (`Panel.lua:16-17`), so this works in combat too.
9. **Scroll frame: `UIPanelScrollFrameTemplate` with a content child.**
    - Rows are parented to the content frame. Its height is `#rows * 26`, and the visible height is `min(#rows, 10) * 26`.
    - Reset scroll to the top when the tab changes.
    - The template name must be checked against `refs/forever-api-index.md` and `refs/widgets.md` at plan time. If it is missing, the fallback is a bare `ScrollFrame` with `SetScrollChild` plus an `OnMouseWheel` script.
    - Why: smallest native scroll. The user chose all tabs at 10 rows.
10. **One owner frame for bindings and CVars** lives in `Actions.lua` next to the Cast button it clicks. The channel events call two functions: `TB.ReelMode(true/false)`.

## What We're NOT Doing
- No weapon swapping in combat, and no auto re-equip when attacked. Reported impossible on Forever (research Q2).
- No double right-click casting. No mouse-click reel on the bar button, because it is not possible.
- No equipment-set (`C_EquipmentSet`) integration. No other gear slots (hat, gloves, boots).
- No Bindings.xml, no key-capture dialog, and no options panel.
- No auto-applied lure. No change to lure, water or miss logic.
- No change to tab contents, tab order or sorting. No per-tab scroll position memory. No resizable panel.
- No adoption of the wowmock harness. The specs stay in `tests/run.lua` for pure logic only.

## Open Risks
- **Double fire:**
  - Buttons register `AnyUp, AnyDown` (`Actions.lua:13`), so a binding click may fire on both key down and key up. That could cast and then cancel or recast.
  - If this shows up in game, register the Cast button for the down edge only, or pass a mouse-button argument in the binding click.
- **Hidden button click:** the Cast button is hidden when the panel is closed (`Actions.lua:72-76`), and it is unconfirmed that a binding click fires on a hidden secure button. Fallback: keep the button's attributes set while it is hidden, or use a dedicated hidden caster.
- **Forever soft-target range:**
  - The maximum range is unknown, and a 3.4.1 report says the range CVar had no effect.
  - Far bobbers may not reel. Mitigation: cast closer. Not fixable from the addon.
- **Interact grabs the wrong target:** a nearby NPC, player or current target may win over the bobber (research Q5). Known limitation, to be documented in the README.
- **Channel starts in combat:** the swap is skipped, so the key keeps casting. Accepted.
- **Channel stops in combat:** the key stays on Interact until combat ends, then `PLAYER_REGEN_ENABLED` restores it.
- **`/equipslot` with bag/slot on Forever:** documented on the wiki but not tested in game. Fallback: `C_Item.EquipItemByName(link, 16)` from a PreClick is not possible because it is insecure. Next fallback is `/equipslot 16 item:<id>`.
- **Scroll template on Forever:** `UIPanelScrollFrameTemplate` may be renamed or replaced by a ScrollBox in the 12.x code. Check it at plan time and use the bare `ScrollFrame` fallback (decision 9) if needed.
- **Zone line width:** long zone names plus status may overflow the 296 px width. Use word wrap off with truncation, as the rows already do (`Panel.lua:120-122`).
- **Two-hand pole + off hand:**
  - Equipping a 2H pole moves the off hand to the bags, possibly into a slot the refresh has not seen yet.
  - `BAG_UPDATE_DELAYED` re-runs the refresh before the next click, but a very fast click right after equipping could use stale slots.
