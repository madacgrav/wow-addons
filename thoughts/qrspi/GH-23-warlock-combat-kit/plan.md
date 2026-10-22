# Implementation Plan

## Overview
A new Forever addon, `WarlockCombatKit/` (global `WCK`), interface 16001, version 0.1.0. The kit:
- runs a `/wck probe` first and gates on its results;
- shows one movable panel with a next-spell core, proc icons, and a cast map of what you cast on each enemy;
- highlights enemies you have crowd-controlled;
- suggests the next spell from a rule list;
- adds 6 mouseover click-cast key slots through `Bindings.xml`.

It follows the WUK/TackleBox skeleton. Every gate is hard-coded from `probe-results.md` and protected by `pcall` or `Secret()` checks.

**Conventions for every phase**
- **Test command:** `lua5.1 WarlockCombatKit/tests/run.lua`. It must print `all tests passed`. Tests are straight-line asserts appended under a `-- Phase N` comment, using the `eq`/`near` helpers.
- **Deploy** after tests pass and the phase is committed. Exit codes 0-7 mean success.
  `robocopy "D:\Source\wow-addons\WarlockCombatKit" "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\WarlockCombatKit" /MIR /XD tests /NJH /NJS /NP /NDL`
  Then the user runs `/reload`.
- **Code style:** same as WUK. Files start with `local ADDON, WCK = ...`. Use two-space indents, short comments, and `ponytail:` notes for deliberate ceilings. `WCK.Secret(v)` comes before any compare, index or arithmetic on an API return that might be secret.
- **Combat rule:** never call `SetAttribute`, `SetPoint` or `Show`/`Hide` on a secure frame while `InCombatLockdown()`. Skip it and let the `PLAYER_REGEN_ENABLED` → `WCK.Refresh()` pass re-apply it.

---

## Phase 1: Skeleton + `/wck probe` + release pipeline

### Changes

#### 1. TOC
**File**: `WarlockCombatKit/WarlockCombatKit.toc` — create
```
## Interface: 16001
## Title: Warlock Combat Kit
## Notes: In-combat cast map, rotation helper, proc alerts and mouseover casting for WoW Forever warlocks.
## Version: 0.1.0
## IconTexture: Interface\Icons\Spell_Shadow_DeathCoil
## SavedVariables: WarlockCombatKitDB
## SavedVariablesPerCharacter: WarlockCombatKitCharDB

Logic.lua
Core.lua
```

#### 2. Pure logic
**File**: `WarlockCombatKit/Logic.lua` — create
```lua
local ADDON, WCK = ...

function WCK.MergeDefaults(sv, defaults)
  if type(sv) ~= "table" then sv = {} end
  for k, v in pairs(defaults) do
    if type(v) == "table" then sv[k] = WCK.MergeDefaults(sv[k], v)
    elseif sv[k] == nil then sv[k] = v end
  end
  return sv
end
```

#### 3. Core
**File**: `WarlockCombatKit/Core.lua` — create
- Header, same shape as `WarlockUtilityKit/Core.lua:1-17`:
  - `WCK.inits, WCK.refreshers = {}, {}`
  - `WCK.Secret`
  - `WCK.Print(msg)`, which prints with the prefix `|cff9482c9WCK|r `
- **`WCK.On` deviates from WUK:** `RegisterEvent` runs under `pcall`, because some Forever events may not exist and an unknown event raises an error. It returns `false` when registration fails.
```lua
local events, handlers = CreateFrame("Frame"), {}
function WCK.On(event, fn)
  if not handlers[event] then
    if not pcall(events.RegisterEvent, events, event) then return false end
    handlers[event] = {}
  end
  table.insert(handlers[event], fn)
  return true
end
events:SetScript("OnEvent", function(_, event, ...) for _, fn in ipairs(handlers[event]) do fn(...) end end)
```
- `local DEFAULTS = { locked = false, shown = true, frames = {}, minimapAngle = 240 }` and `local CHAR_DEFAULTS = {}`.
- `ADDON_LOADED` copies `WarlockUtilityKit/Core.lua:22-28`, using the names `WarlockCombatKitDB`/`WarlockCombatKitCharDB` and `WCK.db`/`WCK.char`.
- `WCK.Refresh` uses the debounce from `TackleBox/Core.lua:42-50`, minus the skill read:
```lua
local pending = false
function WCK.Refresh()
  if not WCK.active or pending then return end
  pending = true
  C_Timer.After(0.1, function() pending = false; for _, fn in ipairs(WCK.refreshers) do fn() end end)
end
```
- `PLAYER_LOGIN`: if the class is not `WARLOCK`, return. Otherwise set `WCK.active = true`, run the inits, then call `WCK.Refresh()`.
- Register `WCK.On("PLAYER_REGEN_ENABLED", WCK.Refresh)`.
- Trace ring of 20 entries, always on:
```lua
WCK.trace = {}
function WCK.Trace(ev, d)
  table.insert(WCK.trace, { GetTime(), ev, d })
  if #WCK.trace > 20 then table.remove(WCK.trace, 1) end
end
local function S(v) if WCK.Secret(v) then return "SECRET" end return tostring(v) end
WCK.S = S
WCK.On("UNIT_SPELLCAST_SENT", function(unit, target, castGUID, spellID)
  if unit == "player" then WCK.Trace("SENT", S(spellID) .. " tgt=" .. S(target) .. " guid=" .. S(castGUID)) end
end)
for _, ev in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
  WCK.On(ev, function(unit, castGUID, spellID)
    if unit == "player" or unit == "pet" then WCK.Trace(ev:sub(16), unit .. " " .. S(spellID) .. " guid=" .. S(castGUID)) end
  end)
end
for _, ev in ipairs({ "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" }) do
  if not WCK.On(ev, function(spellID) WCK.Trace(ev:sub(21), S(spellID)) end) then WCK.Trace("noevent", ev) end
end
for _, ev in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
  WCK.On(ev, function(unit) WCK.Trace(ev:sub(12), S(unit) .. " guid=" .. S(UnitGUID(unit))) end)
end
WCK.On("PLAYER_REGEN_DISABLED", function() WCK.Trace("REGEN_DISABLED") end)
WCK.On("PLAYER_REGEN_ENABLED", function() WCK.Trace("REGEN_ENABLED") end)
```
- `WCK.Probe()` follows the shape of `TackleBox/Core.lua:160-235`:
  - reset `WCK.db.lastProbe = {}`;
  - `P(k, v)` prints the line and appends it to `lastProbe`;
  - `Try(k, fn)` runs `fn` under `pcall` and writes `P(k, "ERROR "..err)` on failure.
- Probe sections, in order:
  - `ctx`: `GetBuildInfo()`, `IsInInstance()` (both returns), and `InCombatLockdown()`.
  - `units`: for each token in `{ "target", "focus", "mouseover", "nameplate1", "nameplate2" }`, if `UnitExists`, print:
    - `UnitGUID`, `UnitName`, `GetRaidTargetIndex`, `UnitIsDead` and `UnitCanAttack("player", u)`, each through `S`;
    - `UnitIsUnit(u, "target")` through `S`, wrapped in `pcall`.
  - `spell`: for each of `"Shadow Bolt"` and `"Corruption"`, print:
    - `C_Spell.IsSpellUsable(n)`, both returns through `S`;
    - `C_Spell.IsSpellInRange(n, "target")` through `S`;
    - `C_Spell.GetSpellCooldown(n)`: `isActive`, `isOnGCD`, `isEnabled` and `startTime`, each through `S`.
  - `secrets`: `C_Secrets.GetSpellAuraSecrecy(17941)` (Shadow Trance), plus `C_Secrets.GetSpellAuraSecrecy("Shadow Trance")`.
  - `assisted`: if `C_AssistedCombat` exists, print `IsAvailable()`, then `GetRotationSpells()` (count, then names via `C_Spell.GetSpellInfo`), then `GetNextCastSpell()`, each in its own `Try`. Otherwise print `P("C_AssistedCombat", "missing")`.
  - `cleu`: removed after the first in-game run. Registering CLEU is a forbidden action on Forever: it raises the blocked-action popup and `pcall` still reports `ok`. Treat CLEU as unavailable.
  - `plate`: `local p = C_NamePlate.GetNamePlateForUnit("target")`, then print:
    - whether `p` is nil;
    - whether `p.UnitFrame` exists;
    - the result of `pcall` creating a texture on `p.UnitFrame` and immediately hiding it.
  - `loc`: if `C_LossOfControl.GetActiveLossOfControlDataCountByUnit` exists, print its value for `"target"` through `S` under `pcall`.
  - `trace`: dump `WCK.trace` with times relative to the first entry, formatted like `TackleBox/Core.lua:233-234`.
- Slash handler: `SLASH_WARLOCKCOMBATKIT1 = "/wck"`. If not active, print "warlocks only". Commands:
  - `probe` runs `WCK.Probe()`;
  - `lock` toggles `db.locked`;
  - `reset` wipes `db.frames` and prints "/reload to apply";
  - anything else prints `/wck probe||lock||reset`.

#### 4. Tests
**File**: `WarlockCombatKit/tests/run.lua` — create
```lua
local dir = ((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
local WCK = {}
assert(loadfile(dir .. "/Logic.lua"))("WarlockCombatKit", WCK)

local function eq(got, want, label)
  if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end
local function near(got, want, label)
  if math.abs(got - want) > 1e-9 then error(label .. ": expected " .. want .. ", got " .. got, 2) end
end

-- Phase 1
local m = WCK.MergeDefaults(nil, { a = 1, t = { b = 2 } })
eq(m.a, 1, "fills scalar"); eq(m.t.b, 2, "fills nested")
m = WCK.MergeDefaults({ a = 5, t = "bad" }, { a = 1, t = { b = 2 } })
eq(m.a, 5, "keeps saved"); eq(m.t.b, 2, "replaces non-table")

print("all tests passed")
```
Later phases insert their blocks above `print`. A later phase may also need `Data.lua`; it is loaded the way `TackleBox/tests/run.lua:3-4` does it, before `Logic.lua`.

#### 5. Docs + CI
- **`WarlockCombatKit/README.md`** — create. Sections: a one-paragraph intro, then `## Install` (same wording as `WarlockUtilityKit/README.md:9-14`), `## Slash commands` (probe/lock/reset), and `## Development`, copied from WUK `README.md:161-169` with the addon name changed.
- **`WarlockCombatKit/CHANGELOG.md`** — create. Header in the WUK form (`CHANGELOG.md:1-3`, `wck-vX.Y.Z`), then `## [Unreleased]` with `### Added` and "Probe (`/wck probe`)".
- **`.github/workflows/package-wck.yml`** — create. Copy `package-wuk.yml` verbatim and apply these replacements:

| WUK value | WCK value |
|---|---|
| `WarlockUtilityKit` | `WarlockCombatKit` |
| `package-wuk.yml` | `package-wck.yml` |
| `wuk-v` | `wck-v` |
| `Warlock Utility Kit` | `Warlock Combat Kit` |

#### 6. Probe results doc
**File**: `thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md` — create after the in-game runs.
- Format it like `thoughts/qrspi/2026-10-19-warlock-utility-kit-v2/probe-results.md`: one section per run (context + raw lines from `WarlockCombatKitDB.lastProbe` in `WTF\Account\*\SavedVariables\WarlockCombatKit.lua`), then a **Conclusions** list that answers each item below with yes, no or secret.
  1. SENT `target` is non-secret in combat, in the world, a dungeon and a battleground.
  2. `castGUID` on SENT and on SUCCEEDED is non-secret and matches between them.
  3. Which overlay event fires for Nightfall (OVERLAY_SHOW 17941 and/or GLOW_SHOW on the Shadow Bolt id), and whether it fires in combat.
  4. `UnitGUID`, `UnitName`, `GetRaidTargetIndex` and `UnitIsDead` on `target`/`mouseover`/`nameplateN`, in combat, per instance type.
  5. `IsSpellUsable`/`IsSpellInRange` in combat.
  6. Results from `C_AssistedCombat`.
  7. CLEU: unavailable (registering it is blocked; see the `cleu` note above).
  8. Whether a texture can be created on a nameplate per instance type.
  9. The `NAME_PLATE_UNIT_REMOVED` payload when a mob dies.
  10. Whether pet `UNIT_SPELLCAST_SUCCEEDED` fires for Seduction.

### Verification
#### Automated
- [x] `lua5.1 WarlockCombatKit/tests/run.lua` prints `all tests passed`.
- [x] `grep -n "## Version: 0.1.0" WarlockCombatKit/WarlockCombatKit.toc` finds a match.
- [ ] After the push to main, the CI "Package Warlock Combat Kit" run is green and creates the `wck-v0.1.0` release.

#### Manual
- [x] Deploy, then `/reload` on a warlock. There are no Lua errors, and `/wck` prints its usage. (The CLEU probe triggered the blocked-action prompt; it was removed in 3fc7f58. Clean since.)
- [ ] On a non-warlock, `/wck probe` prints "warlocks only".
- [ ] (Open world done in Runs 1-12; **dungeon and BG skipped for now by the user**, and still to run before release.) Run `/wck probe` six times: out of combat and in combat, in each of the open world, a dungeon and a battleground. Each in-combat run happens after casting Shadow Bolt, Corruption and Fear on two different mobs, with a mouseover cast on one of them. Include one run right after a mob dies, and one with the succubus out casting Seduction.
- [x] After a Nightfall proc, run `/wck probe`. No overlay event fires; the Shadow Bolt castTime signal is used instead (Runs 7-12).
- [x] `probe-results.md` is written. All ten conclusions are answered for the open world; dungeon and BG are pending.
- [x] **Gate:** (done 2026-10-22, see "Gate review" below) re-read Phases 2-6 against those conclusions, and edit this plan where a result contradicts it (identity key order, death detection, proc event, the `usable` condition, the plate marker) before starting Phase 2.

---

## Gate review (2026-10-22, from probe-results.md)
These results are already applied to Phases 2-6 below:
1. **Identity key:** the raid mark is **SECRET in combat once set**, while GUID and name are non-secret in the open world. The key order is therefore **GUID > name > "target"**. The mark is used only as a "marked" flag (`Secret(mark) or mark ~= nil`), and there is no mark icon in rows.
2. **Pairing:** `castGUID` on SENT and SUCCEEDED is non-secret and matches between them. The castGUID fallback is dropped.
3. **Death detection:** `NAME_PLATE_UNIT_REMOVED` reports a non-secret GUID with `UnitIsDead(unit) == true` on a kill. A leash or evade removes the plate with `dead=false`, so the row is kept.
4. **Proc alerts:** Nightfall raises **no overlay event and no button glow** on Forever (buff icon only). Phase 4 is rebuilt on `C_Spell.GetSpellInfo("Shadow Bolt").castTime == 0` (3000 normally; non-secret in combat).
5. **The `usable` condition:** `IsSpellUsable` and `IsSpellInRange` are non-secret in combat, so `WCK.USABLE_OK = true`.
6. **Assisted Combat:** unavailable for warlocks, so the fallback toggle is **removed** from Phase 5.
7. **Nameplate marker:** textures can be created on enemy plates in the open world. Instances are untested, so `PLATE_OK` stays at world-only.
8. **Pet casts:** pet `SUCCEEDED` fires for Seduction (6358) and for every other succubus ability, so the handler filters to tracked spells, as planned.
9. **Dungeon and BG:** untested. The runtime guards fall back to the "target" key, and the plate marker stays off in instances.

---

## Phase 2: Panel + cast map

### Changes

#### 1. Tracked spell data
**File**: `WarlockCombatKit/Data.lua` — create, and add it to the TOC before `Logic.lua`.
```lua
local ADDON, WCK = ...
WCK.DATA = {}
-- ponytail: enUS names; Forever spell names come from beta notes, unknown ones are skipped at login
-- stale = seconds after which the icon is fully faded (rough durations, not timers)
WCK.DATA.tracked = {
  ["Corruption"] = { kind = "dot", stale = 18 }, ["Immolate"] = { kind = "dot", stale = 15 },
  ["Siphon Life"] = { kind = "dot", stale = 30 }, ["Unstable Affliction"] = { kind = "dot", stale = 18 },
  ["Curse of Agony"] = { kind = "curse", stale = 24 }, ["Bane of Agony"] = { kind = "curse", stale = 24 },
  ["Curse of Doom"] = { kind = "curse", stale = 60 }, ["Bane of Doom"] = { kind = "curse", stale = 60 },
  ["Bane of Havoc"] = { kind = "curse", stale = 300 },
  ["Curse of the Elements"] = { kind = "curse", stale = 300 }, ["Curse of Recklessness"] = { kind = "curse", stale = 120 },
  ["Curse of Weakness"] = { kind = "curse", stale = 120 }, ["Curse of Tongues"] = { kind = "curse", stale = 30 },
  ["Curse of Exhaustion"] = { kind = "curse", stale = 12 },
  ["Fear"] = { kind = "cc", stale = 20 }, ["Banish"] = { kind = "cc", stale = 30 },
  ["Seduction"] = { kind = "cc", stale = 15 }, ["Death Coil"] = { kind = "cc", stale = 3 },
  ["Howl of Terror"] = { kind = "cc", stale = 8 },
}
```

#### 2. Cast map logic
**File**: `WarlockCombatKit/Logic.lua` — append
```lua
-- cast map: what I cast, keyed per enemy; all times are GetTime() seconds
function WCK.NewCastMap() return { pending = {}, rows = {} } end

-- nil for anything secret; guid > name > current target (raid marks turn secret in combat once set)
function WCK.EnemyKey(guid, name)
  if guid then return "guid:" .. guid, name end
  if name then return "name:" .. name, name end
  return "target", nil
end

-- which unit token the SENT target name refers to (names = {token = non-secret name or nil})
local TOKENS = { "mouseover", "target", "focus" }
function WCK.PickUnit(sentName, names)
  if sentName then
    for _, u in ipairs(TOKENS) do if names[u] == sentName then return u end end
  end
  return "target"
end

function WCK.CastSent(map, castGUID, spell, key, label, guid, now)
  if not castGUID or not spell or not key then return end
  for g, p in pairs(map.pending) do if now - p.t > 10 then map.pending[g] = nil end end -- lost SUCCEEDED/FAILED
  map.pending[castGUID] = { spell = spell, key = key, label = label, guid = guid, t = now }
end

function WCK.CastLanded(map, key, label, guid, spell, now)
  local row = map.rows[key]
  if not row then row = { key = key, casts = {} }; map.rows[key] = row end
  row.label, row.guid, row.last = label or row.label, guid or row.guid, now
  row.casts[spell] = now
end

function WCK.CastSucceeded(map, castGUID, now)
  local p = castGUID and map.pending[castGUID]
  if not p then return end
  map.pending[castGUID] = nil
  WCK.CastLanded(map, p.key, p.label, p.guid, p.spell, now)
end

function WCK.CastFailed(map, castGUID) if castGUID then map.pending[castGUID] = nil end end
function WCK.ClearRow(map, key) map.rows[key] = nil end
function WCK.ClearGUID(map, guid)
  for k, row in pairs(map.rows) do if row.guid == guid then map.rows[k] = nil end end
end
function WCK.ClearAll(map) map.pending, map.rows = {}, {} end

-- 1 when fresh, linear down to 0.3 at stale, then stays 0.3 ("cast, maybe expired")
function WCK.IconAlpha(age, stale)
  if age <= 0 then return 1 end
  if age >= stale then return 0.3 end
  return 1 - 0.7 * age / stale
end

-- rows newest first; icons newest first
function WCK.RowsView(map, now, tracked)
  local out = {}
  for _, row in pairs(map.rows) do
    local icons = {}
    for spell, t in pairs(row.casts) do
      local d = tracked[spell] or { kind = "dot", stale = 20 }
      icons[#icons + 1] = { spell = spell, age = now - t, alpha = WCK.IconAlpha(now - t, d.stale), kind = d.kind, stale = d.stale }
    end
    table.sort(icons, function(a, b) return a.age < b.age end)
    out[#out + 1] = { key = row.key, label = row.label, last = row.last, icons = icons }
  end
  table.sort(out, function(a, b) return a.last > b.last end)
  return out
end
```

#### 3. Core cast events
**File**: `WarlockCombatKit/Core.lua` — modify. Add the following after the trace block, inside `table.insert(WCK.inits, function() ... end)` so that it only runs for warlocks.
- `WCK.map = WCK.NewCastMap()`.
- A `NonSecret(v)` helper returns `v`, or nil if `v` is secret.
- `WCK.Identify(unit)` returns `key, label, guid, marked`. It passes the unit's `UnitGUID` and `UnitName` through `NonSecret` and calls `WCK.EnemyKey(guid, name)`. `marked` is `WCK.Secret(m) or m ~= nil`, where `m = GetRaidTargetIndex(unit)`; the `Secret` check runs first, so a secret value is never compared. Each read runs under `pcall`, and a failure counts as nil.
- `WCK.SpellName(spellID)` is copied from `WarlockUtilityKit/Core.lua:160-164`.
- Event handlers:
```lua
WCK.On("UNIT_SPELLCAST_SENT", function(unit, target, castGUID, spellID)
  if unit ~= "player" then return end
  local spell = WCK.SpellName(spellID)
  if not spell or not WCK.DATA.tracked[spell] or WCK.Secret(castGUID) then return end
  local names = {}
  for _, u in ipairs({ "mouseover", "target", "focus" }) do names[u] = NonSecret(UnitName(u)) end
  local u = WCK.PickUnit(NonSecret(target), names)
  local key, label, guid = WCK.Identify(u)
  WCK.CastSent(WCK.map, castGUID, spell, key, label or NonSecret(target), guid, GetTime())
end)
WCK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, castGUID, spellID)
  if unit == "player" and not WCK.Secret(castGUID) then WCK.CastSucceeded(WCK.map, castGUID, GetTime()); WCK.Refresh()
  elseif unit == "pet" then -- Seduction: pet casts have no SENT; key on the pet's target
    local spell = WCK.SpellName(spellID)
    if spell and WCK.DATA.tracked[spell] then
      local key, label, guid = WCK.Identify("pettarget")
      WCK.CastLanded(WCK.map, key, label, guid, spell, GetTime()); WCK.Refresh()
    end
  end
end)
for _, ev in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
  WCK.On(ev, function(unit, castGUID) if unit == "player" and not WCK.Secret(castGUID) then WCK.CastFailed(WCK.map, castGUID) end end)
end
WCK.On("NAME_PLATE_UNIT_REMOVED", function(unit)
  local guid = NonSecret(UnitGUID(unit))
  if guid and UnitIsDead(unit) == true then WCK.ClearGUID(WCK.map, guid); WCK.Refresh() end -- despawn of a live mob keeps its row
end)
WCK.On("PLAYER_REGEN_ENABLED", function() WCK.ClearAll(WCK.map) end) -- Refresh is debounced 0.1s, so this clear lands before the redraw
C_Timer.NewTicker(0.5, function()
  if next(WCK.map.rows) == nil then return end
  if UnitExists("target") and UnitIsDead("target") == true then WCK.ClearRow(WCK.map, (WCK.Identify("target"))) end
  WCK.Refresh()
end)
```
- `UnitIsDead(...) == true` is false for a secret value, which keeps the row without raising an error.
- **Probe-confirmed:** `castGUID` is non-secret and matches between SENT and SUCCEEDED. A `FAILED` carrying a `Cast-2-…` GUID with no SENT is a harmless no-op.

#### 4. Panel
**File**: `WarlockCombatKit/Panel.lua` — create, and add it to the TOC after `Core.lua`.
- Constants: `local CORE, ICON, ROW_H, MAX_ROWS, MAX_ICONS, WIDTH = 44, 18, 22, 8, 8, 236`.
- `WCK.MakeMovable(f, key, x, y)` is copied from `WarlockUtilityKit/UI.lua:13-26`, using `WCK.db`.
- `Disc(f, layer, sub)` is copied from `UI.lua:53-59`, anchored at `TOPLEFT` offset `(8 + CORE/2, -8 - CORE/2)` and centered on the core instead of the ring.
- Build is an init:
```lua
table.insert(WCK.inits, function()
  local f = CreateFrame("Frame", "WCKPanel", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, 60); f:SetFrameStrata("MEDIUM")
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f:SetBackdropColor(0.04, 0, 0.07, 0.85); f:SetBackdropBorderColor(0.58, 0.51, 0.79, 0.9)
  f.rim = Disc(f, "BACKGROUND", 1); f.rim:SetSize(CORE + 10, CORE + 10); f.rim:SetColorTexture(0.58, 0.51, 0.79, 0.55)
  f.disc = Disc(f, "BACKGROUND", 2); f.disc:SetSize(CORE + 4, CORE + 4); f.disc:SetColorTexture(0.04, 0, 0.07, 0.9)
  f.core = f:CreateTexture(nil, "ARTWORK"); f.core:SetSize(CORE, CORE)
  f.core:SetPoint("TOPLEFT", 8, -8); f.core:SetTexture("Interface\\Icons\\Spell_Shadow_DeathCoil"); f.core:SetDesaturated(true)
  -- Phase 4 adds f.procs to the right of the core; Phase 5 drives f.core
  f.rows = {}
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, f); r:SetSize(WIDTH - 16, ROW_H)
    r:SetPoint("TOPLEFT", 8, -(CORE + 16) - (i - 1) * (ROW_H + 2))
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.label:SetPoint("LEFT")
    r.label:SetWidth(88); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
    r.icons = {}
    for j = 1, MAX_ICONS do
      local t = r:CreateTexture(nil, "ARTWORK"); t:SetSize(ICON, ICON); t:SetPoint("LEFT", 92 + (j - 1) * (ICON + 1), 0)
      t:SetTexCoord(0.07, 0.93, 0.07, 0.93); r.icons[j] = t
    end
    r:Hide(); f.rows[i] = r
  end
  WCK.MakeMovable(f, "panel", 260, -160) -- clear of WUK's strip at CENTER 0,-220
  WCK.panel = f
end)
```
- Refresher `WCK.RenderPanel()`:
  - `f:SetShown(WCK.db.shown)`.
  - `local view = WCK.RowsView(WCK.map, GetTime(), WCK.DATA.tracked)`.
  - For `i = 1..MAX_ROWS`, take row `v = view[i]`:
    - `r.label` is `v.label or (v.key == "target" and "Target" or "?")`.
    - Icon `j` is `C_Spell.GetSpellTexture(icon.spell)` with `SetAlpha(icon.alpha)`, and is shown or hidden.
  - Panel height: `CORE + 20 + max(#view, 1) * (ROW_H + 2)`.
- `WCKPanel` is not secure, so it can be shown, hidden and resized in combat. Only dragging is combat-gated, through `MakeMovable`.

#### 5. Settings + minimap
**File**: `WarlockCombatKit/Settings.lua` — create, and add it to the TOC last.
- Copy `WarlockUtilityKit/Settings.lua` whole and change the following:
  - Names become `WCKSettings` and `WCKMinimapButton`, with the title "Warlock Combat Kit".
  - The window size is `380 x 620`. Later phases add sections lower down.
  - There are two checks: "Show panel" (`db.shown`, which sets the value and calls `WCK.Refresh()`) and "Lock panel (no Shift+drag)" (`db.locked`). They write the DB directly instead of going through `Run`.
  - Remove the pet dropdown, the "Assignment board" button and `Run`. Keep "Reset positions" as `wipe(WCK.db.frames); WCK.Print("positions reset - /reload to apply")`.
  - Minimap button:
    - left-click opens or closes the settings with `WCK.ToggleSettings()`;
    - right-click toggles `db.shown`, then calls `WCK.Refresh()`;
    - the icon is `Interface\Icons\Spell_Shadow_DeathCoil`, at the default angle 240.
- Expose `WCK.settingsY`, the next free y offset, so that later phases append their sections below.
- Core slash: add `config` (`WCK.ToggleSettings()`) and `show`/`hide` (set `db.shown`, then `WCK.Refresh()`) to `/wck`.

#### 6. Tests
**File**: `WarlockCombatKit/tests/run.lua` — modify. Load `Data.lua` before `Logic.lua`.
```lua
-- Phase 2
local k, l = WCK.EnemyKey("G1", "Boar"); eq(k, "guid:G1", "guid wins"); eq(l, "Boar", "label kept")
eq((WCK.EnemyKey(nil, "Boar")), "name:Boar", "name next"); eq((WCK.EnemyKey(nil, nil)), "target", "all secret")
eq(WCK.PickUnit("Boar", { target = "Wolf", mouseover = "Boar" }), "mouseover", "mouseover match")
eq(WCK.PickUnit("Wolf", { target = "Wolf" }), "target", "target match")
eq(WCK.PickUnit(nil, { target = "Wolf" }), "target", "secret name")
local map = WCK.NewCastMap()
WCK.CastSent(map, "c1", "Corruption", "guid:G1", "Boar", "G1", 100)
WCK.CastSent(map, "c2", "Fear", "name:Wolf", "Wolf", nil, 100.5)
eq(map.rows["guid:G1"], nil, "not landed yet")
WCK.CastSucceeded(map, "c2", 101); WCK.CastSucceeded(map, "c1", 101.5)
eq(map.rows["guid:G1"].casts.Corruption, 101.5, "c1 landed"); eq(map.rows["name:Wolf"].casts.Fear, 101, "c2 landed")
WCK.CastSent(map, "c3", "Immolate", "guid:G1", "Boar", "G1", 102); WCK.CastFailed(map, "c3"); WCK.CastSucceeded(map, "c3", 103)
eq(map.rows["guid:G1"].casts.Immolate, nil, "failed dropped")
WCK.CastFailed(map, "never-sent"); eq(next(map.pending), nil, "unknown failed is a no-op")
WCK.CastSent(map, "old", "Fear", "x", nil, nil, 0); WCK.CastSent(map, "new", "Fear", "x", nil, nil, 20)
eq(map.pending.old, nil, "stale pending pruned")
near(WCK.IconAlpha(0, 10), 1, "fresh"); near(WCK.IconAlpha(5, 10), 0.65, "half"); near(WCK.IconAlpha(30, 10), 0.3, "floor")
local v = WCK.RowsView(map, 110, WCK.DATA.tracked)
eq(#v, 2, "two rows"); eq(v[1].key, "guid:G1", "newest row first"); eq(v[1].icons[1].spell, "Corruption", "icon")
WCK.CastLanded(map, "guid:G9", "Imp", "G9", "Fear", 111); WCK.ClearGUID(map, "G9"); eq(map.rows["guid:G9"], nil, "clear by guid")
WCK.ClearAll(map); eq(next(map.rows), nil, "clear all")
```

### Verification
#### Automated
- [ ] `lua5.1 WarlockCombatKit/tests/run.lua` prints `all tests passed`.

#### Manual
- [ ] Deploy and `/reload`. The panel shows with an empty desaturated core; Shift+drag moves it, it does not move after `/wck lock`, and its position survives a `/reload`.
- [ ] On a three-mob pack, cast Corruption and Curse of Agony on all three, including one by mouseover. Expect three rows labelled with the mob names; same-named mobs still get separate rows, because they are keyed by GUID. Icons fade over time.
- [ ] A resisted Fear still shows. A cast you cancel mid-cast does not.
- [ ] When the current target dies, its row clears within about 0.5s. All rows clear when you leave combat.
- [ ] In a dungeon pull there are no Lua errors and the rows are as rich as Phase 1 conclusion 4 allows.
- [ ] The minimap button: left-click toggles settings, right-click toggles the panel, and dragging moves it around the minimap.

---

## Phase 3: CC highlight (+ optional nameplate marker)

### Changes

#### 1. Logic
**File**: `WarlockCombatKit/Logic.lua` — append
```lua
function WCK.RowHasCC(viewRow)
  for _, i in ipairs(viewRow.icons) do if i.kind == "cc" and i.age < i.stale then return true end end
  return false
end
```
`RowsView` already passes `stale` on each icon.

#### 2. Glow on rows
**File**: `WarlockCombatKit/Panel.lua` — modify
- Copy `WCK.AddGlow(b)` and `WCK.SetAlert(b, on)` verbatim from `WarlockUtilityKit/UI.lua:96-110`, with `WUK` renamed to `WCK`.
- In the row build, call `WCK.AddGlow(r)` after `r:SetSize`. The glow texture is 1.8 times the row size, which is too large for a 220x22 row, so after `AddGlow` re-anchor it with `r.glow:ClearAllPoints(); r.glow:SetPoint("TOPLEFT", -6, 6); r.glow:SetPoint("BOTTOMRIGHT", 6, -6)`.
- In `RenderPanel`, call `WCK.SetAlert(r, v and WCK.RowHasCC(v))`. Hidden rows get `SetAlert(r, false)`.

#### 3. Nameplate marker (off by default)
**File**: `WarlockCombatKit/Panel.lua` — modify; `Core.lua` adds DEFAULTS `plateMarker = false`.
```lua
-- ponytail: one marker per visible plate; plates are pooled by Blizzard, so key markers by plate frame
local markers = {}
local function PlateMarker(unit, on)
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or not plate or not plate.UnitFrame then return end
  local m = markers[plate]
  if not m and on then
    local okT, t = pcall(plate.UnitFrame.CreateTexture, plate.UnitFrame, nil, "OVERLAY")
    if not okT then return end
    t:SetSize(20, 20); t:SetPoint("BOTTOM", plate.UnitFrame, "TOP", 0, 2)
    t:SetTexture("Interface\\Icons\\Spell_Shadow_Possession") -- Fear icon
    markers[plate], m = t, t
  end
  if m then m:SetShown(on) end
end
```
- Refresher: hide every marker first. If `WCK.db.plateMarker` is on and the Phase 1 hard-coded gate `WCK.PLATE_OK(instanceType)` passes, then for `i = 1..40` with `UnitExists("nameplate"..i)`:
  - call `WCK.Identify("nameplate"..i)`;
  - if a view row with that key has CC, call `PlateMarker("nameplate"..i, true)`.
- `WCK.PLATE_OK` is defined in `Panel.lua` as `function(kind) return kind == "none" end` (open world only). The probe confirmed plate textures work in the open world; instances are untested.
- Rows keyed `"target"` never match a nameplate. That is accepted: a mob only gets a marker when it has an identity key.

#### 4. Settings
**File**: `WarlockCombatKit/Settings.lua` — modify. Add the check "Mark CC'd mobs on nameplates (open world)", which toggles `db.plateMarker` and calls `WCK.Refresh()`.

#### 5. Tests
```lua
-- Phase 3
eq(WCK.RowHasCC({ icons = { { kind = "cc", age = 5, stale = 20 } } }), true, "fresh fear")
eq(WCK.RowHasCC({ icons = { { kind = "cc", age = 25, stale = 20 } } }), false, "stale fear")
eq(WCK.RowHasCC({ icons = { { kind = "dot", age = 1, stale = 20 } } }), false, "dot only")
```

### Verification
#### Automated
- [ ] `lua5.1 WarlockCombatKit/tests/run.lua` prints `all tests passed`.

#### Manual
- [ ] Fear one mob. Its row pulses purple until about 20s after the cast, then stops. DoT-only rows never pulse.
- [ ] With the plate toggle off, no markers appear anywhere.
- [ ] In the open world, with the toggle on, a feared mob (GUID-keyed) shows the Fear icon above its nameplate, and the icon hides when the CC goes stale.
- [ ] In a dungeon with the toggle on, there are no Lua errors and no `ADDON_ACTION_BLOCKED`. Markers are suppressed unless Phase 1 showed instanced plates allow textures.

---

## Phase 4: Proc alerts

Gate result: Nightfall on Forever shows a buff icon only. No `SPELL_ACTIVATION_OVERLAY_*` event fires and no action button glows. The proc signal is instead **Shadow Bolt's `castTime` dropping to 0** (it is 3000 normally, and non-secret in combat). Backlash, if present, makes Shadow Bolt instant too, so this single signal covers both procs.

### Changes

#### 1. Data
**File**: `WarlockCombatKit/Data.lua` — modify
```lua
-- spell = the spell a proc makes instant; the proc is up while its castTime reads 0 (probe runs 11-12)
WCK.DATA.procs = {
  { key = "nightfall", spell = "Shadow Bolt", icon = "Interface\\Icons\\Spell_Shadow_Twilight" },
}
```

#### 2. Logic
**File**: `WarlockCombatKit/Logic.lua` — append
```lua
-- castTimes = {[spell] = ms or nil}; a proc is up when its spell is known and instant
function WCK.ProcsUp(procs, castTimes)
  local up = {}
  for _, p in ipairs(procs) do if castTimes[p.spell] == 0 then up[p.key] = true end end
  return up
end
-- keys that turned on since last time (sound/shine fire once per proc)
function WCK.NewProcs(prev, now)
  local out = {}
  for k in pairs(now) do if not prev[k] then out[#out + 1] = k end end
  return out
end
```

#### 3. Core
**File**: `WarlockCombatKit/Core.lua` — modify, inside the warlock init.
- Add DEFAULTS `procAlerts = true, procSound = true`, and add `WCK.procs = {}`.
- A refresher, inserted before the panel's, reads the cast times and updates `WCK.procs`:
```lua
table.insert(WCK.refreshers, function()
  local times = {}
  for _, p in ipairs(WCK.DATA.procs) do
    local ok, info = pcall(C_Spell.GetSpellInfo, p.spell)
    local ct = ok and info and info.castTime
    if ct ~= nil and not WCK.Secret(ct) and IsPlayerSpell(info.spellID) then times[p.spell] = ct end
  end
  local up = WCK.ProcsUp(WCK.DATA.procs, times)
  if WCK.db.procAlerts and WCK.db.procSound and #WCK.NewProcs(WCK.procs, up) > 0 then
    PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")
  end
  WCK.procs = up
end)
```
- Triggers:
  - `WCK.On("UNIT_AURA", function(u) if u == "player" then WCK.Refresh() end end)`. The unit token is non-secret; the aura payload is never read.
  - `SPELL_UPDATE_USABLE` and `PLAYER_TALENT_UPDATE` both call `WCK.Refresh`.
  - The SUCCEEDED handler already refreshes after the instant Shadow Bolt consumes the proc.
- **Ceiling:** an instant-cast talent or a Shadow Bolt rank with castTime 0 would read as a permanent proc. Add a `ponytail:` comment saying so; it is unlikely for Shadow Bolt.

#### 4. Panel
**File**: `WarlockCombatKit/Panel.lua` — modify
- In the build, create `f.procs[i]` for each entry of `WCK.DATA.procs`: a 28px `Frame` holding an icon texture, placed at `TOPLEFT (CORE + 20 + (i-1)*32, -16)`. Call `WCK.AddGlow(frame)` and add a shine Scale animation copied from `WarlockUtilityKit/UI.lua:135-138`.
- In `RenderPanel`, for each proc:
  - `on = WCK.db.procAlerts and WCK.procs[p.key]`;
  - set the alpha to `on and 1 or 0.25` and call `SetDesaturated(not on)`;
  - call `WCK.SetAlert(frame, on)`;
  - play the shine when `on` flips to true (track `frame.wasOn`).

#### 5. Settings
**File**: `WarlockCombatKit/Settings.lua` — modify. Add the checks "Proc alerts" (`db.procAlerts`) and "Proc sound" (`db.procSound`).

#### 6. Tests
```lua
-- Phase 4
local PR = { { key = "nightfall", spell = "Shadow Bolt" } }
eq(WCK.ProcsUp(PR, { ["Shadow Bolt"] = 0 }).nightfall, true, "instant = proc")
eq(WCK.ProcsUp(PR, { ["Shadow Bolt"] = 3000 }).nightfall, nil, "normal cast")
eq(WCK.ProcsUp(PR, {}).nightfall, nil, "unknown spell")
eq(#WCK.NewProcs({}, { nightfall = true }), 1, "rising edge"); eq(#WCK.NewProcs({ nightfall = true }, { nightfall = true }), 0, "no repeat")
```

### Verification
#### Automated
- [ ] `lua5.1 WarlockCombatKit/tests/run.lua` prints `all tests passed`.

#### Manual
- [ ] Put DoTs up until Nightfall procs, which the buff icon shows. The WCK Nightfall icon lights up, pulses and shines, and the sound plays once. Cast the instant Shadow Bolt: the icon greys out.
- [ ] With no proc, the icon stays grey both in and out of combat.
- [ ] Turning off "Proc sound" silences it. Turning off "Proc alerts" keeps the icon grey.

---

## Phase 5: Rotation helper

### Changes

#### 1. Data
**File**: `WarlockCombatKit/Data.lua` — modify
```lua
-- spells offered in the rule editor (filtered to known spells at login)
WCK.DATA.rotation = { "Shadow Bolt", "Incinerate", "Searing Pain", "Soul Fire", "Shadowburn", "Conflagrate", "Drain Life",
  "Drain Soul", "Life Tap", "Haunt", "Chaos Bolt", "Corruption", "Immolate", "Siphon Life", "Unstable Affliction",
  "Curse of Agony", "Bane of Agony", "Curse of Doom", "Bane of Doom", "Curse of the Elements", "Curse of Recklessness",
  "Fear", "Death Coil", "Howl of Terror" }
WCK.DATA.defaultRules = {
  { spell = "Corruption", cond = "notRecent", n = 15 }, { spell = "Curse of Agony", cond = "notRecent", n = 22 },
  { spell = "Bane of Agony", cond = "notRecent", n = 22 }, { spell = "Immolate", cond = "notRecent", n = 13 },
  { spell = "Shadow Bolt", cond = "proc" }, { spell = "Shadow Bolt", cond = "ready" },
}
WCK.DATA.conds = { "ready", "notRecent", "proc", "marked", "usable" } -- "usable" only if WCK.USABLE_OK
```
**Deviation from structure.md:** "always" and "ready" are merged into `ready`. Every rule requires the spell to be known and off cooldown, so an extra `always` condition would add nothing.

#### 2. Logic
**File**: `WarlockCombatKit/Logic.lua` — append
```lua
-- state = { known = {[spell]=true}, ready = {[spell]=bool}, usable = {[spell]=bool}, lastOnTarget = {[spell]=age},
--           proc = bool, marked = bool }
local CONDS = {
  ready = function() return true end,
  notRecent = function(r, s) local a = s.lastOnTarget[r.spell]; return a == nil or a >= (r.n or 0) end,
  proc = function(_, s) return s.proc end,
  marked = function(_, s) return s.marked end,
  usable = function(r, s) return s.usable[r.spell] ~= false end,
}
function WCK.EvalRules(rules, state)
  for _, r in ipairs(rules) do
    local c = CONDS[r.cond]
    if c and state.known[r.spell] and state.ready[r.spell] ~= false and c(r, state) then return r.spell end
  end
end

function WCK.MoveRule(rules, i, dir)
  local j = i + dir
  if not rules[i] or j < 1 or j > #rules then return false end
  rules[i], rules[j] = rules[j], rules[i]
  return true
end

-- deep copy so editing a character's list never mutates DATA.defaultRules
function WCK.CopyRules(rules)
  local out = {}
  for i, r in ipairs(rules) do out[i] = { spell = r.spell, cond = r.cond, n = r.n } end
  return out
end
```

#### 3. Core
**File**: `WarlockCombatKit/Core.lua` — modify
- `CHAR_DEFAULTS` gets nothing from `MergeDefaults` for rules, because a merged list would mix with the defaults. In the warlock init, if `WCK.char.rules == nil` then set `WCK.char.rules = WCK.CopyRules(WCK.DATA.defaultRules)`.
- `WCK.USABLE_OK = true`. This is a hard-coded gate: probe Run 1 showed `IsSpellUsable` is non-secret in combat in the open world. The `pcall`/`Secret` guard still covers instances.
- `WCK.BuildRuleState(now)`:
```lua
function WCK.BuildRuleState(now)
  local s = { known = {}, ready = {}, usable = {}, lastOnTarget = {}, proc = next(WCK.procs) ~= nil, marked = false }
  for _, name in ipairs(WCK.DATA.rotation) do
    local info = C_Spell.GetSpellInfo(name)
    if info and IsPlayerSpell(info.spellID) then
      s.known[name] = true
      local okC, cd = pcall(C_Spell.GetSpellCooldown, name)
      if okC and cd and not WCK.Secret(cd.isActive) and not WCK.Secret(cd.isOnGCD) then
        s.ready[name] = not cd.isActive or cd.isOnGCD == true -- GCD alone does not block
      end
      if WCK.USABLE_OK then
        local okU, u = pcall(C_Spell.IsSpellUsable, name)
        if okU and not WCK.Secret(u) then s.usable[name] = u end
      end
    end
  end
  if UnitExists("target") then
    local key, _, _, marked = WCK.Identify("target")
    s.marked = marked
    local row = WCK.map.rows[key]
    if row then for spell, t in pairs(row.casts) do s.lastOnTarget[spell] = now - t end end
  end
  return s
end
```
- The refresher `WCK.NextSpell()` computes `local spell = WCK.EvalRules(WCK.char.rules, WCK.BuildRuleState(GetTime()))`.
  - The result is stored in `WCK.next`.
- Refresh also needs a trigger on `SPELL_UPDATE_COOLDOWN`, `PLAYER_TARGET_CHANGED` and `RAID_TARGET_UPDATE`, each calling `WCK.Refresh`. The debounce limits the cost.

#### 4. Panel core icon
**File**: `WarlockCombatKit/Panel.lua` — modify
- In `RenderPanel`:
  - if `WCK.next` is set, use `f.core:SetTexture(C_Spell.GetSpellTexture(WCK.next))` and `SetDesaturated(false)`;
  - otherwise keep the default texture, desaturated.
- The `NextSpell` refresher is inserted before `RenderPanel` in `WCK.refreshers`. Load order makes this hold: Core's refresher is inserted in its init, which runs before Panel's.
- Tooltip on hover of the core: "Next: <spell>", or "No rule matches".

#### 5. Rule editor
**File**: `WarlockCombatKit/Settings.lua` — modify. Add a "Rotation" section at `WCK.settingsY`.
- The section holds 10 pooled rule rows (`MAX_RULES = 10`), each 24px high. A row has:
  - a spell `WowStyle1DropdownTemplate` (width 130) built from `WCK.DATA.rotation`, filtered to known spells, with radios that set `rule.spell`;
  - a condition dropdown (width 90) built from `WCK.DATA.conds`, skipping `usable` unless `WCK.USABLE_OK`;
  - an `InputBoxTemplate` edit box (width 30, numeric), shown only when `cond == "notRecent"`. `OnEnterPressed` and `OnEditFocusLost` set `rule.n = tonumber(text) or 0`;
  - "^" and "v" `UIPanelButtonTemplate` buttons (20x20) that call `WCK.MoveRule(WCK.char.rules, i, -1/1)`;
  - an "x" button that runs `table.remove(WCK.char.rules, i)`.
  - Every change calls `win:SyncRules()` and then `WCK.Refresh()`.
- An "Add rule" button runs `table.insert(WCK.char.rules, { spell = "Shadow Bolt", cond = "ready" })` and is disabled at `MAX_RULES`.
- A "Defaults" button runs `WCK.char.rules = WCK.CopyRules(WCK.DATA.defaultRules)`.
- `win:SyncRules()` shows rows `1..#rules`, regenerates their menus, sets the edit text, and hides the rest. It is called from `win:Sync`.
- **Ceiling:** a list longer than 10 rules is capped by the disabled Add button. Mark it with `-- ponytail: 10 rules max, add a ScrollBox if users want more`.

#### 6. Tests
```lua
-- Phase 5
local st = { known = { ["Corruption"] = true, ["Shadow Bolt"] = true }, ready = {}, usable = {}, lastOnTarget = {}, proc = false, marked = false }
local rules = { { spell = "Corruption", cond = "notRecent", n = 15 }, { spell = "Shadow Bolt", cond = "proc" }, { spell = "Shadow Bolt", cond = "ready" } }
eq(WCK.EvalRules(rules, st), "Corruption", "first rule")
st.lastOnTarget.Corruption = 3; eq(WCK.EvalRules(rules, st), "Shadow Bolt", "recent skips")
st.lastOnTarget.Corruption = 15; eq(WCK.EvalRules(rules, st), "Corruption", "boundary passes")
st.lastOnTarget.Corruption = 1; st.ready["Shadow Bolt"] = false; eq(WCK.EvalRules(rules, st), nil, "cooldown blocks")
st.ready["Shadow Bolt"] = nil; st.known["Shadow Bolt"] = nil; eq(WCK.EvalRules(rules, st), nil, "unknown skipped")
eq(WCK.EvalRules({ { spell = "Corruption", cond = "marked" } }, { known = { Corruption = true }, ready = {}, usable = {}, lastOnTarget = {}, marked = true }), "Corruption", "marked")
eq(WCK.EvalRules({ { spell = "Corruption", cond = "usable" } }, { known = { Corruption = true }, ready = {}, usable = { Corruption = false }, lastOnTarget = {} }), nil, "unusable")
eq(WCK.EvalRules({}, st), nil, "empty list")
eq(WCK.EvalRules({ { spell = "Corruption", cond = "bogus" } }, st), nil, "unknown cond")
local rl = { { spell = "A" }, { spell = "B" } }
eq(WCK.MoveRule(rl, 2, -1), true, "move up"); eq(rl[1].spell, "B", "swapped")
eq(WCK.MoveRule(rl, 1, -1), false, "top edge"); eq(WCK.MoveRule(rl, 2, 1), false, "bottom edge")
local c = WCK.CopyRules(rl); c[1].spell = "Z"; eq(rl[1].spell, "B", "copy is deep")
```

### Verification
#### Automated
- [ ] `lua5.1 WarlockCombatKit/tests/run.lua` prints `all tests passed`.

#### Manual
- [ ] On a fresh character, the core shows Corruption on a new target, then Curse of Agony (or Bane of Agony) once Corruption is cast, then Shadow Bolt.
- [ ] Moving Shadow Bolt "ready" to the top makes the core always show Shadow Bolt. "Defaults" restores the list.
- [ ] A rule saves per character: `/reload` keeps it, and an alt has its own list.
- [ ] The core updates in combat and nothing is cast without a key press.
- [ ] With an empty rule list, the core stays grey and there are no errors.

---

## Phase 6: Mouseover click-cast slots

### Changes

#### 1. Bindings
**File**: `WarlockCombatKit/Bindings.xml` — create. The client auto-loads it, so it is not listed in the TOC.
```xml
<Bindings>
  <Binding name="CLICK WCKCast1:LeftButton" header="WCK" category="ADDONS"/>
  <Binding name="CLICK WCKCast2:LeftButton" category="ADDONS"/>
  <Binding name="CLICK WCKCast3:LeftButton" category="ADDONS"/>
  <Binding name="CLICK WCKCast4:LeftButton" category="ADDONS"/>
  <Binding name="CLICK WCKCast5:LeftButton" category="ADDONS"/>
  <Binding name="CLICK WCKCast6:LeftButton" category="ADDONS"/>
</Bindings>
```

#### 2. Logic
**File**: `WarlockCombatKit/Logic.lua` — append
```lua
WCK.SLOTS = 6
function WCK.CastMacro(spell)
  if type(spell) ~= "string" or spell == "" then return "" end
  return "/cast [@mouseover,harm,nodead][] " .. spell
end
```

#### 3. Actions
**File**: `WarlockCombatKit/Actions.lua` — create, and add it to the TOC after `Core.lua`.
```lua
local ADDON, WCK = ...
-- hidden secure buttons driven by Bindings.xml CLICK bindings; own UIParent holder so no visible frame turns protected
BINDING_HEADER_WCK = "Warlock Combat Kit"
for i = 1, WCK.SLOTS do _G["BINDING_NAME_CLICK WCKCast" .. i .. ":LeftButton"] = "Mouseover cast slot " .. i end

local buttons = {}
table.insert(WCK.inits, function()
  local holder = CreateFrame("Frame", "WCKActionHolder", UIParent)
  for i = 1, WCK.SLOTS do
    local b = CreateFrame("Button", "WCKCast" .. i, holder, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown"); b:SetAttribute("type", "macro")
    buttons[i] = b
  end
end)

-- attributes only out of combat; PLAYER_REGEN_ENABLED -> Refresh re-applies
table.insert(WCK.refreshers, function()
  if InCombatLockdown() then return end
  for i, b in ipairs(buttons) do b:SetAttribute("macrotext", WCK.CastMacro(WCK.char.slots[i])) end
end)
```
- Add `CHAR_DEFAULTS.slots = {}` in Core. Slot values are spell names, or nil.
- `BINDING_*` globals are set at file scope, so the Key Bindings UI shows the names before login.
- **Double-fire fallback:** a key binding sends both a down and an up click. If manual testing shows two casts, or a "spell not ready" error after each key press, change to `b:RegisterForClicks("AnyDown")` and record that in the CHANGELOG.

#### 4. Settings
**File**: `WarlockCombatKit/Settings.lua` — modify. Add a "Mouseover cast slots" section below Rotation.
- Six rows. Each row has:
  - a label: `"Slot "..i.." ["..(GetBindingKey("CLICK WCKCast"..i..":LeftButton") or "unbound").."]"`;
  - a spell dropdown built from `WCK.DATA.rotation`, filtered to known spells, with a first entry "(none)". Selecting an entry sets `WCK.char.slots[i]` and calls `WCK.Refresh()`.
- If `InCombatLockdown()`, print "applies after combat". The refresher already skips the attribute write in that case.
- A note FontString: "Bind keys in Esc > Options > Keybindings > AddOns > Warlock Combat Kit".
- `win:Sync` refreshes the key labels and menus.

#### 5. Tests
```lua
-- Phase 6
eq(WCK.CastMacro("Corruption"), "/cast [@mouseover,harm,nodead][] Corruption", "macro")
eq(WCK.CastMacro(nil), "", "no spell"); eq(WCK.CastMacro(""), "", "empty spell")
eq(WCK.CastMacro("Curse of Agony"), "/cast [@mouseover,harm,nodead][] Curse of Agony", "spaces kept")
```

### Verification
#### Automated
- [ ] `lua5.1 WarlockCombatKit/tests/run.lua` prints `all tests passed`.
- [ ] `grep -c "CLICK WCKCast" WarlockCombatKit/Bindings.xml` prints `6`.

#### Manual
- [ ] Esc > Keybindings > AddOns shows "Warlock Combat Kit" with 6 "Mouseover cast slot" entries. Bind slot 1 to a key.
- [ ] Set slot 1 to Corruption in WCK settings, target mob A, hover mob B's nameplate, and press the key. Corruption lands on B, and the cast map row goes to B.
- [ ] With no mouseover, the key casts on the target.
- [ ] Press the key once: exactly one cast attempt, with no "not ready" spam. If not, apply the double-fire fallback and re-test.
- [ ] Changing a slot spell in combat takes effect after combat, with no `ADDON_ACTION_BLOCKED`.
- [ ] Mouseover on the player and party unit frames with a harmful spell does nothing harmful, because `harm` falls through to the target.

---

## Phase 7: Release docs

### Changes
- **`WarlockCombatKit/README.md`**: fill in sections in WUK's style (`WarlockUtilityKit/README.md:9-169`).
  - `## Install`.
  - `## The panel`: core, procs, cast map, fading, clearing, the "cast, not confirmed" caveat.
  - `## CC highlight` (with the nameplate toggle).
  - `## Proc alerts` (or the unavailable note).
  - `## Rotation helper`: conditions table, per character, display only.
  - `## Mouseover cast slots`: binding steps.
  - `## Minimap button`, `## Settings window`, `## Slash commands`.
  - `## Notes`: Forever secret restrictions; what is not tracked: timers, enemy auras, PvP DR.
  - `## Development`.
- **`WarlockCombatKit/CHANGELOG.md`**: rename `[Unreleased]` to `## [0.1.0] — <release date>` and list each feature under `### Added`.
- **`WarlockCombatKit/WarlockCombatKit.toc`**: confirm it reads `## Version: 0.1.0` and lists Data, Logic, Core, Actions, Panel, Settings.
- **`README.md`** (root): add the line `- [WarlockCombatKit](WarlockCombatKit/) — in-combat cast map, rotation helper, proc alerts and mouseover casting for warlocks (`wck-v` releases).`

### Verification
#### Automated
- [ ] `lua5.1 WarlockCombatKit/tests/run.lua` prints `all tests passed`.
- [ ] After the merge to main, the "Package Warlock Combat Kit" run is green, and `gh release view wck-v0.1.0` lists `WarlockCombatKit-0.1.0.zip`.
- [ ] `unzip -l WarlockCombatKit-0.1.0.zip | grep -c tests/` prints `0`.

#### Manual
- [ ] Install from the release zip into a clean AddOns folder. It loads with no errors, and every README section matches what is seen in game.

---

## Testing Checkpoints
1. **Phase 1**:
   - The addon loads.
   - `lastProbe` is saved.
   - `probe-results.md` has 10 conclusions.
   - The plan gate edits are made.
   - CI is green.
2. **Phase 2**:
   - The multi-mob cast map pairs by `castGUID`.
   - Rows clear on death and on leaving combat.
   - The panel moves, locks and persists.
3. **Phase 3**:
   - CC rows pulse.
   - The plate marker is opt-in and causes no errors in instances.
4. **Phase 4**: the Nightfall icon pulses and sounds, or is documented as unavailable.
5. **Phase 5**:
   - Rules drive the core icon.
   - The editor saves per character.
6. **Phase 6**:
   - 6 bindable slots cast on mouseover.
   - Attributes are written only out of combat.
7. **Phase 7**: `wck-v0.1.0` is released with the docs.

**Note on CI:** the workflow publishes on every push to main that touches the addon. Phase 1 therefore already creates `wck-v0.1.0`, and later pushes re-upload over it (`--clobber`). That is acceptable for a beta. Do not bump the version per phase.
