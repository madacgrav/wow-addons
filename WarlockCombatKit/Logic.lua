local ADDON, WCK = ...

function WCK.MergeDefaults(sv, defaults)
  if type(sv) ~= "table" then sv = {} end
  for k, v in pairs(defaults) do
    if type(v) == "table" then sv[k] = WCK.MergeDefaults(sv[k], v)
    elseif sv[k] == nil then sv[k] = v end
  end
  return sv
end

-- cast map: what I cast, keyed per enemy; all times are GetTime() seconds
function WCK.NewCastMap() return { pending = {}, rows = {} } end

-- nil for anything secret; guid > name > target slot (one per target switch) > current target
-- (raid marks turn secret in combat once set; dungeons hide guid and name in combat)
function WCK.EnemyKey(guid, name, slot)
  if guid then return "guid:" .. guid, name end
  if name then return "name:" .. name, name end
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

-- which unit token the SENT target name refers to (names = {token = non-secret name or nil})
-- target first: in a pack of same-named mobs the hovered one is usually not the one being cast on
local TOKENS = { "target", "mouseover", "focus" }
function WCK.PickUnit(sentName, names)
  if sentName then
    for _, u in ipairs(TOKENS) do if names[u] == sentName then return u end end
  end
  return "target"
end

-- secret = { rawName } when the unit's name is secret (never compared, only handed to SetText)
function WCK.CastSent(map, castGUID, spell, key, label, guid, now, secret)
  if not castGUID or not spell or not key then return end
  for g, p in pairs(map.pending) do if now - p.t > 10 then map.pending[g] = nil end end -- lost SUCCEEDED/FAILED
  map.pending[castGUID] = { spell = spell, key = key, label = label, guid = guid, t = now, secret = secret }
end

function WCK.CastLanded(map, key, label, guid, spell, now, secret)
  local row = map.rows[key]
  if not row then row = { key = key, casts = {} }; map.rows[key] = row end
  row.label, row.guid, row.last = label or row.label, guid or row.guid, now
  row.secret = secret or row.secret
  row.casts[spell] = now
end

function WCK.CastSucceeded(map, castGUID, now)
  local p = castGUID and map.pending[castGUID]
  if not p then return end
  map.pending[castGUID] = nil
  WCK.CastLanded(map, p.key, p.label, p.guid, p.spell, now, p.secret)
end

function WCK.CastFailed(map, castGUID) if castGUID then map.pending[castGUID] = nil end end
-- returns 1 if a row was cleared, else 0
function WCK.ClearRow(map, key)
  if not map.rows[key] then return 0 end
  map.rows[key] = nil; return 1
end
-- returns how many rows it cleared
function WCK.ClearGUID(map, guid)
  local n = 0
  for k, row in pairs(map.rows) do if row.guid == guid then map.rows[k] = nil; n = n + 1 end end
  return n
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
    out[#out + 1] = { key = row.key, label = row.label, secret = row.secret, last = row.last, icons = icons }
  end
  table.sort(out, function(a, b) return a.last > b.last end)
  return out
end

-- a view row (from RowsView) holds a CC cast that isn't stale yet
function WCK.RowHasCC(viewRow)
  for _, i in ipairs(viewRow.icons) do if i.kind == "cc" and i.age < i.stale then return true end end
  return false
end

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

-- spellbook rows {tab, name, itemType, isPassive} -> tabs {{name, spells={sorted}}} in book order, set {[name]=true}
-- itemType 1 = Enum.SpellBookItemType.Spell (FutureSpell/Flyout/PetAction dropped); passives dropped; first tab wins a duplicate
function WCK.BuildSpellTabs(entries)
  local tabs, set, byTab = {}, {}, {}
  for _, e in ipairs(entries) do
    if e.itemType == 1 and not e.isPassive and type(e.name) == "string" and e.name ~= "" and not set[e.name] then
      local t = byTab[e.tab]
      if not t then t = { name = e.tab, spells = {} }; byTab[e.tab] = t; tabs[#tabs + 1] = t end
      t.spells[#t.spells + 1] = e.name; set[e.name] = true
    end
  end
  for _, t in ipairs(tabs) do table.sort(t.spells) end
  return tabs, set
end

-- distinct non-empty rule spells, in rule order
function WCK.RuleSpells(rules)
  local out, seen = {}, {}
  for _, r in ipairs(rules or {}) do
    local s = r.spell
    if type(s) == "string" and s ~= "" and not seen[s] then seen[s] = true; out[#out + 1] = s end
  end
  return out
end

-- rotation bar order: rule spells not in the tail (and not the core spell), then the known tail spells (tail order)
WCK.BAR_MAX = 13 -- 10 rules + Shadow Bolt/Fear/Banish
function WCK.BarSpells(rules, tail, known, core)
  local out, inTail = {}, {}
  for _, s in ipairs(tail) do inTail[s] = true end
  for _, s in ipairs(WCK.RuleSpells(rules)) do
    if not inTail[s] and s ~= core then out[#out + 1] = { spell = s, tail = false } end
  end
  for _, s in ipairs(tail) do
    if known[s] then out[#out + 1] = { spell = s, tail = true } end
  end
  return out
end

-- cd = non-secret fields of C_Spell.GetSpellCooldown (secret ones already nil'd); onCD true only for a real
-- cooldown (GCD alone does not count), nil when unknown; endsAt = startTime + duration when both are known
function WCK.CooldownState(cd)
  if type(cd) ~= "table" or cd.isActive == nil then return nil end
  if not cd.isActive or cd.isOnGCD == true then return false end
  local s, d = cd.startTime, cd.duration
  return true, (type(s) == "number" and type(d) == "number") and s + d or nil
end

-- bar button look: dim = spell on its own cooldown; fel = a proc on this spell is up -- visual only, it stays clickable
function WCK.ButtonLook(spell, onCD, procs, procList)
  local fel = false
  for _, p in ipairs(procList) do if p.spell == spell and procs[p.key] then fel = true end end
  return { dim = onCD == true, fel = fel }
end

-- mouseover cast slots: hostile mouseover, else the normal target
WCK.SLOTS = 6
function WCK.CastMacro(spell)
  if type(spell) ~= "string" or spell == "" then return "" end
  return "/cast [@mouseover,harm,nodead][] " .. spell
end
