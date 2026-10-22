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
