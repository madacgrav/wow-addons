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

-- zone from a channel name: "General - Orgrimmar" -> "Orgrimmar"; "Trade - English 53" is a language channel, not a zone
function BC.ChannelZone(base)
  local z = type(base) == "string" and base:match(" %- (.+)$")
  if not z or z:match("^%a+ %d+$") then return nil end
  return z
end

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

function BC.SeenAdd(seen, name, r, text, now, zone)
  local e = seen[name] or { cats = {} }
  for cat in pairs(r.cats) do e.cats[cat] = now end
  e.text, e.at, e.req, e.dest = text:sub(1, 120), now, r.request, r.dest or e.dest
  e.zone = zone or e.zone
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
        dest = e.dest, card = cards and cards[name], zone = (cards and cards[name] and cards[name].zone) or e.zone }
    end
  end
  for name, c in pairs(cards or {}) do -- guildmates who never advertised
    local cats = BC.CardCats(c)
    if not seen[name] and (filter == "all" or cats[filter]) then
      rows[#rows + 1] = { name = name, cats = cats, at = c.at or 0, age = BC.FormatAge(now - (c.at or 0)), card = c,
        zone = c.zone }
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

-- profs = {{id, name, skill}}, svcs = {key...}, status = {g="a"|"b", [statusKey]="a"|"b"|"o"}
-- Card = {rev, g, profs={{id, skill, st}}, svcs={{key, st}}}
function BC.BuildCard(profs, svcs, status, rev, zone)
  local c = { rev = rev, g = status.g or "a", profs = {}, svcs = {}, zone = zone }
  for _, p in ipairs(profs) do c.profs[#c.profs + 1] = { id = p.id, skill = p.skill, st = status["p" .. p.id] or "a" } end
  for _, k in ipairs(svcs) do c.svcs[#c.svcs + 1] = { key = k, st = status[k] or "a" } end
  return c
end

function BC.SetStatus(char, key, st) -- key "g", "p<id>" or a service key
  if char.status[key] == st then return false end
  char.status[key] = st; char.rev = char.rev + 1
  return true
end

local NEXT = { a = "b", b = "o", o = "a" }
function BC.NextStatus(st) return NEXT[st or "a"] end

BC.PROTO = "1"
local function enc(v) if v == nil or v == "" then return "-" end return tostring(v) end
function BC.Split(msg) local f = {} for p in (msg .. "|"):gmatch("(.-)|") do f[#f + 1] = p end return f end

-- 1|C|rev|g|profs|svcs   profs = id:skill:st,...   svcs = key:st,...
function BC.EncodeCard(c)
  local p, s = {}, {}
  for _, x in ipairs(c.profs) do p[#p + 1] = x.id .. ":" .. x.skill .. ":" .. x.st end
  for _, x in ipairs(c.svcs) do s[#s + 1] = x.key .. ":" .. x.st end
  local zone = c.zone and c.zone:gsub("|", ""):sub(1, 40) -- 7th field; older 6-field cards still decode
  return table.concat({ BC.PROTO, "C", c.rev, c.g, enc(table.concat(p, ",")), enc(table.concat(s, ",")), enc(zone) }, "|")
end

local ST = { a = true, b = true, o = true }
function BC.Decode(msg)
  if type(msg) ~= "string" then return nil end
  local f = BC.Split(msg)
  if f[1] ~= BC.PROTO then return nil end
  if f[2] == "Q" and #f == 2 then return { kind = "Q" } end
  if f[2] == "C" and (#f == 6 or #f == 7) and tonumber(f[3]) and ST[f[4]] then
    local c = { kind = "C", rev = tonumber(f[3]), g = f[4], profs = {}, svcs = {}, zone = f[7] ~= "-" and f[7] or nil }
    if f[5] ~= "-" then for id, sk, st in f[5]:gmatch("(%d+):(%d+):(%a)") do
      c.profs[#c.profs + 1] = { id = tonumber(id), skill = tonumber(sk), st = st } end end
    if f[6] ~= "-" then for k, st in f[6]:gmatch("([%w%-]+):(%a)") do c.svcs[#c.svcs + 1] = { key = k, st = st } end end
    return c
  end
  if f[2] == "RQ" and #f == 3 and tonumber(f[3]) then return { kind = "RQ", prof = tonumber(f[3]) } end
  if f[2] == "RL" and #f == 6 then
    local prof, seq, total = tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
    if prof and seq and total and seq <= total then
      return { kind = "RL", prof = prof, seq = seq, total = total, part = f[6] ~= "-" and f[6] or "" }
    end
  end
end

BC.PROF_CAT = { [333] = "enchanting", [197] = "tailoring", [165] = "leatherworking", [171] = "alchemy", [164] = "blacksmithing",
  [202] = "engineering", [755] = "jewelcrafting", [185] = "cooking", [129] = "firstaid" }
local function SvcCat(key) return key == "S" and "summon" or "portal" end

-- categories a card advertises (status not "o"), for card-only Seen rows
function BC.CardCats(c)
  local cats = {}
  for _, p in ipairs(c.profs) do if p.st ~= "o" and BC.PROF_CAT[p.id] then cats[BC.PROF_CAT[p.id]] = true end end
  for _, s in ipairs(c.svcs) do if s.st ~= "o" then cats[SvcCat(s.key)] = true end end
  return cats
end

-- "a" if globally available and an entry for cat is available, "b" if busy, nil if unknown or the card lists nothing for cat
function BC.CardStatus(c, cat)
  if not c then return nil end
  local found
  for _, p in ipairs(c.profs) do
    if (cat == "all" or BC.PROF_CAT[p.id] == cat) and p.st ~= "o" then found = found == "a" and "a" or p.st end
  end
  for _, s in ipairs(c.svcs) do
    if (cat == "all" or SvcCat(s.key) == cat) and s.st ~= "o" then found = found == "a" and "a" or s.st end
  end
  if found and c.g == "b" then return "b" end
  return found
end

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
function BC.B36(n)
  local s = ""
  repeat local d = n % 36; s = DIGITS:sub(d + 1, d + 1) .. s; n = math.floor(n / 36) until n == 0
  return s
end

-- comma-joined base-36 ids, each chunk <= maxBytes
function BC.ChunkIDs(ids, maxBytes)
  local chunks, cur, len = {}, {}, 0
  for _, id in ipairs(ids) do
    local t = BC.B36(id)
    if len > 0 and len + 1 + #t > maxBytes then chunks[#chunks + 1] = table.concat(cur, ","); cur, len = {}, 0 end
    cur[#cur + 1] = t; len = len + (len > 0 and 1 or 0) + #t
  end
  if #cur > 0 then chunks[#chunks + 1] = table.concat(cur, ",") end
  return chunks
end

-- buf[key] = {total, parts={}, n, at}; returns the full id list when complete, {} for total 0, else nil
function BC.Reassemble(buf, key, seq, total, part, now)
  for k, b in pairs(buf) do if now - b.at > 30 then buf[k] = nil end end
  if total == 0 then return {} end
  local b = buf[key]
  if not b or b.total ~= total then b = { total = total, parts = {}, n = 0, at = now }; buf[key] = b end
  if not b.parts[seq] then b.parts[seq] = part; b.n = b.n + 1 end
  if b.n < total then return nil end
  buf[key] = nil
  local ids = {}
  for i = 1, total do for t in (b.parts[i] or ""):gmatch("[^,]+") do ids[#ids + 1] = tonumber(t, 36) end end
  return ids
end
