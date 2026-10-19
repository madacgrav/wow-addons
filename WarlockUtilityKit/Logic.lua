local ADDON, WUK = ...

-- ponytail: enUS name matching; add a per-locale table when non-English clients matter
local STONES = {
  { "Soul Shard", "shard" }, { "Healthstone", "healthstone" }, { "Soulstone", "soulstone" },
  { "Spellstone", "spellstone" }, { "Firestone", "firestone" },
}

function WUK.ClassifyItem(name)
  if type(name) ~= "string" then return nil end
  for _, s in ipairs(STONES) do
    if name:find(s[1], 1, true) then return s[2] end
  end
end

function WUK.MergeDefaults(sv, defaults)
  if type(sv) ~= "table" then sv = {} end
  for k, v in pairs(defaults) do
    if type(v) == "table" then sv[k] = WUK.MergeDefaults(sv[k], v)
    elseif sv[k] == nil then sv[k] = v end
  end
  return sv
end

-- stone icon click: use the stone if held (soulstone on friendly target, else self), otherwise create one
function WUK.StoneMacro(kind, count, itemID, createSpell, ssTarget)
  if kind == "shard" then return nil end
  if count > 0 and itemID then
    if kind == "soulstone" then
      if ssTarget then return "/use [@" .. ssTarget .. "] item:" .. itemID end
      return "/use [help] item:" .. itemID .. "; [@player] item:" .. itemID
    end
    return "/use item:" .. itemID
  end
  return createSpell and ("/cast " .. createSpell) or nil
end

function WUK.FormatTime(sec)
  return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

local function HasWord(text, words)
  if type(text) ~= "string" then return false end
  for w in text:lower():gmatch("%w+") do if words[w] then return true end end
  return false
end
WUK.HasWord = HasWord

local SUMMON_WORDS = { ["123"] = true, sum = true, summon = true, port = true }
function WUK.IsSummonRequest(text) return HasWord(text, SUMMON_WORDS) end

local HS_WORDS = { hs = true, healthstone = true }
function WUK.IsHealthstoneRequest(text) return HasWord(text, HS_WORDS) end

function WUK.QueueAdd(list, name, max)
  for _, r in ipairs(list) do if r.name == name then return false end end
  if #list >= max then return false end
  list[#list + 1] = { name = name, at = os and os.time and os.time() or 0 }
  return true
end
function WUK.QueueRemove(list, name)
  for i = #list, 1, -1 do if list[i].name == name then table.remove(list, i) end end
end
function WUK.QueuePrune(list, keep)
  for i = #list, 1, -1 do if not keep(list[i]) then table.remove(list, i) end end
end

-- ctx = { inGroup, connected, dead, here: bool?, shards: number, helpers: number? }; nil = unknown, not a failure
function WUK.SummonFailure(ctx)
  if not ctx.inGroup then return "not in group" end
  if ctx.connected == false then return "offline" end
  if ctx.dead then return "dead" end
  if ctx.here then return "already here" end
  if (ctx.shards or 0) < 1 then return "no shard" end
  if ctx.helpers and ctx.helpers < 2 then return "need 2 helpers" end
  return nil
end

function WUK.SoulstoneRemaining(rec, now)
  if type(rec) ~= "table" or not rec.expires then return nil end
  local r = rec.expires - now
  if r <= 0 then return nil end
  return r
end

WUK.CURSES = {
  { key = "elements", name = "Curse of the Elements", short = "Elements" },
  { key = "recklessness", name = "Curse of Recklessness", short = "Recklessness" },
  { key = "tongues", name = "Curse of Tongues", short = "Tongues" },
  { key = "weakness", name = "Curse of Weakness", short = "Weakness" },
  { key = "exhaustion", name = "Curse of Exhaustion", short = "Exhaustion" },
  { key = "shadow", name = "Curse of Shadow", short = "Shadow" }, -- may not exist on Forever; board lists it only if known
}
local CURSE_BY_KEY = {}
for _, c in ipairs(WUK.CURSES) do CURSE_BY_KEY[c.key] = c end
function WUK.CurseInfo(key) return CURSE_BY_KEY[key] end

function WUK.MarkToken(mark)
  if type(mark) == "number" and mark >= 1 and mark <= 8 then return "{rt" .. mark .. "}" end
  return ""
end

-- markFmt: MarkToken for chat, a texture-escape function for FontStrings
function WUK.AssignmentText(row, markFmt)
  if not row then return "No assignment" end
  markFmt = markFmt or WUK.MarkToken
  local parts = {}
  if row.curse then local c = CURSE_BY_KEY[row.curse]; parts[#parts + 1] = c and c.short or row.curse end
  if (row.mark or 0) > 0 then parts[#parts + 1] = "Banish " .. markFmt(row.mark) end
  if row.ss then parts[#parts + 1] = "SS: " .. row.ss end
  if #parts == 0 then return "No assignment" end
  return table.concat(parts, "  ")
end

function WUK.NextRev(rev, now) return math.max(now, (rev or 0) + 1) end

local PROTO = "1"
local function enc(v) if v == nil or v == "" then return "-" end return tostring(v) end
local function dec(s) if s == "-" then return nil end return s end

-- 1|L|rev  1|A|rev|warlock|curse|mark|ss  1|R  1|E|rev ; "-" = nil
function WUK.Encode(kind, ...)
  local parts = { PROTO, kind }
  for i = 1, select("#", ...) do parts[#parts + 1] = enc((select(i, ...))) end
  return table.concat(parts, "|")
end

function WUK.Decode(msg)
  if type(msg) ~= "string" then return nil end
  local f = {}
  for p in (msg .. "|"):gmatch("(.-)|") do f[#f + 1] = p end
  if f[1] ~= PROTO then return nil end
  local kind = f[2]
  if kind == "R" and #f == 2 then return { kind = "R" } end
  if (kind == "L" or kind == "E") and #f == 3 and tonumber(f[3]) then return { kind = kind, rev = tonumber(f[3]) } end
  if kind == "A" and #f == 7 and tonumber(f[3]) and tonumber(f[6]) and dec(f[4]) then
    return { kind = "A", rev = tonumber(f[3]), warlock = f[4], curse = dec(f[5]), mark = tonumber(f[6]), ss = dec(f[7]) }
  end
  return nil
end

function WUK.AcceptLead(board, rev) return rev > (board.rev or 0) end
function WUK.AcceptRow(board, sender, rev) return sender == board.lead and rev >= (board.rev or 0) end
