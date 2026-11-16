local ADDON, BC = ...

function BC.MergeDefaults(sv, defaults)
  if type(sv) ~= "table" then sv = {} end
  for k, v in pairs(defaults) do
    if type(v) == "table" then sv[k] = BC.MergeDefaults(sv[k], v)
    elseif sv[k] == nil then sv[k] = v end
  end
  return sv
end

-- probe: channelBaseName is "Trade - English 53", "Trade (Services) - English 53", "General - Orgrimmar"; key = text before " - "
function BC.ChannelKey(base) if type(base) ~= "string" then return nil end return base:match("^(.-) %- ") or base end

-- strip colour codes and hyperlink payloads, keeping the visible [link text]
function BC.StripLinks(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")) end

-- returns { cats = {cat=true}, request = bool, dest = "ORG"? } or nil when nothing matched
-- request = true means "not an advertisement": a request word, or no offer signal at all
function BC.Classify(text)
  if type(text) ~= "string" then return nil end
  local cats, any, req, offer, dest = {}, false, false, false, nil
  for w in BC.StripLinks(text):lower():gmatch("%w+") do
    for cat, words in pairs(BC.WORDS) do if words[w] then cats[cat] = true; any = true end end
    req = req or BC.REQUEST_WORDS[w] or false
    offer = offer or BC.OFFER_WORDS[w] or w:match("^%d+g$") ~= nil
    dest = dest or BC.PORTAL_DEST[w]
  end
  if not any then return nil end
  offer = offer or text:find("|Htrade:", 1, true) ~= nil
  return { cats = cats, request = req or not offer, dest = cats.portal and dest or nil }
end

function BC.SeenAdd(seen, name, r, text, now)
  local e = seen[name] or { cats = {} }
  for cat in pairs(r.cats) do e.cats[cat] = now end
  e.text, e.at, e.req, e.dest = text:sub(1, 120), now, r.request, r.dest or e.dest
  seen[name] = e
  return e
end

-- drop entries older than maxAge seconds, then the oldest beyond cap
function BC.SeenPrune(seen, now, maxAge, cap)
  local keep = {}
  for name, e in pairs(seen) do
    if now - (e.at or 0) > maxAge then seen[name] = nil else keep[#keep + 1] = name end
  end
  if #keep > cap then
    table.sort(keep, function(a, b) return seen[a].at > seen[b].at end)
    for i = cap + 1, #keep do seen[keep[i]] = nil end
  end
end

function BC.FormatAge(s)
  if s < 60 then return "now" elseif s < 3600 then return math.floor(s / 60) .. "m"
  elseif s < 86400 then return math.floor(s / 3600) .. "h" end
  return math.floor(s / 86400) .. "d"
end

-- filter = cat key or "all"; rows sorted newest first. cards is nil until Phase 5
function BC.SeenRows(seen, cards, filter, now)
  local rows = {}
  for name, e in pairs(seen) do
    if filter == "all" or e.cats[filter] then
      rows[#rows + 1] = { name = name, cats = e.cats, at = e.at, age = BC.FormatAge(now - e.at), text = e.text,
        dest = e.dest, card = cards and cards[name] }
    end
  end
  table.sort(rows, function(a, b) return a.at > b.at end)
  return rows
end

function BC.CatList(cats) -- "Enchanting, Portals" in BC.CATS order
  local out = {}
  for _, c in ipairs(BC.CATS) do if cats[c] then out[#out + 1] = BC.CAT_LABEL[c] end end
  return table.concat(out, ", ")
end
