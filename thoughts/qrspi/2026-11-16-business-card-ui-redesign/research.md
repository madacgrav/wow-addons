# Research Findings

Path roots used below:
- `BC/` = `C:/Users/madac/wt/wow-addons/2026-11-16-profession-business-card/BusinessCard/`
- Repo addons: `TB/` TackleBox, `WCK/` WarlockCombatKit, `WUK/` WarlockUtilityKit, `PP/` ProfessionPlanner, all under `D:/Source/wow-addons/`
- `AO/` = `C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/` (third-party). `FDJ/` = `AO/ForeverDungeonJournal/`, `GS/` = `AO/GuildStock/`, `ALC/` = `AO/AtlasLootClassic/`, `BAG/` = `AO/Baganator/`

## Q1: How is the BusinessCard window built, and what data do rows and cards have?

### Findings
**Main window** (`BC/Panel.lua:46-107`)
- `BusinessCardWin` uses `BasicFrameTemplateWithInset`, DIALOG strata, 500x574 (`:47-48`). Constants: `MAX_ROWS=20`, `ROW_H=24`, `TOP=64` (`:3`).
- The title is a `GameFontHighlight` FontString reading "Business Cards" (`:59-60`). The window is in UISpecialFrames, so Esc closes it (`:58`). OnShow calls `BC.RefreshPanel` (`:105`).
- The view switch is two `UIPanelButtonTemplate` buttons, "Seen" and "My card", each 80x22 at TOPLEFT 12,-30 (`:62-67`). `SetView` writes `BC.db.view` (`:44`).
- The filter is a `DropdownButton` + `WowStyle1DropdownTemplate`, 150 wide (`:69-77`). It has an "All" radio plus one radio per entry in `BC.CATS` and writes `BC.db.filter`.
- Rows: 20 plain Buttons (no template), 472x22, anchored at y -64-(i-1)*24 (`:80-82`). Each row has:
  - `status`: an 8x8 texture (`:84-85`)
  - `icon`: a 12x12 `INV_Letter_15` texture, shown when the player has a card (`:86-87`)
  - `name`: `GameFontHighlightSmall`, 130 wide (`:88-89`)
  - `cats`: `GameFontDisableSmall`, 170 wide (`:90-91`)
  - `zone`: 96 wide, colour 0.6,0.8,1 (`:92-94`)
  - `age` (`:95-96`)
  - a HIGHLIGHT layer that is white at alpha 0.08 (`:97`)
- There is no scrolling. Rows past 20 are not shown (`:109-125`). A footer shows "N shown / total seen" (`:103-104`, `:124`).

**Views**
- `BC.RefreshPanel` (`:128-142`) waits 0.1 s with `C_Timer.After` before redrawing. It picks between `RenderMyCard` and `RenderSeen(BC.SeenRows(...))`, then calls `BC.RefreshDetail` (`:140`).
- `RenderSeen` (`:109-125`):
  - The status badge comes from `BC.CardStatus(card, filter)`: green 0.2,0.9,0.2 for "a" and red 0.9,0.2,0.2 for "b" (`:118-120`).
  - The icon shows when `v.card ~= nil` (`:121`).
- `RenderMyCard` (`:146-164`):
  - It reuses the same row widgets for these rows: "Overall" (key "g"), one per profession (`p<id>`, with skill), and one per service.
  - In each row, `cats` holds `ST_LABEL[st]` and `age` holds the skill (`:153-158`).
  - The footer lists cached recipe counts (`:160-163`).
  - Clicking a row cycles its status (`:166-170`): "g" flips between a and b; the other rows go a, b, o, a.
- Clicks on Seen rows (`:9-22`):
  - Plain click: whisper.
  - Right-click: remove the row.
  - Shift-click: `BC.Ask` + `ShowDetail`.
  - Ctrl-click: `/who`.

**Tooltip** (`:24-42`): `GameTooltip` ANCHOR_RIGHT. It shows the name and categories, then "Last seen in <zone>" and the ad text with its age. If a card exists it adds a "Card:" header, one line per profession (skill + status) and one per service, then a click hint. Colours: title 1,0.82,0; card header 0.9,0.7,0.3.

**Detail frame** (`:172-249`)
- `BusinessCardDetail` uses `BasicFrameTemplateWithInset`, 300x560, anchored to the window's TOPRIGHT +2 (`:182-183`).
- Contents:
  - a services FontString (`:186`)
  - six 88x22 `UIPanelButtonTemplate` profession buttons in a 3x2 grid (`:189-198`)
  - a `SearchBoxTemplate` EditBox (`:199-201`)
  - 18 recipe FontStrings on a 21 px step (`:203-207`)
- Recipe names come from `C_TradeSkillUI.GetRecipeInfo`, then `C_Spell.GetSpellName`, then "Recipe #id" (`:176-179`).
- Empty and loading states are text only: "No card yet…", "Requesting…" and "They haven't opened that profession yet." (`:211-241`).

**Data**
- SavedVariables (`BC/Core.lua:18-27`):
  - `BusinessCardDB` holds locked, frames, seen, cards, maxAgeDays=7, view and filter.
  - `BusinessCardCharDB` holds status={g="a"}, recipes and rev.
- Seen entry: `seen[realm][name] = {cats={cat=ts}, text≤120, at, req, dest, zone, whoAt}` (`BC/Logic.lua:41-48`).
- Seen rows from `BC.SeenRows` (`BC/Logic.lua:75-92`): `{name, cats, at, age (now/Nm/Nh/Nd, :62-66), text, dest, card, zone}`, newest first.
- Card: `cards[realm][name] = {rev, g, profs={{id,skill,st}}, svcs={{key,st}}, zone, at}` (`BC/Logic.lua:132-143`). On the wire it is `1|C|rev|g|profs|svcs|zone` (`:122-128`).
- Categories (12) are in `BC/Data.lua:20-24`: enchanting, tailoring, leatherworking, alchemy, blacksmithing, engineering, jewelcrafting, cooking, firstaid, summon, portal, other. Services S, T-/P- ORG/UC/TB/SW/IF/DARN are at `BC/Data.lua:4-12`.
- Status values are "a", "b" and "o". `CardStatus` ignores "o", and a global "b" forces busy (`BC/Logic.lua:166-177`).
- No class, race, level or guild field is stored on seen rows or cards.
- Colours and icons in use: `ST_LABEL` colour codes green, red and grey (`BC/Panel.lua:5`), the print prefix `|cffe0b050` (`BC/Core.lua:7`), and `INV_Letter_15` as the only icon.
- Position: OnDragStop saves `{point, relPoint, x, y}` into `BC.db.frames.win` (`BC/Panel.lua:53-57`). Size is fixed. `/bcard lock` and `/bcard reset` exist (`BC/Core.lua:249-250`).

## Q2: How do the repo addons use textures, icons, backdrops, fills, status bars and animations?

### Findings
**Backdrops**
- TackleBox has a skin helper, `TB.Skin(f, edge)` (`TB/Panel.lua:43-48`): tooltip bg and border, edgeSize 16, inset 4, colours from `TB.THEME`.
- WUK's summon frame uses a bare WHITE8x8 at alpha 0.6 (`WUK/Summon.lua:67-69`).
- WCK has no box. Its panel is textures only (`WCK/Panel.lua:3`).

**Colour constants**
- `TB.THEME` defines sea, shallows, rope, sand, foam and line (`TB/Panel.lua:8-12`).
- WCK has `SHADOW` and `FEL` (`WCK/Panel.lua:6`). The rim purple 0.58,0.51,0.79 and glow purple 0.7,0.3,1 are duplicated between WCK and WUK (`WCK/Panel.lua:27,119`; `WUK/UI.lua:99,119`).
- PP uses raw literals.

**Gradients and fills**
- There are two copies of a `Fade` helper. Each calls `SetColorTexture(1,1,1,1)` and then `SetGradient(dir, CreateColor(...), CreateColor(...))` (`TB/Panel.lua:51-54`; `WCK/Panel.lua:107-110`).
- The cast-bar fill uses a horizontal gradient (`TB/CastBar.lua:13`).
- Row stripe: alpha 0.03 on alternating rows (`TB/Panel.lua:203`).
- Tab underline (`TB/Panel.lua:152`) and rule line (`TB/Panel.lua:107`).

**Round mask** (recurring)
- The pattern is `CreateMaskTexture` + `Interface\\CharacterFrame\\TempPortraitAlphaMask` with `CLAMPTOBLACKADDITIVE`.
- Used in `WCK/Panel.lua:75-86` (`Round`, `Disc`), `WUK/UI.lua:53-59`, `TB/Panel.lua:77-78` and `TB/CastBar.lua:17-18`.
- TB draws a 106 px portrait ring with `MiniMap-TrackingBorder` (`TB/Panel.lua:80`).

**Status bars**
- `CreateFrame("StatusBar")` + `Interface\\TargetingFrame\\UI-StatusBar` + `SetStatusBarColor` (`TB/CastBar.lua:9-11`, `TB/Panel.lua:91-94`, `:124-127`).
- Row bars turn green when done (`TB/Panel.lua:208`).

**Glows**
- `AddGlow(b)` is duplicated in `WCK/Panel.lua:24-31` and `WUK/UI.lua:96-101`. It is `UI-ActionButton-Border`, ADD blend, 1.8x the frame size, with a BOUNCE alpha. WCK adds `SetAlert(b,on)` (`:33-38`).
- TB has a "ripple" with a BOUNCE alpha from 0.1 to 0.6 over 1.2 s (`TB/Actions.lua:23-25`).

**AnimationGroups**
- Alpha BOUNCE:
  - glow, 0.15 to 1 over 0.6 s
  - Breathe, 0.08 to 0.3 over 2.4 s with IN_OUT smoothing (`WCK/Panel.lua:94-98`)
- Two-step alpha flash (`TB/CastBar.lua:31-33`).
- Rotation REPEAT `Spin` (`WCK/Panel.lua:88-92`; `WUK/UI.lua:123-124`, 90 s).
- Scale "Pop": 1.3x over 0.15 s, then back over 0.2 s (`WCK/Panel.lua:100-105`; `WUK/UI.lua:135-137`).
- No Translation animations in repo code.

**Highlights**: `ButtonHilight-Square` ADD (`TB/Actions.lua:18`, `PP/Panel.lua:53`, `WUK/UI.lua:141`). Rows use `CreateTexture(nil,"HIGHLIGHT")` (`TB/Panel.lua:129,153`; `PP/Panel.lua:25`).

**Shared conventions**
- Shift-drag move with a lock and combat guard (`WCK/Panel.lua:8-21`; `TB/Panel.lua:29-40`; `WUK/UI.lua:14-25`).
- Helpers are copied between addons, not shared. No common library file exists.

## Q3: How do ForeverDungeonJournal and GuildStock build their visual presentation?

### Findings
**FDJ media**
- Paths are addon-relative with no extension, e.g. `Interface\\AddOns\\ForeverDungeonJournal\\Media\\HallOfThanesMap` (`FDJ/Core/Journal.lua:175`). Some include `.tga` (`:4706`, `:4721`).
- Canvases are 1024 or 2048 wide, with the used area cropped by TexCoord (`:175-293`, `:519`).

**FDJ portraits**
- There are no 3D model frames. Journal.lua says `PlayerModel` is never needed (`:911`).
- Pre-baked `Media\\Portraits\\<displayID>.tga` files are shot at 64x64 (`FDJ/Systems/BakedPortraits.lua:1-10,40,48,59`).
- The live fallback is `SetPortraitTextureFromCreatureDisplayID` (`FDJ/Systems/PortraitPool.lua:66`).
  - It renders on an off-screen staging frame (`:18-27`) because unloaded portraits paint as a black square (`:2-7`).
  - It waits 3 s before placing the texture (`:11,73`).
- `SetPortraitTexture(tex,"player")` is called through pcall (`FDJ/Systems/RunLogUI.lua:233`).

**FDJ boss row** (`FDJ/Core/Journal.lua:4686-4724`)
- 315x55 button.
- 44x44 portrait with TexCoord .05-.95 (`:4698-4701`).
- `rareBorder`: a 64x64 OVERLAY dragon frame (`:4703-4707`).
- `levelBadge`: a 28x28 OVERLAY sublevel 6 medallion with text over it (`:4718-4724`).

**FDJ fonts**
- 18 named font families via `CreateFontFamily`, with a `CreateFont` fallback (`FDJ/Core/Fonts.lua:36-216`).
- Files used: `FRIZQT__.TTF`, `MORPHEUS.ttf` (titles, 18) and `ARIALN.TTF`.
- `OwnFonts` swaps template buttons over to these fonts (`:257-270`).

**FDJ panels**
- Main frame (`FDJ/Core/Journal.lua:12441-12464`): 850x590, backdrop `Interface\\FrameGeneral\\UI-Background-Rock` + `UI-DialogBox-Border`, edgeSize 24.
- `AddClassicParchment` (`:934-943`): `Interface\\QuestFrame\\QuestBG` on BACKGROUND sublevel -2, tinted 1,.96,.84 at alpha .13-.18. It is applied to every sub-panel (`:12639,12849,12889,13022,13059`).
- Rows: a WHITE8X8 bg with a tooltip border, edgeSize 10 (`:4690,11013`).
- RPGMode `OptionCard` (`FDJ/Systems/RPGMode.lua:1234-1281`): 250x230, dark bg .09,.07,.05, border .55,.43,.24, a 52x52 icon at the top, a title and a description.
- Unlock toast (`FDJ/Systems/RPGMode.lua:603-709`): `UI-DialogBox-Gold-Border`, a gold glow, a cropped `Media\\Parchment` page and a sketch layer.

**FDJ animation**
- ChainSheen (`FDJ/Core/Journal.lua:4832-4861`): an ADD beam tinted 1,.86,.55 that sweeps for 1.5 s, once per quest per visit.
- 9-slice aura glow (`:4866-4886`, `:4947-4985`): driven by an OnUpdate tick, with breath from .30 to .55 over 2.6 s and a 0.35 s fade-in.
- Fallback when the art is missing: a BOUNCE alpha pulse (`:4998-5008`).
- Map marker pulse: alpha follows a sine curve in OnUpdate (`:1346-1363`).
- Toast:
  - Alpha 0 to 1 + Scale .6 to 1 over 0.25 s.
  - A `star4` shine is moved 560 px by a Translation inside a clipping frame (`FDJ/Systems/RPGMode.lua:656-685`).
  - It pauses while hovered (`:693-697`).

**FDJ hover**
- The backdrop colour swaps to `theme.rowSelected` (`FDJ/Core/Journal.lua:4493-4511`).
- Cards brighten their border to 1,.82,.30 (`FDJ/Systems/RPGMode.lua:1279-1280`) or 1,.76,.22 plus a shade (`FDJ/Core/Journal.lua:9783-9785`).
- `UI-QuestTitleHighlight` ADD (`FDJ/Systems/RPGMode.lua:1579`).

**FDJ class data**
- `RAID_CLASS_COLORS[...]` (`FDJ/Systems/RunLogUI.lua:1122`) and `CLASS_ICON_TCOORDS[classFile]` (`FDJ/Systems/LootFilter.lua:968`).

**GuildStock**
- Palette: gold, cream, muted, window, panel, header, selected and accent (`GS/UI.lua:13-21`). The shared backdrop is WHITE8X8 with edgeSize 1 (`:22`).
- Window: 1180x650, WHITE8X8 + tooltip border edge 16, gold border (`GS/UI.lua:876-892`).
- Header: a 49 px logo `Assets\\Icon` and a size-28 cream title (`GS/UI.lua:893-895`). The four tabs are 45 high on a 166 px step (`:900`).
- Fonts: `Label()` uses `GameFontNormal` for headings and `ChatFontNormal` otherwise, then `SetFontHeight` (`GS/UI.lua:53-66`).
- Section headings: a 1 px gold rule (`GS/UI.lua:430-446`). `HighlightSection` widens it to 2 px in the accent colour with a 0.5 s LEFT-origin Scale animation (`:448-464`).
- Hover: a WHITE8X8 highlight tinted 1,.8,.4 at alpha 0.025 (`GS/UI.lua:312-313`). Selected uses `colors.selected` (`:350`). Rows are separated by a 1 px `RowSeparator` (`:307-310`).
- Race icon per row (`GS/UI.lua:77-79`). The `ProfessionBlue` status-bar texture (`:1018`).
- No portraits, models or sheen.

## Q4: How do AtlasLootClassic and Baganator build list and grid rows, icon buttons, navigation, pooling and scrolling?

### Findings
**AtlasLootClassic**
- Pools are hand-rolled caches, with no `CreateFramePool` (`ALC/GUI/Template_Select.lua:176-190`; `ALC/GUI/ModelFrame.lua:23-42`). `ALC/GUI/ItemFrame.lua:46-57` pre-creates 30 buttons.
- Select rows (`ALC/GUI/Template_Select.lua:226-307`):
  - A plain CheckButton with a `GameFontNormal` label.
  - A right-side "coin" texture, desaturated unless the row is selected.
  - `UI-QuestTitleHighlight` ADD for both the highlight and the checked texture.
- Item grid: 2 columns of 15, with header-line background textures. Filtered items drop to alpha 0.33 (`ALC/GUI/ItemFrame.lua:21,50-120`).
- Icon button (`ALC/Button/Button.lua:244-383`):
  - 270x28, with a 26x26 icon.
  - A `highlightBg` horizontal gradient from white .45 to 0 (`:267-273`).
  - A quality border via `SetAtlas(LOOT_BORDER_BY_QUALITY_AL[q])` (`:202-214`, `:301-308`).
  - Status textures: ReadyCheck-Ready for completed, and a `VignetteKill` atlas for favourite (`:310-330`).
  - A count FontString at the icon's BOTTOMRIGHT (`:354-360`) and a secondary button (`:363-383`).
- Navigation is dropdowns and select lists, with no tabs (`ALC/GUI/Template_DropDown.lua:240-374`). In the class popup, rows have a class-coloured backdrop and unselected rows sit at alpha 0.5 (`ALC/GUI/GUI.lua:390-466`).
- The selected creature button is shown by `Disable()` (`ALC/GUI/GUI.xml:8-33`; `ALC/GUI/ModelFrame.lua:44-54`).
- Scrolling is manual: a `ScrollFrame` + `UIPanelScrollBarTemplate` slider windowing a fixed set of rows (`ALC/GUI/Template_Select.lua:195-216,309-347,393-400,457-484`; `ALC/Addons/Favourites_GUI.lua:535-632,800-829`).

**Baganator**
- Pools:
  - `CreateFramePool` with the Retail templates "on Retail or Forever", and `CreateObjectPool` on Classic (`BAG/ItemViewCommon/Pools.lua:6-34`).
  - Tab pool `BaganatorRetailTabButtonTemplate` (`BAG/ItemViewCommon/Pools.lua:44-47`). Side tabs use `CreateObjectPool` (`:55-60`).
  - Category label and divider pools are reused through `ReleaseAll`/`Acquire` (`BAG/CategoryViews/BagLayout.lua:110-175,397-456`).
- Item buttons inherit Blizzard templates (`ContainerFrameItemButtonTemplate`, `ItemButtonTemplate`) and use `SetItemButtonQuality`/`SetItemButtonCount` (`BAG/ItemViewCommon/ItemButton.xml:2-48`; `BAG/ItemViewCommon/ItemButton.lua:481-482,650-693`).
  - The highlight overlay is the atlas `bags-glow-heirloom` (`BAG/ItemViewCommon/ItemButton.lua:362-371`).
  - A looping Alpha fade plays on search matches (`BAG/SingleViews/Pools.lua:40-57`).
- Top tabs: on Retail/Forever the tab template inherits `PanelTabButtonTemplate`, with `PanelTemplates_TabResize` and `PanelTemplates_DeselectTab` (`BAG/ItemViewCommon/Components.xml:2-18`).
- Side tabs (`BAG/ItemViewCommon/Components.xml:20-46`): 32x32 at scale 0.8.
  - Background: `SpellBook-SkillLineTab`.
  - Selected: `CheckButtonHilight` ADD.
  - Highlight: `ButtonHilight-Square`.
- Collapsible section header: `GameFontNormalMed2` with a `bag-arrow` atlas that rotates (`BAG/CategoryViews/Components.lua:100-150`). Divider template at `BAG/ItemViewCommon/Layouts.xml:99-113`.
- Scrolling:
  - `WowScrollBox` + `MinimalScrollBar` + `ScrollUtil.InitScrollBoxWithScrollBar` (`BAG/ItemViewCommon/Utilities.lua:279-300`).
  - A true list: `CreateScrollBoxListLinearView()`, `SetElementExtent(20)`, `CreateDataProvider`, `WowScrollBoxList` (`BAG/ItemViewCommon/CharacterSelect.lua:53-151`; `BAG/ItemViewCommon/CharacterSelect.xml:19,25`).
  - List rows: `SetHighlightAtlas("search-highlight")`, a class-coloured name, a race icon and the realm right-aligned. The selected row is disabled and gets an arrow glyph (`BAG/ItemViewCommon/CharacterSelect.lua:41-85`).
  - `BAG/ItemViewCommon/CurrencyPanel.lua:95-112` also builds a `WowScrollBoxList` in code.

## Q5: What built-in Blizzard visual resources do addons use without shipping media?

### Findings
**Repo addons**
- No `SetAtlas`, `C_Texture`, class-colour or portrait API calls anywhere.
- Icon paths, all `Interface\\Icons\\…`:
  - `WUK/UI.lua:6-8,121`
  - `WCK/Panel.lua:56,124,129,175`
  - `TB/Panel.lua:75,102,226-261,294`
  - `PP/Panel.lua:52`
- Dynamic icons:
  - `C_Spell.GetSpellTexture` (`WUK/Prep.lua:14,34`; `WCK/Panel.lua:196,215`)
  - `C_Item.GetItemIconByID` (`TB/Panel.lua:246`)
  - fileID fallback `134400` (`TB/Panel.lua:197`; `PP/Panel.lua:83`)
- `GetProfessionInfo` is called, but its icon return value is not read (`TB/Core.lua:32,175`).
- Frame art in use:
  - `UI-ActionButton-Border`, `ButtonHilight-Square`, `UI-Quickslot2`
  - `MiniMap-TrackingBorder`, `UI-Minimap-ZoomButton-Highlight`
  - `UI-Tooltip-Background`/`-Border`, `WHITE8x8`, `UI-StatusBar`
  - `Cooldown\\star4`, `FullScreenTextures\\LowHealth`, `QuestFrame\\UI-QuestTitleHighlight`
  - inline raid marks `|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_N:0|t` (`WUK/Board.lua:8`)
  - (file:line refs under Q2)

**Third-party addons on this client**
- Atlases:
  - `Professions-skillbar-bg`, `-frame`, `-mask` and `Skillbar_Fill_Flipbook_<kit>`, with a flare checked through `AtlasInfo` (`FDJ/Systems/RPGMode.lua:913-947`)
  - `Dungeon` (`FDJ/Systems/QuestText.lua:2241`)
  - three-part `<p>Left/Middle/Right` (`FDJ/Systems/SettingsPanel.lua:1306-1308`)
  - `LOOT_BORDER_BY_QUALITY_AL` and `VignetteKill` (ALC)
  - `bags-glow-heirloom`, `bag-arrow`, `search-highlight` (BAG)
  - also `AO/GearQuestForever/Pins.lua:84` and `AO/GearQuestForever/Gamepad.lua:1375`
- Class data: `RAID_CLASS_COLORS` (`FDJ/Systems/RunLogUI.lua:1122`; `AO/GearQuestForever/Log.lua:10729`) and `CLASS_ICON_TCOORDS` (`FDJ/Systems/LootFilter.lua:968`).
- Portraits: `SetPortraitTexture` and `SetPortraitTextureFromCreatureDisplayID`, both called through pcall (`FDJ/Systems/RunLogUI.lua:233,1073`; `FDJ/Systems/MapMarkers.lua:3863-3869`; `FDJ/Systems/PortraitPool.lua:66`).
- Backgrounds:
  - `Interface\\FrameGeneral\\UI-Background-Rock`, `UI-DialogBox-Border`, `UI-DialogBox-Gold-Border`, `QuestFrame\\QuestBG` (FDJ, see Q3)
  - `SpellBook-SkillLineTab`, `CheckButtonHilight` (BAG, see Q4)
  - `UI-Common-MouseHilight` (`ALC/GUI/GUI.lua:504-565`; `FDJ/Core/Journal.lua:11583`)

## Q6: What templates and animation types are confirmed working, and how are media, sizing and position handled?

### Findings
**Templates in repo code**
- `BasicFrameTemplateWithInset`: `WUK/Settings.lua:19`, `WUK/Board.lua:97`, `WCK/Settings.lua:124`, `PP/Panel.lua:6`, `BC/Panel.lua:47,182`
- `BackdropTemplate`: `TB/CastBar.lua:7`, `TB/Panel.lua:57`, `TB/Actions.lua:39`, `WUK/Summon.lua:67`
- `DropdownButton` + `WowStyle1DropdownTemplate` with `SetupMenu`/`CreateRadio`: `WUK/Settings.lua:42`, `WUK/Board.lua:90`, `WCK/Settings.lua:33,41,100`
- `UIPanelButtonTemplate`: `WUK/Settings.lua:52`, `WCK/Settings.lua:57`
- `InputBoxTemplate`: `WCK/Settings.lua:51`
- `SearchBoxTemplate`: `BC/Panel.lua:199` only

**Templates not in repo code but used by third-party addons on this client**
- `WowScrollBox`/`WowScrollBoxList` + `MinimalScrollBar` + `ScrollUtil`, `PanelTabButtonTemplate`, `CreateFramePool` (BAG, see Q4)
- `UIPanelScrollBarTemplate` slider (ALC)
- Not found in repo code: `PortraitFrameTemplate`, `ButtonFrameTemplate`, `TabButtonTemplate`
- The repo has comments about adding a ScrollBox (`TB/Panel.lua:2` with `MAX_ROWS=30`, `WCK/Settings.lua:17`). The previous business-card research notes that no repo addon scrolls (`thoughts/qrspi/2026-11-16-profession-business-card/research.md:231`).
- The thoughts notes record no template as broken. The only missing API noted is `InChatMessagingLockdown` (`thoughts/qrspi/warlock-utility-kit-v2/probe-results.md:5`).

**Animation types seen working on this client**
- Repo: Alpha (BOUNCE and one-shot), Rotation (REPEAT), Scale. See Q2.
- Third-party adds Translation inside a clipping frame (`FDJ/Systems/RPGMode.lua:656-685`), a LEFT-origin Scale (`GS/UI.lua:448-464`), and OnUpdate sine pulses (`FDJ/Core/Journal.lua:1346-1363`, `:4978`).

**Media, sizing and position**
- The repo ships no media: no `Interface\\AddOns\\<Name>\\` paths and no .tga/.blp/.ttf files.
- Third-party media path formats: `Interface\\AddOns\\GuildStock\\Assets\\Icon` (`GS/UI.lua:893`) and FDJ `Media\\*` with or without `.tga` (Q3).
- No `SetScale`, `SetResizable`, `SetResizeBounds` or `SetUserPlaced` in repo code. Windows use a fixed `SetSize` (`WUK/Settings.lua:20`, `WCK/Settings.lua:125`, `BC/Panel.lua:47-48`).
- Position: `GetPoint()` is saved as `{p, rp, x, y}` into `db.frames[key]` and restored with a CENTER default (`WUK/UI.lua:20-25`, `WCK/Panel.lua:15-20`, `TB/Panel.lua:22-37`, `BC/Panel.lua:49-57`). Settings and Board windows are re-centred each time they open (`WUK/Settings.lua:20-22`, `WUK/Board.lua:98-100`). SavedVariables are declared in each .toc (`WUK/WarlockUtilityKit.toc:6-7`).

## Cross-Cutting Observations
- **Two visual styles:**
  - The repo's HUD addons (TB, WCK, WUK) use masked round icons, additive glows, gradients, and Pop, Spin and Breathe animations.
  - Their windows (Settings, Board, BusinessCard, PP) use stock `BasicFrameTemplateWithInset` + `UIPanelButtonTemplate` with text-only rows.
- **Third-party windows build their own chrome:**
  - a palette table: `GS/UI.lua:13-21`, FDJ `theme.*`, `TB.THEME`
  - backdrops from WHITE8X8 or tooltip borders
  - hover that changes the backdrop or border colour
  - parchment or rock backgrounds at low alpha
- **Helpers are copied, not shared.** `AddGlow`, `Fade`, `Disc`/`Round`, `Pop` and the drag/save code each exist in two or three repo addons.
- **Icons:** every repo icon is a hard-coded `Interface\\Icons` path or a spell/item texture lookup. The profession icon returned by `GetProfessionInfo` is not used anywhere in the repo.
- **pcall guards:** FDJ wraps newer or less certain APIs (`SetPortraitTexture*`, `AtlasInfo`) in pcall or existence checks before using them.

## Open Areas
- No `.tga`/`.blp` header dimensions were read for third-party media (FDJ `Media/`, GS `Assets/`).
- Whether specific Retail atlases exist on Interface 16001 was not checked in-game. They are only known to be referenced by FDJ, ALC and BAG, which run on this client. A probe via `C_Texture.GetAtlasInfo` is not recorded anywhere.
- The Baganator `Layouts.lua` and tab wiring were read only partially.
- Whether `SetPortraitTexture` works for non-group players (by name, not a unit token) on this client is not documented in any source read.
- Auctionator's `ResultsListing` (ScrollBox-based, `AO/Auctionator/Source/Components/ResultsListing/`) appeared in the grep but was not analysed.
