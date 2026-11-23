local ADDON, TB = ...

function TB.MergeDefaults(sv, defaults)
  if type(sv) ~= "table" then sv = {} end
  for k, v in pairs(defaults) do
    if type(v) == "table" then sv[k] = TB.MergeDefaults(sv[k], v)
    elseif sv[k] == nil then sv[k] = v end
  end
  return sv
end

function TB.FormatTime(sec)
  return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

function TB.SkillText(s)
  if not s then return "No Fishing skill" end
  local mod = (s.modifier or 0) > 0 and (" (+" .. s.modifier .. ")") or ""
  return "Fishing " .. s.level .. "/" .. s.max .. mod
end

-- sections = { {key, title, empty?, rows={...}} }; returns the active tab's rows and its key
-- unknown key falls back to the first tab; an empty tab gets one placeholder row
function TB.TabRows(sections, active)
  local pick = sections[1]
  for _, s in ipairs(sections) do if s.key == active then pick = s end end
  if not pick then return {}, nil end
  if #pick.rows == 0 then return { { text = pick.empty or "Nothing here yet.", empty = true } }, pick.key end
  return pick.rows, pick.key
end

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

local function LureFor(lures, need)
  for _, l in ipairs(lures) do if l.bonus >= need then return l end end
end

-- one zone row; shared by the Where tab and the header zone line
local function ZoneRow(z, name, skill, lures, currentZone)
  local sub, need
  if z.noLoss then sub = "no get-aways at " .. z.noLoss else sub = "skill " .. z.band .. "-" .. z.max end
  if z.lure and (skill.modifier or 0) < z.lure then
    local l = LureFor(lures, z.lure); need = l and l.name or ("+" .. z.lure .. " lure"); sub = sub .. ", needs " .. need
  end
  local flag
  if name == currentZone then
    local eff = skill.level + (skill.modifier or 0)
    if eff < (z.cast or 1) then flag = "too low" elseif skill.level >= z.max then flag = "outgrown" else flag = "here" end
  end
  return { text = name .. (flag and (" [" .. flag .. "]") or ""), sub = sub, flag = flag, need = need }
end

-- recommended = groups whose band contains the base skill; the current zone always gets a row with a flag
function TB.WhereRows(zones, lures, skill, currentZone)
  if not skill then return {} end
  local rows, seen = {}, {}
  for _, z in ipairs(zones) do
    if skill.level >= z.band and skill.level < z.max then
      for _, n in ipairs(z.names) do rows[#rows + 1] = ZoneRow(z, n, skill, lures, currentZone); seen[n] = true end
    end
  end
  -- current zone outside the band: appended last so the flag still shows
  for _, z in ipairs(zones) do for _, n in ipairs(z.names) do
    if n == currentZone and not seen[n] then rows[#rows + 1] = ZoneRow(z, n, skill, lures, currentZone); seen[n] = true end
  end end
  return rows
end

-- header line for the zone you stand in; nil without Fishing or a zone name
function TB.ZoneStatus(zones, lures, skill, zone)
  if not skill or not zone or zone == "" then return nil end
  for _, z in ipairs(zones) do for _, n in ipairs(z.names) do
    if n == zone then
      local r = ZoneRow(z, n, skill, lures, zone)
      return { text = n .. ": skill " .. z.band .. "-" .. z.max .. " [" .. r.flag .. "]" .. (r.need and (", needs " .. r.need) or ""), flag = r.flag }
    end
  end end
  return { text = zone .. ": no fishing data" }
end

function TB.IsFishingCatch(isFishingLoot, lastChannel, now, spells)
  if isFishingLoot ~= nil then return isFishingLoot end
  return lastChannel ~= nil and spells[lastChannel.spellID] == true and now - (lastChannel.stopT or now) <= 30
end

-- quality comes from the loot slot: Forever has no separate Uncommon/Rare fish items (probe-results.md),
-- so a better catch is the same item ID with higher loot quality; keep the best seen
function TB.RecordCatch(catches, id, qty, now, zone, quality)
  local c = catches[id] or { n = 0, first = now, zones = {} }
  c.n, c.last = c.n + (qty or 1), now
  if quality and quality > (c.q or -1) then c.q = quality end
  if zone then c.zones[zone] = (c.zones[zone] or 0) + (qty or 1) end
  catches[id] = c
  return catches
end

local Q2TIER = { [2] = "uncommon", [3] = "rare" }
-- rows grouped uncommon, rare, unique, other; known-but-uncaught show as "not caught"
function TB.CollectionView(fish, catches, qualityOf)
  local groups, order = { uncommon = {}, rare = {}, unique = {}, other = {} }, { "uncommon", "rare", "unique", "other" }
  local ids = {}
  for id in pairs(fish) do ids[id] = true end
  for id in pairs(catches) do ids[id] = true end
  for id in pairs(ids) do
    local c = catches[id]
    local q = (c and c.q) or qualityOf(id)
    local tier = fish[id] and fish[id].tier or Q2TIER[q or -1] or "other"
    local sub = c and ("caught " .. c.n) or "not caught"
    table.insert(groups[tier], { itemID = id, tier = tier, caught = c ~= nil, quality = q, sub = sub, knife = fish[id] and fish[id].knife })
  end
  local rows = {}
  for _, t in ipairs(order) do
    table.sort(groups[t], function(a, b) return a.itemID < b.itemID end)
    for _, r in ipairs(groups[t]) do rows[#rows + 1] = r end
  end
  return rows
end

-- top n zones by count, for the catch tooltip
function TB.TopZones(zones, n)
  local list = {}
  for z, c in pairs(zones or {}) do list[#list + 1] = { zone = z, n = c } end
  table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.zone < b.zone end)
  for i = #list, n + 1, -1 do list[i] = nil end
  return list
end

-- channel times are ms (UnitChannelInfo); nil when unusable
function TB.CastProgress(startMs, endMs, nowMs)
  if type(startMs) ~= "number" or type(endMs) ~= "number" or endMs <= startMs then return nil end
  local f = (nowMs - startMs) / (endMs - startMs)
  f = math.max(0, math.min(1, f))
  return f, math.max(0, (endMs - nowMs) / 1000)
end

-- loot lands ~10ms after CHANNEL_STOP (probe run 4); allow 0.5s either way
function TB.IsMiss(stopT, lastLootT)
  return not (lastLootT and lastLootT >= stopT - 0.5)
end

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

-- first owned item the player can use; if none is usable, the first owned one with usable=false (button greys out)
function TB.WaterWalkPick(items, counts, auraActive, level, minLevel)
  if auraActive then return nil end
  local locked
  for _, id in ipairs(items) do
    if (counts[id] or 0) > 0 then
      if (level or 0) >= ((minLevel or {})[id] or 0) then return id, true end
      locked = locked or id
    end
  end
  return locked, false
end

-- items = { {id, classID, subID} }; fishing poles are weapon class 2, subclass 20 (probe run 1: Fishing Pole 6256)
-- ponytail: first pole found; rank by pole bonus if players carry several
function TB.PickPole(items)
  for _, it in ipairs(items) do if it.classID == 2 and it.subID == 20 then return it.id end end
end

-- best-bonus lure the skill allows, nil while the pole already has a lure on it;
-- if only too-advanced lures are owned, the lowest-requirement one with usable=false (button greys out)
function TB.PickLure(lures, counts, lureActive, skill)
  if lureActive then return nil end
  local best, locked
  for _, l in ipairs(lures) do
    if l.id and (counts[l.id] or 0) > 0 then
      if (skill or 0) >= (l.req or 0) then
        if not best or l.bonus > best.bonus then best = l end
      elseif not locked or l.req < locked.req then
        locked = l
      end
    end
  end
  if best then return best.id, true end
  if locked then return locked.id, false, locked.req end
end

-- bag entry for a remembered weapon: exact link first (same enchant/suffix), then any copy by id
function TB.FindWeapon(items, want)
  if not want then return nil end
  local byId
  for _, it in ipairs(items) do
    if want.link and it.link == want.link then return it end
    if not byId and it.id == want.id then byId = it end
  end
  return byId
end

-- /equipslot by bag+slot avoids picking the wrong copy of a duplicate item
function TB.WeaponsMacro(mh, oh)
  if not mh then return nil end
  local m = "/equipslot 16 " .. mh.bag .. " " .. mh.slot
  if oh then m = m .. "\n/equipslot 17 " .. oh.bag .. " " .. oh.slot end
  return m
end

-- "/tb bind f" -> "F"; modifiers keep their case-folded form ("shift-f" -> "SHIFT-F"); empty -> nil
function TB.NormalizeKey(s)
  if type(s) ~= "string" then return nil end
  s = s:match("^%s*(.-)%s*$"):upper()
  return s ~= "" and s or nil
end

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
    for _, k in ipairs(s.pools) do
      local p = TB.PoolByKey(pools, k)
      if p then pnames[#pnames + 1] = p.name; icon = icon or p.icon end
    end
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
