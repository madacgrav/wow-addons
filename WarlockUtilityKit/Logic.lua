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

function WUK.FormatTime(sec)
  return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

-- state = { known = {key=spellName}, counts = Counts, buffs = {[buffName]=true, demonicSacrifice=bool},
--           pet = "imp"|"voidwalker"|... |nil, preferredPet = string, soulstoneActive = bool }
function WUK.PrepSteps(s)
  local k, b, c, out = s.known, s.buffs, s.counts, {}
  local function add(key, macro) out[#out + 1] = { key = key, macro = macro } end
  if k.armor and not b[k.armor] then add("armor", "/cast " .. k.armor) end
  if k.detect and not b[k.detect] then add("detect", "/cast " .. k.detect) end
  if not b.demonicSacrifice then
    local want = s.preferredPet
    if want ~= "imp" and c.shard == 0 then want = "imp" end
    if not k[want] then want = "imp" end
    -- any pet is fine when the preferred one is unaffordable; avoids swapping Felhunter for Imp
    local satisfied = s.pet == s.preferredPet or (s.pet ~= nil and want ~= s.preferredPet)
    if not satisfied and k[want] then add("pet", "/cast " .. k[want]) end
    if k.soullink and s.pet and not b[k.soullink] then add("soullink", "/cast " .. k.soullink) end
  end
  if k.healthstone and c.healthstone == 0 and c.shard > 0 then add("healthstone", "/cast " .. k.healthstone) end
  if k.soulstone and c.soulstone == 0 and not s.soulstoneActive and c.shard > 0 then
    add("soulstone", "/cast " .. k.soulstone)
  end
  if c.soulstone > 0 and not s.soulstoneActive and c.ids.soulstone then
    add("usesoulstone", "/target player\n/use item:" .. c.ids.soulstone .. "\n/targetlasttarget")
  end
  return out
end

function WUK.SoulstoneRemaining(rec, now)
  if type(rec) ~= "table" or not rec.expires then return nil end
  local r = rec.expires - now
  if r <= 0 then return nil end
  return r
end
