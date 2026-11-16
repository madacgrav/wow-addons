# Design Discussion

Restyle the BusinessCard UI. Code lives on the worktree branch `2026-11-16-profession-business-card`, at `C:/Users/madac/wt/wow-addons/2026-11-16-profession-business-card/BusinessCard/` (shortened to `BC/` below). The data, comms and chat parsing stay as they are. Only the presentation changes.

## Current State
- **All UI is in one file, `BC/Panel.lua` (~261 lines).**
  - The main window is `BasicFrameTemplateWithInset`, 500x574 (`BC/Panel.lua:46-48`).
  - "Seen" and "My card" are switched with two `UIPanelButtonTemplate` buttons (`:62-67`).
  - A filter dropdown sits at the top (`:69-77`).
- **Rows** (`:80-100`) are plain Buttons, 472x22. Each has an 8x8 status square, a 12x12 `INV_Letter_15` icon that shows only when the player has a card, then four text fields (name, categories, zone, age). Hover is a white 0.08 highlight.
- **No scrolling.** The window has 20 rows and the rest are hidden (`:109-125`). The footer reports "N shown / total" (`:124`).
- **My card** reuses the Seen rows. Status shows as coloured text and the skill level sits in the age column (`:146-164`). Clicking a row cycles its status (`:166-170`).
- **Detail** is a second `BasicFrameTemplateWithInset` frame (300x560) docked to the right (`:181-207`). It has a services text line, six profession buttons in a 3x2 grid, a search box and 18 recipe text lines.
- **Data available per row and card:**
  - Seen row: name, a category set from 12 categories, age, zone, ad text, and the card if there is one (`BC/Logic.lua:75-92`).
  - Card: global status, each profession's id, skill and status, each service's key and status, zone, and `at` (`BC/Logic.lua:132-143`).
  - No class, race or level is stored.
- **Position:** the window position is saved to `BC.db.frames.win` (`BC/Panel.lua:53-57`). Size is fixed.
- **Elsewhere in the repo**, the HUD addons already have visual helpers, but each addon has its own copy:
  - `AddGlow`: `WCK/Panel.lua:24-31`
  - `Fade` (gradient): `TB/Panel.lua:51-54`, `WCK/Panel.lua:107-110`
  - Round mask: `WCK/Panel.lua:75-86`
  - `Pop`: `WCK/Panel.lua:100-105`
  - Breathe: `WCK/Panel.lua:94-98`
  - Skin and theme table: `TB/Panel.lua:8-12,43-48`
  - Status bar: `TB/Panel.lua:91-94`

## Desired End State
The window looks like a merchant's ledger, and the card views look like real business cards. All art comes from the game client, so the addon ships no media files.

**Window chrome**
- The frame is built by hand, not from a template. It has a `UI-Background-Rock` backdrop, a `UI-DialogBox-Border` or gold-border edge, and a faint `QuestFrame\QuestBG` parchment layer at about 0.15 alpha (the ForeverDungeonJournal approach).
- The title is set in Morpheus. A close button sits in the corner and the window drags by its header.
- "Seen" and "My card" become real tabs (`PanelTabButtonTemplate`) hanging off the bottom edge, or styled header tabs with a gold underline on the active one.
- Gold rule lines separate the header, list and footer.

**Seen list**
- **Scrolling:** a `WowScrollBoxList` with a `MinimalScrollBar`, so every entry is reachable and nothing is hidden past row 20.
- **Taller rows, about 34 px.** Each row shows, left to right:
  - a status pill: a round dot, green for available and red for busy, hidden if unknown;
  - name, coloured gold if the player runs BusinessCard and white if not;
  - one to three category icons for professions, summon and portal;
  - zone in small grey-blue text;
  - age, right-aligned;
  - an envelope "card" badge when the player has a card.
- **Row styling:** alternating stripes at about 0.03 alpha. On hover the row gets a warm gradient (gold to transparent, like AtlasLoot's `highlightBg`) and the border brightens.
- **Filter:** keep the existing dropdown (it works, see `WUK/Settings.lua:42`), restyled to fit the header.
  - Optional: a strip of category icon buttons in place of the dropdown. Structure decides this.
- **Footer:** keep the "N shown / total seen" count, but render it in parchment style.

**My card**
- A card-shaped panel, about 300x180, framed by a tooltip border on a cream fill. It shows:
  - your portrait, from `SetPortraitTexture(tex, "player")` with the round mask and a ring;
  - name, realm and zone;
  - one line per profession: icon, name, a skill bar out of the max, and a status pill;
  - service icons for summon and portals, each with its own status pill;
  - a large global "Available / Busy" toggle pill.
- Clicking a pill cycles its status, as it does today.
- The footer shows cached recipe counts.

**Card detail**
- The same card widget, filled with the other player's card.
- A portrait isn't available for strangers, so it shows the icon of their first profession or service inside the ring, with `INV_Letter_15` as the fallback.
- The recipe list sits below the card: the profession buttons become icon tabs, then a search box, then a scrolling recipe list.
- Empty and loading states each get an icon and a message: "No card yet", "Requesting…" (with a spinning icon) and "Not opened yet".

**Motion (subtle)**
- Hovering a row or card brightens its border colour.
- Rows that are new since the last render flash in once: alpha goes 0 to 0.6 to 0 on a gold highlight, over about 0.8 s.
- The "available" status dot breathes, using an Alpha BOUNCE from 0.6 to 1 over 2.4 s with IN_OUT smoothing.
- When a card arrives or updates while the detail view is open, a sheen sweeps across it once. The sheen is a `star4` or gradient texture moved by a Translation animation inside a clipping frame (`FDJ/Systems/RPGMode.lua:656-685`).
- Toggling a status pill gives it a small Pop.

**How to verify (in game)**
1. With 30 or more ads logged, every entry can be reached by scrolling, newest first.
2. The icons on each row match its categories, and the status pill matches the card.
3. My card shows your portrait, professions with skill bars, and services. Clicking a pill cycles its status, and other players see the new status.
4. Shift-clicking a Seen row opens the card detail. When the card arrives the sheen plays. Recipes are searchable and scroll.
5. Esc closes the window, its position survives a `/reload`, and `/bcard lock` and `/bcard reset` still work.
6. No Lua errors appear with BugSack or with `/console scriptErrors 1`.
7. `tests/run.lua` still passes.

## Patterns to Follow
**Visual helpers to adapt**
- Theme table: copy the shape of `TB.THEME` (`TB/Panel.lua:8-12`) and the GuildStock palette (`GS/UI.lua:13-21`). Define `BC.THEME` with these colours: ink, parchment, gold, goldBright, muted, available, busy, off.
- Skin helper: `TB.Skin` (`TB/Panel.lua:43-48`) adapted for the rock background and dialog border. Frames inherit `BackdropTemplate` (`TB/Panel.lua:57`).
- Parchment layer: `AddClassicParchment` (`FDJ/Core/Journal.lua:934-943`), using `QuestBG` on BACKGROUND sublevel -2, tinted and at low alpha.
- Gradient: `Fade` (`TB/Panel.lua:51-54`), which is `SetColorTexture(1,1,1,1)` plus `SetGradient`.
- Round portrait: the mask from `WCK/Panel.lua:75-86` (`TempPortraitAlphaMask`, `CLAMPTOBLACKADDITIVE`) and the ring from `TB/Panel.lua:80` (`MiniMap-TrackingBorder`).
- Skill bar: `TB/Panel.lua:91-94` (`UI-StatusBar`, a dark BACKGROUND, coloured fill).
- Animations:
  - Breathe: `WCK/Panel.lua:94-98`
  - Pop: `WCK/Panel.lua:100-105`
  - Two-step flash: `TB/CastBar.lua:31-33`
  - Sheen as a Translation inside a clip: `FDJ/Systems/RPGMode.lua:656-685`

**List, scroll and tabs**
- Scrolling list: `CreateScrollBoxListLinearView` + `SetElementExtent` + `CreateDataProvider` + `ScrollUtil.InitScrollBoxListWithScrollBar` with `WowScrollBoxList`/`MinimalScrollBar` (`BAG/ItemViewCommon/CharacterSelect.lua:53-151`). It is built in code (`BAG/ItemViewCommon/CurrencyPanel.lua:95-112`) so no XML is needed.
- Tabs: `PanelTabButtonTemplate` + `PanelTemplates_TabResize` (`BAG/ItemViewCommon/Components.xml:2-18`).
- Hover gradient: AtlasLoot `highlightBg` (`ALC/Button/Button.lua:267-273`). Border brightening on hover: `FDJ/Systems/RPGMode.lua:1279-1280`.

**Keep from the existing code**
- Position save and restore: `BC/Panel.lua:49-57`.
- Closing with Esc via UISpecialFrames: `BC/Panel.lua:58`.
- The 0.1 s refresh delay: `BC/Panel.lua:128-142`.
- Click semantics: `BC/Panel.lua:9-22`.
- The tooltip content: `BC/Panel.lua:24-42`.
- Recipe name lookup: `BC/Panel.lua:176-179`.

**Testable logic**
- Pure display helpers go in `Logic.lua` so `tests/run.lua` can cover them without a client. Examples: category to icon, status to colour, a row's icon list, and skill as a fraction of max.

**Do NOT follow**
- `BasicFrameTemplateWithInset` and `UIPanelButtonTemplate` for the main surfaces. They are the "boring" look this redesign replaces.
- Fixed `MAX_ROWS` pools that silently hide the overflow (`BC/Panel.lua:3,109-125`; `TB/Panel.lua:2`).
- Copying a helper into a second addon. Keep BusinessCard's helpers inside BusinessCard. A shared repo library is out of scope, so don't build one.
- Shipping `.tga` media (FDJ and GuildStock do). We use only built-in art.
- Calling APIs that might be missing without a guard. Wrap `SetPortraitTexture` and the ScrollBox/`ScrollUtil` lookups in a pcall or nil check, the way FDJ does (`FDJ/Systems/RunLogUI.lua:233`).

## Design Decisions
1. **Theme: merchant ledger.** A rock backdrop, faint parchment, gold border and Morpheus title. This is the user's choice, and it suits a "business card" without needing custom art.
2. **Seen list: rich rows with real scrolling.** This is the user's choice. `WowScrollBoxList` is proven on Forever by Baganator, and it removes the 20-row ceiling.
3. **Motion: subtle.** Hover brightening, a one-time flash for new rows, a breathing "available" dot, a sheen when a card arrives, and a pop when a pill is toggled. This is the user's choice. Nothing loops except the breathing dot.
4. **Cards: a real business-card widget, shared by My card and the detail view.** This is the user's choice. One builder function gets two uses.
5. **No class or race data.** The wire format and the stored card stay unchanged (`BC/Logic.lua:122-143`). Stranger cards use a profession or service icon in the portrait ring.
6. **Built-in art only.** Use `Interface\Icons\*` paths and client textures. Hard-coded profession icon paths are the reliable choice: the repo has never read the icon returned by `GetProfessionInfo`.
7. **File split:**
   - `Skin.lua`: theme, skin, parchment, fade, round mask, animations.
   - `Panel.lua`: the window, tabs and Seen list.
   - `Card.lua`: the card widget, My card, and the detail view.
   - Display helpers go in `Logic.lua`.
   - The `.toc` load order is updated to match.
8. **Window size.** Width about 540, height about 560. The size stays fixed, with no resizing this round. The detail card docks to the right as it does now.

## What We're NOT Doing
- No changes to chat parsing, comms, the wire format, SavedVariables layout, or status semantics.
- No class or race colours, and no fetching portraits for strangers.
- No custom media files and no LibSharedMedia/Ace libraries.
- No resizable or scalable window and no minimap button.
- No toasts or popups outside the window.
- No shared UI library across repo addons.
- No refactoring of the other addons' copied helpers.
- No settings panel for the theme.

## Open Risks
- **Unverified atlases.** No atlas has been probed on Interface 16001. The design uses texture paths, not atlases, but any atlas added later must be guarded with `C_Texture.GetAtlasInfo`.
- **ScrollBox and the tests.** `ScrollUtil` and `CreateDataProvider` exist on this client (Baganator uses them). The headless `tests/run.lua` only loads logic, so the UI stays out of the tests.
- **Portrait timing.** `SetPortraitTexture("player")` can paint black if the portrait hasn't loaded (`FDJ/Systems/PortraitPool.lua:2-7`). Re-apply it on `UNIT_PORTRAIT_UPDATE` and on show.
- **Font.** If `Fonts\MORPHEUS.ttf` is missing or renders oddly on this client, fall back to `GameFontNormalLarge`.
- **Row flash.** It needs a "seen since last render" marker. Keep it per session only, not in SavedVariables.
- **Sheen.** The art may look cheap without FDJ's custom `ChainSheen`. Fallback: a gradient bar (`Fade`) swept by the Translation, or no sheen.
- **Testing.** This is all visual and must be checked in game. Deploy to `_forever_\Interface\AddOns` after each phase.
