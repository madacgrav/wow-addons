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

-- nil for anything secret; guid > name > current target (raid marks turn secret in combat once set)
function WCK.EnemyKey(guid, name)
  if guid then return "guid:" .. guid, name end
  if name then return "name:" .. name, name end
  return "target", nil
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
    out[#out + 1] = { key = row.key, label = row.label, last = row.last, icons = icons }
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
