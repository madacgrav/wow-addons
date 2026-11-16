# Structure Outline

## Approach
Each ring view is a list of keys in `Logic.lua`. Every spell gets its own secure button, and switching views only shows/hides buttons and repositions them, out of combat. Right-click on the soulstone switches views; right-click on the healthstone trades a stone. Tooltips and the healthstone trade ship first, because they are useful without the views. Every phase ends with tests plus a deploy to the Forever AddOns folder and an in-game check.

## Phase 1: Tooltips on existing ring buttons
Hovering the shard, stones, armor and pet shows the matching item or spell tooltip.

**Files**: `UI.lua`, `Prep.lua`
**Key changes**:
- `WUK.SpellTooltip(name)` — new (UI.lua). Calls `GameTooltip:SetSpellByID(C_Spell.GetSpellInfo(name).spellID)`, or `AddLine(name)` when there is no ID.
- `WUK.AttachTooltip(b, fill)` — new (UI.lua).
  - `fill(b)` adds the tooltip lines.
  - Sets `OnEnter`: `SetOwner(b, "ANCHOR_RIGHT")`, then `fill`, then `Show`.
  - Sets `OnLeave = GameTooltip_Hide`. Same shape as `Settings.lua:102-108`.
- Stone fill: `SetBagItem(unpack(WUK.counts.slots[kind]))` when held; otherwise `SpellTooltip(WUK.known[kind])`. The shard shows its bag item, or "Soul Shards: 0".
- Armor and pet fill: `SpellTooltip(<current spell>)`.

**Verify**: `lua5.1 WarlockUtilityKit/tests/run.lua` passes. Deploy, then in-game: hover each of the 7 buttons with and without stones in bags; the tooltip hides when the mouse leaves; no Lua errors.

---

## Phase 2: Healthstone right-click trade
Left-click is unchanged (consume if held, otherwise create). Right-click opens a trade with your friendly target and places the stone in slot 1.

**Files**: `UI.lua`, `Trade.lua`
**Key changes**:
- Healthstone button: `SetAttribute("type1", "macro")` replaces `type`. Other stones keep `type`. `macrotext` is unchanged.
- `WUK.OfferHealthstone(name)` — new (Trade.lua). Sets `hsQueue[name] = time()`. The existing `TRADE_SHOW` handler (`Trade.lua:17-26`) places the stone.
- `HookScript("OnClick")` on the healthstone (UI.lua), for RightButton up:
  - Guards, in order: not in combat; friendly player target; `CheckInteractDistance("target", 2)`; `counts.healthstone > 0`.
  - If all pass: `WUK.OfferHealthstone(WUK.UnitFull("target"))`, then `InitiateTrade("target")`.
  - If one fails: `WUK.Print(<reason>)`.
- The healthstone tooltip gets the line "Right-click: trade to target".

**Verify**: tests pass. Deploy, then in-game:
- left-click with no stone creates one;
- left-click with a stone eats it;
- right-click on a party member opens a trade with the stone in slot 1, and Accept completes it;
- right-click with no target, an enemy or an out-of-range player prints the reason and opens no trade.

---

## Phase 3: View switching — Party ⇄ Buff
Right-click on the soulstone switches between Party and Buff views, with an icon tint and a re-bloom. Leaving the ring or entering combat returns it to Party.

**Files**: `Logic.lua`, `tests/run.lua`, `Core.lua`, `UI.lua`, `Prep.lua`
**Key changes**:
- `WUK.VIEWS = { party = {...today's ORBIT}, buff = { "soulstone", "armor", "detect", "shadowward", "soullink", "unending", "eye", "sense" } }` — new (Logic).
- `WUK.VIEW_ORDER = { "party", "buff" }` — new (Logic). Demon is added in Phase 4.
- `WUK.ViewKeys(view, known, has) -> { key... }` — new (Logic). Keeps a key if `has[key]` (the button exists) and, for buff and demon views, the spell is known (`known[key]`). The party list is returned unfiltered.
- `WUK.NextView(view) -> view` — new (Logic). Wraps around `VIEW_ORDER`.
- `WUK.FlipAngle(angle, iOld, nOld, iNew, nNew) -> angle` — new (Logic). Keeps the soulstone at the same angle across a flip.
- `SPELLS` gains `shadowward`, `unending`, `eye`, `sense` (Core.lua:48-62).
- `WUK.SpellButton(key) -> Button` — new (Prep.lua).
  - The shape is from `Prep.lua:4-19`: secure 36x36, glow, highlight, icon `GetSpellTexture`, macro `/cast known[key]` set out of combat, and a tooltip.
  - Buttons are registered into `strip.icons[key]`.
  - Created for `detect`, `shadowward`, `soullink`, `unending`, `eye`, `sense`. `armor` reuses the existing armor button.
- `strip.view` — new runtime field, default `"party"`.
- `LayoutRing`:
  - Iterates `ViewKeys(strip.view, ...)` instead of `ORBIT`.
  - Hides buttons outside the view and shows those inside, touching only buttons whose membership changed.
- `WUK.SetView(view)` — new (UI.lua).
  - Out of combat only.
  - Sets `strip.angle = FlipAngle(...)` and `strip.radius = 0`, then `Animate()`.
  - Tints the soulstone icon with `SetVertexColor` per view.
- Soulstone button: `type1="macro"`. Its `HookScript` on RightButton up calls `SetView(NextView(strip.view))`.
- Tooltip hint: "Right-click: \<next view\> view".
- Fallbacks to Party: `CombatFreeze` calls `SetView("party")` before lockdown. `Step` sets Party when the radius reaches 0 and `db.collapse` is on.

**Verify**: tests pass, with new tests for `NextView`, `ViewKeys` (filters unknown spells, party unfiltered) and `FlipAngle` (the soulstone angle is unchanged for 2→1 and 1→2 index moves). Deploy, then in-game:
- right-click toggles Party ⇄ Buff, with a blue tint in Buff;
- only known buffs show, and casting each one works;
- the soulstone stays under the cursor;
- left-click still uses the soulstone;
- mouse off the ring resets to Party;
- pulling a mob resets to Party, and right-click does nothing in combat;
- Party view looks exactly as before.

---

## Phase 4: Demon view and ring growth; release 0.4.0
Adds the third view, all summons, a ring that grows for 10 buttons, and the release bookkeeping.

**Files**: `Logic.lua`, `tests/run.lua`, `Core.lua`, `UI.lua`, `Prep.lua`, `WarlockUtilityKit.toc`, `CHANGELOG.md`
**Key changes**:
- `WUK.VIEWS.demon = { "soulstone", "imp", "voidwalker", "succubus", "incubus", "felhunter", "felguard", "inferno", "doom", "feldom" }`.
- `VIEW_ORDER` becomes `{ "party", "buff", "demon" }`.
- `SPELLS` gains `felguard`, `inferno`, `doom`, `feldom`.
- `SpellButton` is created for every demon key. The pet button stays Party-only.
- `WUK.ViewRadius(n) -> number` — new (Logic). Returns `max(58, n*40/(2*pi))`.
- `LayoutRing`, `Target()`, the alpha and the disc sizes use `strip.fullR = ViewRadius(#keys)` instead of the constant `R`.
- Demon tint is red.
- Version `0.4.0` in the toc. `CHANGELOG.md` gets `## [0.4.0]` with an "Added" section covering tooltips, healthstone trade, and the Buff and Demon views.

**Verify**: tests pass, with new tests for `ViewRadius` (6 gives 58, 10 gives about 63.7) and a 3-view cycle in `NextView`. Deploy, then in-game:
- Party → Buff → Demon → Party, with the tints;
- all known summons show and cast;
- 10 buttons don't overlap;
- the collapse and combat fallbacks still work.

## Testing Checkpoints
- **After Phase 1**: every existing ring button has a tooltip. No behaviour change.
- **After Phase 2**: healthstone right-click trades to the target. Left-click is unchanged.
- **After Phase 3**: two views work. `Logic.lua` has the view helpers with tests. Party view is identical to v0.3.3.
- **After Phase 4**: three views, the ring grows to fit, version is 0.4.0 with a CHANGELOG entry. Ready for PR.
