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
function BC.Classify(text)
  if type(text) ~= "string" then return nil end
  local cats, any, req, offer, dest = {}, false, false, false, nil
  for w in BC.StripLinks(text):lower():gmatch("%w+") do
    for cat, words in pairs(BC.WORDS) do if words[w] then cats[cat] = true; any = true end end
    req = req or BC.REQUEST_WORDS[w] or false
    offer = offer or BC.OFFER_WORDS[w] or false
    dest = dest or BC.PORTAL_DEST[w]
  end
  if not any then return nil end
  return { cats = cats, request = req and not offer, dest = cats.portal and dest or nil }
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
