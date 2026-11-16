# Implementation Plan

## Overview
Restyle BusinessCard's UI.
- **Window:** a "merchant ledger" frame built from rock, parchment and gold.
- **Seen list:** detailed rows that scroll.
- **Cards:** one real business-card widget shared by My card and the detail view.
- **Motion:** subtle animation.

Data, comms, the wire format and SavedVariables stay the same. The addon ships no media files and uses only built-in art.

**Working tree.** Work happens on worktree branch `2026-11-16-profession-business-card`, in folder `C:/Users/madac/wt/wow-addons/2026-11-16-profession-business-card/BusinessCard/` (`BC/` below).

**Commands.** Run every command from `BC/`.
- Tests: `lua tests/run.lua`. Lua is at `C:/Users/madac/AppData/Local/Programs/Lua/bin/lua`. Expect `all tests passed`.
- Deploy at the end of each phase, after the commit:
  `robocopy "C:\Users\madac\wt\wow-addons\2026-11-16-profession-business-card\BusinessCard" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\BusinessCard" /MIR /XD tests /NJH /NJS /NP /NDL`
  Exit codes 0 to 7 mean success. Then the user runs `/reload` in game.

**Each phase ends the same way:**
1. Add a CHANGELOG.md entry.
2. Bump `## Version` in `BusinessCard.toc`: P1 0.8.0, P2 0.8.1, P3 0.8.2, P4 0.8.3, P5 0.8.4.
3. Commit.
4. Deploy.
5. Ask for the in-game check.

---

## Phase 1: Ledger chrome

### Changes

#### 1. Theme colours
**File**: `BC/Data.lua`
**Action**: modify (append)

```lua
-- merchant-ledger palette {r,g,b[,a]}
BC.THEME = {
  ink = { 0.07, 0.06, 0.05, 0.97 }, parchment = { 1, 0.96, 0.84 }, cream = { 0.94, 0.88, 0.73 },
  gold = { 0.72, 0.58, 0.32 }, goldBright = { 1, 0.82, 0.30 }, muted = { 0.55, 0.52, 0.46 },
  zone = { 0.6, 0.8, 1 }, available = { 0.25, 0.9, 0.3 }, busy = { 0.95, 0.25, 0.2 }, off = { 0.5, 0.5, 0.5 },
}
```

#### 2. Skin helpers
**File**: `BC/Skin.lua`
**Action**: create

```lua
local ADDON, BC = ...
local T = BC.THEME

local EDGES = {
  dialog = { bg = "Interface\\FrameGeneral\\UI-Background-Rock", edge = "Interface\\DialogFrame\\UI-DialogBox-Border", size = 24, inset = 6 },
  tooltip = { bg = "Interface\\Buttons\\WHITE8x8", edge = "Interface\\Tooltips\\UI-Tooltip-Border", size = 12, inset = 3 },
}
-- f must inherit BackdropTemplate
function BC.Skin(f, kind, bg)
  local e = EDGES[kind or "dialog"]
  f:SetBackdrop({ bgFile = e.bg, edgeFile = e.edge, edgeSize = e.size, tile = true, tileSize = 256,
    insets = { left = e.inset, right = e.inset, top = e.inset, bottom = e.inset } })
  local c = bg or T.ink
  f:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
  f:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3])
end

function BC.Parchment(f, alpha, inset) -- ForeverDungeonJournal AddClassicParchment
  local t = f:CreateTexture(nil, "BACKGROUND", nil, -2)
  t:SetTexture("Interface\\QuestFrame\\QuestBG")
  t:SetPoint("TOPLEFT", inset or 6, -(inset or 6)); t:SetPoint("BOTTOMRIGHT", -(inset or 6), inset or 6)
  t:SetVertexColor(T.parchment[1], T.parchment[2], T.parchment[3]); t:SetAlpha(alpha or 0.15)
  return t
end

function BC.Rule(parent, y, x1, x2) -- 1px gold line; y from parent TOP
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(T.gold[1], T.gold[2], T.gold[3], 0.8); t:SetHeight(1)
  t:SetPoint("TOPLEFT", x1 or 12, y); t:SetPoint("TOPRIGHT", -(x2 or 12), y)
  return t
end

function BC.Fade(t, dir, c, a1, a2) -- TackleBox Panel.lua:51-54
  t:SetColorTexture(1, 1, 1, 1)
  t:SetGradient(dir, CreateColor(c[1], c[2], c[3], a1), CreateColor(c[1], c[2], c[3], a2))
end

function BC.TitleFont(fs, size)
  if not fs:SetFont("Fonts\\MORPHEUS.ttf", size or 20, "") then fs:SetFontObject("GameFontNormalLarge") end
  fs:SetTextColor(T.goldBright[1], T.goldBright[2], T.goldBright[3]); fs:SetShadowOffset(1, -1)
end
```

#### 3. Panel chrome
**File**: `BC/Panel.lua`
**Action**: modify. Only `Build()` changes. The row creation loop (`:79-102`) stays for now.

- Line 47: change the frame to `CreateFrame("Frame", "BusinessCardWin", UIParent, "BackdropTemplate")`, then `BC.Skin(win)`, then `BC.Parchment(win, 0.15)`.
- Line 48: change the size to `win:SetSize(540, TOP + 40 + MAX_ROWS * ROW_H)`. Keep the DIALOG strata.
- Keep the position, drag and UISpecialFrames code (`:49-58`) unchanged.
- Replace the title (`:59-60`):
  ```lua
  local title = win:CreateFontString(nil, "OVERLAY"); BC.TitleFont(title, 20)
  title:SetPoint("TOPLEFT", 18, -14); title:SetText("Business Cards")
  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
  BC.Rule(win, -44); win.footRule = BC.Rule(win, 0) -- re-anchored below
  win.footRule:ClearAllPoints(); win.footRule:SetPoint("BOTTOMLEFT", 12, 28); win.footRule:SetPoint("BOTTOMRIGHT", -12, 28)
  ```
- Replace `seenBtn` and `cardBtn` (`:62-67`) with bottom tabs. Name them so both older and newer `PanelTemplates` find them:
  ```lua
  win.Tabs = {}
  for i, v in ipairs({ { "Seen", "seen" }, { "My card", "card" } }) do
    local tab = CreateFrame("Button", "BusinessCardWinTab" .. i, win, "PanelTabButtonTemplate")
    tab:SetID(i); tab:SetText(v[1]); tab.view = v[2]
    tab:SetPoint(i == 1 and "TOPLEFT" or "LEFT", i == 1 and win or win.Tabs[i - 1], i == 1 and "BOTTOMLEFT" or "RIGHT", i == 1 and 12 or -14, i == 1 and 2 or 0)
    tab:SetScript("OnClick", function(self) SetView(self.view) end)
    PanelTemplates_TabResize(tab, 0)
    win.Tabs[i] = tab
  end
  PanelTemplates_SetNumTabs(win, 2)
  ```
- `SetView` (`:44`) becomes:
  `local function SetView(v) BC.db.view = v; PanelTemplates_SetTab(win, v == "card" and 2 or 1); BC.RefreshPanel() end`
- The OnShow handler (`:105`) also calls `PanelTemplates_SetTab(win, BC.db.view == "card" and 2 or 1)`.
- Filter dropdown (`:69-70`): move it to `TOPRIGHT -34, -14`. It sits in the header, left of the close button.
- Rows: change the anchor to `TOPLEFT 16, -TOP-...` with `TOP = 54`, and the width to 508.
- Footer: anchor it at `BOTTOMLEFT 18, 10` and colour it `T.muted`.
- `BuildDetail` (`:182`) changes only its base: `"BackdropTemplate"`, then `BC.Skin(detail)`, `BC.Parchment(detail, 0.15)`, a `UIPanelCloseButton`, and `BC.TitleFont(detail.title, 16)`. Its full rebuild comes in Phase 4.

#### 4. Load order
**File**: `BC/BusinessCard.toc`
**Action**: modify. Set the file list to Data, Logic, Core, Comm, Skin, Panel, and set `## Version: 0.8.0`.

### Verification
#### Automated
- [x] `lua tests/run.lua` prints `all tests passed`.
- [x] `grep -c "BasicFrameTemplateWithInset" Panel.lua` returns 0. The detail panel's profession buttons still use `UIPanelButtonTemplate` until Phase 4 replaces them.

#### Manual
- [x] `/bcard` opens a dark rock window with a faint parchment layer, a gold border, a gold Morpheus title and a close X.
- [x] The Seen and My card tabs hang under the frame. Clicking a tab switches the view and highlights it.
- [x] Esc closes the window. Drag it, run `/reload`, and it reopens in the same place. `/bcard lock` blocks dragging.
- [x] Shift-clicking a row opens the detail panel in the same skin.
- [x] No Lua errors.

---

## Phase 2: Detailed scrolling Seen list

### Changes

#### 1. Icons and service labels
**File**: `BC/Data.lua`
**Action**: modify (append)

```lua
local I = "Interface\\Icons\\"
BC.CAT_ICON = { enchanting = I .. "Trade_Engraving", tailoring = I .. "Trade_Tailoring",
  leatherworking = I .. "INV_Misc_ArmorKit_17", alchemy = I .. "Trade_Alchemy", blacksmithing = I .. "Trade_BlackSmithing",
  engineering = I .. "Trade_Engineering", jewelcrafting = I .. "INV_Misc_Gem_02", cooking = I .. "INV_Misc_Food_15",
  firstaid = I .. "Spell_Holy_SealOfSacrifice", summon = I .. "Spell_Shadow_Twilight",
  portal = I .. "Spell_Arcane_PortalIronForge", other = I .. "INV_Misc_Key_03" }
BC.SVC_ICON = { S = I .. "Spell_Shadow_Twilight" }
for _, d in ipairs({ { "ORG", "Orgrimmar" }, { "UC", "UnderCity" }, { "TB", "ThunderBluff" }, { "SW", "StormWind" },
  { "IF", "IronForge" }, { "DARN", "Darnassus" } }) do
  BC.SVC_ICON["T-" .. d[1]] = I .. "Spell_Arcane_Teleport" .. d[2]; BC.SVC_ICON["P-" .. d[1]] = I .. "Spell_Arcane_Portal" .. d[2]
end
BC.SVC_LABEL = {}
for _, s in ipairs(BC.SERVICES) do BC.SVC_LABEL[s.key] = s.label or s.name end
BC.ICON_FALLBACK = I .. "INV_Letter_15"
```

In `Panel.lua`, delete the local `SVC_LABEL` (`:6-7`) and use `BC.SVC_LABEL` instead (`:38`, `:152`, `:227`).

#### 2. Display helpers
**File**: `BC/Logic.lua`
**Action**: modify (append)

```lua
function BC.RowIcons(cats, max) -- icon paths in BC.CATS order, capped
  local out = {}
  for _, c in ipairs(BC.CATS) do
    if cats and cats[c] and #out < (max or 3) then out[#out + 1] = BC.CAT_ICON[c] or BC.ICON_FALLBACK end
  end
  return out
end
local ST_THEME = { a = "available", b = "busy", o = "off" }
function BC.StatusColor(st) return st and BC.THEME[ST_THEME[st]] or nil end
```

#### 3. ScrollBox list and new rows
**File**: `BC/Panel.lua`
**Action**: modify

- Delete `MAX_ROWS`, the row loop (`:79-102`) and the ponytail comment on line 2. Use `ROW_H = 34` and `TOP = 54`. The window size becomes `540 x 560`.
- Add a round-dot helper to `Skin.lua`. Its mask matches `WCK/Panel.lua:75-80`:
  ```lua
  function BC.Dot(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK"); t:SetSize(size, size); t:SetTexture("Interface\\Buttons\\WHITE8x8")
    local m = parent:CreateMaskTexture(); m:SetAllPoints(t)
    m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    t:AddMaskTexture(m); return t
  end
  ```
- `BuildRow(row)` runs lazily the first time `InitRow` sees a row. Left to right, the row has:
  - **Stripe:** a BACKGROUND texture, white at alpha 0.03, shown on odd rows.
  - **Hover:** a HIGHLIGHT-layer texture with `BC.Fade(hl, "HORIZONTAL", T.goldBright, 0.18, 0)`, the AtlasLoot `highlightBg` look.
  - **Status dot:** `row.dot = BC.Dot(row, 10)` at `LEFT 6,0`.
  - **Name:** `row.name`, `GameFontNormal`, at `LEFT 22,0`, 150 wide, no wrap.
  - **Category icons:** `row.icons[1..3]`, each 20x20 with TexCoord 0.07-0.93, starting at `LEFT 180,0` on a 22 px step.
  - **Zone:** `row.zone`, `GameFontHighlightSmall`, coloured `T.zone`, at `LEFT 252,0`, 150 wide.
  - **Card badge:** `row.badge`, 16x16, `BC.ICON_FALLBACK`, at `RIGHT -48,0`.
  - **Age:** `row.age`, `GameFontDisableSmall`, at `RIGHT -8,0`.
  - `RegisterForClicks("LeftButtonUp","RightButtonUp")`, and the existing `RowClick`, `RowEnter` and `GameTooltip_Hide` scripts.
- `InitRow(row, v)`:
  ```lua
  local function InitRow(row, v)
    if not row.built then BuildRow(row) end
    row.key, row.data = v.key or v.name, v
    if v.mine then -- My card fallback until Phase 3
      row.name:SetText(v.label); row.zone:SetText(v.skill or ""); row.age:SetText(ST_LABEL[v.st or "a"])
      row.dot:Hide(); row.badge:Hide(); for _, ic in ipairs(row.icons) do ic:Hide() end
      return
    end
    row.name:SetText(v.name)
    row.name:SetTextColor(unpack(v.card and T.goldBright or T.cream))
    local icons = BC.RowIcons(v.cats, 3)
    for i, ic in ipairs(row.icons) do ic:SetShown(icons[i] ~= nil); if icons[i] then ic:SetTexture(icons[i]) end end
    row.zone:SetText(v.zone or ""); row.age:SetText(v.age)
    local c = BC.StatusColor(BC.CardStatus(v.card, BC.db.filter))
    row.dot:SetShown(c ~= nil); if c then row.dot:SetVertexColor(c[1], c[2], c[3]) end
    row.badge:SetShown(v.card ~= nil)
  end
  ```
  Stripe: `row.stripe:SetShown((v.i or 0) % 2 == 1)`. `RenderSeen` stamps `v.i` on each row, and the My card rows stamp it too.
- The list is built in `Build()` (Baganator `CharacterSelect.lua:53-97`):
  ```lua
  if not (CreateScrollBoxListLinearView and ScrollUtil and CreateDataProvider) then
    BC.Print("scroll list unavailable on this client"); return
  end
  win.list = CreateFrame("Frame", nil, win, "WowScrollBoxList")
  win.list:SetPoint("TOPLEFT", 12, -TOP); win.list:SetPoint("BOTTOMRIGHT", -26, 32)
  win.bar = CreateFrame("EventFrame", nil, win, "MinimalScrollBar")
  win.bar:SetPoint("TOPLEFT", win.list, "TOPRIGHT", 6, 0); win.bar:SetPoint("BOTTOMLEFT", win.list, "BOTTOMRIGHT", 6, 0)
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(ROW_H)
  view:SetElementInitializer("Button", InitRow)
  ScrollUtil.InitScrollBoxListWithScrollBar(win.list, win.bar, view)
  ```
- `BC.RenderSeen(rows, total)`:
  ```lua
  for i, v in ipairs(rows) do v.i = i end
  win.list:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
  win.footer:SetText(#rows .. " shown / " .. total .. " seen")
  ```
- `BC.RenderMyCard(w)`: build the same row list as today, with fields `{mine=true, key, label, st, skill}`, then call `w.list:SetDataProvider(CreateDataProvider(rows))`. The footer is unchanged.
- `RowClick` is unchanged. Card view rows carry `key`, and `OnCardRowClick` reads `row.key`.

#### 4. Tests
**File**: `BC/tests/run.lua`
**Action**: modify. Add the following before `print("all tests passed")`.

```lua
-- UI redesign P2
local ic = BC.RowIcons({ portal = true, enchanting = true, summon = true, alchemy = true }, 3)
eq(#ic, 3, "row icons capped"); eq(ic[1], BC.CAT_ICON.enchanting, "row icons in CATS order")
eq(ic[3], BC.CAT_ICON.summon, "portal dropped past cap")
eq(#BC.RowIcons(nil, 3), 0, "no cats no icons")
eq(BC.StatusColor("a"), BC.THEME.available, "available colour"); eq(BC.StatusColor("b"), BC.THEME.busy, "busy colour")
eq(BC.StatusColor("o"), BC.THEME.off, "off colour"); eq(BC.StatusColor(nil), nil, "unknown no colour")
for _, c in ipairs(BC.CATS) do assert(BC.CAT_ICON[c], "icon for " .. c) end
for _, s in ipairs(BC.SERVICES) do assert(BC.SVC_ICON[s.key], "icon for " .. s.key) end
```

### Verification
#### Automated
- [x] `lua tests/run.lua` prints `all tests passed`.
- [x] `grep -n "MAX_ROWS" Panel.lua` returns nothing.

#### Manual
- [x] With 25 or more seen entries, the mouse wheel and the scroll bar reach the last entry. The footer reads "N shown / N seen".
- [x] Each row shows its category icons. Write down any icon that renders blank or green so it can be swapped in Data.lua.
- [x] Players who run BusinessCard have gold names and the envelope badge. The dot is green for available and red for busy.
- [x] Hovering shows a gold gradient and the tooltip. Click whispers, shift-click opens the detail, ctrl-click runs `/who`, and right-click removes the row.
- [x] The My card tab lists entries, and clicking one cycles its status (temporary layout).
- [x] Changing the filter dropdown refilters the list.

---

## Phase 3: Business-card widget plus My card

### Changes

#### 1. Profession icons
**File**: `BC/Data.lua`
**Action**: modify (append)

```lua
BC.PROF_ICON = { [171] = I .. "Trade_Alchemy", [164] = I .. "Trade_BlackSmithing", [333] = I .. "Trade_Engraving",
  [202] = I .. "Trade_Engineering", [165] = I .. "INV_Misc_ArmorKit_17", [197] = I .. "Trade_Tailoring",
  [185] = I .. "INV_Misc_Food_15", [129] = I .. "Spell_Holy_SealOfSacrifice", [186] = I .. "Trade_Mining",
  [182] = I .. "Spell_Nature_NatureTouchGrow", [393] = I .. "INV_Misc_Pelt_Wolf_01", [356] = I .. "Trade_Fishing",
  [755] = I .. "INV_Misc_Gem_02" }
```

`I` is the local defined in Phase 2. Place this block after it.

#### 2. Card view model
**File**: `BC/Logic.lua`
**Action**: modify (append)

```lua
function BC.SkillFrac(skill, cap)
  local n = tonumber(skill) or 0
  return math.max(0, math.min(1, n / (cap or 300))) -- ponytail: cards carry no max skill; 300 = classic cap
end

-- opts.self: portrait "player"; else first prof/service icon in the portrait ring
function BC.CardModel(card, opts)
  local m = { g = card.g or "a", profs = {}, svcs = {}, zone = card.zone }
  for _, p in ipairs(card.profs or {}) do
    m.profs[#m.profs + 1] = { key = "p" .. p.id, icon = BC.PROF_ICON[p.id] or BC.ICON_FALLBACK,
      name = BC.PROF_NAMES[p.id] or ("Profession " .. p.id), skill = tonumber(p.skill) or 0, frac = BC.SkillFrac(p.skill), st = p.st or "a" }
  end
  for _, s in ipairs(card.svcs or {}) do
    m.svcs[#m.svcs + 1] = { key = s.key, icon = BC.SVC_ICON[s.key] or BC.ICON_FALLBACK, label = BC.SVC_LABEL[s.key] or s.key, st = s.st or "a" }
  end
  if opts and opts.self then m.portrait = "player"
  else m.portrait = (m.profs[1] and m.profs[1].icon) or (m.svcs[1] and m.svcs[1].icon) or BC.ICON_FALLBACK end
  return m
end
```

#### 3. Card widget
**File**: `BC/Card.lua`
**Action**: create

```lua
local ADDON, BC = ...
local T = BC.THEME
local ST_TEXT = { a = "Available", b = "Busy", o = "Off" }

function BC.Pill(parent, w)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w or 74, 18); BC.Skin(b, "tooltip", { 0, 0, 0, 0.5 })
  b.dot = BC.Dot(b, 8); b.dot:SetPoint("LEFT", 6, 0)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.text:SetPoint("LEFT", b.dot, "RIGHT", 4, 0)
  function b:SetStatus(st)
    local c = BC.StatusColor(st) or T.off
    self.dot:SetVertexColor(c[1], c[2], c[3]); self.text:SetText(ST_TEXT[st] or "")
    self:SetBackdropBorderColor(c[1], c[2], c[3], 0.8); self.st = st
  end
  b:SetScript("OnClick", function(self) if parent.onPill then parent.onPill(self.key) end end)
  return b
end

function BC.RoundPortrait(parent, size)
  local t = BC.Dot(parent, size, "ARTWORK") -- masked round texture
  local ring = parent:CreateTexture(nil, "OVERLAY"); ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ring:SetSize(size * 1.9, size * 1.9); ring:SetPoint("TOPLEFT", t, "TOPLEFT", -size * 0.12, size * 0.1) -- TackleBox Panel.lua:80 offsets; tune in game
  t.ring = ring
  function t:SetPortrait(p)
    self:SetVertexColor(1, 1, 1)
    if p == "player" then
      if not (SetPortraitTexture and pcall(SetPortraitTexture, self, "player")) then self:SetTexture(BC.ICON_FALLBACK) end
      self:SetTexCoord(0, 1, 0, 1)
    else self:SetTexture(p); self:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    self.p = p
  end
  return t
end
```

`BC.NewCard(parent)` builds a 300-wide `BackdropTemplate` frame with `BC.Skin(card, "tooltip", {0.12,0.10,0.07,0.96})` and `BC.Parchment(card, 0.22, 3)`. It contains:
- **Header:**
  - a 56 px portrait at `TOPLEFT 14,-14`;
  - `card.title` (TitleFont 18) at `TOPLEFT 84,-16`;
  - `card.sub` (`GameFontHighlightSmall`, coloured `T.muted`) under the title, for the zone;
  - `card.g`, a 96-wide pill, at `TOPRIGHT -12,-14`, key `"g"`.
- **Rule:** `BC.Rule(card, -82)`.
- **Profession line pool `card.lines[i]`** (Frame 276x22, starting at y -90 on a 24 px step). Each line has:
  - a 18x18 icon;
  - a name (`GameFontNormalSmall`, 90 wide);
  - a StatusBar 100x8 using `Interface\\TargetingFrame\\UI-StatusBar`, coloured `T.gold`, with a BACKGROUND colour texture of `0,0,0,0.55` (TackleBox `Panel.lua:91-94`);
  - the skill number;
  - a pill, 64 wide.
- **Service row:** a pool of 22x22 icon buttons in one wrapping row below the profession lines. Each has a small status dot at its BOTTOMRIGHT corner. Clicking the button calls `card.onPill(key)`. Its tooltip shows the label and status.

```lua
function card:SetModel(m, title, sub)
  self.portrait:SetPortrait(m.portrait); self.title:SetText(title); self.sub:SetText(sub or "")
  self.g.key = "g"; self.g:SetStatus(m.g)
  -- acquire/layout lines for m.profs (show i<=#m.profs, hide rest); line.pill.key = p.key; bar:SetValue(p.frac)
  -- acquire/layout svc buttons for m.svcs, wrap at 11 per row
  self:SetHeight(96 + #m.profs * 24 + (#m.svcs > 0 and (math.ceil(#m.svcs / 11) * 26 + 8) or 0) + 10)
end
```

Pills are children of `card`, so each pill's `parent.onPill` resolves to `card.onPill`. Service buttons call `card.onPill` directly.

Portrait refresh:
```lua
card:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
card:SetScript("OnEvent", function(self) if self.portrait.p == "player" then self.portrait:SetPortrait("player") end end)
card:HookScript("OnShow", function(self) if self.portrait.p == "player" then self.portrait:SetPortrait("player") end end)
```

#### 4. My card view
**File**: `BC/Panel.lua`
**Action**: modify

- In `Build()`, after the list:
  ```lua
  win.card = BC.NewCard(win); win.card:SetPoint("TOP", 0, -TOP - 8); win.card:Hide()
  win.card.onPill = function(key)
    local cur = BC.char.status[key] or "a"
    if key == "g" then BC.ChangeStatus("g", cur == "a" and "b" or "a") else BC.ChangeStatus(key, BC.NextStatus(cur)) end
  end
  ```
- Replace `BC.RenderMyCard(w)`:
  ```lua
  function BC.RenderMyCard(w)
    w.list:Hide(); w.bar:Hide(); w.card:Show()
    w.card:SetModel(BC.CardModel(BC.MyCard(), { self = true }), UnitName("player"), GetRealZoneText())
    -- footer: recipes cached (existing :160-163 code unchanged)
  end
  ```
- `BC.RenderSeen` starts with `win.card:Hide(); win.list:Show(); win.bar:Show()`.
- Delete `BC.OnCardRowClick` and the `v.mine` branch in `InitRow`, along with the `RowClick` card-view branch (`:16-17`). Card clicks now go through `onPill`.

#### 5. Load order
**File**: `BC/BusinessCard.toc`
**Action**: modify. Add `Card.lua` after `Panel.lua`. `Panel.lua` calls `BC.NewCard` only inside `Build()`, which runs on first toggle, after everything has loaded.

#### 6. Tests
**File**: `BC/tests/run.lua`
**Action**: modify

```lua
-- UI redesign P3
eq(BC.SkillFrac(150), 0.5, "skill half"); eq(BC.SkillFrac(400), 1, "skill clamps high")
eq(BC.SkillFrac(nil), 0, "skill nil"); eq(BC.SkillFrac(75, 150), 0.5, "skill custom cap")
local cm = BC.CardModel({ g = "b", profs = { { id = 333, skill = 225, st = "o" } }, svcs = { { key = "P-ORG", st = "a" } } }, { self = true })
eq(cm.g, "b", "model global"); eq(cm.portrait, "player", "self portrait")
eq(cm.profs[1].name, "Enchanting", "model prof name"); eq(cm.profs[1].key, "p333", "model prof key")
eq(cm.profs[1].icon, BC.PROF_ICON[333], "model prof icon"); eq(cm.profs[1].st, "o", "model prof status")
eq(cm.svcs[1].label, "Portal: Orgrimmar", "model svc label")
eq(BC.CardModel({ profs = {}, svcs = { { key = "S", st = "a" } } }).portrait, BC.SVC_ICON.S, "stranger portrait = first svc icon")
eq(BC.CardModel({}).portrait, BC.ICON_FALLBACK, "empty card fallback portrait")
```

### Verification
#### Automated
- [x] `lua tests/run.lua` prints `all tests passed`.
- [x] `grep -n "OnCardRowClick" *.lua` returns nothing.

#### Manual
- [x] The My card tab shows a card with your round portrait in a ring, your name and zone, and a global pill.
- [x] Each profession shows its icon, a skill bar and a pill. Services show as icons with status dots.
- [x] After `/reload` the portrait is not a black square. If it is, add `C_Timer.After(1, ...)` to re-apply it in the OnShow hook.
- [x] Clicking the global pill toggles Available and Busy. Profession and service pills cycle Available, Busy, Off. Each change persists across `/reload`.
- [x] A guildmate running BusinessCard sees your updated status, or check with `/bcard` on an alt.
- [x] Note any ring misalignment and adjust the offsets in `RoundPortrait`.

---

## Phase 4: Card detail on the widget

### Changes

#### 1. Move the detail into Card.lua and rebuild it
**Files**: `BC/Panel.lua` (delete `:172-249`: `DETAIL_ROWS`, `names`, `RecipeName`, `BuildDetail`, `BC.RefreshDetail`, `BC.ShowDetail`), `BC/Card.lua` (add them)
**Action**: modify

`BuildDetail()` builds a frame named `BusinessCardDetail`, parented to `BusinessCardWin` and created as a `BackdropTemplate` frame. It is 320x560, with `TOPLEFT` at the window's `TOPRIGHT +2,0`.
- Skin, parchment and close button as in Phase 1. Add it to `UISpecialFrames`.
- `detail.card = BC.NewCard(detail)` at `TOP 0,-12`. Its `onPill` is nil, so pills on strangers' cards are display-only: `BC.Pill`'s OnClick checks `parent.onPill`.
- **Profession tabs:** `detail.tabs[1..6]`, each a 28x28 Button.
  - Icon: TexCoord 0.07-0.93.
  - Highlight: `ButtonHilight-Square` ADD.
  - Selected: a `CheckButtonHilight` ADD texture, shown when `tab.prof == detail.prof`. This mirrors Baganator side tabs (`Components.xml:20-46`).
  - The tabs sit in a row under the card. Their y is set in `RefreshDetail` after `card:GetHeight()`.
  - OnClick keeps the existing behaviour: set `detail.prof`, call `RequestRecipes` if the list is missing, then refresh.
  - OnEnter shows a tooltip with the profession name and skill.
- **Search:** `detail.search`, a `SearchBoxTemplate` 280x20 placed under the tabs, with the existing OnTextChanged hook.
- **Recipe list:** `detail.list` is a `WowScrollBoxList` plus `MinimalScrollBar`, extent 18, filling from under the search box to `BOTTOMRIGHT -26,30`. Its initializer:
  ```lua
  view:SetElementInitializer("Frame", function(f, name)
    if not f.fs then f.fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.fs:SetPoint("LEFT", 6, 0)
      f.fs:SetPoint("RIGHT", -4, 0); f.fs:SetJustifyH("LEFT"); f.fs:SetWordWrap(false) end
    f.fs:SetText(name)
  end)
  ```
- **State overlay:** `detail.state`, a Frame with a 32 px icon and a `GameFontNormal` message, centred over the list area. `detail.spin` is a REPEAT Rotation of 360° over 1.2 s on the icon (`WCK/Panel.lua:88-92`).
- **Footer:** `detail.footer`, as today.

```lua
local function DetailState(card, ids, prof)
  if not card then return "nocard" end
  if not prof then return "pick" end
  if not ids then return "requesting" end
  if #ids == 0 then return "empty" end
  return "list"
end
local STATE = {
  nocard = { BC.ICON_FALLBACK, "No card yet - they may not run BusinessCard." },
  pick = { "Interface\\Icons\\INV_Misc_Book_09", "Pick a profession to see recipes" },
  requesting = { "Interface\\Icons\\INV_Misc_PocketWatch_01", "Requesting..." },
  empty = { "Interface\\Icons\\INV_Misc_Note_01", "They haven't opened that profession yet." },
}
```

`BC.RefreshDetail()` keeps its signature. It:
1. Builds `m = BC.CardModel(card or {}, {})` and calls `detail.card:SetModel(m, who, card and card.zone)`. With no card, the card shows the fallback portrait and no lines.
2. Lays out the tabs from `card.profs`. The tab icon is `BC.PROF_ICON[p.id]`.
3. Computes `st = DetailState(card, ids, detail.prof)`.
4. If `st ~= "list"`, shows the state overlay, plays `spin` only for "requesting", and clears the list (`SetDataProvider(CreateDataProvider({}))`).
5. Otherwise, filters the sorted names with the search text exactly as today (`Panel.lua:233-239`), sets the data provider, and sets the footer to `#shown .. " of " .. #ids .. " known"`.

`BC.ShowDetail(name)` is unchanged apart from the move. `RecipeName` and the `names` cache move as-is.

### Verification
#### Automated
- [x] `lua tests/run.lua` prints `all tests passed`.
- [x] `grep -n "BuildDetail\|DETAIL_ROWS" Panel.lua` returns nothing.

#### Manual
- [x] Shift-clicking a row that has a card opens the detail panel. It shows their card with professions, skill bars and statuses, and the portrait ring shows their first profession's icon.
- [x] The profession tabs match their professions. Clicking a tab shows the spinning "Requesting..." state, then a recipe list that scrolls. The selected tab is highlighted.
- [x] Search filters the list, and the footer updates.
- [x] Clicking pills on someone else's card does nothing.
- [x] Shift-clicking a player with no card shows the "No card yet" state.
- [x] Esc closes the detail first, then the window.

---

## Phase 5: Subtle motion

### Changes

#### 1. Animation helpers
**File**: `BC/Skin.lua`
**Action**: modify (append)

```lua
function BC.Breathe(t) -- WCK Panel.lua:94-98
  local g = t:CreateAnimationGroup(); g:SetLooping("BOUNCE")
  local a = g:CreateAnimation("Alpha"); a:SetFromAlpha(0.55); a:SetToAlpha(1); a:SetDuration(1.2); a:SetSmoothing("IN_OUT")
  return g
end
function BC.Flash(t) -- TackleBox CastBar.lua:31-33
  local g = t:CreateAnimationGroup()
  local a = g:CreateAnimation("Alpha"); a:SetFromAlpha(0); a:SetToAlpha(0.6); a:SetDuration(0.2); a:SetOrder(1)
  local b = g:CreateAnimation("Alpha"); b:SetFromAlpha(0.6); b:SetToAlpha(0); b:SetDuration(0.6); b:SetOrder(2)
  g:SetScript("OnFinished", function() t:SetAlpha(0) end)
  return g
end
function BC.Pop(f) -- WCK Panel.lua:100-105
  if not f.pop then
    local g = f:CreateAnimationGroup()
    local up = g:CreateAnimation("Scale"); up:SetScaleFrom(1, 1); up:SetScaleTo(1.25, 1.25); up:SetDuration(0.12); up:SetOrder(1)
    local dn = g:CreateAnimation("Scale"); dn:SetScaleFrom(1.25, 1.25); dn:SetScaleTo(1, 1); dn:SetDuration(0.18); dn:SetOrder(2)
    f.pop = g
  end
  f.pop:Stop(); f.pop:Play()
end
function BC.Spin(t, seconds) -- WCK Panel.lua:88-92
  local g = t:CreateAnimationGroup(); g:SetLooping("REPEAT")
  local r = g:CreateAnimation("Rotation"); r:SetDegrees(-360); r:SetDuration(seconds or 1.2)
  return g
end
function BC.Sheen(f) -- FDJ RPGMode.lua:656-685: Translation inside a clipping frame
  local clip = CreateFrame("Frame", nil, f); clip:SetAllPoints(); clip:SetClipsChildren(true)
  clip:SetFrameLevel(f:GetFrameLevel() + 5)
  local L = clip:CreateTexture(nil, "OVERLAY"); L:SetSize(40, 400); L:SetPoint("RIGHT", clip, "LEFT", 0, 0)
  BC.Fade(L, "HORIZONTAL", BC.THEME.goldBright, 0, 0.35); L:SetBlendMode("ADD"); L:SetRotation(math.rad(-20))
  local R = clip:CreateTexture(nil, "OVERLAY"); R:SetSize(40, 400); R:SetPoint("LEFT", L, "RIGHT")
  BC.Fade(R, "HORIZONTAL", BC.THEME.goldBright, 0.35, 0); R:SetBlendMode("ADD"); R:SetRotation(math.rad(-20))
  L:Hide(); R:Hide()
  local groups = {}
  for i, t in ipairs({ L, R }) do
    local g = t:CreateAnimationGroup(); local m = g:CreateAnimation("Translation"); m:SetDuration(0.9); m:SetSmoothing("IN_OUT")
    g:SetScript("OnFinished", function() t:Hide() end); groups[i] = { g = g, m = m, t = t }
  end
  return { Play = function()
    for _, x in ipairs(groups) do x.m:SetOffset(f:GetWidth() + 120, 0); x.t:Show(); x.g:Stop(); x.g:Play() end
  end }
end
```

`SetRotation` on a gradient texture gives a slanted beam. If it renders oddly, drop the two `SetRotation` calls.

#### 2. New-row detection
**File**: `BC/Logic.lua`
**Action**: modify (append)

```lua
-- names whose ad is newer than lastAt; first render (lastAt nil) flashes nothing
function BC.NewSince(rows, lastAt)
  local out, maxAt = {}, lastAt or 0
  for _, v in ipairs(rows) do
    if lastAt and (v.at or 0) > lastAt then out[v.name] = true end
    if (v.at or 0) > maxAt then maxAt = v.at end
  end
  return out, maxAt
end
```

#### 3. Hooks
**File**: `BC/Panel.lua`
**Action**: modify

- Add file locals `local lastAt, flash = nil, {}`.
- In `BC.RenderSeen`, before `SetDataProvider`:
  ```lua
  local new; new, lastAt = BC.NewSince(rows, lastAt)
  for n in pairs(new) do flash[n] = true end
  ```
- In `BuildRow`, add `row.glow`: an OVERLAY `SetAllPoints` texture with `BC.Fade(glow,"HORIZONTAL",T.goldBright,0.5,0)`, alpha 0, and `row.flash = BC.Flash(row.glow)`.
- In `InitRow`, add `if flash[v.name] then flash[v.name] = nil; row.flash:Play() end`. This plays once per new ad, even if the row is re-initialised by scrolling.
- Row hover brightening is already covered by the HIGHLIGHT gradient from Phase 2. No further change.

**File**: `BC/Card.lua`
**Action**: modify

- In `BC.Pill`, add `b.breathe = BC.Breathe(b.dot)`. In `SetStatus`, add `if st == "a" then self.breathe:Play() else self.breathe:Stop(); self.dot:SetAlpha(1) end`. Do the same for the service-button dots.
- **Card hover:** in `NewCard`, set OnEnter to `self:SetBackdropBorderColor(unpack(T.goldBright))` and OnLeave to restore `T.gold`. Do the same for pills (restore their status colour) and service buttons. Use `HookScript` so existing tooltips keep working.
- **Pop on click:** in the pill OnClick, call `BC.Pop(self)` before `parent.onPill`. Service buttons call `BC.Pop(btn)` too.
- **Sheen:** in `NewCard`, add `card.sheen = BC.Sheen(card)`. In `BC.RefreshDetail`:
  ```lua
  local rev = card and card.rev
  if detail.shownWho == who and rev and detail.shownRev ~= rev then detail.card.sheen.Play() end
  detail.shownWho, detail.shownRev = who, rev
  ```
  It plays when a card arrives or updates while that player's detail is open, and not on first open of a player who already has a card. **Exception:** it also plays when the first card arrives after "No card", because `shownRev` is nil then and `rev` is set. That is intended.

#### 4. Tests
**File**: `BC/tests/run.lua`
**Action**: modify

```lua
-- UI redesign P5
local nr = { { name = "A", at = 10 }, { name = "B", at = 20 } }
local ns, mx = BC.NewSince(nr, nil); eq(next(ns), nil, "first render flashes nothing"); eq(mx, 20, "max at tracked")
ns, mx = BC.NewSince({ { name = "C", at = 25 }, nr[1], nr[2] }, 20)
eq(ns.C, true, "newer ad flagged"); eq(ns.B, nil, "old ad not flagged"); eq(mx, 25, "max advances")
```

### Verification
#### Automated
- [x] `lua tests/run.lua` prints `all tests passed`.

#### Manual
- [x] Leave the window open on Seen. A new trade-chat ad's row flashes gold once and doesn't flash again on later refreshes or when scrolled past.
- [x] On My card, green dots breathe, while busy and off dots stay still.
- [x] Clicking a pill pops it. Hovering the card or a pill brightens its border.
- [x] Open the detail for a guildmate, then have them toggle their status. The sheen sweeps across their card once.
- [x] With the window closed, frame rate is unchanged (check with `/framerate` before and after opening and closing the window).
- [x] No Lua errors over 10 minutes of normal play.

---

## Testing Checkpoints
- **P1:** ledger chrome, tabs, close button, position save. Old rows inside the new frame.
- **P2:** the Seen list scrolls with icon rows and status dots. My card is a temporary list.
- **P3:** My card is a business card with a portrait, skill bars and pills, and status changes still go out to other players.
- **P4:** the detail view uses the card widget, with icon tabs, a scrolling and searchable recipe list, and state icons.
- **P5:** flash, breathe, pop, hover glow and sheen.
- **Every phase:** tests pass, a CHANGELOG entry is added, the `.toc` version is bumped, the change is committed and deployed, and `/reload` shows no errors.
