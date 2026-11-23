# Research Findings

All paths relative to `D:\Source\wow-addons` unless noted. All five TOCs declare `## Interface: 16001`.

## Q1: How is the WCK settings window built end to end?

### Findings
- Load order `WarlockCombatKit.toc:9-15`: Data, Logic, Core, Actions, Panel, Rotation, Settings (Settings last). SavedVariables `WarlockCombatKitDB` (:6), `WarlockCombatKitCharDB` (:7); runtime aliases `WCK.db` / `WCK.char` (`Core.lua:27-33`).
- **Frame** `Build()` `Settings.lua:169-204`: `CreateFrame("Frame","WCKSettings",UIParent,"BasicFrameTemplateWithInset")` (:170), initial 380x560, CENTER, strata DIALOG (:171), LeftButton drag (:172-173), no position persistence, `tinsert(UISpecialFrames,"WCKSettings")` (:174). Title FontString `GameFontHighlight` "Warlock Combat Kit" at TOP 0,-5 (:175-176). Lazily built on first `WCK.ToggleSettings()` (:206-209); hidden at end of Build (:203).
- **Height**: `win:SetHeight(-y + 50)` after sections (:195). Computed from section returns: rotation ends -528, slots -726, alt clicks -1090, so height = **1140px**. No scroll frame; content is one tall column.
- **Sync model**: `win.syncs` list (:178) of objects with `:Sync()`; `win:Sync()` iterates (:201); `OnShow = win.Sync` (:202). Sections push sync entries (:87, :114, :157).
- **Section protocol**: `WCK.settingsSections` (:4) — each `function(win, y) -> next y`, called in order starting `y = -212` (:193-194). This is a running y cursor at section granularity; inside sections, offsets are hardcoded.
- **Top checkboxes** via `WCK.Check(parent,label,y,get,onClick)` (:6-14): `UICheckButtonTemplate` at TOPLEFT 16,y, `GameFontHighlight` label right of box; OnClick writes then re-reads `get()`. Hardcoded y in 28px steps (:179-191):
  - "Show panel" -36 `db.shown` (+Refresh)
  - "Show rotation buttons" -64 `db.showBar` (+Refresh, combat print)
  - "Lock panel (no Shift+drag)" -92 `db.locked`
  - "Mark CC'd mobs on nameplates (open world)" -120 `db.plateMarker`
  - "Proc alerts (Nightfall)" -148 `db.procAlerts`
  - "Proc sound" -176 `db.procSound`
  - No group header above these six.
- **Section 1 — Rotation** (:29-89). Header `GameFontNormal` "Rotation (first matching rule shows in the panel core)" at 20,y. `MAX_RULES = 10` (:18). Pooled rows 348x24 at `14, y-18-(i-1)*26` (:35): number label `GameFontDisableSmall` (:36); spell `DropdownButton`/`WowStyle1DropdownTemplate` w120 (:37-42); cond dropdown w110 (:43-52, "usable" only if `WCK.USABLE_OK`); numeric `InputBoxTemplate` 26x20 maxLetters 3 (:53-57); three 20x20 `UIPanelButtonTemplate` buttons labelled "x", "v", "^" anchored RIGHT at 0/-22/-44 (:58-64). Writes `WCK.char.rules[i].spell/cond/n`. `Changed()` = `win:Sync(); WCK.Refresh()` (:33); N box calls only `WCK.Refresh()` (:55). "Add rule" 100x22 inserts `{spell="Shadow Bolt",cond="ready"}` (:68-70); "Defaults" 100x22 copies `DATA.defaultRules` (:71-73). `SyncRules` (:75-86) shows/hides rows, `GenerateMenu()`, shows N box only for `notRecent`, disables Add at max. Returns `by - 34` (:88).
- **Section 2 — Mouseover cast slots** (:92-121). Header + note `GameFontDisableSmall` "Bind keys: Esc > Options > Keybindings > AddOns > Warlock Combat Kit" (:96). `WCK.SLOTS` (=6, `Logic.lua:207`) rows at `14, y-34-(i-1)*26` (:99): label "Slot i [key|unbound]" from `GetBindingKey("CLICK WCKCast"..i..":LeftButton")` (:116), spell dropdown w170 at x120 with "(none)" + SpellMenu (:102-111). Writes `WCK.char.slots[i]` (:105), combat print (:106).
- **Section 3 — Alt clicks** (:124-167). Header "Alt clicks"; column captions "Right-click"/"Shift+click" at hardcoded x 148/262 (:127-129). `WCK.BAR_MAX` (=13, `Logic.lua:177`) rows at `14, y-18-(i-1)*26` (:148): spell label w110, right dropdown w110 at x120, shift dropdown w110 (:149-154). Rows bound to `WCK.BarSpells(...)` output in sync (:157-165). `Set` prunes empty alt entries (:131-137).
- **SpellMenu** (:20-27): one submenu per `WCK.spellTabs` entry (`root:CreateButton(tab.name)`), `CreateRadio` per spell. Tabs built by `WCK.ScanSpellbook` (`Core.lua:159-176`) via `WCK.BuildSpellTabs` (`Logic.lua:153-164`).
- **Bottom**: "Reset positions" 130x22 at BOTTOMLEFT 16,16 wipes `db.frames`, prints reload message (:197-199).
- **Fonts used**: `GameFontHighlight`, `GameFontNormal`, `GameFontDisableSmall`, `GameFontHighlightSmall`. No backdrop/theme helper; no tooltips on any settings control.
- **Minimap button** (:211-248): created in `WCK.inits` (post-login, warlocks only). 31x31 plain Button, DeathCoil icon, TrackingBorder; angle `db.minimapAngle`; drag via OnUpdate atan2; left = ToggleSettings, right = toggle `db.shown`; tooltip "Click: settings   Right-click: panel   Drag: move".

## Q2: What WCK exposes via window vs other entry points; defaults/validation

### Findings
- **Slash** `/wck` `Core.lua:420-430`: rejects non-warlocks (:422); subcommands `probe` (`WCK.Probe`, :318-418, writes `db.lastProbe`), `lock`, `reset` (wipes `db.frames`), `config` (ToggleSettings), `show`/`hide`; usage string at :429.
- **Other entry points**: rotation core button right-click calls `WCK.ToggleSettings()` (`Rotation.lua:32`, tooltip "Right-click: options" :27); minimap left-click; key bindings in `Bindings.xml` (`CLICK WCKCast<i>:LeftButton`). Shift+drag panel/bar gated by `db.locked` and combat, writes `db.frames[key]` (`Panel.lua:10-17`).
- **Exposure**:
  - Window only: `showBar`, `plateMarker`, `procAlerts`, `procSound`, `char.rules`, `char.slots`, `char.alts`.
  - Window + slash/minimap: `shown`, `locked`, `frames` (reset).
  - Not in window: `minimapAngle`, `lastProbe`.
- **Defaults** `Core.lua:23-25`: `DEFAULTS = {locked=false, shown=true, frames={}, minimapAngle=240, plateMarker=false, procAlerts=true, procSound=true, showBar=true}`; `CHAR_DEFAULTS = {slots={}, alts={}}`. Merged at ADDON_LOADED via `WCK.MergeDefaults` (`Logic.lua:3-10`, nil-safe, fills nil keys, recurses tables).
- `char.rules` intentionally not in CHAR_DEFAULTS (`Core.lua:253`); seeded in `WCK.inits` only when nil (:252-254), so an emptied list stays empty. No schema version/migration code.
- **Data** `Data.lua`: `defaultRules` (:23-27, six rules), `conds` (:28: ready, notRecent, proc, marked, usable), `condLabels` (:29-30: "off cooldown", "not cast on target in N s", "proc up", "target has a mark", "usable (mana/range)"), `tail` (:20 Shadow Bolt/Fear/Banish), `core` (:22 Life Tap).
- **Validation** `Logic.lua`: `EvalRules` skips unknown cond / unknown spell / not ready (:130-135); `MoveRule` bounds-checked (:137-142); `CopyRules` deep copy (:145-149); `RuleSpells` drops empty, dedups (:167-174); `BarSpells` (:178-188); `CastMacro` returns "" for empty (:208-211); `AltAttrs` (:216-225). No pruning of rules against spellbook.
- `WCK.Refresh` debounced 0.1s via `C_Timer`, runs `WCK.refreshers` (`Core.lua:36-43`); secure attrs skipped in combat (`Rotation.lua:62`); `PLAYER_REGEN_ENABLED` triggers Refresh (`Core.lua:52`).
- UI limits: `MAX_RULES=10` (`Settings.lua:18`), `BAR_MAX=13`, `SLOTS=6`.

## Q3: Styling/layout helpers in BusinessCard/Skin.lua and WarlockUtilityKit/UI.lua

### Findings
- **BusinessCard** palette `BC.THEME` (`BusinessCard/Data.lua:53-57`: ink, parchment, cream, gold, goldBright, muted, zone, available, busy, off).
  - `BC.Skin(f, kind, bg)` (`Skin.lua:9-16`): "dialog" (rock bg, DialogBox border, 24) or "tooltip" (WHITE8x8, tooltip border, 12); gold border. Requires BackdropTemplate.
  - `BC.Parchment(f, alpha, inset)` (:18) QuestBG overlay; `BC.Rule(parent, y, x1, x2)` (:27) 1px gold divider; `BC.Fade` (:34) gradient; `BC.Dot` (:39); `BC.Spin/Breathe/Pop` (:47/53/59) animations; `BC.Sheen` (:70); `BC.HoverGlow(f, restore)` (:89).
  - `BC.TitleFont(fs, size)` (:96-99): MORPHEUS.ttf, fallback GameFontNormalLarge, goldBright, shadow.
  - No spacing constants, header/button/tab/scroll/tooltip helpers.
  - Consumers: `Panel.lua:94,106,109-111`; `Card.lua:9,79,81,86,89-90,195-199`.
- **WarlockUtilityKit** palette `WUK.THEME` (`UI.lua:14-19`: bg, edge, bar, barEnd, accent fel green, text, btn).
  - `WUK.Skin(f, title, opts)` (`UI.lua:36-93`): WHITE8x8 1px edge backdrop (:39-40), purple haze gradient (:42-44), optional swirl, pulsing halo (:59-64), 22px gradient title bar + underline (:66-71), shard icon (:73-79), accent title text (:80-82), optional `UIPanelCloseButton` (:83-86), fade-in on show (:88-90). Returns title FontString; sets `f.titleBar`, `f.titleText`.
  - `WUK.Divider(parent, x, y, width)` (:96); `WUK.Header(parent, text, x, y, width)` (:105-111, GameFontNormalSmall accent + divider at y-13); `WUK.Button(parent, label, width, onClick)` (:114-130, 22px backdrop button with hover); `WUK.MakeMovable(f, key, x, y, free)` (:133-147, persists to `WUK.db.frames[key]` :142); `WUK.AttachTooltip(b, fill)` (:277-282); `WUK.SpellTooltip(name)` (:270).
  - Local-only: `Gradient` (:22), `Pulse` (:28). Ring constants (:10) are strip-specific.
  - Consumers: `Settings.lua:28-32,63-69`; `Board.lua:99-106,141`; `Summon.lua:98-99,102`; `Prep.lua:11,35,67`.
- **TackleBox** has its own `TB.THEME` (`TackleBox/Panel.lua:8-11`) and `TB.Skin(f, edge)` (:43-48). ProfessionPlanner has no helpers.
- No cross-addon shared module; each addon copies its own (recorded as a known issue in BC redesign `design.md:19-26`).

## Q4: Panel organization, chrome, and layout in sibling addons

### Findings
- **BusinessCard** `Panel.lua`: BackdropTemplate 540x560 DIALOG (:93-95); drag gated by `db.locked`, saved to `db.frames.win` (:96-104); UISpecialFrames (:105); title via `BC.TitleFont(…,20)` at 18,-14, close button TOPRIGHT -4,-4 (:106-108); rules at -44 and footer (:109-111); bottom `PanelTabButtonTemplate` tabs (:113-124, `PanelTemplates_SetNumTabs/SetTab/TabResize`); filter dropdown top-right (:126-134); `WowScrollBoxList` + `MinimalScrollBar` + `CreateScrollBoxListLinearView` + `ScrollUtil.InitScrollBoxListWithScrollBar`, nil-guarded (:137-145); footer count (:154). Detail window `Card.lua:192-240` (own UISpecialFrames, icon side tabs :203-213, `SearchBoxTemplate` :214, second scroll list :218-233). Layout: fixed offsets + anchor chains, `TOP` constant (:139).
- **TackleBox** `Panel.lua`: BackdropTemplate, MEDIUM, width 320, dynamic height `TOP+10+max(n,3)*26` (:57-59,213); Shift+drag via shared dock frame, saved `db.frames.dock` (:22,29-40); no UISpecialFrames; close button sets `db.shown=false` (:67-69); title GameFontNormalLarge + random subtitle (:82-88); portrait, StatusBar, rule (:91-105); lazily built custom icon tabs (:142-160) with tooltips; 30 pooled rows, no scroll (:3,115); content from `TB.sections` registry (:217). Constants `WIDTH, ROW_W, TOP, TAB_H = 320, 296, 128, 34` (:4).
- **ProfessionPlanner** `Panel.lua`: `BasicFrameTemplateWithInset` parented to `ProfessionsFrame`, width 360, anchored to it (:6-9); not movable, no UISpecialFrames; template CloseButton hooked (:10); title GameFontHighlight TOP 0,-5 (:11-12) — same title pattern as WCK; flat 16-row list at `-64-(i-1)*30`, height `74+n*30` (:18,92); row tooltips (:27-33).
- **WarlockUtilityKit Settings** `Settings.lua`: 320x336 DIALOG (:26-27); `WUK.Skin(win, title, {close=true, swirl=true})`, `MakeMovable(win,"settings",280,0,true)`, UISpecialFrames (:28-30); three `WUK.Header` sections "Strip & ring" (-32), "Pet" (-162), "Frames" (-218) at width 288 (:32,43,63); local `Check` helper (:14-23); pet dropdown (:53-55); three bottom buttons anchored BOTTOMLEFT/BOTTOMRIGHT (:67-69); `win:Sync` on OnShow (:71-76). Absolute y per control, 26px steps.
- **WUK Board** `Board.lua`: 560 wide, height `110+MAX_ROWS*28` (:97-98); Skin/MakeMovable/UISpecialFrames (:99-101); four column `WUK.Header`s at fixed x + `WUK.Divider` (:104-106); striped rows with three dropdowns via local `Dropdown(row,x,width,build)` (:90,118-135); bottom buttons (:140-147).
- **WUK Summon** `Summon.lua`: skinned, non-free MakeMovable, no UISpecialFrames, title-bar hit frame with click-help tooltip (:96-115).
- **Common**: position persistence always `db.frames[key] = {point, relPoint, x, y}`, wiped by `reset` slash (BC `Core.lua:186`, WUK `Core.lua:255`, TB `Core.lua:243`). WCK settings window itself does not persist position.
- Real scroll lists only in BC. Pooled fixed rows elsewhere (TB, PP, WUK Board/Summon, WCK).
- Section-header pattern exists only in WUK (`WUK.Header`) and BC (`BC.Rule`); WCK uses bare `GameFontNormal` FontStrings.

## Q5: Prior qrspi UI docs — problems, patterns, verification

### Findings
- **2026-11-16-business-card-ui-redesign**: problems `design.md:6-26` (single Panel.lua, `BasicFrameTemplateWithInset` + `UIPanelButtonTemplate` look :7-9,114, no scrolling, 20 pooled rows :11, copied helpers :19-26). Decisions `design.md:83-133`: "merchant ledger" theme (:121), `WowScrollBoxList` (:122), subtle motion (:123), shared card widget (:124), built-in art only, no Ace/LSM (:126,138), split into Skin/Panel/Card/Logic (:127-132), copy `TB.THEME` shape (:85), pcall/nil-guard optional APIs (:118), atlases guarded by `C_Texture.GetAtlasInfo` (:146), fixed ~540x560 (:133). Verification: pure display helpers in Logic.lua covered by `tests/run.lua`; per-phase `lua tests/run.lua` + grep checks (e.g. `grep -c BasicFrameTemplateWithInset` = 0); robocopy deploy (`plan.md:17`); manual in-game checklists all `[x]`. Open risks `design.md:146-151`.
- **2026-11-16-wuk-board-summon-ui**: problems `design.md:5-34` — board stock template, no saved position, no headers, truncated dropdown labels ("No soulsto...") (:21-24); settings opened on top of board with five unlabelled checkboxes (:27-29); theme only on strip (:32). Decisions: shared `WUK.Skin(frame,title)` in UI.lua (:109-113), Blizzard buttons/checkboxes/dropdowns keep templates; saved positions via `MakeMovable` with `free` flag, side-by-side defaults (:114-118); settings grouped into "Strip & ring", "Pet", "Frames" (:129-132); fel green accent (:90). Verification: `lua5.1 tests/run.lua` + `luac -p` + robocopy each phase (`plan.md:132-141,244-253,304-313`); manual checks incl. untruncated labels, positions persisting, "In-game look approved" (`plan.md:398`). Open risk: dropdown strata above a BackdropTemplate dialog (`design.md:145-153`).
- **2026-11-17-businesscard-ace3-ui-review**: research only. Notes no Blizzard `Settings.*` registration anywhere (`research.md:58,139`); WCK and WUK have custom settings windows; minimap button code duplicated in three addons (:101-103); frame code untested, no repo addon uses wowmock (:138); no Forever verification of any Ace3 library (:143-145).

## Q6: Blizzard templates/widgets in repo and skill docs

### Findings
- Used in repo:
  - `BackdropTemplate`: WUK Board:97, Settings:26, UI:59,116, Summon:96; TB Actions:39, CastBar:7, Panel:57; BC Card:8,78,194, Panel:93.
  - `BasicFrameTemplateWithInset`: `ProfessionPlanner/Panel.lua:6`, `WarlockCombatKit/Settings.lua:170` (only remaining uses).
  - `UIPanelButtonTemplate`: only `WarlockCombatKit/Settings.lua:59,68,71,197`.
  - `UICheckButtonTemplate`: `WarlockUtilityKit/Settings.lua:15`, `WarlockCombatKit/Settings.lua:7`.
  - `InputBoxTemplate`: only `WarlockCombatKit/Settings.lua:53`. `SearchBoxTemplate`: `BusinessCard/Card.lua:214`.
  - `UIPanelCloseButton`: WUK UI:84; TB Panel:67; BC Card:198, Panel:108.
  - `DropdownButton` + `WowStyle1DropdownTemplate` + `SetupMenu`: WUK Board:90-92, Settings:53-55; WCK Settings:37-45,102-108,139,151-153; BC Panel:126-128. `MenuUtil` unused.
  - `PanelTabButtonTemplate`: `BusinessCard/Panel.lua:116` (+ `PanelTemplates_*` :42,121,124,156).
  - `WowScrollBoxList`/`CreateScrollBoxListLinearView`/`ScrollUtil.InitScrollBoxListWithScrollBar`/`CreateDataProvider`: BC Card:218-233, Panel:137-167 (nil-guarded :137; `ScrollBoxConstants.RetainScrollPosition` :167).
  - `UISpecialFrames`: WUK Board:101, Settings:30; WCK Settings:174; BC Card:197, Panel:105.
  - `SecureActionButtonTemplate`: WUK UI:315, Prep:5,29,63, Summon:114; TB Actions:12; WCK Actions:10, Rotation:18,39.
  - Not used: `PortraitFrameTemplate`, `UIPanelScrollFrameTemplate`, `ScrollFrame`, `Settings.RegisterCanvasLayoutCategory`, `SettingsPanel`.
  - Comments naming ScrollBox as a later option: `TackleBox/Panel.lua:2`, `WarlockCombatKit/Settings.lua:17`.
- Skill (`C:\Users\madac\.claude\plugins\cache\wow-forever-addon-marketplace\wow-forever-addon\1.0.0\skills\wow-forever-addon\references\`):
  - `widgets.md:3` points to Gethe/wow-ui-source branch `forever` for signatures; :11 frame types; :13 templates listed: BackdropTemplate, UIPanelButtonTemplate, UICheckButtonTemplate, SecureActionButtonTemplate. Gotcha: BackdropTemplate frame with no SetBackdrop/texture is invisible (found in-game 2026-11-17). :14 "Create each frame **once**. Frames are never freed."
  - `forever-api-notes.md:7-9`: Forever is Mainline-family, built from Retail 12.1.5 code. :33 Retail `C_*` namespaces present. :69-74 verify names via index, wow-ui-source `forever` FrameXML, or `/dump Name` in-game.
  - `forever-api-index.md:879-880`: `C_SettingsUtil.NotifySettingsLoaded`, `OpenSettingsPanel`; events `SETTINGS_LOADED`, `SETTINGS_PANEL_OPEN` (:2448-2449). Index covers API namespaces, not FrameXML templates.
  - `taint-and-secure.md:23`: secure buttons configured via attributes outside combat.
  - Skill docs say nothing about `Settings.RegisterCanvasLayoutCategory`, `MenuUtil`/`SetupMenu`, ScrollBox, `BasicFrameTemplateWithInset`, tab templates, or `UISpecialFrames`.

## Q7: WCK tests and mock harness

### Findings
- `WarlockCombatKit/tests/run.lua:1-4` loadfiles only `Data.lua` and `Logic.lua` into bare `WCK = {}`; never loads Settings/Panel/Rotation/Core; no `CreateFrame`; helpers `eq`/`near` (:6-11); ends `print("all tests passed")` (:165).
- Covers pure Logic: MergeDefaults (:14-17), EnemyKey/PickUnit/cast map/RowsView (:20-67), RowHasCC (:70-72), ProcsUp/NewProcs (:75-79), EvalRules/MoveRule/CopyRules (:82-96), CastMacro (:99-101), BuildSpellTabs/RuleSpells (:104-118), BarSpells (:121-131), ButtonLook (:134-139), CooldownState (:142-150), AltAttrs (:153-163).
- No repo test touches frames (no `CreateFrame` under any `tests/`). No repo addon vendors wowmock.
- wowmock lives in skill source `D:\Source\wowskill\skills\wow-forever-addon\scripts\wowmock\frames.lua`: `CreateFrame(ftype, name, parent)` (:65) ignores template; generic frame object (:22-28); no-op and stateful method lists (:5-8, :32-63); unknown uppercase methods error "wowmock: unimplemented Frame:X" (:13-19). No DropdownButton/SetupMenu, EditBox, CheckButton (`SetChecked`/`GetChecked`), ScrollBox, ScrollUtil, CreateDataProvider support.
- Run: CI `lua5.1 WarlockCombatKit/tests/run.lua` (`.github/workflows/package-wck.yml:21`); locally `lua tests/run.lua` expecting `all tests passed` (BC `plan.md:15`); WUK plan also runs `luac -p` on all files (WUK `plan.md:132`).

## Cross-Cutting Observations
- No Ace3, no shared library, no Blizzard Settings panel registration in any addon; every UI is hand-rolled `CreateFrame`.
- Two "skinned" families exist: BC (gold/parchment, `BC.Skin`) and WUK (purple/fel, `WUK.Skin` + `Header`/`Divider`/`Button`/`MakeMovable`/`AttachTooltip`). WUK is the other Warlock addon. WCK and PP use stock `BasicFrameTemplateWithInset` with a TOP 0,-5 `GameFontHighlight` title.
- WCK Settings.lua is the sole user of `UIPanelButtonTemplate` and `InputBoxTemplate` in the repo.
- Earlier redesigns (BC, WUK) moved off `BasicFrameTemplateWithInset`/`UIPanelButtonTemplate`, kept Blizzard checkbox/dropdown templates, added section headers, saved window positions, and verified visuals manually in-game after robocopy deploy.
- Settings windows refresh via an OnShow `Sync` pattern in both WCK (`Settings.lua:201-202`) and WUK (`Settings.lua:71-76`).
- WCK is the only addon with a section registry that threads a running y cursor (`WCK.settingsSections`); TB has a similar `TB.sections` registry for content. All others use absolute offsets.
- Position persistence convention `db.frames[key]` is shared by all addons; WCK uses it for panel/bar (`Panel.lua:10-17`) but not for the settings window.

## Open Areas
- Whether `Settings.RegisterCanvasLayoutCategory`, `MenuUtil`, `UIPanelScrollFrameTemplate`, or `PortraitFrameTemplate` exist on Forever (16001) is not documented in repo or skill; would need `/dump` in-game or wow-ui-source `forever` branch.
- WCK in-game rendered height (1140px computed) vs typical screen height not measured; no screenshots in repo.
- `Bindings.xml` contents not read.
- WUK board/summon `structure.md` and `research.md` not read.
