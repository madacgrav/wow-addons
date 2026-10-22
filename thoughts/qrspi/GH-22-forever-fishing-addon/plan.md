# Implementation Plan

## Overview
New addon **TackleBox** (`TackleBox/`, namespace `TB`, slash `/tb`, CI tag `tb-v<ver>`) for WoW Forever. It shows one movable panel with these sections:
- Fishing skill
- Quest fish
- Where to fish
- Fish collection
- Camp buffs
- Water-walking

It also adds a cast timer bar and a "got away" flash. `/tb probe` captures the in-game facts the static data needs. Every ID in `Data.lua` must trace to a line in `probe-results.md`.

### Conventions (apply to every phase)
- **Header.** Every Lua file starts with `local ADDON, TB = ...`. Use 2-space indent and the terse one-line style of `WarlockUtilityKit/Core.lua`. A `ponytail:` comment names any deliberate ceiling.
- **Logic.lua stays pure.** No WoW API in it. Every decision function lives there and is tested in `TackleBox/tests/run.lua`.
- **Tests.**
  - Run with `lua5.1 TackleBox/tests/run.lua`. It must print `all tests passed`.
  - Lua 5.1 is not on PATH on this Windows box, so use whatever `lua5.1`/`lua` the earlier phases used. If none exists, rely on CI and note it.
- **Deploy after each phase** (tests pass, phase committed), before asking for an in-game check:
  `robocopy "D:\Source\wow-addons\TackleBox" "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\TackleBox" /MIR /XD tests /NJH /NJS /NP /NDL`
  Exit codes 0-7 mean success. The user then runs `/reload`.
- **Secret values.** Any value from an aura, a cast or a unit API passes through `TB.Secret(v)` before it is compared or used in arithmetic.

### Deviation from structure.md
- **Phase 5: the water-walk secure button is a standalone frame on UIParent** (movable, key `"water"`), not a child of the panel.
  - **Why.** A secure child makes its parent protected in combat. Show, Hide and SetHeight on the panel would then be blocked, and so would the collapse toggles. WUK has this exact limit: `/wuk show` is blocked in combat (`WarlockUtilityKit/Core.lua:225`).
  - **What the panel shows instead.** The Water section shows a text row that points at the button.

---

## Phase 1: Shell, skill line, probe, CI

### Changes

#### 1. TOC
**File**: `TackleBox/TackleBox.toc` — create
```
## Interface: 16001
## Title: TackleBox
## Notes: Forever fishing companion: skill, where to fish, quest fish, catches, camp buffs, water-walking.
## Version: 0.1.0
## IconTexture: Interface\Icons\Trade_Fishing
## SavedVariables: TackleBoxDB
## SavedVariablesPerCharacter: TackleBoxCharDB

Data.lua
Logic.lua
Core.lua
Panel.lua
```
Phase 3b appends `CastBar.lua` after `Panel.lua`.

#### 2. Data
**File**: `TackleBox/Data.lua` — create
```lua
local ADDON, TB = ...
-- Hand-maintained. Every ID must trace to a line in thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md
TB.DATA = {
  fishingSpells = { [7620] = true, [131474] = true }, -- probe confirms which fires on Forever
  castSeconds = 30,   -- fallback cast length when UnitChannelInfo is secret; set from probe
  questFish = {},     -- Phase 2
  zones = {}, lures = {}, -- Phase 2b
  fish = {},          -- Phase 3
  campBuffs = {},     -- Phase 4
  waterWalk = { items = {}, auras = {} }, -- Phase 5
}
```

#### 3. Logic
**File**: `TackleBox/Logic.lua` — create
- `TB.MergeDefaults`: copy verbatim from `WarlockUtilityKit/Logic.lua:16-23`.
- `TB.FormatTime`: copy verbatim from `WarlockUtilityKit/Logic.lua:38-40`.
- `TB.SkillText` and `TB.BuildView` are new:
```lua
function TB.SkillText(s)
  if not s then return "No Fishing skill" end
  local mod = (s.modifier or 0) > 0 and (" (+" .. s.modifier .. ")") or ""
  return "Fishing " .. s.level .. "/" .. s.max .. mod
end

-- sections = { {key, title, rows={...}} }; collapsed = {[key]=true}
-- flattens to panel rows; header rows carry .header=key so a click can toggle them
function TB.BuildView(sections, collapsed)
  local out = {}
  for _, s in ipairs(sections) do
    if #s.rows > 0 then
      local closed = collapsed[s.key]
      out[#out + 1] = { header = s.key, text = (closed and "+ " or "- ") .. s.title .. " (" .. #s.rows .. ")" }
      if not closed then for _, r in ipairs(s.rows) do out[#out + 1] = r end end
    end
  end
  return out
end
```

#### 4. Core
**File**: `TackleBox/Core.lua` — create

**Copied pieces**
- Copy `WarlockUtilityKit/Core.lua:3-17` for the inits/refreshers, `Secret`, `Print` and `On` pieces.
  - The Print prefix is `|cff3fa7d6TB|r`.
- ADDON_LOADED follows the same pattern as `WarlockUtilityKit/Core.lua:22-28`.
  - Keep the "Forever beta loader bug" comment.
  - Defaults:
```lua
local DEFAULTS = { locked = false, shown = true, frames = {}, minimapAngle = 200, collapsed = {}, flash = true }
local CHAR_DEFAULTS = { catches = {} }
```

**Debounced refresh**, as in `ProfessionPlanner/Panel.lua:136-137`:
```lua
local pending = false
function TB.Refresh()
  if not TB.active or pending then return end
  pending = true
  C_Timer.After(0.1, function()
    pending = false
    TB.skill = TB.ReadSkill()
    for _, fn in ipairs(TB.refreshers) do fn() end
  end)
end
```

**Skill read**
```lua
-- GetProfessions() 4th return is the fishing index; fall back to the skill-line API (356 = Fishing)
function TB.ReadSkill()
  local idx = GetProfessions and select(4, GetProfessions())
  if idx then
    local _, _, level, max, _, _, _, modifier = GetProfessionInfo(idx)
    return { level = level, max = max, modifier = modifier or 0 }
  end
  local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID(356)
  if info and info.maxSkillLevel and info.maxSkillLevel > 0 then
    return { level = info.skillLevel, max = info.maxSkillLevel, modifier = info.skillModifier or 0 }
  end
end
```

**PLAYER_LOGIN**
- Run `TB.active = true`. Unlike WUK, there is no gate: every character gets the panel, and "No Fishing skill" shows when the skill is missing.
- Run the inits, then `TB.Refresh()`.

**Events → `TB.Refresh`**
- `SKILL_LINES_CHANGED`
- `PLAYER_REGEN_ENABLED`
- `BAG_UPDATE_DELAYED`

**Probe snapshots** (always on; Phase 3 and 3b build on them)
```lua
TB.trace = {} -- last 12 {t, event, detail}; the probe reads the event order
local function Trace(ev, d) table.insert(TB.trace, { GetTime(), ev, d }); if #TB.trace > 12 then table.remove(TB.trace, 1) end end
TB.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if unit ~= "player" then return end
  local _, _, _, st, et = UnitChannelInfo("player")
  TB.lastChannelInfo = { spellID = spellID, start = st, finish = et, secret = TB.Secret(st) or TB.Secret(spellID) }
  Trace("CHANNEL_START", tostring(spellID))
end)
TB.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit) if unit == "player" then Trace("CHANNEL_STOP") end end)
TB.On("LOOT_READY", function()
  local slots = {}
  for i = 1, GetNumLootItems() do
    local _, name, qty, _, quality = GetLootSlotInfo(i)
    slots[#slots + 1] = { link = GetLootSlotLink(i), name = name, qty = qty, quality = quality }
  end
  TB.lastLoot = { slots = slots, fishing = IsFishingLoot and IsFishingLoot(), hasAPI = IsFishingLoot ~= nil }
  Trace("LOOT_READY", #slots)
end)
```

**`TB.Probe()`**
- Built like `WarlockUtilityKit/Core.lua:167-219`: a `P(k, v)` helper prints each line and appends it to `TackleBoxDB.lastProbe` (reset to `{}` first). An `S(v)` helper prints `"SECRET"` for secret values. Wrap each uncertain call in `pcall`.
- Output lines, in order:
  1. Build and client: `GetBuildInfo()`, `WOW_PROJECT_ID`, combat state.
  2. Skill:
     - `GetProfessions()` as all 5 returns.
     - `GetProfessionInfo(fishing idx)` as all returns.
     - `C_TradeSkillUI.GetProfessionInfoBySkillLineID(356)` with skillLevel, maxSkillLevel and skillModifier.
  3. Spells: `C_Spell.GetSpellInfo(7620)` and `C_Spell.GetSpellInfo(131474)`, giving name and spellID.
  4. `IsFishingLoot` present (type).
  5. Zone: `GetRealZoneText()`, `GetSubZoneText()`.
  6. Player auras: loop `C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")` for i = 1..40 and print `spellId`, `name` and `expirationTime` through `S()`.
  7. `C_UnitAuras.GetPlayerAuraBySpellID` on the first aura's spellId. This checks that the by-ID path works.
  8. Bags: for bags 0..`NUM_BAG_SLOTS or 4`, each `C_Container.GetContainerItemInfo` item with `itemID`, `itemName` and `quality`, plus `select(12, C_Item.GetItemInfo(id))` (classID) and the 13th return (subclassID).
     - **Filter:** keep items whose classID is 7 (trade goods) or 0 (consumable), or whose name matches `"Fish"`, `"Surfer"`, `"Waterwalk"`, `"Knife"`, `"Lure"`, `"Bauble"`, `"Snapper"`, `"Ahi"`, `"Mahi"`, `"Striker"` or `"Sailfin"`.
     - **Why:** this keeps the dump short.
  9. `TB.lastChannelInfo`, all fields through `S()`.
  10. `TB.lastLoot`: `hasAPI`, `fishing`, and each slot (link, quality, qty).
  11. `TB.trace` in order, with times relative to the first entry.

**Slash**: `SLASH_TACKLEBOX1 = "/tb"`. Lowercase the input, then:
| Command | Action |
|---|---|
| `show` / `hide` | set `db.shown`, `TB.Refresh()` |
| `lock` | toggle `db.locked`, print the state |
| `reset` | `wipe(TB.db.frames)`, print "reload to apply" |
| `probe` | `TB.Probe()` |
| `flash` | Phase 3b |
| bare `/tb` | toggle `db.shown` |
| anything else | print `"/tb show|hide|lock|reset|probe|flash"` |

#### 5. Panel
**File**: `TackleBox/Panel.lua` — create

**MakeMovable.** `TB.MakeMovable(f, key, x, y)` is copied from `WarlockUtilityKit/UI.lua:13-26`, with `WUK.db` replaced by `TB.db`.

**`Build()`**
- Frame `TBPanel`: a `BasicFrameTemplateWithInset` on UIParent, width 320, made movable with key `"panel"` at (300, 0).
- The CloseButton hook sets `TB.db.shown = false`.
- Title is "TackleBox" in `GameFontHighlight`. A header fontstring holds `TB.SkillText(TB.skill)` plus session misses (Phase 3b).
- `MAX_ROWS = 30` rows, built the same way as `ProfessionPlanner/Panel.lua:16-37`: icon, text, sub and highlight, 24px tall at a 26px pitch. Add the comment `-- ponytail: fixed 30 rows; collapse sections when they overflow, add a ScrollBox if that bites`.
- Each row's `OnMouseUp`: if `self.header`, toggle `TB.db.collapsed[self.header]`, then `TB.Refresh()`.
- Each row's `OnEnter`: if `self.itemID`, call `GameTooltip:SetItemByID`.

**`TB.RenderPanel(rows)`**
- Same as `ProfessionPlanner/Panel.lua:72-94`.
- Header rows: no icon, `GameFontNormal` colour (1, 0.82, 0).
- `row.color` is an `{r,g,b}` table.
- Panel height is `64 + n * 26`.

**Refresher**
```lua
TB.sections = {} -- each phase's init appends {key, title, build=function() return rows end}
table.insert(TB.refreshers, function()
  if not TB.db.shown then if panel then panel:Hide() end return end
  local secs = {}
  for _, s in ipairs(TB.sections) do secs[#secs + 1] = { key = s.key, title = s.title, rows = s.build() } end
  TB.RenderPanel(TB.BuildView(secs, TB.db.collapsed))
end)
```

**Minimap button**
- Copy `WarlockUtilityKit/Settings.lua:73-110` as `TBMinimapButton` with icon `Interface\Icons\Trade_Fishing`.
- Left-click toggles `db.shown` and refreshes.
- Right-click prints `TB.SkillText(TB.skill)`.
- Tooltip: "TackleBox" / "Click: panel   Right-click: skill   Drag: move".

#### 6. Tests
**File**: `TackleBox/tests/run.lua` — create
- Copy the harness head from `WarlockUtilityKit/tests/run.lua:1-7`. Load `Data.lua` and then `Logic.lua` into the same `TB`.
```lua
-- Phase 1
local t = TB.MergeDefaults(nil, { a = 1, f = {} }); eq(t.a, 1, "defaults scalar"); eq(type(t.f), "table", "defaults table")
eq(TB.FormatTime(75), "1:15", "format time")
eq(TB.SkillText(nil), "No Fishing skill", "no skill")
eq(TB.SkillText({ level = 120, max = 150, modifier = 25 }), "Fishing 120/150 (+25)", "skill with mod")
local v = TB.BuildView({ { key = "a", title = "A", rows = { { text = "x" } } }, { key = "b", title = "B", rows = {} } }, {})
eq(#v, 2, "empty section hidden"); eq(v[1].header, "a", "header row"); eq(v[1].text, "- A (1)", "open header")
v = TB.BuildView({ { key = "a", title = "A", rows = { { text = "x" } } } }, { a = true })
eq(#v, 1, "collapsed hides rows"); eq(v[1].text, "+ A (1)", "closed header")
```
- End the file with `print("all tests passed")`.

#### 7. CI
**File**: `.github/workflows/package-tb.yml` — create
- Copy `.github/workflows/package-wuk.yml` and change these strings:
  - `WarlockUtilityKit` → `TackleBox`
  - `package-wuk.yml` → `package-tb.yml`
  - `wuk-v` → `tb-v`
  - Name and title: `Package TackleBox` / `TackleBox $TAG`

#### 8. Docs
- **`TackleBox/README.md`** — create. Sections:
  - Install
  - The panel
  - Slash commands
  - Probe
  - Notes (Forever data is probe-verified; enUS zone names)
  - Development: the `lua5.1 TackleBox/tests/run.lua` command, and that CI publishes `tb-v` on version bump.
- **`TackleBox/CHANGELOG.md`** — create.
  - Header: `# Changelog — TackleBox`
  - Intro line in the WUK format.
  - `## [0.1.0] — <date>`, with `### Added` covering the panel, skill line, minimap button, `/tb` and `/tb probe`.

### Verification
#### Automated
- [x] `lua5.1 TackleBox/tests/run.lua` prints `all tests passed`
- [x] `git diff --name-only` shows only `TackleBox/**` and `.github/workflows/package-tb.yml` (plus thoughts/)

#### Manual
- [ ] Deploy with robocopy, then `/reload`. There are no Lua errors (`/console scriptErrors 1`).
- [ ] The panel shows "Fishing N/M". Shift-drag moves it, and the position survives `/reload`.
- [ ] The minimap button toggles the panel, and right-click prints the skill.
- [ ] Run `/tb probe` at each site below. After each run, the user `/reload`s and pastes `TackleBoxDB.lastProbe` from `WTF\Account\<acct>\SavedVariables\TackleBox.lua`:
  1. Plain, with fishing gear and any quest fish, Surfer Shoes and Draught in bags.
  2. Right after catching a fish (loot window closed).
  3. After a cast that expired with no click.
  4. Standing at a Campsite Fishing Rack, and again at a Fishing Hut, if reachable.
  5. With water-walking active.
- [x] Write `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md`. It records:
  - The fishing spell ID, and which skill read worked.
  - Whether `IsFishingLoot` exists, the event order (CHANNEL_STOP vs LOOT_READY), whether channel times are secret, and the real cast length.
  - Fish, quest-fish, water-walk, lure and Chef's Knife item IDs and qualities.
  - Camp and water-walk aura spell IDs, and whether `expirationTime` is secret out of combat.
  - Any deviation from the guides.
- [x] Set `TB.DATA.fishingSpells` and `TB.DATA.castSeconds` from the probe.

**Gate:** do not start Phase 2 until `probe-results.md` exists.

---

## Phase 2: Quest fish

### Changes
**`Data.lua`.** Fill `questFish`, with item IDs from the probe. If a fish was not in the user's bags, look it up by name (ask the user to `/dump C_Item.GetItemInfoInstant("Feralas Ahi")` in game).
```lua
questFish = {
  { id = <probe>, need = <n>, zone = "Feralas" },               -- Feralas Ahi
  { id = <probe>, need = <n>, zone = "Swamp of Sorrows" },      -- Misty Reed Mahi Mahi
  { id = <probe>, need = <n>, zone = "Desolace" },              -- Sar'theris Striker
  { id = <probe>, need = <n>, zone = "Stranglethorn Vale" },    -- Savage Coast Blue Sailfin
},
```
- The `need` values come from the Nat Pagle quest text, which the user reads in game. If they are unknown, use `need = 1` and note it in probe-results.

**`Logic.lua`**
```lua
-- rows sorted incomplete first, then by data order
function TB.QuestRows(list, counts)
  local rows = {}
  for i, q in ipairs(list) do
    local have = counts[q.id] or 0
    rows[#rows + 1] = { itemID = q.id, have = have, need = q.need, done = have >= q.need, order = i,
      sub = have .. "/" .. q.need .. "  " .. q.zone, color = have >= q.need and { 0.25, 0.75, 0.25 } or nil }
  end
  table.sort(rows, function(a, b) if a.done ~= b.done then return not a.done end return a.order < b.order end)
  return rows
end
```

**`Core.lua`**
- `TB.CountItems(ids)` maps each id with `C_Item.GetItemCount(id, true)` to `{[id]=n}`.
- Register `BANKFRAME_OPENED` and `PLAYERBANKSLOTS_CHANGED` to `TB.Refresh`.

**`Panel.lua`**
- Add an init that appends the `quest` section, titled "Quest fish".
- Its `build` returns QuestRows over CountItems.
- Each row's text is the item name from `C_Item.GetItemInfo(id)`. On a miss, use `"item:"..id` plus `Item:CreateFromItemID(id):ContinueOnItemLoad(TB.Refresh)`, the same way as `ProfessionPlanner/Panel.lua:96-100`.
- Each row's icon is `C_Item.GetItemIconByID(id)`.

**Tests**
```lua
-- Phase 2
local q = TB.QuestRows({ { id = 1, need = 2, zone = "Z" }, { id = 2, need = 1, zone = "Y" } }, { [1] = 2 })
eq(q[1].itemID, 2, "incomplete first"); eq(q[2].done, true, "complete"); eq(q[1].sub, "0/1  Y", "zero have")
```

### Verification
#### Automated
- [x] `lua5.1 TackleBox/tests/run.lua` passes

#### Manual
- [x] Deploy, then `/reload`. The Quest fish section lists 4 fish with the correct have counts.
- [ ] Moving a fish to the bank keeps the count (bank included). Looting one increments it.

---

## Phase 2b: Where to fish

### Changes
**`Data.lua`**
- Bands come from `thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/research.md:70-73`.
- `cast` is the minimum skill to catch anything. `noLoss` is the skill at which fish stop getting away (nil when unknown). `lure` is the bonus needed.
```lua
-- ponytail: enUS zone names matched against GetRealZoneText; add a locale table if non-English clients matter
zones = {
  { band = 1,   max = 75,  noLoss = 25, names = { "Elwynn Forest", "Dun Morogh", "Teldrassil", "Durotar", "Mulgore", "Tirisfal Glades" } },
  { band = 75,  max = 150, noLoss = 75, names = { "Stormwind City", "Ironforge", "Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity" } },
  { band = 75,  max = 150, names = { "The Barrens", "Darkshore", "Loch Modan", "Silverpine Forest", "Westfall" } },
  { band = 75,  max = 150, cast = 55, noLoss = 150, names = { "Redridge Mountains" } },
  { band = 150, max = 225, names = { "Dustwallow Marsh", "Alterac Mountains", "Arathi Highlands", "Desolace",
      "Stranglethorn Vale", "Swamp of Sorrows", "Thousand Needles" } },
  { band = 225, max = 300, lure = 75, names = { "Felwood", "Feralas", "The Hinterlands", "Tanaris", "Un'Goro Crater", "Western Plaguelands" } },
},
lures = { { name = "Shiny Bauble", bonus = 25 }, { name = "Nightcrawlers", bonus = 50 }, { name = "Bright Baubles", bonus = 75 },
  { name = "Aquadynamic Fish Attractor", bonus = 100 } },
```

**`Logic.lua`**
```lua
local function LureFor(lures, need)
  for _, l in ipairs(lures) do if l.bonus >= need then return l end end
end

-- recommended = groups whose band contains the base skill; the current zone always gets a row with a flag
function TB.WhereRows(zones, lures, skill, currentZone)
  if not skill then return {} end
  local eff, rows, seen = skill.level + (skill.modifier or 0), {}, {}
  local function row(z, name)
    local sub
    if z.noLoss then sub = "no get-aways at " .. z.noLoss else sub = "skill " .. z.band .. "-" .. z.max end
    if z.lure and (skill.modifier or 0) < z.lure then
      local l = LureFor(lures, z.lure); sub = sub .. ", needs " .. (l and l.name or ("+" .. z.lure .. " lure"))
    end
    local flag
    if name == currentZone then
      if eff < (z.cast or 1) then flag = "too low" elseif skill.level >= z.max then flag = "outgrown" else flag = "here" end
    end
    rows[#rows + 1] = { text = name .. (flag and (" [" .. flag .. "]") or ""), sub = sub, flag = flag }
    seen[name] = true
  end
  for _, z in ipairs(zones) do
    if skill.level >= z.band and skill.level < z.max then for _, n in ipairs(z.names) do row(z, n) end end
  end
  -- current zone outside the band: appended last so the flag still shows
  for _, z in ipairs(zones) do for _, n in ipairs(z.names) do if n == currentZone and not seen[n] then row(z, n) end end end
  return rows
end
```
- Band test uses `skill.level`. `cast` uses effective skill. That matches the Classic rule: gear and lure help you cast but do not change the band.

**`Core.lua`**
- Register `ZONE_CHANGED_NEW_AREA` → `TB.Refresh`.
- Register `UNIT_INVENTORY_CHANGED` with `u == "player"` → `TB.Refresh`.

**`Panel.lua`**
- Add a section `where`, titled "Where to fish".
- Its build is `TB.WhereRows(TB.DATA.zones, TB.DATA.lures, TB.skill, GetRealZoneText())`.
- Colors: here = green, outgrown = grey, too low = red.

**Tests**
```lua
-- Phase 2b
local Z = { { band = 1, max = 75, noLoss = 25, names = { "Elwynn Forest" } }, { band = 75, max = 150, cast = 55, noLoss = 150, names = { "Redridge Mountains" } },
  { band = 225, max = 300, lure = 75, names = { "Feralas" } } }
local L = { { name = "Bright Baubles", bonus = 75 } }
local w = TB.WhereRows(Z, L, { level = 1, modifier = 0 }, "Elwynn Forest")
eq(#w, 1, "skill 1 one zone"); eq(w[1].flag, "here", "here flag")
w = TB.WhereRows(Z, L, { level = 80, modifier = 0 }, "Elwynn Forest")
eq(w[1].text, "Redridge Mountains", "band 75 zone"); eq(w[2].flag, "outgrown", "outgrown current")
w = TB.WhereRows(Z, L, { level = 230, modifier = 0 }, "Feralas")
eq(w[1].sub, "skill 225-300, needs Bright Baubles", "lure note")
w = TB.WhereRows(Z, L, { level = 230, modifier = 75 }, "Nowhere"); eq(w[1].sub, "skill 225-300", "lure satisfied")
w = TB.WhereRows(Z, L, { level = 40, modifier = 0 }, "Redridge Mountains"); eq(w[#w].flag, "too low", "too low")
eq(#TB.WhereRows(Z, L, nil, "x"), 0, "no skill")
```

### Verification
#### Automated
- [x] `lua5.1 TackleBox/tests/run.lua` passes

#### Manual
- [x] Deploy, then `/reload`. "Where to fish" lists the zones for the current band, and the current zone row is flagged.
- [x] Equipping a +pole leaves the band unchanged. On a toon at 225+, it removes the lure note once the modifier is ≥ 75.
- [x] Changing zone updates the flagged row.

---

## Phase 3: Fish collection

### Changes
**`Data.lua`.** Fill `fish` from the probe, covering every Uncommon/Rare/Unique fish seen plus the Chef's Knife product:
```lua
fish = { [<id>] = { tier = "uncommon" }, [<id>] = { tier = "unique", knife = <productItemID> } },
```
- If no Unique fish or knife product was observed, leave those entries out. Note it in probe-results.

**`Logic.lua`**
```lua
local Q2TIER = { [2] = "uncommon", [3] = "rare" }
function TB.IsFishingCatch(isFishingLoot, lastChannel, now, spells)
  if isFishingLoot ~= nil then return isFishingLoot end
  return lastChannel ~= nil and spells[lastChannel.spellID] == true and now - (lastChannel.stopT or now) <= 30
end
function TB.RecordCatch(catches, id, qty, now, zone)
  local c = catches[id] or { n = 0, first = now, zones = {} }
  c.n, c.last = c.n + (qty or 1), now
  if zone then c.zones[zone] = (c.zones[zone] or 0) + (qty or 1) end
  catches[id] = c
  return catches
end
-- rows grouped uncommon, rare, unique, other; known-but-uncaught show as "not caught"
function TB.CollectionView(fish, catches, qualityOf)
  local groups, order = { uncommon = {}, rare = {}, unique = {}, other = {} }, { "uncommon", "rare", "unique", "other" }
  local ids = {}
  for id in pairs(fish) do ids[id] = true end
  for id in pairs(catches) do ids[id] = true end
  for id in pairs(ids) do
    local tier = fish[id] and fish[id].tier or Q2TIER[qualityOf(id) or -1] or "other"
    local c = catches[id]
    local sub = c and ("caught " .. c.n) or "not caught"
    if fish[id] and fish[id].knife then sub = sub .. ", knife: item:" .. fish[id].knife end
    table.insert(groups[tier], { itemID = id, tier = tier, caught = c ~= nil, sub = sub, knife = fish[id] and fish[id].knife })
  end
  local rows = {}
  for _, t in ipairs(order) do
    table.sort(groups[t], function(a, b) return a.itemID < b.itemID end)
    for _, r in ipairs(groups[t]) do rows[#rows + 1] = r end
  end
  return rows
end
```
- The panel replaces the `knife: item:N` text with the item name when it renders.
- The "other" bucket covers common catches. The collection records every fishing loot, including junk and common fish.

**`Core.lua`**
- Extend the Phase 1 channel handlers:
  - START sets `TB.lastChannel = { spellID = spellID, t = GetTime() }`, only when `not TB.Secret(spellID)`.
  - STOP sets `TB.lastChannel.stopT = GetTime()`.
- `LOOT_READY` gets a second handler, guarded by `looted`. `looted` resets on `LOOT_CLOSED`, because LOOT_READY can fire twice per window:
```lua
local looted = false
TB.On("LOOT_CLOSED", function() looted = false end)
TB.On("LOOT_READY", function()
  if looted then return end
  local isFL -- nil = API missing; keep false distinct from nil
  if IsFishingLoot then isFL = IsFishingLoot() and true or false end
  if not TB.IsFishingCatch(isFL, TB.lastChannel, GetTime(), TB.DATA.fishingSpells) then return end
  looted = true
  TB.lastLootT = GetTime()
  local sub = GetSubZoneText()
  local zone = GetRealZoneText() .. ((sub and sub ~= "") and (" - " .. sub) or "")
  for i = 1, GetNumLootItems() do
    local link = GetLootSlotLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then TB.RecordCatch(TB.char.catches, id, select(3, GetLootSlotInfo(i)), time(), zone) end
  end
  TB.Refresh()
end)
```

**`Panel.lua`**
- Add a section `catch`, titled "Collection".
- Its build is `TB.CollectionView(TB.DATA.fish, TB.char.catches, function(id) return C_Item.GetItemQualityByID(id) end)`.
- Text is the item name, colored with `C_Item.GetItemQualityColor(quality)`.
- `OnEnter` shows the item tooltip and adds lines for the top 3 `zones` by count.

**Tests**
```lua
-- Phase 3
local S = { [7620] = true }
eq(TB.IsFishingCatch(true, nil, 0, S), true, "api true"); eq(TB.IsFishingCatch(false, { spellID = 7620, stopT = 0 }, 1, S), false, "api false wins")
eq(TB.IsFishingCatch(nil, { spellID = 7620, stopT = 10 }, 12, S), true, "fallback recent")
eq(TB.IsFishingCatch(nil, { spellID = 7620, stopT = 10 }, 50, S), false, "fallback stale")
eq(TB.IsFishingCatch(nil, { spellID = 1, stopT = 10 }, 11, S), false, "other spell")
local c = TB.RecordCatch({}, 5, 1, 100, "Z"); TB.RecordCatch(c, 5, 2, 200, "Z")
eq(c[5].n, 3, "accumulate"); eq(c[5].first, 100, "first kept"); eq(c[5].zones.Z, 3, "zone count")
local cv = TB.CollectionView({ [9] = { tier = "rare" }, [8] = { tier = "unique", knife = 77 } }, { [5] = c[5] }, function() return 1 end)
eq(cv[1].itemID, 9, "rare first"); eq(cv[1].caught, false, "not caught"); eq(cv[2].knife, 77, "knife"); eq(cv[3].tier, "other", "other bucket")
```

### Verification
#### Automated
- [x] `lua5.1 TackleBox/tests/run.lua` passes

#### Manual
- [x] Deploy, then `/reload`. Catching a fish increments its row, and the tooltip shows the zone/subzone.
- [x] Looting a mob or a chest records nothing.
- [x] The catch survives `/reload` and is per-character, so an alt shows an empty collection.

---

## Phase 3b: Cast timer bar + got-away flash

### Changes
**`TackleBox.toc`.** Append `CastBar.lua`.

**`Logic.lua`**
```lua
-- channel times are ms (UnitChannelInfo); nil when unusable
function TB.CastProgress(startMs, endMs, nowMs)
  if type(startMs) ~= "number" or type(endMs) ~= "number" or endMs <= startMs then return nil end
  local f = (nowMs - startMs) / (endMs - startMs)
  f = math.max(0, math.min(1, f))
  return f, math.max(0, (endMs - nowMs) / 1000)
end
-- loot may land just before CHANNEL_STOP (probe records the order), so allow 0.5s before the stop
function TB.IsMiss(stopT, lastLootT)
  return not (lastLootT and lastLootT >= stopT - 0.5)
end
```
- Logic never sees a secret value. Core swaps secret channel times for a fixed-length fallback before calling.

**`Core.lua`**
- Add `TB.session = { misses = 0 }`.
- In the CHANNEL_START handler, for fishing spells only:
```lua
local _, _, _, st, et = UnitChannelInfo("player")
if TB.Secret(st) or TB.Secret(et) or not st then st = GetTime() * 1000; et = st + TB.DATA.castSeconds * 1000 end
TB.StartCastBar(st, et)
```
- In the CHANNEL_STOP handler, for fishing spells only:
```lua
TB.StopCastBar()
local stopT = GetTime()
C_Timer.After(1, function()
  if TB.IsMiss(stopT, TB.lastLootT) then
    TB.session.misses = TB.session.misses + 1
    if TB.db.flash then TB.Flash() end
    TB.Refresh()
  end
end)
```
- Slash: `flash` toggles `TB.db.flash` and prints "flash on/off".

**`CastBar.lua`** — create
```lua
local ADDON, TB = ...
local bar, flash

table.insert(TB.inits, function()
  bar = CreateFrame("StatusBar", "TBCastBar", UIParent)
  bar:SetSize(200, 14); bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetStatusBarColor(0.25, 0.65, 0.9)
  bar:SetMinMaxValues(0, 1)
  local bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.5)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); bar.text:SetPoint("CENTER")
  TB.MakeMovable(bar, "castbar", 0, -180)
  bar:Hide()

  flash = CreateFrame("Frame", "TBFlash", UIParent)
  flash:SetAllPoints(UIParent); flash:SetFrameStrata("FULLSCREEN_DIALOG"); flash:EnableMouse(false)
  local t = flash:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints()
  t:SetTexture("Interface\\FullScreenTextures\\LowHealth"); t:SetBlendMode("ADD"); t:SetVertexColor(0.3, 0.6, 1)
  flash:SetAlpha(0); flash:Show()
  local ag = flash:CreateAnimationGroup()
  local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(0.8); a1:SetDuration(0.15); a1:SetOrder(1)
  local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(0.8); a2:SetToAlpha(0); a2:SetDuration(0.6); a2:SetOrder(2)
  flash.anim = ag
end)

function TB.StartCastBar(st, et)
  bar:Show()
  bar:SetScript("OnUpdate", function(self)
    local f, left = TB.CastProgress(st, et, GetTime() * 1000)
    if not f then return end
    self:SetValue(1 - f); self.text:SetText(string.format("%.0fs", left))
  end)
end
function TB.StopCastBar() bar:SetScript("OnUpdate", nil); bar:Hide() end
function TB.Flash() flash.anim:Stop(); flash.anim:Play() end
```
- The bar's MakeMovable needs `EnableMouse` for dragging. A hidden bar takes no clicks, and while shown it sits away from the bobber by default, so this is acceptable.
- If the flash texture path is missing on Forever, fall back to `t:SetColorTexture(0.3, 0.6, 1, 0.25)` with a border-only look, and note it in probe-results.

**`Panel.lua`.** Header text becomes `TB.SkillText(TB.skill) .. "   got away: " .. TB.session.misses`.

**Tests**
```lua
-- Phase 3b
local f, left = TB.CastProgress(1000, 21000, 1000); eq(f, 0, "start"); eq(left, 20, "left at start")
f = TB.CastProgress(1000, 21000, 11000); eq(f, 0.5, "mid")
f, left = TB.CastProgress(1000, 21000, 30000); eq(f, 1, "clamped end"); eq(left, 0, "no negative")
eq(TB.CastProgress(nil, 21000, 0), nil, "nil start")
eq(TB.IsMiss(10, nil), true, "no loot"); eq(TB.IsMiss(10, 9.7), false, "loot just before stop")
eq(TB.IsMiss(10, 10.2), false, "loot after stop"); eq(TB.IsMiss(10, 5), true, "old loot")
```

### Verification
#### Automated
- [x] `lua5.1 TackleBox/tests/run.lua` passes

#### Manual
- [ ] Deploy, then `/reload`. A cast shows the bar counting down, and the bar hides on stop.
- [ ] A cast clicked with a catch produces no flash, and the counter stays the same.
- [ ] A cast left to expire produces a blue edge flash, and "got away" increments. Jumping mid-cast does the same.
- [ ] `/tb flash` silences the flash, and the counter still increments.
- [ ] Fishing, then getting attacked, produces no Lua errors.

---

## Phase 4: Camp buffs

### Changes
**`Data.lua`.** Fill `campBuffs` from the probe at sites 4–5:
```lua
campBuffs = { { spellID = <probe>, name = "Fishing Rack", unlock = <n> }, { spellID = <probe>, name = "Fishing Hut", unlock = <n> } },
```
- **Fallback:** the probe may show no player aura at the Rack or Hut. In that case add `subzone = "<probe GetSubZoneText>"` and leave `spellID` nil, then document it. Rows are then driven by the subzone match. If neither an aura nor a subzone shows up, rows show only unlock vs skill.

**`Logic.lua`**
```lua
-- state[spellID] = {active, remaining|nil}; skill = TB.skill
function TB.CampRows(buffs, state, skill, subzone)
  local rows, lvl = {}, skill and skill.level or 0
  for _, b in ipairs(buffs) do
    local s = b.spellID and state[b.spellID]
    local active = (s and s.active) or (b.subzone ~= nil and b.subzone == subzone)
    local sub
    if active then sub = (s and s.remaining) and TB.FormatTime(s.remaining) .. " left" or "active"
    elseif lvl < b.unlock then sub = "needs skill " .. b.unlock
    else sub = "available" end
    rows[#rows + 1] = { text = b.name, sub = sub, active = active, color = active and { 0.25, 0.75, 0.25 } or nil }
  end
  return rows
end
```

**`Core.lua`**
```lua
TB.auraState = {}
function TB.ReadAura(spellID)
  if InCombatLockdown() then return TB.auraState[spellID] end -- combat aura reads error on Forever (WUK probe)
  local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
  if not ok or not a then return { active = false } end
  local exp = a.expirationTime
  if TB.Secret(exp) or not exp or exp == 0 then return { active = true } end
  return { active = true, remaining = math.max(0, exp - GetTime()) }
end
```
- Register `UNIT_AURA` with `u == "player"` → `TB.Refresh`.
- Add a 1-second `C_Timer.NewTicker`. It calls `TB.Refresh()` only while any camp buff is active, so the countdown ticks.

**`Panel.lua`**
- Add a section `camp`, titled "Camp".
- Its build:
  1. Fill `TB.auraState[id] = TB.ReadAura(id)` for each buff with a spellID.
  2. Return `TB.CampRows(TB.DATA.campBuffs, TB.auraState, TB.skill, GetSubZoneText())`.

**Tests**
```lua
-- Phase 4
local B = { { spellID = 1, name = "Rack", unlock = 140 }, { spellID = 2, name = "Hut", unlock = 300 }, { name = "Fire", unlock = 1, subzone = "Camp" } }
local cr = TB.CampRows(B, { [1] = { active = true, remaining = 65 }, [2] = { active = false } }, { level = 200 }, "Camp")
eq(cr[1].sub, "1:05 left", "timer"); eq(cr[2].sub, "needs skill 300", "below unlock"); eq(cr[3].sub, "active", "subzone active")
cr = TB.CampRows(B, { [1] = { active = true } }, { level = 300 }, nil)
eq(cr[1].sub, "active", "secret timer"); eq(cr[2].sub, "available", "eligible")
```

### Verification
#### Automated
- [ ] `lua5.1 TackleBox/tests/run.lua` passes

#### Manual
- [ ] Deploy, then `/reload`. At a Rack, the row shows a countdown, or "active" if the timer is secret.
- [ ] Away from a camp, the row shows "available" or "needs skill N".
- [ ] Entering combat with the buff up produces no error, and the row freezes until combat ends.

---

## Phase 5: Water-walk button

### Changes
**`Data.lua`.** Fill `waterWalk` from the probe:
```lua
waterWalk = { items = { <Draught id>, <Surfer Shoes id> }, auras = { <aura spellIDs> } },
```
- Item order is preference order. The Draught comes first, since it is the consumable.
- Surfer Shoes may be equipped gear with an on-use effect, not a consumable. `type=item` uses the equipped item by ID too.

**`Logic.lua`**
```lua
function TB.WaterWalkPick(items, counts, auraActive)
  if auraActive then return nil end
  for _, id in ipairs(items) do if (counts[id] or 0) > 0 then return id end end
end
```

**`Core.lua`**
- Gather counts with `C_Item.GetItemCount(id)`. For equipped shoes, add `C_Item.IsEquippedItem(id) and 1 or 0`.
- `auraActive` = any `TB.ReadAura(id).active` over `waterWalk.auras`.

**`Panel.lua`.** The button is a standalone frame; see the deviation note at the top.
```lua
table.insert(TB.inits, function()
  local b = CreateFrame("Button", "TBWaterButton", UIParent, "SecureActionButtonTemplate")
  b:SetSize(36, 36); b:RegisterForClicks("AnyUp", "AnyDown"); b:SetAttribute("type", "item")
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
  TB.MakeMovable(b, "water", 0, -220)
  b:SetScript("OnEnter", function(self) if self.itemID then GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetItemByID(self.itemID); GameTooltip:Show() end end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:Hide()
  TB.waterButton = b
end)
-- attributes and visibility only out of combat; PLAYER_REGEN_ENABLED -> Refresh re-applies
local function ApplyWater(id)
  local b = TB.waterButton
  if InCombatLockdown() then return end
  b.itemID = id
  if id then b:SetAttribute("item", "item:" .. id); b.icon:SetTexture(C_Item.GetItemIconByID(id)); b:Show() else b:Hide() end
end
```
- Add a section `water`, titled "Water-walking".
- Its build:
  1. Compute `id = TB.WaterWalkPick(...)` and call `ApplyWater(id)`.
  2. Return one row: `{ itemID = id, text = name, sub = "click the water button to use" }` when id is set, `{ text = "Water-walking active" }` when the aura is up, or `{}` when no item is owned.
- `MakeMovable`'s drag uses `StartMoving` on a secure button out of combat. That is allowed, as with WUK's strip at `WarlockUtilityKit/UI.lua:149`.

**Tests**
```lua
-- Phase 5
eq(TB.WaterWalkPick({ 1, 2 }, {}, false), nil, "none owned")
eq(TB.WaterWalkPick({ 1, 2 }, { [2] = 1 }, false), 2, "first present")
eq(TB.WaterWalkPick({ 1, 2 }, { [1] = 3, [2] = 1 }, false), 1, "preference order")
eq(TB.WaterWalkPick({ 1 }, { [1] = 1 }, true), nil, "aura active")
```

### Verification
#### Automated
- [ ] `lua5.1 TackleBox/tests/run.lua` passes

#### Manual
- [ ] Deploy, then `/reload`. With the Draught in bags and no buff, the button shows. Clicking it drinks the Draught, and the button hides once the aura is up.
- [ ] When the aura expires, the button reappears. This runs out of combat.
- [ ] Entering combat while the button is shown produces no `ADDON_ACTION_BLOCKED`. The button state changes only after combat ends.
- [ ] If Forever blocks the item click, record it in probe-results, hide the section, and move the item to the README Notes as a known limit.

---

## Phase 6: Release

### Changes
- **`TackleBox/TackleBox.toc`:** `## Version: 1.0.0`.
- **`TackleBox/CHANGELOG.md`:** add `## [1.0.0] — <date>`. Under `### Added`, list one bold-lead-in bullet per section, plus the cast bar and flash.
- **`TackleBox/README.md`:** add one section per panel section, a cast bar/flash section, and the full slash list. Notes cover:
  - no bite detection (the game exposes none)
  - enUS zone names
  - data from probe `<build>`
  - the water button is standalone because of combat rules
- **Root `README.md`:** add a list of the three addons, one line each, linking their folders.

### Verification
#### Automated
- [ ] `lua5.1 TackleBox/tests/run.lua` passes
- [ ] After merge to main, `gh run list --workflow package-tb.yml -L 1` shows success
- [ ] `gh release view tb-v1.0.0 --json assets -q '.assets[].name'` prints `TackleBox-1.0.0.zip`
- [ ] `unzip -l TackleBox-1.0.0.zip | grep tests` prints nothing

#### Manual
- [ ] Install the release zip into `_classic_beta_\Interface\AddOns`. It loads cleanly, and every section renders.
- [ ] Re-run `/tb probe` on launch build day (2026-11-04). Diff its IDs against `Data.lua`, and cut 1.0.1 if any changed.
