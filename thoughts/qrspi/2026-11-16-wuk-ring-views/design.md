# Design Discussion

## Current State
- **The ring.** `WUKStrip` is a ring with 6 orbit slots (`ORBIT`, `UI.lua:11`) around a shard core.
  - The order is healthstone, soulstone, spellstone, firestone, armor, pet.
  - `LayoutRing()` places every key in `ORBIT` using `WUK.RingPoint(i, #ORBIT, radius, angle)` (`UI.lua:33-50`, `Logic.lua:174-177`).
  - A button is drawn only if its key is in `ORBIT` and its frame is in `strip.icons` (`UI.lua:142`, `Prep.lua:6`, `25`).
- **Button types.**
  - Stone buttons are `SecureActionButtonTemplate` with `type="macro"` and one shared `macrotext`, so every mouse button runs the same macro (`UI.lua:128-133`, `165-168`).
  - The soulstone macro comes from `WUK.StoneMacro`: use the stone on the assigned target, or on a friendly target, or on yourself; create one when none is held (`Logic.lua:26-36`).
  - Armor and pet are separate secure buttons that cast a known spell by name (`Prep.lua:4-39`).
- **Spells.** Spells are tracked by name in `WUK.known` and come from `SPELLS` (`Core.lua:48-62`, `87-93`).
  - `detect` and `soullink` are scanned but nothing reads them.
  - Shadow Ward, Unending Breath, Eye of Kilrogg, Sense Demons, Fel Domination, Felguard, Inferno and Ritual of Doom are not in `SPELLS`.
- **Tooltips.** No ring button has a tooltip. The only tooltip in the addon is on the minimap button (`Settings.lua:102-108`).
- **Animation.** The ring spins and blooms through a self-removing OnUpdate (`UI.lua:61-85`). It collapses to radius 0 when the mouse leaves (`UI.lua:64-66`).
- **Combat.** `CombatFreeze` on `PLAYER_REGEN_DISABLED` expands the ring before lockdown (`UI.lua:88-93`, `151`). Every protected change (position, attributes, show/hide) is guarded with `InCombatLockdown()`. Textures can change at any time.
- **State.** No view or page state exists, and none is saved.

## Desired End State
- **Tooltips.** Hovering any ring button shows a tooltip.
  - Spell buttons show the spell tooltip.
  - Stone buttons show the bag item when one is held, otherwise the create spell.
  - The shard core shows the shard item.
  - The soulstone tooltip adds a hint line: "Right-click: \<next view\>".
- **Three views on the ring.**
  1. **Party** (default): today's ring, unchanged.
  2. **Buff**: soulstone toggle plus each known buff. Candidates: Demon Armor/Skin, Detect Invisibility (highest rank), Shadow Ward, Soul Link, Unending Breath, Eye of Kilrogg, Sense Demons.
  3. **Demon**: soulstone toggle plus each known summon. Candidates: Imp, Voidwalker, Succubus, Incubus, Felhunter, Felguard, Inferno, Ritual of Doom, Fel Domination.
- **Cycling views.** Right-clicking the soulstone moves Party → Buff → Demon → Party.
  - The soulstone icon is tinted per view: Party normal, Buff blue, Demon red.
  - The ring closes and re-blooms with the new set as the "flip".
  - Left-click on the soulstone still uses or creates a soulstone, in every view.
- **Healthstone button (Party view).**
  - Left-click: if a stone is held, consume it; if none is held, create one. This is already what `StoneMacro` does (`Logic.lua:33`, `35`), so it is kept.
  - Right-click: trade the stone to your current target. It opens a trade window with the target and places the healthstone in trade slot 1. You still click Accept yourself.
  - The tooltip hint is "Right-click: trade to target".
- **Falling back to Party.**
  - When the ring collapses (mouse leaves and the ring reaches radius 0).
  - When entering combat (forced in `CombatFreeze`). The toggle does nothing in combat.
  - On reload (the view is not saved).
- **Verification.**
  - `lua5.1 tests/run.lua` passes, with new tests for the view helpers.
  - In-game: hover each button for a tooltip; right-click cycles 3 views with colour changes; left-click still uses the soulstone; moving the mouse off resets to Party; entering combat resets to Party; casting from the Buff and Demon views works.
  - In-game, healthstone: left-click with none held creates one; left-click with one held eats it; right-click on a friendly player opens a trade with the stone already in slot 1.

## Patterns to Follow
- **Init and refresher pairs** per feature file (`Core.lua:3`, `141-153`). Put the new view and tooltip code in the same pattern rather than adding a new event loop.
- **Pure logic in `Logic.lua` with tests in `tests/run.lua`** (`tests/run.lua:1-7`). View lists, next view, filtering view keys by `known`, and the flip-angle maths go there.
- **Spell button shape** from `Prep.lua:4-19`:
  - `SecureActionButtonTemplate`, 36x36, `AddGlow`, highlight texture.
  - Macro `/cast <WUK.known[key]>`, set only out of combat.
  - Icon from `C_Spell.GetSpellTexture(name)`, with 134400 as the fallback.
  - The new buff and demon buttons should share one small helper instead of copying this a third time.
- **Ranked spell names in `SPELLS`**, highest rank first, first known wins (`Core.lua:46-47`). Shadow Ward and Unending Breath use one name each; `/cast Name` casts the highest rank.
- **Secure button plus insecure hook**: the summon rows keep their secure actions and use `HookScript("OnClick")` for right-click (`Summon.lua:77`, `80-82`). The soulstone toggle copies this.
- **Combat guards**: every `SetAttribute`, `Show`/`Hide`, `SetPoint` and `EnableMouse` sits behind `InCombatLockdown()`, with work re-applied on `PLAYER_REGEN_ENABLED` (`UI.lua:35`, `165`; `Core.lua:156`). Tint and texture changes are allowed in combat (`UI.lua:95`).
- **Healthstone trade flow** (`Trade.lua:2-3`, `17-26`): `hsQueue[name] = time()` marks a requester. On `TRADE_SHOW`, if the partner is queued within the TTL, the handler picks up `WUK.counts.slots.healthstone` and calls `ClickTradeButton(1)`, and it clears the entry on `ERR_TRADE_COMPLETE`. Right-click reuses this path rather than building a second one.
- **Tooltip shape**: `SetOwner` / `Show` in `OnEnter`, and `OnLeave = GameTooltip_Hide` (`Settings.lua:102-108`).
- **Do NOT follow**:
  - The single shared `type`/`macrotext` on the soulstone and healthstone (`UI.lua:133`). It makes right-click run the stone macro. Both buttons must bind left-click only (`type1`).
  - The hardcoded `#ORBIT` and constant `R` in `LayoutRing` and `Target`. These must read the current view's key list and radius.

## Design Decisions
1. **Right-click on the soulstone cycles views.** Left-click stays the stone macro.
   - The soulstone button gets `type1="macro"` instead of `type="macro"`. The `macrotext` attribute already falls back for button 1, so `StoneMacro` is unchanged.
   - The insecure `HookScript("OnClick")` on `RightButton` up calls `WUK.NextView()` when out of combat.
   - Why: no lost function, and it matches the summon-row pattern.
2. **Each view is a list of keys in `Logic.lua`.**
   - The lists: `WUK.VIEWS = { party = {...today's ORBIT}, buff = {"soulstone", ...}, demon = {"soulstone", ...} }`, plus `WUK.VIEW_ORDER = {"party","buff","demon"}`.
   - Buff and demon keys are shown only if `WUK.known[key]` is set.
   - `LayoutRing` iterates the filtered current list. Buttons outside that list are hidden and lose mouse input (out of combat).
   - Why: one ring code path, testable, and the Party view stays byte-for-byte identical.
3. **One button per spell key.** Buttons are created at init and shown or hidden by view; macros are not rewritten when the view changes.
   - Why: the only protected work on a flip is Show/Hide/SetPoint, and that already happens out of combat in `LayoutRing`.
   - The existing `armor` and `pet` buttons stay Party-only. The Buff view gets its own `armor` entry pointing at the same armor button, so it is reused rather than duplicated.
4. **The soulstone stays under the cursor across flips.**
   - On a flip the code adjusts `strip.angle` so the soulstone's angle is unchanged, even though its slot index and slot count change.
   - This is a pure helper, `WUK.FlipAngle(angle, idxOld, nOld, idxNew, nNew)`, and it is tested.
   - Why: right-clicking again must land on the same button.
5. **The flip animation reuses the bloom.** A flip sets `strip.radius = 0`, and the existing `Step` animator re-blooms with the new set. Why: no new animation code.
6. **The view colour is a soulstone icon tint.** `b.icon:SetVertexColor(...)`, re-applied in the stone refresher. Party is (1,1,1), Buff is about (0.5,0.75,1), Demon is about (1,0.45,0.45). Why: texture-level, so it is safe even in combat.
7. **Fall back to Party** in three places:
   - `CombatFreeze`, which runs before lockdown;
   - `Step`, when the radius reaches 0 with `db.collapse` on;
   - a reload, because the view is runtime-only (`strip.view`), not saved.
8. **The ring radius grows with the button count.**
   - The view radius is `max(58, n*40/(2π))`. For 10 buttons that is about 64; for 6 or fewer it stays 58.
   - `Target()`, the alpha (`radius/R`) and the disc sizes use the view's full radius.
   - Why: the Demon view can hold up to 10 buttons, which overlap at R=58.
9. **Tooltips are set on every ring button at init.**
   - Spell buttons resolve the ID with `C_Spell.GetSpellInfo(name).spellID`, then call `GameTooltip:SetSpellByID`, falling back to `AddLine(name)` if there is no ID.
   - Stones use `SetBagItem(bag, slot)` from `WUK.counts.slots[kind]` when held; otherwise the create spell's tooltip, the same way.
   - The soulstone appends the next-view hint.
10. **New `SPELLS` keys** (`Core.lua:48-62`): `shadowward`, `unending`, `eye`, `sense`, `felguard`, `inferno`, `doom`, `feldom`. Existing keys reused: `armor`, `detect`, `soullink`, `imp`, `voidwalker`, `succubus`, `incubus`, `felhunter`.
11. **Right-click on the healthstone trades it to the target.**
    - The healthstone button gets `type1="macro"`, so left-click keeps the `StoneMacro` behaviour: consume if held, otherwise create.
    - The `HookScript("OnClick")` on `RightButton` up checks four things: the target is a friendly player (`UnitIsPlayer`, `UnitIsFriend`), the target is in trade range (`CheckInteractDistance("target", 2)`), at least one healthstone is held, and you are not in combat.
    - If all four pass, it sets `hsQueue[<target name>] = time()` and calls `InitiateTrade("target")`. Otherwise it prints why it did not trade ("no friendly target", "out of range", "no healthstone").
    - The existing `TRADE_SHOW` handler (`Trade.lua:17-26`) places the stone. Trade.lua exposes a small `WUK.OfferHealthstone(name)` that sets the queue entry, so `hsQueue` stays local to the file.
    - Why: it is one code path for both the requested and the manual trade, and the trade completes only on your own Accept click.
12. **Release**: version 0.4.0 and a CHANGELOG "Added" entry, following `CHANGELOG.md:5-9`.

## What We're NOT Doing
- Switching views in combat (no `SecureHandler*` snippets). The toggle is inert in combat and the ring is forced to Party.
- Saving the current view, or any setting or slash command for views.
- User-configurable view contents or ordering.
- Changing Party view contents, the order, or any existing button's left-click behaviour.
- Auto-accepting the trade, trading anything except a healthstone, or adding a right-click to the other stones (spellstone, firestone).
- Tooltips outside the ring (Board, Summon queue).
- Curses, Banish, Health Funnel, Enslave Demon, Demonic Sacrifice, or steed mounts.
- Locale tables. Spell names stay enUS (`Logic.lua:3`).
- Changes to the Summon queue, Board, Trade, Dock or Comm.

## Open Risks
- **Spell names on Forever are not verified.** That covers Shadow Ward, Unending Breath, Eye of Kilrogg, Sense Demons, Felguard, Inferno, Ritual of Doom and Fel Domination. Unknown names are hidden, so the cost is only a missing button. A wrong name means a missing button rather than a bug.
- **`GameTooltip:SetSpellByID` and `C_Spell.GetSpellInfo(name).spellID` are not verified on Forever.** The `AddLine(name)` fallback covers a nil ID.
- **Hidden buttons and hit testing.** A hidden secure button must not keep stealing clicks; `Hide()` covers this. Show/Hide inside the 60fps `LayoutRing` should only touch buttons whose membership changed.
- **The soulstone keeps a dual role.** Left-click in Buff or Demon view still uses or creates a soulstone. That is intended, but it may surprise you.
- **Inferno targets the ground.** `/cast Inferno` enters cursor targeting, which is normal client behaviour.
- **Healthstone trade risks (not verified on Forever).**
  - Whether `InitiateTrade` and `ClickTradeButton` work from a hooked click on Forever. `Trade.lua:24` already falls back to a print when `ClickTradeButton` is missing.
  - Whether the game blocks trading in combat. The hook refuses in combat anyway.
  - Possible name mismatch: `TRADE_SHOW` matches the partner name with `Ambiguate`, so the queue entry must use the same `WUK.UnitFull("target")` form.
- **Collapse fallback when collapse is off.** With `db.collapse` off, the view stays until you right-click or enter combat. That is the intended behaviour.
