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

function TB.WaterWalkPick(items, counts, auraActive)
  if auraActive then return nil end
  for _, id in ipairs(items) do if (counts[id] or 0) > 0 then return id end end
end
