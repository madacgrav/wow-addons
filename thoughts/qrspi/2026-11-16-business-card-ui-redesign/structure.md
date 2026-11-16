# Structure Outline

`BC/` = `C:/Users/madac/wt/wow-addons/2026-11-16-profession-business-card/BusinessCard/` (worktree branch `2026-11-16-profession-business-card`).

## Approach
- Replace the stock UI with "merchant ledger" chrome, a scrolling list of detailed rows, and one business-card widget used by both My card and the detail view. Restyle one surface per phase.
- Data, comms and the wire format stay untouched.
- **Layers in each phase.** The two layers are:
  - pure display helpers in `Logic.lua`, covered by `tests/run.lua`;
  - frames in `Skin.lua`, `Panel.lua` and `Card.lua`, checked in game.
- **Deploy each phase.** At the end of every phase, robocopy `BC/` into `_forever_\Interface\AddOns\BusinessCard`.
- **Load order** in `BusinessCard.toc`: Data, Logic, Core, Comm, Skin, Panel, Card.

---

## Phase 1: Ledger chrome
The window gets the new look: a hand-built frame with a rock backdrop, faint parchment, a gold border, a Morpheus title, a close button, tabs and gold rules. Rows keep their current text layout, so all current behaviour still works inside the new frame.

**Files**: `BC/Skin.lua` (new), `BC/Data.lua`, `BC/Panel.lua`, `BC/BusinessCard.toc`

**Key changes**:
- `BC.THEME = { ink, parchment, gold, goldBright, muted, available, busy, off }`: colour tables `{r,g,b[,a]}`. It lives in `Data.lua`, so Logic and the tests can read it.
- `BC.Skin(f: Frame, opts?: {edge?: "dialog"|"tooltip", bg?: "rock"|"plain"})`: sets the backdrop and border colours.
- `BC.Parchment(f: Frame, alpha?: number): Texture`: `QuestBG` on BACKGROUND sublevel -2.
- `BC.Rule(parent, y): Texture`: a 1 px gold line.
- `BC.Fade(t: Texture, dir: "VERTICAL"|"HORIZONTAL", c: color, a1: number, a2: number)`.
- `BC.TitleFont(fs: FontString, size: number)`: Morpheus with a fallback to `GameFontNormalLarge`.
- Panel `Build()` creates its frame with `CreateFrame("Frame","BusinessCardWin",UIParent,"BackdropTemplate")`, about 540x560.
- The tabs (`PanelTabButtonTemplate` ×2) replace `seenBtn` and `cardBtn` and keep `SetView(view)`.
- Kept: drag and position save, UISpecialFrames, `/bcard lock` and `/bcard reset`.

**Verify**:
- `lua tests/run.lua` passes.
- In game: `/bcard` opens the ledger frame and the tabs switch views. Esc closes it. Drag, then `/reload`, and the position persists.
- No Lua errors.

---

## Phase 2: Detailed scrolling Seen list
Seen becomes a `WowScrollBoxList` with 34 px rows. Each row shows a status dot, the name (gold if the player runs BusinessCard), up to 3 category icons, the zone, the age and a card badge. Rows are striped and get a hover gradient. Every entry is reachable. The filter dropdown is restyled into the header.

**Files**: `BC/Data.lua`, `BC/Logic.lua`, `BC/Panel.lua`, `BC/tests/run.lua`

**Key changes**:
- Data:
  - `BC.CAT_ICON[cat] = "Interface\\Icons\\..."`: one icon per category in the 12 `BC.CATS`.
  - `BC.SVC_ICON[key]`: icons for summon and each portal.
- Logic:
  - `BC.RowIcons(cats: set, max: integer): {path...}`: in `BC.CATS` order, capped at `max`.
  - `BC.StatusColor(st: "a"|"b"|"o"|nil): {r,g,b}|nil`: reads from `BC.THEME`.
- Panel:
  - `BuildList(win): ScrollBox`: `CreateScrollBoxListLinearView()`, `SetElementExtent(34)`, `ScrollUtil.InitScrollBoxListWithScrollBar`, guarded with a nil check.
  - `InitRow(row: Button, v: SeenRow)`: replaces the per-row code in `RenderSeen`. Click, tooltip and right-click behaviour are kept.
  - `BC.RenderSeen(rows, total)` now does `SetDataProvider(CreateDataProvider(rows))`.
  - `MAX_ROWS` is removed.
- `RenderMyCard` keeps a temporary plain-list fallback until Phase 3. It reuses the ScrollBox with the card entries.

**Verify**:
- Tests cover `RowIcons` (order and cap) and `StatusColor` (a, b, o, nil).
- In game: with 25 or more ads, scrolling reaches every row. The icons match the categories and the dot matches the card. Click to whisper, shift-click for detail and right-click to remove all still work.

---

## Phase 3: Business-card widget plus My card
A card-shaped panel shows:
- your portrait inside a round ring;
- your name, realm and zone;
- one line per profession, each with an icon, a skill bar and a status pill;
- service icons, each with a status pill;
- a large global Available/Busy pill.

Clicking a pill cycles its status through the existing `BC.ChangeStatus`. The footer shows recipe-cache counts.

**Files**: `BC/Card.lua` (new), `BC/Data.lua`, `BC/Logic.lua`, `BC/Panel.lua`, `BC/BusinessCard.toc`, `BC/tests/run.lua`

**Key changes**:
- Data: `BC.PROF_ICON[profId]`.
- Logic:
  - `BC.SkillFrac(skill: number, cap?: number): number`: 0 to 1, with a default cap of 300. Cards carry no max skill.
  - `BC.CardModel(card, opts: {self: boolean}): { title, sub, portrait: "player"|iconPath, profs: {{key, icon, name, skill, frac, st}}, svcs: {{key, icon, label, st}}, g }`: a pure view model for the card.
- Card.lua:
  - `BC.NewCard(parent: Frame): CardFrame`: builds once and holds pools of profession lines and service icons.
  - `CardFrame:SetModel(m: CardModel)`: lays out the lines and pills.
  - `CardFrame.onPill = function(key) end`: the click hook.
  - `BC.Pill(parent): Button`: a round dot plus a label, with `Pill:SetStatus(st)`.
  - `BC.RoundPortrait(parent, size): Texture`: masked, with a `MiniMap-TrackingBorder` ring. Uses `SetPortraitTexture` through pcall and re-applies it on `UNIT_PORTRAIT_UPDATE` and on show.
- Panel:
  - The "card" view shows `win.card`, built with `BC.NewCard`, and hides the list.
  - `RenderMyCard` becomes `win.card:SetModel(BC.CardModel(BC.MyCard(), {self=true}))`.

**Verify**:
- Tests: `SkillFrac` clamps correctly. `CardModel` maps profs and svcs, and picks `"player"` vs an icon for `self`.
- In game:
  - My card shows your portrait (not black after a reload), professions with bars, and services.
  - Clicking a pill cycles its status and persists across `/reload`.
  - A guildmate running the addon sees the new status.

---

## Phase 4: Card detail on the widget
The detail panel is rebuilt as the same ledger chrome, docked to the right.
- **Card:** a `NewCard` showing the stranger's card. Their portrait ring shows the icon of their first profession or service, with `INV_Letter_15` as the fallback.
- **Recipe list:**
  - icon tabs, one per profession they have;
  - a search box;
  - a scrolling recipe list.
- **States:** "No card", "Requesting…" (with a spinning icon) and "Not opened yet" each get an icon and a line of text.

**Files**: `BC/Card.lua`, `BC/Panel.lua` (the old `BuildDetail`, `RefreshDetail` and `ShowDetail` move into `Card.lua`)

**Key changes**:
- `BuildDetail(win): Frame`: ledger chrome holding `detail.card` (a `NewCard`), `detail.tabs` (an icon tab pool), `detail.search` (`SearchBoxTemplate`, kept) and `detail.list` (a ScrollBox of recipe names with an 18 px extent).
- `BC.RefreshDetail()` and `BC.ShowDetail(who)`: signatures unchanged. Internally they use `CardModel(card, {self=false})`, `BC.RecipeList` and `BC.RequestRecipes`.
- `DetailState(who, prof): "nocard"|"requesting"|"empty"|"list"`: a local helper.

**Verify**:
- `lua tests/run.lua` passes.
- In game:
  - Shift-clicking a row that has a card opens the detail with the right professions and statuses.
  - Clicking a profession tab fetches its recipes, and they scroll.
  - Search filters the list.
  - A player who doesn't run the addon shows "No card".

---

## Phase 5: Subtle motion
- Hovering a row or card brightens its border or gradient.
- New rows flash once.
- The "available" dot breathes.
- When a card arrives while the detail view is open, a sheen sweeps across it once.
- Toggling a pill pops it.

**Files**: `BC/Skin.lua`, `BC/Panel.lua`, `BC/Card.lua`, `BC/Logic.lua`, `BC/tests/run.lua`

**Key changes**:
- Skin:
  - `BC.Breathe(t: Texture): AnimationGroup`: Alpha BOUNCE from 0.6 to 1 over 2.4 s, IN_OUT.
  - `BC.Flash(t: Texture): AnimationGroup`: two steps, 0 to 0.6 to 0.
  - `BC.Pop(f: Frame)`: scale 1.3, then back.
  - `BC.Sheen(f: Frame): {Play()}`: a clipping child with a `Fade` bar or `star4` moved by a Translation.
- Logic: `BC.NewSince(rows, lastAt: number): set<name>`. It is held per session in a local variable in Panel, not in SavedVariables.
- Hooks:
  - `InitRow` plays Flash when the row's name is in NewSince.
  - `Pill:SetStatus("a")` plays Breathe, and other statuses stop it.
  - `onPill` calls Pop.
  - `RefreshDetail` plays Sheen when `card.rev` changes for the shown player.

**Verify**:
- Tests cover `NewSince`.
- In game:
  - A new ad flashes once, and doesn't flash again on the next refresh.
  - The available dot breathes and the busy dot is still.
  - The sheen plays once when a card arrives.
  - The pop is visible.
  - Frame rate is unchanged when the window is closed: the animations are stopped while hidden.

---

## Testing Checkpoints
- **After P1:** ledger window, tabs and position save all work. Rows still have the old layout.
- **After P2:** Seen scrolls with detailed rows, and the 20-row cap is gone. My card is a temporary plain list.
- **After P3:** My card is a real business card with a portrait, skill bars and clickable pills, and status changes still go out to other players.
- **After P4:** card detail uses the same widget, with recipe tabs, search and scrolling.
- **After P5:** motion is in place: hover, flash, breathe, sheen and pop.
- **Every phase:**
  - `lua tests/run.lua` passes.
  - The addon is deployed to `_forever_` and `/reload` raises no errors.
  - The CHANGELOG gets an entry and the `.toc` version is bumped (currently 0.7.4).
