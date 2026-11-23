# Implementation Plan

## Overview
- In a dungeon pull, the WCK tracker shows one row per enemy cast on, labelled with the mob's name (shown even when it is secret) or "Enemy N" as a last resort.
- When the target dies, its row clears even if the GUID is secret.
- Phase 1 first confirms in-game which values a dungeon hides.

**Conventions (all phases)**
- Tests: run `lua WarlockCombatKit/tests/run.lua` from the repo root. It must print `all tests passed`. Local Lua is 5.4; the README says `lua5.1`, and CI uses the same script.
- Lint: run `luacheck WarlockCombatKit --globals WCK` if it runs cleanly before your change. Treat only new warnings as failures.
- Deploy after each phase, before asking for an in-game check (exit codes 0-7 are success):
  `robocopy "D:\Source\wow-addons\WarlockCombatKit" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WarlockCombatKit" /MIR /XD tests /NJH /NJS /NP /NDL`
- **Never compare, concatenate, truth-test or use `or` on a secret value.** The only allowed operation is `WCK.Secret(v)` (comment at `Core.lua:242`: "comparing a secret errors"). A secret name travels wrapped in a table, `{ raw }`, so that the table itself is the thing that gets truth-tested.
- Trace detail strings wrap anything that might be secret in `S()` (`Core.lua:59`).

---

## Phase 1: Dungeon probe + per-cast key trace

### Changes

#### 1. SENT handler: KEY and DROP traces
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify the `UNIT_SPELLCAST_SENT` handler inside `WCK.inits` (currently `Core.lua:254-263`).

```lua
WCK.On("UNIT_SPELLCAST_SENT", function(unit, target, castGUID, spellID)
  if unit ~= "player" then return end
  local spell = WCK.SpellName(spellID)
  -- trace casts lost to secrecy so a dungeon run shows whether SENT itself is blind
  if WCK.Secret(spellID) or (spell and WCK.DATA.tracked[spell] and WCK.Secret(castGUID)) then
    WCK.Trace("DROP", "spell=" .. S(spellID) .. " guid=" .. S(castGUID)); return
  end
  if not spell or not WCK.DATA.tracked[spell] then return end
  local names = {}
  for _, u in ipairs({ "mouseover", "target", "focus" }) do names[u] = NonSecret(UnitName(u)) end
  local u = WCK.PickUnit(NonSecret(target), names)
  local key, label, guid = WCK.Identify(u)
  label = label or NonSecret(target)
  WCK.Trace("KEY", u .. " " .. key .. " lbl=" .. S(label))
  WCK.CastSent(WCK.map, castGUID, spell, key, label, guid, GetTime())
end)
```
- `S` and `NonSecret` are file-level locals defined above this handler (`Core.lua:59`, `Core.lua:111`).
- `key` is always a plain string, because EnemyKey only concatenates values that have already been made non-secret.

#### 2. Probe: secret-identity checks and pettarget
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify `WCK.Probe()`.
- Add `"pettarget"` to the unit loop list (`{ "target", "focus", "mouseover", "nameplate1", "nameplate2" }`, about `Core.lua:311`). Its existing `isTarget` column then reports `UnitIsUnit("pettarget","target")`.
- After the unit loop, add:

```lua
if C_Secrets then
  Try("secrets identity", function() P("secrets identity", S(C_Secrets.ShouldUnitIdentityBeSecret("target"))) end)
  Try("secrets compare", function()
    P("secrets compare", "can " .. S(C_Secrets.CanCompareUnitTokens("target", "nameplate1"))
      .. " secret " .. S(C_Secrets.ShouldUnitComparisonBeSecret("target", "nameplate1")))
  end)
  Try("secrets restricted", function() P("secrets restricted", S(C_Secrets.HasSecretRestrictions())) end)
else
  P("secrets", "C_Secrets: missing")
end
```
- The signatures of these `C_Secrets` functions are unknown. `Try` prints `ERROR ...` if one is wrong, and that output is itself a probe result.

#### 3. Changelog
**File**: `WarlockCombatKit/CHANGELOG.md`
**Action**: add a section above `## [0.2.1]`:

```markdown
## [Unreleased]

### Added
- `/wck probe` reports secret-identity checks (`C_Secrets`) and the pet's target; the trace logs the row key chosen for each cast (`KEY`) and casts dropped because the game hid their spell or cast ID (`DROP`).
```

#### 4. Record the dungeon run
**File**: `thoughts/qrspi/GH-23-warlock-combat-kit/probe-results.md`
**Action**: modify after the user pastes the dungeon `/wck probe` output.
- Append it as the next numbered run, in the same format as the existing runs.
- Tick `[ ] Dungeon, in combat: unit identity, SENT target, plate texture` (line 197).
- Add a one-line conclusion.

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] luacheck shows no new warnings
- [x] robocopy deploy exits 0-7

#### Manual
- [x] (covered by the Phase 2/4 open-world checks) Open world: cast Corruption on a mob, then `/wck probe`. Expect a `secrets ...` line and a `trace ... KEY target guid:Creature-... lbl=<name>` line.
- [x] Dungeon, in combat with 2+ mobs dotted: `/wck probe`. The user pastes the output and it is recorded in `probe-results.md`.
- [x] **GATE decision** (Run 13: identity and SENT target SECRET, no DROP: skip SENT-name step, continue), written into `probe-results.md` as a conclusion line:
  - KEY lines show `guid:` or `name:` keys in the dungeon: theory wrong. Stop and re-run research.
  - DROP lines appear for every cast: castGUID or spellID is secret. Stop and re-run design.
  - SENT `tgt=SECRET`: skip Phase 2's SENT-name step. The secret-label part of Phase 2 still applies.
  - Otherwise continue with Phase 2.

---

## Phase 2: Key on SENT name + show hidden names

> **Gate (Run 13):** the SENT target is SECRET in dungeons, so the SENT-name key step (EnemyKey `sentName`, Identify `sentName`, its tests and the "different names get rows" changelog wording) was skipped. Only the secret-label pass-through was built.

### Changes

#### 1. Logic: key chain and secret label carried through
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify.

```lua
-- nil for anything secret; guid > name > SENT target name > current target
function WCK.EnemyKey(guid, name, sentName)
  if guid then return "guid:" .. guid, name end
  if name then return "name:" .. name, name end
  if sentName then return "name:" .. sentName, sentName end
  return "target", nil
end

-- secret = { rawName } when the unit's name is secret (never compared, only handed to SetText)
function WCK.CastSent(map, castGUID, spell, key, label, guid, now, secret)
  ...unchanged...
  map.pending[castGUID] = { spell = spell, key = key, label = label, guid = guid, t = now, secret = secret }
end

function WCK.CastLanded(map, key, label, guid, spell, now, secret)
  local row = map.rows[key]
  if not row then row = { key = key, casts = {} }; map.rows[key] = row end
  row.label, row.guid, row.last = label or row.label, guid or row.guid, now
  row.secret = secret or row.secret
  row.casts[spell] = now
end
```
- `CastSucceeded`: pass `p.secret` as the last argument to `CastLanded`.
- `RowsView`: add `secret = row.secret` to each `out` entry.

#### 2. Core: Identify returns the wrapped secret name and takes the SENT name
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify `WCK.Identify` (`Core.lua:119-127`) and its SENT and pet callers.

```lua
-- key, label, guid, marked, secret ({ rawName } when the name is secret; only ever passed to SetText)
function WCK.Identify(unit, sentName)
  local okG, guid = pcall(UnitGUID, unit)
  local okN, raw = pcall(UnitName, unit)
  local okM, m = pcall(GetRaidTargetIndex, unit)
  local secret = okN and WCK.Secret(raw) and { raw } or nil
  guid = okG and NonSecret(guid) or nil
  local name = okN and NonSecret(raw) or nil
  local key, label = WCK.EnemyKey(guid, name, sentName)
  return key, label, guid, okM and (WCK.Secret(m) or m ~= nil) or false, secret
end
```
SENT handler (from Phase 1):

```lua
local sent = NonSecret(target)
local u = WCK.PickUnit(sent, names)
local key, label, guid, _, secret = WCK.Identify(u, sent)
label = label or sent
WCK.Trace("KEY", u .. " " .. key .. " lbl=" .. S(label) .. (secret and " secret" or ""))
WCK.CastSent(WCK.map, castGUID, spell, key, label, guid, GetTime(), secret)
```
- Pet branch: `local key, label, guid, _, secret = WCK.Identify("pettarget")`, then `WCK.CastLanded(WCK.map, key, label, guid, spell, GetTime(), secret)`.
- Probe `row` line: append `.. (row.secret and " secretName" or "")`.
- The other Identify callers (BuildRuleState, the ticker, the probe, RenderMarkers) ignore the extra return. No change.

#### 3. Panel: show the secret name
**File**: `WarlockCombatKit/Panel.lua`
**Action**: replace line 206.

```lua
local lbl = r.label
if v.label then lbl:SetText(v.label)
elseif not (v.secret and pcall(lbl.SetText, lbl, v.secret[1])) then
  lbl:SetText(v.key == "target" and "Target" or "?")
end
```

#### 4. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: add after the Phase 2 block's `ClearAll` line.

```lua
-- dungeon names
eq((WCK.EnemyKey(nil, nil, "Wolf")), "name:Wolf", "sent name when unit secret")
eq(select(2, WCK.EnemyKey(nil, nil, "Wolf")), "Wolf", "sent name labels")
eq((WCK.EnemyKey("G1", nil, "Wolf")), "guid:G1", "guid beats sent name")
eq((WCK.EnemyKey(nil, "Boar", "Wolf")), "name:Boar", "unit name beats sent name")
local sec = { "opaque" }
WCK.CastSent(map, "s1", "Corruption", "target", nil, nil, 200, sec); WCK.CastSucceeded(map, "s1", 201)
eq(map.rows.target.secret, sec, "secret name lands")
WCK.CastLanded(map, "target", nil, nil, "Fear", 202); eq(map.rows.target.secret, sec, "nil recast keeps secret name")
eq(WCK.RowsView(map, 203, WCK.DATA.tracked)[1].secret, sec, "view carries secret name")
WCK.ClearAll(map)
```

#### 5. Changelog
**File**: `WarlockCombatKit/CHANGELOG.md`
**Action**: under `## [Unreleased]`, add `### Fixed` with: "In dungeons, enemies with different names get their own rows, and rows show the mob's name even when the game hides it from addons."

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] luacheck shows no new warnings
- [x] robocopy deploy exits 0-7

#### Manual
- [ ] (n/a: SENT-name step skipped) Dungeon: dot two differently named mobs. Expect two rows with their names. `/wck probe` shows `row name:<Mob>` lines or `secretName`.
- [x] Open world: dot two mobs. Expect `guid:` rows and the same look as before.

---

## Phase 3: Target slot fallback

> **As built:** with the SENT-name step skipped (Run 13), signatures are `EnemyKey(guid, name, slot)` and `Identify(unit, slot)`; the "sent name beats slot" test became "name beats slot" / "guid beats slot".

### Changes

#### 1. Logic: slot key and fallback label
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify `EnemyKey` and add `FallbackLabel`.

```lua
-- nil for anything secret; guid > name > SENT name > target slot (one per target switch) > current target
function WCK.EnemyKey(guid, name, sentName, slot)
  if guid then return "guid:" .. guid, name end
  if name then return "name:" .. name, name end
  if sentName then return "name:" .. sentName, sentName end
  if slot then return "slot:" .. slot, nil end
  return "target", nil
end

-- label for a row with no readable name (a secret name, if any, is tried first by the panel)
function WCK.FallbackLabel(key)
  if key == "slot:pet" then return "Pet target" end
  local n = key:match("^slot:(%d+)$")
  if n then return "Enemy " .. n end
  return key == "target" and "Target" or "?"
end
```
- **Deviation from the structure:** a slot row's label is nil rather than "Enemy N". That lets the secret name (Phase 2) win over the generic label. The panel calls `FallbackLabel` only when there is neither a readable nor a secret name.

#### 2. Core: slot counter and passing slots
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify.
- `WCK.Identify(unit, sentName, slot)`: pass `slot` as the 4th argument of `EnemyKey`.
- Add a field near the top of the file: `WCK.targetSlot = 1`. It is a field, not a local, so that BuildRuleState and the ticker can read it.
- Inside `WCK.inits`, next to the other cast-map handlers:

```lua
WCK.On("PLAYER_TARGET_CHANGED", function() WCK.targetSlot = WCK.targetSlot + 1 end)
```
- Change the `PLAYER_REGEN_ENABLED` handler (`Core.lua:282`) to:
  `function() WCK.ClearAll(WCK.map); WCK.targetSlot = 1 end`.
- SENT handler: `WCK.Identify(u, sent, u == "target" and WCK.targetSlot or nil)`.
- Pet branch:

```lua
local okS, same = pcall(UnitIsUnit, "pettarget", "target")
local slot = (okS and not WCK.Secret(same) and same == true) and WCK.targetSlot or "pet"
local key, label, guid, _, secret = WCK.Identify("pettarget", nil, slot)
```
- BuildRuleState (`Core.lua:195`): change `WCK.Identify("target")` to `WCK.Identify("target", nil, WCK.targetSlot)`. Otherwise the rotation's "not cast on target in N s" check looks up `"target"` while dungeon rows are keyed `slot:N`.
  - **Deviation:** not in the structure, but required for the rotation to stay correct.
  - Known limit: a row keyed `name:<SENT name>` is not found from `"target"`, because the target's own name is secret.
- Probe `target key` line (`Core.lua:384`): `WCK.Identify("target", nil, WCK.targetSlot)`.

#### 3. Panel
**File**: `WarlockCombatKit/Panel.lua`
**Action**: in the Phase 2 label block, replace the fallback `v.key == "target" and "Target" or "?"` with `WCK.FallbackLabel(v.key)`.
- `RenderMarkers` is unchanged. It stays open-world only via `PLATE_OK` (`Panel.lua:46`).

#### 4. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: add after the Phase 2 dungeon block.

```lua
-- target slots
eq((WCK.EnemyKey(nil, nil, nil, 3)), "slot:3", "slot when all secret")
eq(select(2, WCK.EnemyKey(nil, nil, nil, 3)), nil, "slot leaves label to the panel")
eq((WCK.EnemyKey(nil, nil, nil, nil)), "target", "no slot keeps old fallback")
eq((WCK.EnemyKey(nil, nil, "Wolf", 3)), "name:Wolf", "sent name beats slot")
eq(WCK.FallbackLabel("slot:3"), "Enemy 3", "slot label"); eq(WCK.FallbackLabel("slot:pet"), "Pet target", "pet label")
eq(WCK.FallbackLabel("target"), "Target", "target label"); eq(WCK.FallbackLabel("guid:G1"), "?", "unknown label")
WCK.CastLanded(map, "slot:3", nil, nil, "Corruption", 300); WCK.CastLanded(map, "slot:3", nil, nil, "Curse of Agony", 301)
WCK.CastLanded(map, "slot:4", nil, nil, "Corruption", 302)
eq(#WCK.RowsView(map, 303, WCK.DATA.tracked), 2, "one row per slot")
WCK.ClearAll(map)
```

#### 5. Changelog
**File**: `WarlockCombatKit/CHANGELOG.md`
**Action**: add to `### Fixed`: "When the game hides every name, each target you switch to gets its own row (\"Enemy 1\", \"Enemy 2\"…) instead of all casts sharing one \"Target\" row."

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] luacheck shows no new warnings
- [x] robocopy deploy exits 0-7

#### Manual
- [x] Dungeon: tab between 3 mobs, putting Corruption on each. Expect 3 rows (named, or "Enemy N"); `/wck probe` lists the matching `row slot:N` or `row name:` lines.
- [x] Seduction from the succubus on a different mob than your target. Expect a "Pet target" row (or the mob's name).
- [x] Open world: unchanged.

---

## Phase 4: Clear on target death without GUID + release

### Changes

#### 1. Logic: ClearRow returns a count
**File**: `WarlockCombatKit/Logic.lua`
**Action**: modify `Logic.lua:53`.

```lua
-- returns 1 if a row was cleared, else 0
function WCK.ClearRow(map, key)
  if not map.rows[key] then return 0 end
  map.rows[key] = nil; return 1
end
```

#### 2. Core: dead-target ticker falls back to the key
**File**: `WarlockCombatKit/Core.lua`
**Action**: modify the ticker body (`Core.lua:286-289`).

```lua
if WCK.IsDead("target") then
  local key, _, guid = WCK.Identify("target", nil, WCK.targetSlot)
  local n = guid and WCK.ClearGUID(WCK.map, guid) or WCK.ClearRow(WCK.map, key)
  local id = guid or key
  if id ~= lastDeadTarget then lastDeadTarget = id; WCK.Trace("CLR_TARGET", id .. " rows=" .. n) end
end
```
- `key` is always a plain string, so concatenating it is safe.

#### 3. Tests
**File**: `WarlockCombatKit/tests/run.lua`
**Action**: add.

```lua
WCK.CastLanded(map, "slot:5", nil, nil, "Corruption", 400); WCK.CastLanded(map, "slot:6", nil, nil, "Corruption", 401)
eq(WCK.ClearRow(map, "slot:5"), 1, "clear row by key"); eq(map.rows["slot:5"], nil, "row gone")
eq(map.rows["slot:6"] ~= nil, true, "other row kept"); eq(WCK.ClearRow(map, "slot:5"), 0, "nothing left to clear")
WCK.ClearAll(map)
```

#### 4. Docs and release
**File**: `WarlockCombatKit/README.md`
**Action**: replace the "Dungeons and battlegrounds are untested" bullet in `## Notes` (about line 117) with:

```markdown
- **Dungeons.** Forever hides enemy GUIDs and names from addons in dungeons. Rows are keyed by the cast's target name, or by a slot per target switch, and labelled with the mob's name (shown by the game) or "Enemy N". Tabbing back to a mob you already dotted may start a second row. A dead target's row clears; other dead mobs' rows clear when combat ends. The nameplate marker stays off in instances. Battlegrounds are untested.
```
Adjust the wording to match what the Phase 1 probe actually found. For example, drop "names" if names stayed readable.

**File**: `WarlockCombatKit/CHANGELOG.md`
**Action**: rename `## [Unreleased]` to `## [0.2.2] — <date>` and add to `### Fixed`: "In dungeons, a dead target's row clears even when the game hides its GUID."

**File**: `WarlockCombatKit/WarlockCombatKit.toc`
**Action**: change `## Version: 0.2.1` to `## Version: 0.2.2`.

### Verification
#### Automated
- [x] `lua WarlockCombatKit/tests/run.lua` prints `all tests passed`
- [x] luacheck shows no new warnings
- [x] `grep -n "Version: 0.2.2" WarlockCombatKit/WarlockCombatKit.toc` matches
- [x] robocopy deploy exits 0-7

#### Manual
- [x] Dungeon: dot 3 mobs and kill the target. Its row disappears within about 0.5s and the others stay. `/wck probe` trace shows `CLR_TARGET slot:N rows=1` (or `name:` / `guid:`).
- [x] Open world: killing a dotted target clears its row (`CLR_TARGET Creature-... rows=1`), as before.
