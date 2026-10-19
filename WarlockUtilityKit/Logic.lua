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
function WUK.StoneMacro(kind, count, itemID, createSpell)
  if kind == "shard" then return nil end
  if count > 0 and itemID then
    if kind == "soulstone" then return "/use [help] item:" .. itemID .. "; [@player] item:" .. itemID end
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
