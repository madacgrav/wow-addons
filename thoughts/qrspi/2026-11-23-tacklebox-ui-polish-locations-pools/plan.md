# Implementation Plan

## Overview
TackleBox 1.2.0: polished panel, a Spots tab (best zones for your skill + nearest learned pools with waypoint), pools learned while fishing and saved account-wide, pools pinned on world map and minimap (HereBeDragons-Pins), and a soft-interact/tooltip pool detector.

## Conventions (every phase)
- Lint: `bash D:/Source/wowskill/skills/wow-forever-addon/scripts/lint.sh D:/Source/wow-addons/TackleBox` (already excludes `Libs/**`).
- Tests: `lua D:/Source/wow-addons/TackleBox/tests/run.lua` prints `all tests passed` (CI runs it with lua5.1, so no 5.2+ syntax).
- Deploy after tests pass and the phase commits:
  `robocopy "D:\Source\wow-addons\TackleBox" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\TackleBox" /MIR /XD tests /NJH /NJS /NP /NDL` (exit 0-7 is success). Then the user runs `/reload`.
- Constraints: Interface 16001 (unchanged in `TackleBox.toc:1`); no never-emit names (`references/forever-api-notes.md`); every new API name grepped in `references/forever-api-index.md` (globals/events) or `templates/luacheck/forever-std.lua` (FrameXML). Already checked: `UnitExists`, `UnitIsGameObject`, `UnitGUID`, `GetPlayerFacing`, `C_Map.*`, `C_SuperTrack.SetSuperTrackedUserWaypoint`, `PLAYER_SOFT_INTERACT_CHANGED` (index); `UiMapPoint`, `WorldMapFrame`, `MapCanvasDataProviderMixin` (std). Not in either, added to `.luacheckrc`: `LibStub`, `GameTooltipTextLeft1`, `HBD_PINS_WORLDMAP_SHOW_PARENT`.
- Pure logic goes in `Logic.lua` and gets `eq` tests in `tests/run.lua`; WoW calls go in `Core.lua` / `Map.lua` / `Panel.lua`.
- Commit each phase after lint + tests pass.

---

## Phase 1: Probe pools, position, map hooks

### Changes

#### 1. Probe additions
**File**: `TackleBox/Core.lua`
**Action**: modify

Trace soft-interact changes and the soft-interact name at each channel start. Put this after the existing `Trace` helper (`Core.lua:94`):
```lua
local function SoftName()
  local ok, n = pcall(function()
    if UnitExists("softinteract") then return (UnitIsGameObject("softinteract") and "obj " or "unit ") .. tostring(UnitName("softinteract")) end
  end)
  if not ok then return "ERR" end
  if TB.Secret(n) then return "SECRET" end
  return n or "none"
end
TB.On("PLAYER_SOFT_INTERACT_CHANGED", function(_, new) Trace("SOFT", TB.Secret(new) and "SECRET" or tostring(new) .. " " .. SoftName()) end)
TB.On("UNIT_SPELLCAST_CHANNEL_START", function(unit) if unit == "player" then Trace("SOFT@CAST", SoftName()) end end)
```

In `TB.Probe()`, insert these after the `zone` line (`Core.lua:198`):
```lua
Try("softinteract", function()
  P("softinteract", tostring(UnitExists("softinteract")) .. " obj " .. tostring(UnitIsGameObject("softinteract"))
    .. " name " .. S(UnitName("softinteract")) .. " guid " .. S(UnitGUID("softinteract")))
end)
Try("tooltip", function() P("tooltip", tostring(GameTooltip:IsShown()) .. " " .. S(GameTooltipTextLeft1:GetText())) end)
Try("cvar", function() P("SoftTargetInteract", tostring(C_CVar.GetCVar("SoftTargetInteract"))) end)
Try("map", function()
  local m = C_Map.GetBestMapForUnit("player")
  local pos = m and C_Map.GetPlayerMapPosition(m, "player")
  P("map", tostring(m) .. " pos " .. (pos and (S(pos.x) .. "," .. S(pos.y)) or "nil") .. " facing " .. S(GetPlayerFacing()))
end)
P("map hooks", "AddDataProvider " .. type(WorldMapFrame and WorldMapFrame.AddDataProvider) .. " mixin " .. type(MapCanvasDataProviderMixin))
```

#### 2. Lint globals
**File**: `TackleBox/.luacheckrc`
**Action**: modify. Change the loop list to include `"GameTooltipTextLeft1"`, `"LibStub"` and `"HBD_PINS_WORLDMAP_SHOW_PARENT"`, with a comment that they are FrameXML/lib globals missing from the std.

#### 3. HereBeDragons licence check (offline)
Read the LICENSE (or the header and CurseForge page) for https://github.com/Nevcairiel/HereBeDragons, and for Ace3's LibStub and CallbackHandler-1.0 (https://github.com/WoWUIDev/Ace3).
- Record the result in `probe-results.md`.
- If HereBeDragons forbids redistribution in an addon zip, **stop and ask the user** before Phase 4.

#### 4. Results
**File**: `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md`
**Action**: append a "Run 6: pools, position, map hooks" section with the pasted `TackleBoxDB.lastProbe` lines and the licence result.

### Verification
#### Automated
- [x] Lint clean
- [x] Tests pass (no logic change)

#### Manual
- [x] Deployed with robocopy
- [x] `/reload` with no errors
- [x] Stand facing a pool and run `/tb probe`: softinteract false; pools are not soft-interact targets (probe B)
- [x] Mouse over the pool and `/tb probe`. `tooltip` line shows the pool name.
- [ ] Cast at the pool, catch, `/tb probe`. Trace shows `SOFT@CAST obj <pool name>`.
- [x] `map` line shows a numeric map and position outdoors; `map hooks` shows `function table`
- [x] Results pasted into probe-results.md
- [x] **Gate**: at least one of softinteract / tooltip returns the plain pool name. If neither does, stop and revisit design decision 1.
- [x] Licence recorded; redistribution allowed

---

## Phase 2: Panel polish

### Changes
**File**: `TackleBox/Panel.lua`
**Action**: modify

#### 1. Layout constants (replace `Panel.lua:2-4`)
```lua
-- HEAD = collapsed height; the tab strip starts at -HEAD; TOP = first row's y
local WIDTH, ROW_W, PAD, TAB_H, HEAD = 320, 296, 12, 34, 100
local TOP = HEAD + TAB_H + PAD               -- 146
local PITCH, ROW_H = 26, 24                  -- row spacing and height
local SKILL_Y, ZONE_Y = -58, -86             -- skill bar top; zone line centre
local VISIBLE, LIST_W = 10, ROW_W - 20
```
Replace the literals with these constants:
- `12` (left/right content) → `PAD`
- `-58` → `SKILL_Y`; `-65` → `SKILL_Y - 7`
- `-86` → `ZONE_Y`; `-100` → `-HEAD`
- `-TOP + 8` stays
- `26` → `PITCH`; `24` → `ROW_H`; `3 * 26` → `3 * PITCH`

#### 2. Theme entries
```lua
TB.THEME.muted = { 0.6, 0.6, 0.6 }  -- inactive labels, empty text
TB.THEME.hi = 0.10                  -- hover alpha for rows and tabs
```
- Use `T.muted` at `Panel.lua:195`, `:233` and `:327`.
- Use `T.hi` at `:154` (was .08) and `:177` (was .12).

#### 3. Close button
`close:SetPoint("TOPRIGHT", -4, -4)` (matches `BusinessCard/Panel.lua:108`).

#### 4. Title font
Add after `Fade`:
```lua
-- display font with fallback (pattern: BusinessCard/Skin.lua:96-97)
function TB.TitleFont(fs, size)
  if not fs:SetFont("Fonts\\MORPHEUS.ttf", size or 18, "") then fs:SetFontObject("GameFontNormalLarge") end
  fs:SetShadowOffset(1, -1)
end
```
Call `TB.TitleFont(panel.title)` right after creating `panel.title` (before `SetTextColor`).

#### 5. Header band
In `Build`, after the glow:
```lua
local band = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
band:SetPoint("TOPLEFT", 4, -4); band:SetPoint("TOPRIGHT", -4, -4); band:SetHeight(-SKILL_Y - 4)
Fade(band, T.shallows[1], T.shallows[2], T.shallows[3], 0.35, 0)
```

#### 6. Row icon border
In `GetRow`, before the icon:
```lua
row.frame = row:CreateTexture(nil, "BORDER"); row.frame:SetSize(22, 22); row.frame:SetPoint("LEFT", 1, 0)
row.frame:SetColorTexture(T.rope[1], T.rope[2], T.rope[3], 0.6)
```
In `RenderPanel`, `row.frame:SetShown(not v.empty)` next to `row.icon:SetShown`.

#### 7. Empty state
- In `Build`, create `panel.emptyIcon` (32x32, ARTWORK, desaturated, alpha .5) anchored to `TOP` of `panel.scroll` at 0,-6.
- Also create `panel.emptyText` (`GameFontDisableSmall`, `T.muted`) under it, at 0,-4.

In `RenderPanel`:
```lua
local empty = n == 1 and rows[1].empty
local activeTab; for _, s in ipairs(tabs) do if s.key == active then activeTab = s end end
panel.emptyIcon:SetShown(exp and empty); panel.emptyText:SetShown(exp and empty)
if empty then
  panel.emptyIcon:SetTexture(activeTab and activeTab.icon); panel.emptyText:SetText(rows[1].text)
  if panel.rows[1] then panel.rows[1]:Hide() end
end
```
Run this after the row loop, so the row loop still runs and the placeholder row then gets hidden.

#### 8. Six-tab strip
In `MakeTab`, when `n >= 6`:
- hide `t.label`;
- re-anchor `t.icon` to `CENTER, 0, 1`, size 18.

The tooltip already shows `self.title`.

**File**: `TackleBox/CastBar.lua`. No change needed unless a literal grey appears; leave it alone otherwise.

### Verification
#### Automated
- [x] Lint clean
- [x] Tests pass

#### Manual
- [x] Deployed with robocopy
- [ ] `/reload`
- [ ] Collapsed panel: title in MORPHEUS, header band, skill bar and zone line aligned as before
- [ ] Expanded: tab strip, rule and rows aligned; `/fstack` shows no overlaps
- [ ] An empty tab (e.g. Water with no items) shows a centred icon and text
- [ ] Row and tab hover look the same strength; close button sits inside the border
- [ ] Collapse, expand and `/reload` keep the state

---

## Phase 3: Spots tab (static data) + Forever zone bands

### Changes

#### 1. Data
**File**: `TackleBox/Data.lua`
**Action**: modify

Replace `zones` (`Data.lua:15-26`):
```lua
-- third-party: Gfinity Forever fishing guide 2026-10-22 tiers (band = skill to fish without get-aways there).
-- Forever-only zone names unverified in game. ponytail: enUS names; locale table if non-English clients matter
zones = {
  { band = 1, max = 55, names = { "Elwynn Forest", "Dun Morogh", "Teldrassil", "Durotar", "Mulgore", "Tirisfal Glades",
    "Stormwind City", "Ironforge", "Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity", "Zephras Isle" } },
  { band = 55, max = 135, names = { "Westfall", "Loch Modan", "Darkshore", "The Barrens", "Silverpine Forest", "Redridge Mountains" } },
  { band = 135, max = 205, names = { "Wetlands", "Ashenvale", "Hillsbrad Foothills", "Stonetalon Mountains", "Duskwood", "The Riverglades" } },
  -- old-guide band (not in Gfinity): kept so these zones still list
  { band = 150, max = 225, names = { "Swamp of Sorrows", "Thousand Needles", "Alterac Mountains" } },
  { band = 205, max = 275, names = { "Stranglethorn Vale", "Arathi Highlands", "Desolace", "Dustwallow Marsh", "Feralas", "The Hinterlands", "Shen'Dralas" } },
  -- max 301 so capped anglers still see the top tier; lure = 75 kept from the old Classic band
  { band = 275, max = 301, lure = 75, names = { "Tanaris", "Azshara", "Felwood", "Un'Goro Crater", "Winterspring",
    "Western Plaguelands", "Eastern Plaguelands", "Mount Hyjal" } },
},
```

Add after `lures`:
```lua
-- third-party: warcraft.wiki.gg Fishing_Pool (Classic) + WarcraftTavern Classic loot list; Forever placement unverified
pools = {
  { key = "oily", name = "Oily Blackmouth School", loot = "Oily Blackmouth", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
  { key = "firefin", name = "Firefin Snapper School", loot = "Firefin Snapper", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
  { key = "mixed", name = "Mixed Ocean School", loot = "Firefin Snapper", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
  { key = "eel", name = "Stonescale Eel Swarm", loot = "Stonescale Eel", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
  { key = "sage", name = "Sagefish School", loot = "Raw Sagefish", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
  { key = "gsage", name = "Greater Sagefish School", loot = "Raw Greater Sagefish", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
  { key = "deviate", name = "School of Deviate Fish", loot = "Deviate Fish", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
  { key = "oilspill", name = "Oil Spill", loot = "Firefin Snapper", icon = "Interface\\Icons\\INV_Misc_Fish_02" },
  { key = "debris", name = "Floating Debris", loot = "Tightly Sealed Trunk", icon = "Interface\\Icons\\INV_Box_02" },
  { key = "wreck", name = "Floating Wreckage", loot = "Mithril Bound Trunk", icon = "Interface\\Icons\\INV_Box_02" },
  { key = "bloodsail", name = "Bloodsail Wreckage", loot = "Mithril Bound Trunk", icon = "Interface\\Icons\\INV_Box_02" },
  { key = "waterlog", name = "Waterlogged Wreckage", loot = "Iron Bound Trunk", icon = "Interface\\Icons\\INV_Box_02" },
  { key = "schooner", name = "Schooner Wreckage", loot = "Watertight Trunk", icon = "Interface\\Icons\\INV_Box_02" },
},
-- zone -> notable catches and pool keys; same sources as pools
spots = {
  ["Darkshore"] = { notable = { "Darkshore Grouper", "Oily Blackmouth" }, pools = { "oily", "debris" } },
  ["Westfall"] = { notable = { "Oily Blackmouth" }, pools = { "debris" } },
  ["Silverpine Forest"] = { notable = { "Sickly Looking Fish", "Oily Blackmouth" }, pools = { "sage", "debris" } },
  ["The Barrens"] = { notable = { "Deviate Fish", "Oil Covered Fish", "Oily Blackmouth" }, pools = { "deviate", "debris" } },
  ["Redridge Mountains"] = { notable = { "Spotted Sunfish" }, pools = { "debris" } },
  ["Wetlands"] = { notable = { "Firefin Snapper", "Oily Blackmouth" }, pools = { "oily", "sage", "schooner" } },
  ["Ashenvale"] = { notable = { "Raw Sagefish", "Oily Blackmouth" }, pools = { "oily", "sage", "schooner" } },
  ["Hillsbrad Foothills"] = { notable = { "Firefin Snapper", "Oily Blackmouth" }, pools = { "oily", "schooner" } },
  ["Stonetalon Mountains"] = { notable = { "Firefin Snapper", "Oil Covered Fish" }, pools = { "oilspill", "schooner" } },
  ["Duskwood"] = { notable = { "Raw Sagefish" }, pools = { "sage", "debris" } },
  ["Swamp of Sorrows"] = { notable = { "Misty Reed Mahi Mahi", "Stonescale Eel" }, pools = { "oily", "eel" } },
  ["Thousand Needles"] = { notable = { "Stonescale Eel" }, pools = { "eel" } },
  ["Stranglethorn Vale"] = { notable = { "Savage Coast Blue Sailfin", "Stonescale Eel", "Firefin Snapper" }, pools = { "mixed", "sage", "wreck", "bloodsail" } },
  ["Arathi Highlands"] = { notable = { "Firefin Snapper", "Oily Blackmouth" }, pools = { "oily" } },
  ["Desolace"] = { notable = { "Sar'theris Striker", "Firefin Snapper" }, pools = { "oily", "waterlog" } },
  ["Dustwallow Marsh"] = { notable = { "Firefin Snapper", "Oily Blackmouth" }, pools = { "waterlog" } },
  ["Feralas"] = { notable = { "Feralas Ahi", "Lightning Eel", "Plated Armorfish", "Stonescale Eel" }, pools = { "waterlog" } },
  ["The Hinterlands"] = { notable = { "Lightning Eel" }, pools = {} },
  ["Tanaris"] = { notable = { "Stonescale Eel", "Firefin Snapper" }, pools = { "oily", "eel" } },
  ["Azshara"] = { notable = { "Darkclaw Lobster", "Lightning Eel", "Stonescale Eel" }, pools = { "oily", "eel", "debris" } },
  ["Felwood"] = { notable = { "Lightning Eel" }, pools = {} },
  ["Un'Goro Crater"] = { notable = { "Lightning Eel" }, pools = {} },
  ["Winterspring"] = { notable = { "Lightning Eel", "Plated Armorfish" }, pools = {} },
  ["Western Plaguelands"] = { notable = { "Lightning Eel", "Raw Greater Sagefish" }, pools = { "gsage", "waterlog" } },
  ["Eastern Plaguelands"] = { notable = { "Lightning Eel", "Plated Armorfish" }, pools = { "gsage" } },
},
```

#### 2. Logic
**File**: `TackleBox/Logic.lua`
**Action**: add
```lua
function TB.PoolByKey(pools, key) for _, p in ipairs(pools) do if p.key == key then return p end end end
function TB.PoolKey(name, pools) for _, p in ipairs(pools) do if p.name == name then return p.key end end end

-- spot rows for zones whose band holds the base skill; current zone first even when out of band
function TB.SpotsRows(spots, zones, pools, skill, current)
  if not skill then return {} end
  local rows, seen = {}, {}
  local function add(name)
    local s = spots[name]
    if not s or seen[name] then return end
    seen[name] = true
    local pnames, icon = {}, nil
    for _, k in ipairs(s.pools) do local p = TB.PoolByKey(pools, k); if p then pnames[#pnames + 1] = p.name; icon = icon or p.icon end end
    local sub = table.concat(s.notable, ", ")
    if #pnames > 0 then sub = sub .. " - " .. table.concat(pnames, ", ") end
    rows[#rows + 1] = { text = name .. (name == current and " [here]" or ""), sub = sub, icon = icon or "Interface\\Icons\\INV_Misc_Fish_02", zone = name }
  end
  add(current)
  for _, z in ipairs(zones) do
    if skill.level >= z.band and skill.level < z.max then for _, n in ipairs(z.names) do add(n) end end
  end
  return rows
end
```

#### 3. Section
**File**: `TackleBox/Panel.lua`
**Action**: add a section after `catch` (order: quest, where, camp, water, catch, spots).
```lua
table.insert(TB.sections, { key = "spots", title = "Best spots", tab = "Spots", empty = "No spot data for your skill yet.", icon = "Interface\\Icons\\INV_Misc_Spyglass_01", build = function()
  return TB.SpotsRows(TB.DATA.spots, TB.DATA.zones, TB.DATA.pools, TB.skill, GetRealZoneText())
end })
```
Sub lines can be long. Add a tooltip that shows the full sub: in `GetRow` `OnEnter`, when there is no `itemID` but `self.full` is set, show `self.full` wrapped. Set `row.full = v.sub` in `RenderPanel`, only for rows that have `v.zone`.

#### 4. Tests
**File**: `TackleBox/tests/run.lua`
**Action**: modify
- Update `tests/run.lua:39`: `eq(#TB.WhereRows(TB.DATA.zones, TB.DATA.lures, { level = 2, modifier = 25 }, "Orgrimmar"), 13, "real data: 13 starter zones incl. Orgrimmar")`.
- Add:
```lua
-- Spots
local SP = { A = { notable = { "Eel" }, pools = { "p1" } }, B = { notable = { "Cod" }, pools = {} }, C = { notable = { "Ray" }, pools = {} } }
local SZ = { { band = 1, max = 50, names = { "A", "B" } }, { band = 50, max = 100, names = { "C" } } }
local SPools = { { key = "p1", name = "Eel Swarm", icon = "i" } }
local sr = TB.SpotsRows(SP, SZ, SPools, { level = 10 }, "C")
eq(sr[1].text, "C [here]", "current zone first"); eq(#sr, 3, "band zones + current")
eq(sr[2].sub, "Eel - Eel Swarm", "notable + pool names"); eq(sr[2].icon, "i", "pool icon")
eq(#TB.SpotsRows(SP, SZ, SPools, nil, "A"), 0, "no skill")
eq(#TB.SpotsRows(SP, SZ, SPools, { level = 10 }, "Nowhere"), 2, "unknown current zone skipped")
eq(TB.PoolKey("Eel Swarm", SPools), "p1", "pool key"); eq(TB.PoolKey("x", SPools), nil, "no pool key")
for name, s in pairs(TB.DATA.spots) do for _, k in ipairs(s.pools) do assert(TB.PoolByKey(TB.DATA.pools, k), name .. " pool " .. k) end end
```
- Check the existing `ZoneStatus` tests still pass with the new bands. They use synthetic data; any that use `TB.DATA.zones` get updated to the new bands.

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass, including the Spots tests and the data integrity loop

#### Manual
- [ ] Deployed
- [ ] `/reload`
- [ ] 6 tabs, icon-only; Spots tab lists zones for current skill, with the current zone first if it has data
- [ ] Hovering a spot row shows the full text
- [ ] Where tab shows the new bands; zone line still coloured

---

## Phase 4: Learn pools + nearby list + waypoint

### Changes

#### 1. Libraries
**Files**: `TackleBox/Libs/LibStub/LibStub.lua`, `TackleBox/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua` (from https://github.com/WoWUIDev/Ace3), `TackleBox/Libs/HereBeDragons/HereBeDragons-2.0.lua`, `HereBeDragons-Pins-2.0.lua` (+ LICENSE if present; from https://github.com/Nevcairiel/HereBeDragons at its latest tag)
**Action**: create (vendored copies)
- Fetch with `git clone --depth 1` into the scratchpad, then copy only these files.
- Ask the user before fetching.

**File**: `TackleBox/TackleBox.toc`
**Action**: modify. Add before `Data.lua`:
```
Libs\LibStub\LibStub.lua
Libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
Libs\HereBeDragons\HereBeDragons-2.0.lua
Libs\HereBeDragons\HereBeDragons-Pins-2.0.lua
```
`.github/workflows/package-tb.yml` zips all of `TackleBox/` except `tests/`, so `Libs/` ships with no workflow change.

#### 2. Saved variables
**File**: `TackleBox/Core.lua`
**Action**: modify `DEFAULTS` (`Core.lua:17`):
```lua
-- version 2: pools/pins/detect added; nothing to convert from v1, MergeDefaults fills them. Bump + migrate here on schema change.
local DEFAULTS = { version = 2, locked = false, shown = true, frames = {}, minimapAngle = 200, tab = "where", flash = true, expanded = false,
  pools = {}, pins = { map = true, minimap = true }, detect = true }
```
`pools[uiMapID] = { {x, y, t = poolKey, n, last} }`, with x and y as 0-1 zone coordinates.

#### 3. Pure logic
**File**: `TackleBox/Logic.lua`
**Action**: add
```lua
local function Yards(ax, ay, bx, by, w, h) return math.sqrt(((ax - bx) * w) ^ 2 + ((ay - by) * h) ^ 2) end

-- facing: GetPlayerFacing radians, 0 = north, counter-clockwise; zone y grows south, x grows east
function TB.OffsetPos(x, y, facing, yards, w, h)
  return x - math.sin(facing) * yards / w, y - math.cos(facing) * yards / h
end

-- same type within radius yards: average into it; else append. ponytail: linear scan, fine for hundreds per map
function TB.MergePool(list, x, y, t, now, radius, w, h)
  for _, p in ipairs(list) do
    if p.t == t and Yards(p.x, p.y, x, y, w, h) <= radius then
      p.x, p.y = (p.x * p.n + x) / (p.n + 1), (p.y * p.n + y) / (p.n + 1)
      p.n, p.last = p.n + 1, now
      return list, false
    end
  end
  list[#list + 1] = { x = x, y = y, t = t, n = 1, last = now }
  return list, true
end

function TB.NearestPools(list, px, py, w, h, max)
  local out = {}
  for _, p in ipairs(list) do out[#out + 1] = { pool = p, yd = Yards(p.x, p.y, px, py, w, h) } end
  table.sort(out, function(a, b) return a.yd < b.yd end)
  for i = #out, (max or 10) + 1, -1 do out[i] = nil end
  return out
end
```

#### 4. Reading, position, learning
**File**: `TackleBox/Core.lua`
**Action**: add near the catch-tracking block
```lua
TB.HBD = LibStub("HereBeDragons-2.0")
TB.POOL_OFFSET, TB.POOL_MERGE = 15, 15 -- yards; tune if one pool splits or two merge

-- pool under soft-interact, else the world tooltip; nil when secret or not a known pool (Phase 1 probe)
function TB.ReadPoolTarget()
  local ok, n = pcall(function() if UnitExists("softinteract") and UnitIsGameObject("softinteract") then return UnitName("softinteract") end end)
  if ok and n and not TB.Secret(n) and TB.PoolKey(n, TB.DATA.pools) then return n end
  if GameTooltip:IsShown() then
    local t = GameTooltipTextLeft1:GetText()
    if t and not TB.Secret(t) and TB.PoolKey(t, TB.DATA.pools) then return t end
  end
end

-- probe 6B: pools never become softinteract, the name only shows in the hover tooltip. Remember the last
-- hovered pool so a cast within 60 s of hovering still learns it (one-key cast users rarely hover at cast time).
TB.lastHover = nil -- { name, t }
table.insert(TB.inits, function()
  GameTooltip:HookScript("OnShow", function()
    local t = GameTooltipTextLeft1:GetText()
    if t and not TB.Secret(t) and TB.PoolKey(t, TB.DATA.pools) then TB.lastHover = { name = t, t = GetTime() } end
  end)
end)
-- ReadPoolTarget falls back to: if TB.lastHover and GetTime() - TB.lastHover.t < 60 then return TB.lastHover.name end

function TB.PlayerPos()
  local x, y, map = TB.HBD:GetPlayerZonePosition()
  if not x or TB.Secret(x) or not map then return end
  return x, y, map
end

TB.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if unit ~= "player" or not IsFishing(spellID) then TB.castPool = nil return end
  local name = TB.ReadPoolTarget()
  local x, y, map = TB.PlayerPos()
  TB.castPool = name and x and { key = TB.PoolKey(name, TB.DATA.pools), x = x, y = y, map = map, facing = GetPlayerFacing() } or nil
end)

function TB.LearnPool()
  local c = TB.castPool; TB.castPool = nil
  if not c or TB.Secret(c.facing) then return end
  local w, h = TB.HBD:GetZoneSize(c.map)
  if not w or w == 0 then return end
  local x, y = TB.OffsetPos(c.x, c.y, c.facing or 0, TB.POOL_OFFSET, w, h)
  TB.db.pools[c.map] = TB.db.pools[c.map] or {}
  local _, isNew = TB.MergePool(TB.db.pools[c.map], x, y, c.key, time(), TB.POOL_MERGE, w, h)
  if isNew then TB.Print("learned " .. TB.PoolByKey(TB.DATA.pools, c.key).name) end
  if TB.Pins then TB.Pins.Refresh() end
end
```
- Place the `CHANNEL_START` handler after the `IsFishing` local (`Core.lua:121`).
- In the catch `LOOT_READY` handler (`Core.lua:145-161`), call `TB.LearnPool()` right after `looted = true`. That handler already gates on `IsFishingCatch`, so only confirmed fishing loot learns.

#### 5. Waypoint + Spots nearby section
**File**: `TackleBox/Core.lua`
**Action**: add
```lua
function TB.Waypoint(map, x, y)
  if not C_Map.CanSetUserWaypointOnMap(map) then return TB.Print("can't set a waypoint on this map") end
  C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
  C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end
-- nearby distances go stale as you walk; refresh only while the Spots tab is on screen
table.insert(TB.inits, function()
  C_Timer.NewTicker(2, function() if TB.db.shown and TB.db.expanded and TB.db.tab == "spots" then TB.Refresh() end end)
end)
```
(The design said "ticker cancelled otherwise". A 2 s check-and-skip costs the same and is simpler.)

**File**: `TackleBox/Panel.lua`
**Action**: modify
- Spots `build` appends the nearby section:
```lua
local rows = TB.SpotsRows(TB.DATA.spots, TB.DATA.zones, TB.DATA.pools, TB.skill, GetRealZoneText())
local x, y, map = TB.PlayerPos()
local list, w, h = map and TB.db.pools[map], nil, nil
if map then w, h = TB.HBD:GetZoneSize(map) end
if not map then rows[#rows + 1] = { header = true, text = "No map position here" }
elseif list and #list > 0 and w and w > 0 then
  rows[#rows + 1] = { header = true, text = "Nearby pools" }
  for _, n in ipairs(TB.NearestPools(list, x, y, w, h, 10)) do
    local p, info = n.pool, TB.PoolByKey(TB.DATA.pools, n.pool.t)
    rows[#rows + 1] = { text = info and info.name or n.pool.t, sub = math.floor(n.yd) .. " yd - seen " .. p.n .. "x",
      icon = info and info.icon, hint = "Click: set waypoint", onClick = function() TB.Waypoint(map, p.x, p.y) end }
  end
end
return rows
```
- In `RenderPanel`, header rows:
  - `row.icon` and `row.frame` hidden;
  - text in `T.sand`; empty `sub`; no stripe (leave `stripe` unchanged);
  - `row.onClick = v.onClick`; `row.hint = v.hint`.
- In `GetRow`:
  - `row:SetScript("OnMouseUp", function(self, b) if b == "LeftButton" and self.onClick then self.onClick() end end)`.
  - `OnEnter` shows `self.hint` (white) when there is no `itemID` and no `full`.

#### 6. Tests
**File**: `TackleBox/tests/run.lua`
**Action**: add
```lua
-- Pools
local ox, oy = TB.OffsetPos(0.5, 0.5, 0, 10, 1000, 1000); eq(ox, 0.5, "north keeps x"); eq(oy, 0.49, "north moves up")
ox, oy = TB.OffsetPos(0.5, 0.5, math.pi / 2, 10, 1000, 1000); eq(math.floor(ox * 1000 + 0.5), 490, "west moves left")
local pl = {}
local _, new = TB.MergePool(pl, 0.5, 0.5, "eel", 1, 15, 1000, 1000); eq(new, true, "first pool new")
_, new = TB.MergePool(pl, 0.505, 0.5, "eel", 2, 15, 1000, 1000); eq(new, false, "5 yd merges"); eq(pl[1].n, 2, "count bumped"); eq(pl[1].last, 2, "last updated")
_, new = TB.MergePool(pl, 0.505, 0.5, "oily", 3, 15, 1000, 1000); eq(new, true, "other type separate")
_, new = TB.MergePool(pl, 0.6, 0.5, "eel", 4, 15, 1000, 1000); eq(new, true, "100 yd separate")
local near = TB.NearestPools(pl, 0.6, 0.5, 1000, 1000, 2); eq(#near, 2, "max respected"); eq(near[1].pool.x, 0.6, "nearest first")
```
`0.49` check: floating `0.5 - 10/1000`. If `eq` fails on float equality, compare `math.floor(oy * 1000 + 0.5) == 490`.

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass (Pools block)

#### Manual
- [ ] Deployed
- [ ] `/reload` with no errors; libs load (`/dump LibStub("HereBeDragons-2.0").GetPlayerZonePosition ~= nil`)
- [ ] Fish a pool: chat `learned <pool>`; Spots tab shows "Nearby pools" with distance
- [ ] Fish the same pool again: no new line, `seen 2x`
- [ ] Click a nearby row: waypoint appears and is super-tracked
- [ ] `/reload`: pool still listed (`/dump TackleBoxDB.version` = 2)
- [ ] Inside an instance or indoors: "No map position here", no errors

---

## Phase 5: Map pins

### Changes

#### 1. Map module
**File**: `TackleBox/Map.lua`
**Action**: create
```lua
local ADDON, TB = ...
local Pins = LibStub("HereBeDragons-Pins-2.0")
local T = TB.THEME
local frames, used = {}, 0
TB.Pins = {}

local function Acquire()
  used = used + 1
  local f = frames[used]
  if not f then
    f = CreateFrame("Frame", nil, UIParent); f:SetSize(14, 14)
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetAllPoints(); f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.name, T.sand[1], T.sand[2], T.sand[3]); GameTooltip:AddLine("seen " .. self.n .. "x", 1, 1, 1)
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)
    frames[used] = f
  end
  f:Show()
  return f
end

local function Fill(f, p)
  local info = TB.PoolByKey(TB.DATA.pools, p.t)
  f.name, f.n = info and info.name or p.t, p.n
  f.icon:SetTexture(info and info.icon or "Interface\\Icons\\INV_Misc_Fish_02")
  return f
end

-- ponytail: full rebuild on every change; fine for hundreds of pins, diff if it ever stutters
function TB.Pins.Refresh()
  Pins:RemoveAllWorldMapIcons(TB.Pins); Pins:RemoveAllMinimapIcons(TB.Pins)
  for i = 1, used do frames[i]:Hide() end
  used = 0
  local _, _, cur = TB.PlayerPos()
  for map, list in pairs(TB.db.pools) do
    for _, p in ipairs(list) do
      if TB.db.pins.map then Pins:AddWorldMapIconMap(TB.Pins, Fill(Acquire(), p), map, p.x, p.y, HBD_PINS_WORLDMAP_SHOW_PARENT) end
      if TB.db.pins.minimap and map == cur then Pins:AddMinimapIconMap(TB.Pins, Fill(Acquire(), p), map, p.x, p.y, false, false) end
    end
  end
end

table.insert(TB.inits, function()
  TB.HBD.RegisterCallback(TB.Pins, "PlayerZoneChanged", TB.Pins.Refresh)
  TB.Pins.Refresh()
end)
```

#### 2. TOC
**File**: `TackleBox/TackleBox.toc`. Add `Map.lua` after `Panel.lua`.

#### 3. Slash toggles
**File**: `TackleBox/Core.lua`
**Action**: modify `SlashCmdList.TACKLEBOX`
```lua
elseif cmd == "pins" then
  local which = (msg or ""):lower():match("^%s*%S+%s+(%S+)")
  if which ~= "map" and which ~= "minimap" then TB.Print("usage: /tb pins map||minimap")
  else TB.db.pins[which] = not TB.db.pins[which]; TB.Pins.Refresh(); TB.Print(which .. " pins " .. (TB.db.pins[which] and "on" or "off")) end
```
Add `pins map||minimap` to the help line.

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass

#### Manual
- [ ] Deployed
- [ ] `/reload`
- [ ] Learned pools show on the world map (current zone and parent continent) and the minimap; hover tooltip shows name + count
- [ ] Toggle the `rotateMinimap` option: pins stay in place relative to terrain
- [ ] `/tb pins map` and `/tb pins minimap` hide/show
- [ ] Open the world map in combat, close it, cast spells: no `ADDON_ACTION_BLOCKED` (BugSack)
- [ ] Learning a new pool adds a pin without `/reload`

---

## Phase 6: Pool detector

### Changes

#### 1. Logic
**File**: `TackleBox/Logic.lua`
```lua
function TB.ShouldAlert(last, key, now, cooldown)
  if last[key] and now - last[key] < cooldown then return false end
  last[key] = now
  return true
end
```

#### 2. Wiring
**File**: `TackleBox/Core.lua`
```lua
TB.alerts = {}
local function Detect()
  if not TB.active or not TB.db.detect or InCombatLockdown() then return end
  local name = TB.ReadPoolTarget()
  if name and TB.ShouldAlert(TB.alerts, name, GetTime(), 60) then
    TB.Print(name .. " nearby")
    if TB.db.flash then TB.Flash() end
  end
end
TB.On("PLAYER_SOFT_INTERACT_CHANGED", Detect)
table.insert(TB.inits, function() GameTooltip:HookScript("OnShow", Detect) end)
```
Slash: `elseif cmd == "detect" then TB.db.detect = not TB.db.detect; TB.Print("pool alerts " .. (TB.db.detect and "on" or "off"))`; add `detect` to the help line.

#### 3. Tests
**File**: `TackleBox/tests/run.lua`
```lua
local al = {}
eq(TB.ShouldAlert(al, "p", 0, 60), true, "first alert"); eq(TB.ShouldAlert(al, "p", 30, 60), false, "cooldown")
eq(TB.ShouldAlert(al, "q", 30, 60), true, "other pool"); eq(TB.ShouldAlert(al, "p", 61, 60), true, "after cooldown")
```

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass

#### Manual
- [ ] Deployed
- [ ] `/reload`
- [ ] Walk up to a pool (soft-interact) or mouse over it: one chat line + flash
- [ ] Again within 60 s: silent; after 60 s: alerts again
- [ ] In combat: silent
- [ ] `/tb detect` turns it off and back on

---

## Phase 7: Docs and release 1.2.0

### Changes
- **`TackleBox/TackleBox.toc`**: `## Version: 1.2.0`.
- **`TackleBox/CHANGELOG.md`**: `## 1.2.0` with:
  - panel polish;
  - Spots tab;
  - Forever zone bands;
  - learned pools + nearby + waypoint;
  - world map/minimap pins (HereBeDragons, with its licence noted);
  - pool detector;
  - new `/tb pins`, `/tb detect`.
- **`TackleBox/README.md`**: feature list and commands (`/tb pins map|minimap`, `/tb detect`). Note that pools are learned by fishing them and that alerts work best with Enable Interact Key on. Add a third-party data note and a library credits section.
- **`README.md`** (root): update the TackleBox one-liner to mention spots and pool map.
- **`docs/index.html`**: update the TackleBox entry's description in `ADDONS`.

### Verification
#### Automated
- [ ] Lint clean
- [ ] Tests pass
- [ ] `grep -n "pins\|detect" TackleBox/README.md` matches the `/tb` help line in `Core.lua`

#### Manual
- [ ] Deployed; `/reload`; `/tb help` text matches the README
- [ ] Local zip check: `cd D:/Source/wow-addons && zip -r -q "$TEMP/tb.zip" TackleBox -x 'TackleBox/tests/*' && unzip -l "$TEMP/tb.zip" | grep Libs` lists the four lib files
