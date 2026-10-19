# Implementation Plan

## Overview
A self-contained `WarlockUtilityKit/` addon for the WoW Forever client (interface 16001). It provides:
- a shard/stone strip
- a one-button prep chain
- a soulstone timer
- a local summon queue from chat
- a healthstone whisper-and-trade helper

It uses Mainline APIs only, learns enUS names from the client, and rewrites secure macro buttons out of combat.

## Conventions (all phases)
- Every file starts `local ADDON, WUK = ...` (the addon's shared namespace table).
- **Pure logic lives only in `Logic.lua`**: no WoW API calls at load time or inside the functions. `tests/run.lua` loads that file alone.
  - Deviation from structure.md, which spread pure functions across modules: this keeps tests free of WoW stubs.
- Lua must stay 5.1-compatible (the WoW client) and run under 5.4 (local tests). That rules out `//`, `goto`, integer-division semantics, and `unpack` vs `table.unpack` differences.
- Secret-value guard helper (Core): `WUK.Secret(v)` returns `issecretvalue ~= nil and issecretvalue(v)`. Any chat, aura or range value checked with it is skipped when it returns true.
- Warlock-only behaviour: modules push init functions into `WUK.inits`. Core runs them at `PLAYER_LOGIN` only when the class is `WARLOCK`. Other classes load the addon and do nothing.
- All secure-frame changes (SetAttribute, Show/Hide of secure frames) happen only when `not InCombatLockdown()`. Otherwise they are deferred to `PLAYER_REGEN_ENABLED`, which calls `WUK.Refresh()`.

## Prerequisite (once)
- [x] `winget install DEVCOM.Lua`. Ask the user for approval before running it. Then confirm `lua -v` prints a version; a new shell may be needed for PATH.
- Test command for every phase, from the repo root: `lua WarlockUtilityKit/tests/run.lua`. It must print `all tests passed` and exit 0.

---

## Phase 1: Load, persist, count shards and stones

### Changes

#### 1. TOC
**File**: `WarlockUtilityKit/WarlockUtilityKit.toc`
**Action**: create

```
## Interface: 16001
## Title: Warlock Utility Kit
## Notes: Shards, stones, prep, summons and healthstone trades for WoW Forever.
## Version: 0.1.0
## IconTexture: Interface\Icons\INV_Misc_Gem_Amethyst_02
## SavedVariables: WarlockUtilityKitDB
## SavedVariablesPerCharacter: WarlockUtilityKitCharDB

Logic.lua
Core.lua
UI.lua
Prep.lua
Summon.lua
Trade.lua
```
Prep.lua, Summon.lua and Trade.lua are listed now. They are created as one-line stubs (`local ADDON, WUK = ...`) in Phase 1 so the TOC never references a missing file.

#### 2. Pure logic
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: create (Phase 1 part)

```lua
local ADDON, WUK = ...

-- ponytail: enUS name matching; add a per-locale table when non-English clients matter
local STONES = {
  { "Soul Shard", "shard" }, { "Healthstone", "healthstone" }, { "Soulstone", "soulstone" },
  { "Spellstone", "spellstone" }, { "Firestone", "firestone" },
}

function WUK.ClassifyItem(name)
  if type(name) ~= "string" then return nil end
  for _, s in ipairs(STONES) do
    if name:find(s[1], 1, true) then return s[2] end
  end
end

function WUK.MergeDefaults(sv, defaults)
  if type(sv) ~= "table" then sv = {} end
  for k, v in pairs(defaults) do
    if type(v) == "table" then sv[k] = WUK.MergeDefaults(sv[k], v)
    elseif sv[k] == nil then sv[k] = v end
  end
  return sv
end

function WUK.FormatTime(sec)
  return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end
```

#### 3. Core: events, SavedVariables, scans, slash
**File**: `WarlockUtilityKit/Core.lua`
**Action**: create

```lua
local ADDON, WUK = ...

WUK.inits, WUK.refreshers = {}, {}
WUK.counts = { shard = 0, healthstone = 0, soulstone = 0, spellstone = 0, firestone = 0, ids = {}, slots = {} }
WUK.known = {}

function WUK.Secret(v) return issecretvalue ~= nil and issecretvalue(v) end
function WUK.Print(msg) print("|cff9482c9WUK|r " .. msg) end

local events, handlers = CreateFrame("Frame"), {}
function WUK.On(event, fn)
  if not handlers[event] then handlers[event] = {}; events:RegisterEvent(event) end
  table.insert(handlers[event], fn)
end
events:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do fn(...) end
end)

local DEFAULTS = { locked = false, shown = true, frames = {} }
local CHAR_DEFAULTS = { pet = "imp" }

WUK.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  -- nil-safe: the Forever beta loader bug can leave these nil every session
  WarlockUtilityKitDB = WUK.MergeDefaults(WarlockUtilityKitDB, DEFAULTS)
  WarlockUtilityKitCharDB = WUK.MergeDefaults(WarlockUtilityKitCharDB, CHAR_DEFAULTS)
  WUK.db, WUK.char = WarlockUtilityKitDB, WarlockUtilityKitCharDB
end)

function WUK.ScanBags()
  local c = { shard = 0, healthstone = 0, soulstone = 0, spellstone = 0, firestone = 0, ids = {}, slots = {} }
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local kind = info and WUK.ClassifyItem(info.itemName or C_Item.GetItemInfo(info.itemID))
      if kind then
        c[kind] = c[kind] + (info.stackCount or 1)
        c.ids[kind] = c.ids[kind] or info.itemID
        c.slots[kind] = c.slots[kind] or { bag, slot }
      end
    end
  end
  return c
end

function WUK.Refresh()
  if not WUK.active then return end
  WUK.counts = WUK.ScanBags()
  for _, fn in ipairs(WUK.refreshers) do fn() end
end

WUK.On("PLAYER_LOGIN", function()
  local _, class = UnitClass("player")
  if class ~= "WARLOCK" then return end
  WUK.active = true
  for _, init in ipairs(WUK.inits) do init() end
  WUK.Refresh()
end)
WUK.On("BAG_UPDATE_DELAYED", WUK.Refresh)
WUK.On("PLAYER_REGEN_ENABLED", WUK.Refresh)
```

Slash command, also in Core.lua. Phase 2 adds `pet`:
```lua
SLASH_WARLOCKUTILITYKIT1 = "/wuk"
SlashCmdList.WARLOCKUTILITYKIT = function(msg)
  if not WUK.active then return WUK.Print("warlocks only") end
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  if InCombatLockdown() and (cmd == "show" or cmd == "hide") then return WUK.Print("not in combat") end
  if cmd == "show" or cmd == "hide" then WUK.db.shown = (cmd == "show"); WUK.ApplyShown()
  elseif cmd == "lock" then WUK.db.locked = not WUK.db.locked; WUK.Print(WUK.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(WUK.db.frames); WUK.Print("positions reset - /reload to apply")
  else WUK.Print("/wuk show | hide | lock | reset | pet <imp|voidwalker|succubus|felhunter>") end
end
```

#### 4. UI: strip + movable helper
**File**: `WarlockUtilityKit/UI.lua`
**Action**: create

```lua
local ADDON, WUK = ...

function WUK.MakeMovable(f, key, x, y)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() and not WUK.db.locked and not InCombatLockdown() then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, px, py = self:GetPoint()
    WUK.db.frames[key] = { p, rp, px, py }
  end)
  local pos = WUK.db.frames[key]
  f:ClearAllPoints()
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", UIParent, "CENTER", x, y) end
end

function WUK.ApplyShown()
  if WUK.db.shown then WUK.strip:Show() else WUK.strip:Hide() end
end

table.insert(WUK.inits, function()
  local f = CreateFrame("Frame", "WUKStrip", UIParent, "BackdropTemplate")
  f:SetSize(300, 44)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  f:SetBackdropColor(0, 0, 0, 0.6); f:SetBackdropBorderColor(0.58, 0.51, 0.79, 1)
  f.counts = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.counts:SetPoint("TOPLEFT", 48, -8)
  f.stone = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.stone:SetPoint("TOPLEFT", f.counts, "BOTTOMLEFT", 0, -4)
  WUK.strip = f
  WUK.MakeMovable(f, "strip", 0, -220)
  WUK.ApplyShown()
end)

table.insert(WUK.refreshers, function()
  local c = WUK.counts
  WUK.strip.counts:SetText(string.format("Shards %d  HS %d  SS %d  Spell %d  Fire %d",
    c.shard, c.healthstone, c.soulstone, c.spellstone, c.firestone))
end)
```
The strip's left 44px is reserved for the prep button (Phase 2). `f.stone` is filled in Phase 3.

#### 5. Stubs
**Files**: `WarlockUtilityKit/Prep.lua`, `Summon.lua`, `Trade.lua`
**Action**: create, each containing `local ADDON, WUK = ...`

#### 6. Tests
**File**: `WarlockUtilityKit/tests/run.lua`
**Action**: create (not listed in the TOC, so the client never loads it)

```lua
local dir = ((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
local WUK = {}
assert(loadfile(dir .. "/Logic.lua"))("WarlockUtilityKit", WUK)

local function eq(got, want, label)
  if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end

-- Phase 1
eq(WUK.ClassifyItem("Soul Shard"), "shard", "shard")
eq(WUK.ClassifyItem("Major Healthstone"), "healthstone", "hs rank")
eq(WUK.ClassifyItem("Greater Soulstone"), "soulstone", "ss rank")
eq(WUK.ClassifyItem("Spellstone"), "spellstone", "spellstone")
eq(WUK.ClassifyItem("Lesser Firestone"), "firestone", "firestone")
eq(WUK.ClassifyItem("Linen Cloth"), nil, "other item")
eq(WUK.ClassifyItem(nil), nil, "nil name")
local sv = WUK.MergeDefaults(nil, { a = 1, t = { b = 2 } })
eq(sv.a, 1, "merge nil"); eq(sv.t.b, 2, "merge nested")
sv = WUK.MergeDefaults({ a = 5, t = {} }, { a = 1, t = { b = 2 } })
eq(sv.a, 5, "keep existing"); eq(sv.t.b, 2, "fill nested")
eq(WUK.FormatTime(1799), "29:59", "format")

print("all tests passed")
```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual (Forever client; copy or symlink `WarlockUtilityKit/` into `_retail_`-equivalent `Interface/AddOns/`)
- [x] The addon list shows "Warlock Utility Kit", not marked out of date
- [x] On a warlock, the strip appears with the correct counts; looting or creating a shard changes the count
- [x] Shift+drag moves the strip and the position survives `/reload` and relog; `/wuk lock` blocks dragging
- [x] On the rogue alt there is no strip and no Lua errors; `/wuk` prints "warlocks only"
- [x] `/console scriptErrors 1` shows no errors during login, looting or `/reload`

---

## Phase 2: Spellbook scan + prep button

### Changes

#### 1. Prep logic
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify (append)

```lua
-- state = { known = {key=spellName}, counts = Counts, buffs = {[buffName]=true, demonicSacrifice=bool},
--           pet = "imp"|"voidwalker"|... |nil, preferredPet = string, soulstoneActive = bool }
function WUK.PrepSteps(s)
  local k, b, c, out = s.known, s.buffs, s.counts, {}
  local function add(key, macro) out[#out + 1] = { key = key, macro = macro } end
  if k.armor and not b[k.armor] then add("armor", "/cast " .. k.armor) end
  if k.detect and not b[k.detect] then add("detect", "/cast " .. k.detect) end
  if not b.demonicSacrifice then
    local want = s.preferredPet
    if want ~= "imp" and c.shard == 0 then want = "imp" end
    if not k[want] then want = "imp" end
    -- any pet is fine when the preferred one is unaffordable; avoids swapping Felhunter for Imp
    local satisfied = s.pet == s.preferredPet or (s.pet ~= nil and want ~= s.preferredPet)
    if not satisfied and k[want] then add("pet", "/cast " .. k[want]) end
    if k.soullink and s.pet and not b[k.soullink] then add("soullink", "/cast " .. k.soullink) end
  end
  if k.healthstone and c.healthstone == 0 and c.shard > 0 then add("healthstone", "/cast " .. k.healthstone) end
  if k.soulstone and c.soulstone == 0 and not s.soulstoneActive and c.shard > 0 then
    add("soulstone", "/cast " .. k.soulstone)
  end
  if c.soulstone > 0 and not s.soulstoneActive and c.ids.soulstone then
    add("usesoulstone", "/target player\n/use item:" .. c.ids.soulstone .. "\n/targetlasttarget")
  end
  return out
end
```

#### 2. Spellbook scan + buff/pet reads
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify (append)

Classic-era ranked stone spells have **distinct names**. The list is therefore ordered from the highest rank down, and the first known name wins. Ranked spells with one shared name (Demon Armor) cast their highest rank through `/cast Name`.
```lua
local SPELLS = {
  armor = { "Demon Armor", "Demon Skin" },
  detect = { "Detect Greater Invisibility", "Detect Invisibility", "Detect Lesser Invisibility" },
  imp = { "Summon Imp" }, voidwalker = { "Summon Voidwalker" },
  succubus = { "Summon Succubus" }, felhunter = { "Summon Felhunter" },
  soullink = { "Soul Link" }, ritual = { "Ritual of Summoning" },
  healthstone = { "Create Healthstone (Major)", "Create Healthstone (Greater)", "Create Healthstone",
                  "Create Healthstone (Lesser)", "Create Healthstone (Minor)" },
  soulstone = { "Create Soulstone (Major)", "Create Soulstone (Greater)", "Create Soulstone",
                "Create Soulstone (Lesser)", "Create Soulstone (Minor)" },
}

local function SpellbookNames()
  local names = {}
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    local bank = Enum.SpellBookSpellBank.Player
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
      for j = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local n = C_SpellBook.GetSpellBookItemName(j, bank)
        if n then names[n] = true end
      end
    end
  else -- Classic-style spellbook, in case Forever kept it
    for t = 1, GetNumSpellTabs() do
      local _, _, offset, num = GetSpellTabInfo(t)
      for j = offset + 1, offset + num do
        local n = GetSpellBookItemName(j, "spell")
        if n then names[n] = true end
      end
    end
  end
  return names
end

function WUK.ScanSpells()
  local names, known = SpellbookNames(), {}
  for key, list in pairs(SPELLS) do
    for _, n in ipairs(list) do if names[n] then known[key] = n; break end end
  end
  WUK.known = known
end

local DEMONIC_SACRIFICE = { ["Burning Wish"] = true, ["Fel Stamina"] = true, ["Touch of Shadow"] = true, ["Fel Energy"] = true }
function WUK.ReadPlayerBuffs()
  local set = {}
  for i = 1, 40 do
    local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not a then break end
    local n = a.name
    if n and not WUK.Secret(n) then
      set[n] = true
      if DEMONIC_SACRIFICE[n] then set.demonicSacrifice = true end
    end
  end
  return set
end

function WUK.PetFamily()
  if not UnitExists("pet") then return nil end
  local fam = UnitCreatureFamily("pet")
  if not fam or WUK.Secret(fam) then return nil end
  return fam:lower()
end
```
Wiring: in the `PLAYER_LOGIN` handler, call `WUK.ScanSpells()` before the inits run. Add these registrations:
- `WUK.On("SPELLS_CHANGED", function() if WUK.active then WUK.ScanSpells(); WUK.Refresh() end end)`
- `WUK.On("UNIT_AURA", function(u) if u == "player" then WUK.Refresh() end end)`
- `WUK.On("UNIT_PET", function(u) if u == "player" then WUK.Refresh() end end)`

The slash handler gains a `pet` branch:
```lua
elseif cmd == "pet" and (arg == "imp" or arg == "voidwalker" or arg == "succubus" or arg == "felhunter") then
  WUK.char.pet = arg; WUK.Print("preferred pet: " .. arg); WUK.Refresh()
```

#### 3. Prep button
**File**: `WarlockUtilityKit/Prep.lua`
**Action**: modify (replace stub)

```lua
local ADDON, WUK = ...
local btn

local function State()
  return {
    known = WUK.known, counts = WUK.counts, buffs = WUK.ReadPlayerBuffs(), pet = WUK.PetFamily(),
    preferredPet = WUK.char.pet,
    soulstoneActive = WUK.SoulstoneRemaining and WUK.SoulstoneRemaining(WUK.char.soulstone, time()) ~= nil or false,
  }
end

local function SetBorder(r, g, b) btn:SetBackdropBorderColor(r, g, b, 1) end

function WUK.UpdatePrepButton()
  if InCombatLockdown() then return SetBorder(0.9, 0.1, 0.1) end
  local steps = WUK.PrepSteps(State())
  local step = steps[1]
  btn:SetAttribute("macrotext", step and step.macro or "")
  btn.badge:SetText(#steps > 0 and #steps or "")
  local spell = step and step.macro:match("^/cast (.+)$")
  btn.icon:SetTexture(spell and C_Spell.GetSpellTexture(spell) or (step and 134400) or 136195)
  if step then SetBorder(1, 0.82, 0) else SetBorder(0.1, 0.9, 0.1) end
end

table.insert(WUK.inits, function()
  btn = CreateFrame("Button", "WUKPrepButton", WUK.strip, "SecureActionButtonTemplate,BackdropTemplate")
  btn:SetSize(36, 36); btn:SetPoint("LEFT", 4, 0)
  btn:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
  btn.icon = btn:CreateTexture(nil, "ARTWORK"); btn.icon:SetPoint("TOPLEFT", 2, -2); btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  btn.badge = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal"); btn.badge:SetPoint("BOTTOMRIGHT", -2, 2)
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn:SetAttribute("type", "macro")
  WUK.On("PLAYER_REGEN_DISABLED", function() SetBorder(0.9, 0.1, 0.1) end)
end)
table.insert(WUK.refreshers, function() WUK.UpdatePrepButton() end)
```
Icon IDs: 134400 is the question mark, 136195 a green check-like icon. If they are wrong on Forever, any valid file ID works; this is cosmetic.

#### 4. Tests
**File**: `WarlockUtilityKit/tests/run.lua`
**Action**: modify. Insert before `print`:

```lua
-- Phase 2
local function state(o)
  local s = { known = { armor = "Demon Armor", detect = "Detect Invisibility", imp = "Summon Imp",
      felhunter = "Summon Felhunter", healthstone = "Create Healthstone", soulstone = "Create Soulstone" },
    counts = { shard = 3, healthstone = 0, soulstone = 0, ids = {} }, buffs = {}, pet = nil,
    preferredPet = "felhunter", soulstoneActive = false }
  for k, v in pairs(o or {}) do s[k] = v end
  return s
end
local steps = WUK.PrepSteps(state())
eq(steps[1].key, "armor", "armor first"); eq(steps[2].key, "detect", "detect second")
eq(steps[3].macro, "/cast Summon Felhunter", "preferred pet"); eq(steps[4].key, "healthstone", "hs")
eq(steps[5].key, "soulstone", "ss create"); eq(#steps, 5, "count fresh")
local done = state({ buffs = { ["Demon Armor"] = true, ["Detect Invisibility"] = true }, pet = "felhunter",
  counts = { shard = 1, healthstone = 1, soulstone = 0, ids = {} }, soulstoneActive = true })
eq(#WUK.PrepSteps(done), 0, "fully prepped")
local noShard = WUK.PrepSteps(state({ buffs = { ["Demon Armor"] = true, ["Detect Invisibility"] = true },
  counts = { shard = 0, healthstone = 1, soulstone = 0, ids = {} } }))
eq(noShard[1].macro, "/cast Summon Imp", "imp fallback"); eq(#noShard, 1, "no shard skips stones")
eq(#WUK.PrepSteps(state({ buffs = { ["Demon Armor"] = true, ["Detect Invisibility"] = true }, pet = "felhunter",
  counts = { shard = 0, healthstone = 1, soulstone = 0, ids = {} } })), 0, "keeps felhunter when broke")
local use = WUK.PrepSteps(state({ buffs = { ["Demon Armor"] = true, ["Detect Invisibility"] = true }, pet = "felhunter",
  counts = { shard = 2, healthstone = 1, soulstone = 1, ids = { soulstone = 16893 } } }))
eq(use[1].key, "usesoulstone", "use ss"); eq(use[1].macro, "/target player\n/use item:16893\n/targetlasttarget", "use macro")
eq(#WUK.PrepSteps(state({ buffs = { demonicSacrifice = true, ["Demon Armor"] = true, ["Detect Invisibility"] = true },
  counts = { shard = 1, healthstone = 1, soulstone = 0, ids = {} }, soulstoneActive = true })), 0, "demonic sacrifice skips pet")
```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual
- [x] `/dump WUK` is not global. Instead, `/run print(WUKPrepButton:GetAttribute("macrotext"))` shows the first missing step
- [x] On a warlock with no armor, no pet and no stones: repeated clicks cast armor, then Detect, then the pet, then Healthstone, then Soulstone, then use Soulstone on self. The border goes from yellow with a count to green
- [x] With 0 shards and Felhunter preferred, an Imp is summoned; with Felhunter already out and 0 shards, nothing is summoned
- [x] Entering combat turns the border red, and a click does nothing new. Leaving combat restores yellow or green
- [x] `/wuk pet voidwalker` changes the pet step
- [x] If the spellbook scan finds nothing on Forever, both scan branches have failed: report the API names found via `/dump C_SpellBook` and stop

---

## Phase 3: Soulstone target + timer

### Changes

#### 1. Logic
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify (append)
```lua
function WUK.SoulstoneRemaining(rec, now)
  if type(rec) ~= "table" or not rec.expires then return nil end
  local r = rec.expires - now
  if r <= 0 then return nil end
  return r
end
```

#### 2. Cast capture
**File**: `WarlockUtilityKit/Core.lua`
**Action**: modify. Shared "last cast target" capture, also used by Summon in Phase 4:
```lua
WUK.On("UNIT_SPELLCAST_SENT", function(unit, target)
  if unit == "player" then WUK.lastCastTarget = (target and not WUK.Secret(target) and target ~= "") and target or nil end
end)
function WUK.SpellName(spellID)
  if not spellID or WUK.Secret(spellID) then return nil end
  local info = C_Spell.GetSpellInfo(spellID)
  return info and info.name
end
```

#### 3. Record + ticker
**File**: `WarlockUtilityKit/Prep.lua`
**Action**: modify. Append inside a new init:
```lua
table.insert(WUK.inits, function()
  WUK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit == "player" and WUK.SpellName(spellID) == "Soulstone Resurrection" then
      WUK.char.soulstone = { target = WUK.lastCastTarget or UnitName("player"), expires = time() + 1800 }
      WUK.Refresh()
    end
  end)
  local wasActive = false
  C_Timer.NewTicker(1, function()
    local rem = WUK.SoulstoneRemaining(WUK.char.soulstone, time())
    WUK.strip.stone:SetText(rem and ("Soulstone: " .. WUK.char.soulstone.target .. "  " .. WUK.FormatTime(rem)) or "Soulstone: none")
    if wasActive and not rem then WUK.Refresh() end -- expiry re-enables the prep steps
    wasActive = rem ~= nil
  end)
end)
```
`time()` (wall clock), not `GetTime()`, so the record survives relog.

#### 4. Tests
**Action**: append to `tests/run.lua`:
```lua
-- Phase 3
eq(WUK.SoulstoneRemaining(nil, 100), nil, "ss absent")
eq(WUK.SoulstoneRemaining({ expires = 100 }, 100), nil, "ss expired")
eq(WUK.SoulstoneRemaining({ expires = 160 }, 100), 60, "ss active")
```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual
- [x] Using a soulstone on self shows "Soulstone: <you> 29:59" and counts down
- [x] Using one on a party member (target them, `/use Soulstone`) shows their name
- [x] The record survives `/reload` and relog, and while it is active the prep button skips create/use soulstone
- [x] If the cast name is not "Soulstone Resurrection" on Forever, `/etrace` UNIT_SPELLCAST_SUCCEEDED, read the spell name, and update the string

---

## Phase 4: Summon queue

### Changes

#### 1. Logic
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify (append)
```lua
local function HasWord(text, words)
  if type(text) ~= "string" then return false end
  for w in text:lower():gmatch("%w+") do if words[w] then return true end end
  return false
end
WUK.HasWord = HasWord

local SUMMON_WORDS = { ["123"] = true, sum = true, summon = true, port = true }
function WUK.IsSummonRequest(text) return HasWord(text, SUMMON_WORDS) end

function WUK.QueueAdd(list, name, max)
  for _, r in ipairs(list) do if r.name == name then return false end end
  if #list >= max then return false end
  list[#list + 1] = { name = name, at = os and os.time and os.time() or 0 }
  return true
end
function WUK.QueueRemove(list, name)
  for i = #list, 1, -1 do if list[i].name == name then table.remove(list, i) end end
end
function WUK.QueuePrune(list, keep)
  for i = #list, 1, -1 do if not keep(list[i]) then table.remove(list, i) end end
end

-- ctx = { inGroup, connected, dead, here: bool?, shards: number, helpers: number? }; nil = unknown, not a failure
function WUK.SummonFailure(ctx)
  if not ctx.inGroup then return "not in group" end
  if ctx.connected == false then return "offline" end
  if ctx.dead then return "dead" end
  if ctx.here then return "already here" end
  if (ctx.shards or 0) < 1 then return "no shard" end
  if ctx.helpers and ctx.helpers < 2 then return "need 2 helpers" end
  return nil
end
```
`os.time` is absent in the WoW sandbox. Summon.lua therefore overwrites `at` with `time()` after `QueueAdd`; the fallback exists only for tests.

#### 2. Summon module
**File**: `WarlockUtilityKit/Summon.lua`
**Action**: modify (replace stub)
```lua
local ADDON, WUK = ...
local MAX, TTL = 10, 600
local queue, rows, panel = {}, {}, nil

local function GroupUnits()
  local u = {}
  if IsInRaid() then for i = 1, GetNumGroupMembers() do u[#u + 1] = "raid" .. i end
  else for i = 1, GetNumSubgroupMembers() do u[#u + 1] = "party" .. i end end
  return u
end

local function UnitFull(unit)
  local n, realm = UnitName(unit)
  if not n or WUK.Secret(n) then return nil end
  return Ambiguate((realm and realm ~= "") and (n .. "-" .. realm) or n, "none")
end

local function RosterZone(name)
  if not IsInRaid() then return nil end -- ponytail: party zone unknown; add C_Map.GetBestMapForUnit name lookup if needed
  for i = 1, GetNumGroupMembers() do
    local n, _, _, _, _, _, zone = GetRaidRosterInfo(i)
    if n and Ambiguate(n, "none") == name then return zone end
  end
end

local function Context(name)
  local ctx, target = { shards = WUK.counts.shard }, nil
  for _, unit in ipairs(GroupUnits()) do
    if UnitFull(unit) == name then target = unit end
  end
  if not target then return ctx, nil end
  ctx.inGroup = true
  ctx.connected = UnitIsConnected(target)
  ctx.dead = UnitIsDeadOrGhost(target)
  local zone = RosterZone(name)
  ctx.here = zone ~= nil and zone == GetRealZoneText()
  local helpers = 0
  for _, unit in ipairs(GroupUnits()) do
    if unit ~= target and UnitIsConnected(unit) then
      local inRange = UnitInRange(unit)
      if WUK.Secret(inRange) then helpers = nil; break end
      if inRange then helpers = helpers + 1 end
    end
  end
  ctx.helpers = helpers
  return ctx, zone
end

function WUK.UpdateSummonRows()
  if InCombatLockdown() then return end
  local now = time()
  WUK.QueuePrune(queue, function(r) return now - r.at < TTL end)
  for i, row in ipairs(rows) do
    local r = queue[i]
    if r and WUK.known.ritual then
      local ctx, zone = Context(r.name)
      row:SetAttribute("macrotext1", "/target " .. r.name .. "\n/cast " .. WUK.known.ritual)
      row:SetAttribute("ctrl-macrotext1", "/target " .. r.name)
      row.name = r.name
      row.text:SetText(r.name .. "  |cffaaaaaa" .. (zone or "?") .. "|r  |cffff6060" .. (WUK.SummonFailure(ctx) or "") .. "|r")
      row:Show()
    else
      row:Hide()
    end
  end
  if queue[1] then panel:Show() else panel:Hide() end
end

local function OnChat(text, sender)
  if WUK.Secret(text) or WUK.Secret(sender) or not WUK.IsSummonRequest(text) then return end
  local name = Ambiguate(sender, "none")
  if name == UnitName("player") then return end
  if WUK.QueueAdd(queue, name, MAX) then queue[#queue].at = time() end
  WUK.UpdateSummonRows() -- no-op in combat; PLAYER_REGEN_ENABLED -> Refresh applies it
end

table.insert(WUK.inits, function()
  panel = CreateFrame("Frame", "WUKSummon", UIParent, "BackdropTemplate")
  panel:SetSize(300, 20 + MAX * 20)
  panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); panel:SetBackdropColor(0, 0, 0, 0.6)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", 6, -4); title:SetText("Summon queue (click: summon, ctrl: target, right: remove)")
  WUK.MakeMovable(panel, "summon", 0, -300)
  for i = 1, MAX do
    local row = CreateFrame("Button", "WUKSummonRow" .. i, panel, "SecureActionButtonTemplate")
    row:SetSize(288, 18); row:SetPoint("TOPLEFT", 6, -2 - i * 20)
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetAttribute("type1", "macro"); row:SetAttribute("ctrl-type1", "macro")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.text:SetPoint("LEFT")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:HookScript("OnClick", function(self, button, down)
      if button == "RightButton" and not down and self.name then WUK.QueueRemove(queue, self.name); WUK.UpdateSummonRows() end
    end)
    rows[i] = row
  end
  panel:Hide()
  for _, e in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
                       "CHAT_MSG_GUILD", "CHAT_MSG_SAY", "CHAT_MSG_WHISPER" }) do WUK.On(e, OnChat) end
  WUK.On("GROUP_ROSTER_UPDATE", WUK.UpdateSummonRows)
  WUK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit == "player" and WUK.known.ritual and WUK.SpellName(spellID) == WUK.known.ritual and WUK.lastCastTarget then
      WUK.QueueRemove(queue, Ambiguate(WUK.lastCastTarget, "none")); WUK.UpdateSummonRows()
    end
  end)
end)
table.insert(WUK.refreshers, function() WUK.UpdateSummonRows() end)
```
These are deliberate deviations from structure.md:
- Rows auto-remove once the ritual has been cast on that requester, and after 10 minutes. This replaces "Prune on GROUP_ROSTER_UPDATE"; roster updates only refresh the reasons.
- The zone check became "already here" (user decision during planning).

#### 3. Tests
**Action**: append to `tests/run.lua`:
```lua
-- Phase 4
for _, t in ipairs({ "123", "sum", "Summon pls", "can i get a port?", "SUM me" }) do eq(WUK.IsSummonRequest(t), true, "yes: " .. t) end
for _, t in ipairs({ "1234", "summoner", "portal", "sumo", "", 5 }) do eq(WUK.IsSummonRequest(t), false, "no: " .. tostring(t)) end
local q = {}
eq(WUK.QueueAdd(q, "Bob", 2), true, "add"); eq(WUK.QueueAdd(q, "Bob", 2), false, "dedupe")
WUK.QueueAdd(q, "Ann", 2); eq(WUK.QueueAdd(q, "Cid", 2), false, "max")
WUK.QueueRemove(q, "Bob"); eq(#q, 1, "remove"); eq(q[1].name, "Ann", "order")
WUK.QueuePrune(q, function() return false end); eq(#q, 0, "prune")
local base = { inGroup = true, connected = true, dead = false, here = false, shards = 1, helpers = 2 }
local function with(o) local c = {}; for k, v in pairs(base) do c[k] = v end; for k, v in pairs(o) do c[k] = v end; return c end
eq(WUK.SummonFailure(base), nil, "ok")
eq(WUK.SummonFailure(with({ inGroup = false })), "not in group", "group")
eq(WUK.SummonFailure(with({ connected = false })), "offline", "offline")
eq(WUK.SummonFailure(with({ dead = true })), "dead", "dead")
eq(WUK.SummonFailure(with({ here = true })), "already here", "here")
eq(WUK.SummonFailure(with({ shards = 0 })), "no shard", "shard")
eq(WUK.SummonFailure(with({ helpers = 1 })), "need 2 helpers", "helpers")
local unknown = with({}); unknown.helpers = nil
eq(WUK.SummonFailure(unknown), nil, "unknown helpers ok")
```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual
> **DEFERRED (2026-10-19):** user could not test in game yet; verify these before release.
- [ ] (deferred) A party member types "123" in party chat and a row appears with their name, zone ("?" in a party) and reason
- [ ] (deferred) The reason changes when they go offline or die, or when the warlock has 0 shards; with fewer than 2 other members in range it shows "need 2 helpers"
- [ ] (deferred) Left-click targets them and starts Ritual of Summoning; the row disappears after the cast succeeds
- [ ] (deferred) Ctrl+click only targets; right-click removes the row
- [ ] (deferred) A request during combat appears after combat ends
- [ ] (deferred) A guild member who is not in the group shows "not in group"

---

## Phase 5: Healthstone trade helper

### Changes

#### 1. Logic
**File**: `WarlockUtilityKit/Logic.lua`
**Action**: modify (append)
```lua
local HS_WORDS = { hs = true, healthstone = true }
function WUK.IsHealthstoneRequest(text) return HasWord(text, HS_WORDS) end
```

#### 2. Trade module
**File**: `WarlockUtilityKit/Trade.lua`
**Action**: modify (replace stub)
```lua
local ADDON, WUK = ...
local TTL = 600
local hsQueue, tradingWith = {}, nil
-- replies contain no request keyword, so two warlocks running WUK cannot ping-pong
local READY, EMPTY = "Stone ready - open a trade with me.", "Out of stones right now, sorry."

local function Whisper(msg, to) (C_ChatInfo.SendChatMessage or SendChatMessage)(msg, "WHISPER", nil, to) end

table.insert(WUK.inits, function()
  WUK.On("CHAT_MSG_WHISPER", function(text, sender)
    if WUK.Secret(text) or WUK.Secret(sender) or not WUK.IsHealthstoneRequest(text) then return end
    local name = Ambiguate(sender, "none")
    if hsQueue[name] and time() - hsQueue[name] < TTL then return end -- one reply per requester
    if WUK.counts.healthstone > 0 then hsQueue[name] = time(); Whisper(READY, sender)
    else Whisper(EMPTY, sender) end
  end)
  WUK.On("TRADE_SHOW", function()
    local n, realm = UnitName("NPC")
    if not n or WUK.Secret(n) then return end
    local partner = Ambiguate((realm and realm ~= "") and (n .. "-" .. realm) or n, "none")
    local at, slot = hsQueue[partner], WUK.counts.slots.healthstone
    if not at or time() - at >= TTL or not slot or CursorHasItem() then return end
    C_Container.PickupContainerItem(slot[1], slot[2])
    if ClickTradeButton then ClickTradeButton(1) else WUK.Print("drop the healthstone into the trade window") end
    tradingWith = partner
  end)
  WUK.On("UI_INFO_MESSAGE", function(_, msg)
    if msg == ERR_TRADE_COMPLETE and tradingWith then hsQueue[tradingWith] = nil; tradingWith = nil end
  end)
  WUK.On("TRADE_CLOSED", function() C_Timer.After(1, function() tradingWith = nil end) end)
end)
```
The code never calls `AcceptTrade`, which is restricted and requires a hardware event. The player clicks Trade.

#### 3. Tests
**Action**: append to `tests/run.lua`:
```lua
-- Phase 5
eq(WUK.IsHealthstoneRequest("hs pls"), true, "hs"); eq(WUK.IsHealthstoneRequest("Healthstone?"), true, "healthstone")
eq(WUK.IsHealthstoneRequest("this is it"), false, "no hs in words"); eq(WUK.IsHealthstoneRequest("Stone ready - open a trade with me."), false, "reply safe")
```

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual
> **DEFERRED (2026-10-19):** needs a second player; verify before release.
- [ ] (deferred) Another player whispers "hs" and receives "Stone ready - open a trade with me." exactly once, even if they repeat the whisper
- [ ] (deferred) With 0 healthstones, they receive "Out of stones right now, sorry." and are not queued
- [ ] (deferred) When they open a trade, a healthstone appears in trade slot 1; if `ClickTradeButton` is missing, the stone stays on the cursor and a hint is printed
- [ ] (deferred) After the trade completes they are dequeued, and another "hs" gets a fresh reply
- [ ] (deferred) A trade with someone who is not queued is left untouched

---

## Phase 6: Icon strip (added after Phase 1 in-game review)
Replace the strip's text counts ("Shards 5  HS 1 ...") with five item icons, each with a count overlay. An icon is desaturated when its count is 0.

### Changes

#### 1. UI
**File**: `WarlockUtilityKit/UI.lua`
**Action**: modify

```lua
local KINDS = { "shard", "healthstone", "soulstone", "spellstone", "firestone" }
-- fallback textures for kinds not in bags (no item ID to ask the client)
local FALLBACK = {
  shard = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02", healthstone = "Interface\\Icons\\INV_Stone_04",
  soulstone = "Interface\\Icons\\Spell_Shadow_SoulGem", spellstone = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
  firestone = "Interface\\Icons\\INV_Ammo_FireTar",
}
```
- In the init: replace `f.counts` with `f.icons[kind]`, 22x22 textures anchored left to right from x=48. Each gets an `OVERLAY` `NumberFontNormalSmall` count at BOTTOMRIGHT. `f.stone` anchors under the icon row.
- In the refresher: for each kind,
  - set the texture with `SetTexture(c.ids[kind] and C_Item.GetItemIconByID(c.ids[kind]) or FALLBACK[kind])`
  - set the count text
  - call `SetDesaturated(c[kind] == 0)`
- Remember the last real icon per kind in `WUK.db.icons[kind]`, so a used-up stone keeps its true icon. Add `icons = {}` to `DEFAULTS` in Core.lua.

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed` (no new pure logic)

#### Manual
- [x] The strip shows five icons with counts; a kind with 0 count is grey
- [x] Icons match the actual items in bags; after using the last healthstone, its icon stays (greyed)
- [x] The prep button (Phase 2) still sits left of the icons with no overlap

---

## Phase 7: Clickable 36px stone icons (added after Phase 6 in-game review)
The stone icons become 36px `SecureActionButtonTemplate` macro buttons, the same size as the prep button, laid out in one row.
- The strip is 244x62. The soulstone line moves to the bottom.
- `WUK.StoneMacro(kind, count, itemID, createSpell)` (pure, in Logic.lua) decides what a click does:
  - If the stone is held, use it. The soulstone goes on a friendly target, or on yourself.
  - Otherwise, cast the highest known create spell.
  - The shard icon has no action.
- Core `SPELLS` gains `spellstone` and `firestone` create-spell names.
- The refresher sets `macrotext` out of combat only. Textures and counts still update in combat.

### Verification
#### Automated
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`

#### Manual
- [x] The icons are the same size as the prep button, in one row with no overlap
- [x] Clicking healthstone uses it if you have one, or creates one if you don't; same for spellstone and firestone
- [x] Clicking soulstone with a friendly target soulstones them, and with no target soulstones yourself
- [ ] Shift+drag on the strip's bottom edge (the soulstone text area) still moves it

---

## Fix: prep pet step (after Phase 7 in-game review)
Two changes to `PrepSteps`, both from the user's in-game report:
- The pet step no longer falls back to Imp when you have 0 shards; it stays on the pet chosen with `/wuk pet`. It uses Imp only if that pet isn't learned yet.
- While mounted (`IsMounted()`), the pet and Soul Link steps are skipped, so the dismissed pet doesn't flip the button.

- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [ ] In game: with the preferred pet dead and 0 shards, the button still shows that pet; mounting doesn't change the button

---

## Final checks (after Phase 7)
- [x] `lua WarlockUtilityKit/tests/run.lua` prints `all tests passed`
- [ ] (deferred) `/console addonCombatRestrictionsForced 1`, then exercise the strip, prep, chat "123" and whisper "hs": no Lua errors. Reset with `/console addonCombatRestrictionsForced 0`
- [ ] (deferred) Inside a dungeon, out of combat: no Lua errors. Summon rows may not appear (chat can be secret on restricted maps); this is expected
- [x] Everything new lives under `WarlockUtilityKit/` (plus `thoughts/`); `git status` shows no other paths
