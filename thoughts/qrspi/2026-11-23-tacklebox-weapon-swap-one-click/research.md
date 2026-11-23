# Research Findings

Paths: `TackleBox/` = `D:\Source\wow-addons\TackleBox`; `refs/` = `D:\Source\wowskill\skills\wow-forever-addon\references`; "gaps research" = `thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/research.md`; "GH-22" = `thoughts/qrspi/GH-22-forever-fishing-addon/`.
Web facts are labelled **verified** (read on the cited page), **reported** (author/forum claim) or **unverified** for Forever. No addon Lua source or Gethe/wow-ui-source was read this round.

## Q1: How does the action bar build, show, configure and click its secure buttons?

### Findings
- Load order: Data, Logic, Core, Actions, Panel, CastBar (`TackleBox.toc:9-14`). `TB.inits` and `TB.refreshers` are created at `Core.lua:3` and run in file-load order. The Actions refresher (`Actions.lua:100`) runs before the Panel refresher (`Panel.lua:277`), and Panel's Water tab reads `TB.actions.water` (`Panel.lua:250`).
- **Build** (init, `Actions.lua:38-44`):
  - Frame `TBActionBar` is parented to UIParent with BackdropTemplate, 52x52, skinned by `TB.Skin`.
  - It is anchored `TOPRIGHT` to `TB.Dock()`'s `TOPLEFT` with offset (2,0), and made draggable via `TB.DockDrag(bar)` (`Actions.lua:42`).
  - Header comment: secure buttons live on their own UIParent frame because a secure child or anchor would make the panel protected in combat (`Actions.lua:3`, `Panel.lua:16-17`).
- **Buttons**:
  - `ORDER = { "pole", "lure", "water", "cast" }` (`Actions.lua:5`). Each is `CreateFrame("Button", "TBAction_"..key, bar, "SecureActionButtonTemplate")`, 40x40, with `RegisterForClicks("AnyUp","AnyDown")` (`Actions.lua:12-13`).
  - Each has an icon, rim, count FontString, a looping ripple and an OnEnter tooltip (`SetItemByID` or the `TIPS[key]` text, plus `self.need` in red; `Actions.lua:27-32`).
  - Buttons start hidden (`Actions.lua:34`). There is no OnClick script: the template runs the attributes.
- **Refresher** (`Actions.lua:100-126`) builds a new table `A`, sets `TB.actions = A`, then calls `Apply()`.
  - `PoleEquipped()` (`Actions.lua:93-98`) reads `GetInventoryItemID("player", 16)`, then `C_Item.GetItemInfoInstant`. It is true when classID == 2 and subID == 20 (fishing pole).
  - **No pole equipped:** `TB.PickPole(BagItems())` returns the first bag item with class 2 / sub 20 (`Logic.lua:163-165`) and sets `A.pole = {item=id}`.
    - `BagItems()` walks bags `0..NUM_BAG_SLOTS or 4` with `C_Container.GetContainerNumSlots` / `GetContainerItemID` and returns `{id, classID, subID}` entries without bag/slot (`Actions.lua:79-91`).
  - **Pole equipped:** sets lure via `TB.PickLure(lures, counts, (GetWeaponEnchantInfo()), skill)` (`Actions.lua:105-111`, `Logic.lua:169-183`). The pole button is not shown while a pole is equipped.
  - Water: `TB.WaterWalkPick` (`Actions.lua:113-118`, `Logic.lua:149-159`).
  - Cast: `C_Spell.GetSpellInfo(7620)` gives `A.cast = {spell=name, icon}`, set only when `TB.skill` is non-nil (`Actions.lua:120-123`).
- **Apply()** (`Actions.lua:47-77`):
  - Guard `if not bar or InCombatLockdown() then return end` (`:48`). No pending queue exists: `PLAYER_REGEN_ENABLED -> TB.Refresh` re-runs everything (`:46`, `Core.lua:58`).
  - Attributes by key:
    - `usable == false` sets `type=nil`, so the button is visible but inert, desaturated and at 0.5 alpha (`:53-54`, `:66-67`).
    - pole: `type=macro`, `macrotext="/equip item:<id>"` (`:56`).
    - lure: `type=macro`, `macrotext="/use item:<id>\n/use 16"` (`:59`).
    - water: `type=item`, `item="item:<id>"` (`:61`).
    - cast: `type=spell`, `spell=<name>` (`:63`).
  - Layout: buttons stack from y=6 in steps of 44 (`:69-70`). Hidden keys get `b:Hide()` (`:72`).
  - Then `bar:SetHeight(max(52, y+2))` and `bar:SetShown(y > 6 and TB.db.shown)` (`:75-76`).
- **Dock** (`Panel.lua:18-40`):
  - `TB.Dock()` lazily creates a 1x1 movable `TBDock`. Its position comes from `TB.db.frames.dock`, defaulting to `TOPLEFT, UIParent, CENTER, 140, 150`.
  - `TB.DockDrag` moves the dock only on Shift-drag when not locked and not in combat, and saves `{p, rp, x, y}` to `TB.db.frames.dock`.
- **Refresh triggers**:
  - `TB.Refresh` is a 0.1 s debounce gated on `TB.active` (`Core.lua:42-50`).
  - Events:
    - `PLAYER_LOGIN` (`:52-56`)
    - `SKILL_LINES_CHANGED` (`:57`)
    - `PLAYER_REGEN_ENABLED` (`:58`)
    - `BAG_UPDATE_DELAYED` (`:59`)
    - `BANKFRAME_OPENED` (`:60`)
    - `PLAYERBANKSLOTS_CHANGED` (`:61`)
    - `ZONE_CHANGED_NEW_AREA` (`:62`)
    - `UNIT_INVENTORY_CHANGED` for player, commented "pole/gear changes the skill modifier" (`:63`)
    - `UNIT_AURA` for player (`:74`)
  - Other callers:
    - a 1 s ticker while a camp buff has `remaining` (`:76-80`)
    - the loot handler (`:155`)
    - the miss timer (`:133`)
    - `/tb` show/hide (`:240-241`)
    - panel close, minimap and tab clicks (`Panel.lua:69, 154, 317`)
  - `PLAYER_EQUIPMENT_CHANGED` is not registered anywhere in TackleBox.

## Q2: Which Forever APIs/events read, track and equip main-hand (16) / off-hand (17)? Combat restrictions? Item identity?

### Findings
- **Read**:
  - `GetInventoryItemID` and `GetInventoryItemLink` are in the index as hand-added globals (`refs/forever-api-index.md:1065`). They are confirmed in-game on build 70959 (2026-11-17) but missing from Blizzard docs (`refs/forever-api-notes.md:31`). TackleBox already uses `GetInventoryItemID("player", 16)` (`Actions.lua:94`).
  - `C_PaperDollInfo.GetInventorySlotInfo` is in the index (`:763`). No global form is listed.
  - `C_Item.IsEquippedItem` and `IsEquippedItemType` are in the index (`:646`).
  - Slot constants such as `INVSLOT_MAINHAND`: not in references. TackleBox hard-codes 16 (`Actions.lua:59, 94`).
- **Change events**:
  - `PLAYER_EQUIPMENT_CHANGED` (`refs/forever-api-index.md:2254`, C_PaperDollInfo). Payload `equipmentSlot` (number), `hasCurrent` (boolean, documented "true when a slot becomes empty") is **verified** on the wiki (warcraft.wiki.gg/wiki/PLAYER_EQUIPMENT_CHANGED). Its Forever payload is not in refs.
  - `UNIT_INVENTORY_CHANGED` (`:2695`). Payload: not in refs.
  - `EQUIPMENT_SWAP_PENDING` / `EQUIPMENT_SWAP_FINISHED` / `EQUIPMENT_SETS_CHANGED` (`:1646-1648`).
- **Equip**:
  - `C_Item.EquipItemByName(itemInfo[, dstSlot])` is in the index (`:646`), tagged AllowedWhenUntainted (gaps research:101; wiki **verified**).
  - The global `EquipItemByName` is not in the index. The wiki says it was deprecated in 10.2.6 with the fallback removed in 12.1.5, and that "since 3.3.0, calling it in combat picks up the item rather than equipping it" (**verified**, wiki API_EquipItemByName).
  - `EquipCursorItem` is in the index (`:1060`).
  - `PickupInventoryItem` is not in the index. The wiki marks it #nocombat (**verified**).
  - `C_Container.PickupContainerItem` is in the index (`:433`). The global `PickupContainerItem` is on the never-emit list (`refs/forever-api-notes.md:53`).
  - `C_EquipmentSet.*` is in the index (`:517`), including `UseEquipmentSet`, `CreateEquipmentSet`, `SaveEquipmentSet`, `GetItemIDs`, `GetItemLocations` and `IgnoreSlotForSave`. Users: FishingBuddy-fork stores `LastGearSet` and uses EquipmentManager (gaps research:127); Fishing Mode uses a set named "Fishing" plus "Fishing Mode Backup" (gaps research:14; CurseForge page **reported**).
  - Slash `/equip` and `/equipslot` are not in refs (slash commands are not indexed).
    - Wiki syntax (**verified**): `/equipslot [options] InvSlot item` and `/equipslot [options] InvSlot bagID slot`, where `item` is a name or the `item:...` part of a link (warcraft.wiki.gg/wiki/MACRO_equipslot).
    - Forum report that `/equipslot 16 item:18838` did not work for one Classic-era poster: **reported**.
    - The wiki pages have no combat notes for these macros. Behaviour in combat on Forever: **unverified**.
- **Combat**:
  - Fishing Mode's author: "addons can't swap weapons during combat" on Forever (**reported**, CurseForge). The same is reported in gaps research:101, :141.
  - Quick Fish (Forever) claims "both weapons on instantly when attacked" (**reported**, EU forum 636280, mechanism unstated).
  - refs have no per-function protected list. `refs/taint-and-secure.md:8` gives the general rule only.
- **Item identity / duplicates**:
  - The read paths return an item ID (`GetInventoryItemID`) or a link (`GetInventoryItemLink`, which carries enchant and suffix data).
  - `/equipslot` accepts a bag/slot pair or a name / `item:` string.
  - `C_EquipmentSet.GetItemLocations` returns locations.
  - How duplicates of one item ID are handled: not in references.

## Q3: SavedVariables shape, defaults merge, availability timing

### Findings
- TOC: `SavedVariables: TackleBoxDB`, `SavedVariablesPerCharacter: TackleBoxCharDB` (`TackleBox.toc:6-7`).
- Defaults:
  - `DEFAULTS = {locked=false, shown=true, frames={}, minimapAngle=200, tab="where", flash=true}` (`Core.lua:17`).
  - `CHAR_DEFAULTS = {catches={}}` (`Core.lua:18`).
- Runtime keys:
  - `TB.db.lastProbe` (`Core.lua:162`)
  - `TB.db.frames.dock` (`Panel.lua:38`)
  - `TB.char.catches[itemID] = {n, first, last, q, zones}` (`Logic.lua:80-87`)
- There is no version field and no migration code.
- `TB.MergeDefaults(sv, defaults)` (`Logic.lua:3-10`):
  - A non-table `sv` becomes `{}`.
  - Table defaults recurse. Scalars fill only when nil. Extra keys are kept and the default table is not mutated.
  - It is tested at `tests/run.lua:11`.
- Timing:
  - `ADDON_LOADED` for this addon merges both SVs and sets `TB.db`, `TB.char` (`Core.lua:20-26`). Comment: nil-safe because of a Forever beta loader bug.
  - `PLAYER_LOGIN` sets `TB.active = true`, runs all inits (the first `TB.db` reader is `TB.Dock()` inside the Actions init), then `TB.Refresh()` (`Core.lua:52-56`).
  - Nothing reads `TB.db` at file scope. Refreshers are gated by `TB.active`.

## Q4: Fishing cast lifecycle as TackleBox observes it

### Findings
- Registered player-unit events:
  - `UNIT_SPELLCAST_CHANNEL_START`: four handlers at `Core.lua:92, 110, 119`.
  - `UNIT_SPELLCAST_CHANNEL_STOP`: three handlers at `Core.lua:98, 113, 125`.
  - `LOOT_READY`: two handlers at `Core.lua:99, 140`.
  - `LOOT_CLOSED`: `Core.lua:139`.
  - No `UNIT_SPELLCAST_START/SUCCEEDED/INTERRUPTED/FAILED` handlers exist. A cancel is seen only as `CHANNEL_STOP`.
- Payload of `UNIT_SPELLCAST_CHANNEL_START` is (unitTarget, castGUID, spellID, castBarID), tagged SecretWhenUnitSpellCastRestricted, which is unverified for the player (gaps research:89).
- `UnitChannelInfo("player")` returns start and end ms as the 4th and 5th values (`Core.lua:94, 121`). Probe run 2: plain (not secret) values, 30000 ms channel (GH-22 `probe-results.md:19-26`).
- **"Line in the water" state**:
  - There is no boolean. `TB.lastChannel = {spellID, t}` is set on a non-secret channel start (`Core.lua:110-112`), and `.stopT` is set on stop (`:113-115`). `lastChannel` is never cleared, so `stopT == nil` means the channel is still active.
  - The cast bar holder is shown between `TB.StartCastBar` and `TB.StopCastBar` (`CastBar.lua:38-53`).
  - `IsFishing(spellID)` = non-nil, non-secret, and in `TB.DATA.fishingSpells` (`Core.lua:118`). The fishing spell is 7620 (probe run 1).
- Cast bar (`Core.lua:119-124`):
  - Start and end come from `UnitChannelInfo`. If those are missing or secret it falls back to `TB.DATA.castSeconds`.
  - The bar is updated with an OnUpdate calling `TB.CastProgress` (`CastBar.lua:47-51`, `Logic.lua:121-126`).
- Miss (`Core.lua:125-136`):
  - On a fishing `CHANNEL_STOP`, `StopCastBar`, then after 1 s, `TB.IsMiss(stopT, lastLootT)` checks whether there was no loot within 0.5 s before the stop (`Logic.lua:129-131`).
  - A miss increments `TB.session.misses` (not persisted, `Core.lua:117`), plays the optional `TB.Flash()`, and calls Refresh.
- Catch (`Core.lua:140-156`):
  - `looted` guards a double `LOOT_READY`.
  - `TB.IsFishingCatch(isFL, lastChannel, now, spells)` uses `IsFishingLoot()` when present, else a 30 s window after stop (`Logic.lua:73-76`).
  - On a catch: `TB.lastLootT`, then `RecordCatch` per loot slot.
- Observed order (GH-22 `probe-results.md`):
  - A catch is `CHANNEL_STOP`, then `LOOT_READY` about 10 ms later, firing once (run 4, :37-51).
  - Early stops without loot at 20.8 s, 22.6 s and 13.5 s were interpreted as unclicked bites, not confirmed (runs 2-4).
  - `CHANNEL_STOP` can land about 1.6 s after the nominal end (run 3, :29-35).
  - What the player clicked on each cast was not recorded (:35).

## Q5: Mechanisms for an addon click/key to interact with a fishing bobber

### Findings
- **SecureActionButtonTemplate types**: actionbar, action, pet, spell, toy, item, macro, flyout, glyph, worldmarker, cancelaura, stop, target, focus, assist, mainassist, maintank, click, attribute, togglemenu, destroytotem, multispell. There is **no "interact" type** (**verified**, warcraft.wiki.gg/wiki/SecureActionButtonTemplate).
- **Macro**: the wiki macro-command list has no `/interact` (**verified**). A Dec 2022 Blizzard forum request for `/softinteract` says the soft target can be interacted with only via mouse click or keybind (**reported**).
- **INTERACTTARGET**:
  - This is the binding action behind the "Interact with target" key and needs the "Enable Interact Key" option (**reported**: Fishing-OneKey, Soft Interact HUD pages).
  - It is not in the index (bindings are not indexed).
  - `C_PlayerInteractionManager.InteractUnit` is in the index (`refs/forever-api-index.md:802`). Its wiki page 404s and its protected status is unverified.
- **Override bindings** (wiki, **verified**):
  - `SetOverrideBinding`, `SetOverrideBindingClick` and `SetBinding` are restricted and #nocombat ("cannot be called while in combat").
  - The SetBinding page: "Snippets executed by SecureHandlers may alter [override] bindings in-combat."
  - `SetOverrideBindingClick(owner, isPriority, key, buttonName[, mouseClick])` (gaps research:98).
  - None of these are in the Forever index.
  - Fishing-OneKey's page says addon keybindings through `Bindings.xml` are no longer supported, so it binds with `/fok bind` (**reported**).
- **Soft-target CVars**:
  - `SoftTargetInteract`: 0 off / 1 gamepad / 2 KBM / 3 always, default 0.
  - `SoftTargetInteractRange`: default 10.
  - `SoftTargetInteractArc`: default 0.
  - `SoftTargetIconInteract`: default 1.
  - The defaults are from a wiki 3.4.1 API-changes search snippet (**reported**).
  - None are in the index. C_CVar is at `refs/forever-api-index.md:357` (functions only).
  - `SetCVar` returns nil for a *secure* CVar in combat. Whether SoftTarget CVars are secure is **unverified**.
  - A 3.4.1 forum thread reports `SoftTargetInteractRange` had no effect (**reported**).
  - Better Fishing says Classic Era/TBC/Mists soft-target range is fixed and too low for fishing (**reported**).
  - Forever default and max range: not in references (gaps research:166).
- **Events**: `PLAYER_SOFT_INTERACT_CHANGED` (old/new target) and `PLAYER_SOFT_TARGET_INTERACTION` (**reported**, wiki snippet). Their presence in the Forever index was not checked.
- **What fishing addons use**:
  - **Fishing-OneKey** (lists 1.60.1 / Forever; **reported**, CurseForge): out of channel, the key clicks an invisible secure button that casts Fishing. While the channel is active it does `SetOverrideBinding` of the key to INTERACTTARGET, and removes the remap when the channel ends. It needs "Enable Interact Key". It states "No protected function is called from insecure code." The trigger event and combat behaviour are not stated.
  - **BetterFishing** (gaps research:114-118, from source read in the earlier research):
    - The cast is `SetOverrideBindingSpell` / a `type=spell` secure button.
    - On channel start it rebinds the key to `INTERACTTARGET`.
    - Double right-click is detected via `GLOBAL_MOUSE_DOWN` within the `doubleClickSpeed` window, then `SetOverrideBindingClick(btn, true, "BUTTON2", "BetterFishingButton")`, cleared on mouse up (BetterFishing.lua:298-328).
    - During the channel it sets `SoftTargetInteract=3`, `Arc=2`, `Range=60`, restoring them on stop or logout (:233-247, :346-347).
    - A PostClick `SecureHandlerWrapScript` clears bindings (:83-88).
    - `BetterFishing_Run` exits early in combat (gaps research:114).
  - **FishingBuddy-fork**: the same button plus BUTTON2 pattern (LibFishing:2249-2287), and toggles `autoInteract` (gaps research:99, :128).
  - **Fishing Mode**: temporarily overrides cast/interact keybinds and soft-target settings while the mode is on. In Retail, combat disables the mode (**reported**).
  - **CFC, Angler, Fishmonger, Avid Angler**: double right-click cast (**reported**, snippets). Fishmonger uses a secure action button with a 50-400 ms window.
  - **ForeverPlusPlus**: no secure buttons and no combat handling (GH-22 research:211, :237).
- Reported limits: the interact key grabs a nearby NPC, player or current target instead of the bobber; soft range is too short for far bobbers (gaps research:104, :138-139).

## Q6: Can one secure button change behaviour between clicks? What works in combat?

### Findings
- Insecure `SetAttribute` is only allowed out of combat. Guidance is to gate on `InCombatLockdown()` and re-apply on `PLAYER_REGEN_ENABLED` (`refs/taint-and-secure.md:14, 23`). TackleBox follows this (`Actions.lua:48`, `Core.lua:58`).
- The SecureActionButtonTemplate wiki page says to create the button outside combat. It does not list which attributes may change in combat (**verified**).
- `RegisterStateDriver` is not in the index. `refs/taint-and-secure.md:24` names it only for show/hide/move of secure frames in combat.
- `SecureHandlerWrapScript` / `SecureHandlerStateTemplate` are not in the index. Restricted-snippet rules are not in refs.
  - Used by BetterFishing's PostClick wrap (gaps research:116).
  - Wiki: SecureHandler snippets may alter override bindings in combat (**verified**, SetBinding page).
- Macro conditionals (`[channeling]`, `[equipped:Fishing Poles]`) and `/stopcasting`: not in references, and not checked this round.
- Fishing-OneKey switches behaviour by swapping an override binding (cast button outside the channel, INTERACTTARGET during it) rather than by changing button attributes (**reported**).
- `UnitChannelInfo` is the channel check used by BetterFishing (gaps research:117) and by TackleBox (`Core.lua:94`).

## Q7: Offline tests and available stubs

### Findings
- `tests/run.lua` is a plain Lua script.
  - It derives `dir` from `arg[0]` (`:1`) and loads only `Data.lua` and `Logic.lua` into `TB` (`:3-4`), with an `eq` helper (`:6-8`). Last line prints "all tests passed" (`:90`).
  - Covered:
    - MergeDefaults, FormatTime, SkillText, TabRows (`:11-19`)
    - QuestRows (`:22-24`)
    - WhereRows (`:27-39`)
    - IsFishingCatch, RecordCatch, CollectionView, TopZones (`:42-52`)
    - CastProgress, IsMiss (`:55-60`)
    - CampRows (`:63-67`)
    - WaterWalkPick (`:70-77`)
    - PickPole, PickLure (`:80-88`)
  - Not covered: Core/Actions/Panel/CastBar, PoleEquipped, BagItems, Apply, macro text, combat deferral, event wiring.
  - There are no WoW API stubs.
- The shared wowmock harness (`refs/testing.md`):
  - It runs `*_spec.lua` via `wowmock.new_env(opts)` with opts `saved, login, items, in_combat, …`, and env methods `load_addon, fire, advance, update, slash`.
  - It does not model taint, secure frames, combat lockdown or ADDON_ACTION_BLOCKED (`refs/testing.md:51`), or secret values (`:53`).
  - `InCombatLockdown` reads `opts.in_combat` (`scripts/wowmock/luaext.lua:60`).
  - `C_Item` stubs cover only GetDetailedItemLevelInfo, GetItemInfo and GetItemCount (`scripts/wowmock/tooltip.lua:18-31`).
  - Missing stubs: GetInventoryItemID, Equip*, binding functions, SetAttribute/GetAttribute, GetItemInfoInstant, C_Container, GetWeaponEnchantInfo, issecretvalue, UnitChannelInfo.
  - Unknown frame methods raise "unimplemented Frame:X" (`refs/testing.md:43`).
  - TackleBox does not use wowmock today.

## Cross-Cutting Observations
- All secure-button configuration in TackleBox follows one pattern: rebuild `TB.actions` from scratch on every Refresh, then apply attributes only when `not InCombatLockdown()`, relying on `PLAYER_REGEN_ENABLED` to re-apply (`Actions.lua:46-48`, `Core.lua:58`).
- State is derived each refresh, not stored. Pole presence, lure, water-walk and cast are all recomputed from live API reads. The only persisted runtime state is the dock position and catches.
- Slot 16 is hard-coded as the main hand (`Actions.lua:59, 94`). There are no references to slot 17 anywhere in TackleBox.
- Pure decision logic lives in `Logic.lua` and is unit-tested. WoW-API glue lives in Core/Actions and is untested offline.
- `GH-22/design.md` and the gaps research recorded casting and gear swap as out of scope for the original addon (gaps research and GH-22 docs). This is noted only as history.

## Open Areas
- Whether `/equip` / `/equipslot` macros on a secure button swap weapons in combat on Forever: unverified. One Forever addon reports that addons cannot do it.
- How `/equipslot` / `C_Item.EquipItemByName` choose between duplicate copies of one item ID: unverified.
- Forever `PLAYER_EQUIPMENT_CHANGED` and `UNIT_INVENTORY_CHANGED` payloads: wiki only, not confirmed in game.
- Forever soft-target interact default and maximum range, and whether the SoftTarget CVars are secure in combat: unknown.
- Which event or hook Fishing-OneKey uses to swap the override binding, and whether that works in combat: not stated on its page. No addon source was read this round.
- Whether macro conditionals such as `[channeling]` work on Forever: not checked.
- What the player did on each probe cast (clicked bobber vs not): not recorded (GH-22 `probe-results.md:35`).
