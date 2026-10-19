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
